"""Corrige las glosas de las frases que marcó la revisión.

    python tool/rag_corregir_glosas.py              # las marcadas para revisar
    python tool/rag_corregir_glosas.py --menores    # también las menores

Toma las frases de `docs/negocio/rag/revision_glosas.json` con algo que
falta o sobra y las manda a la Lambda LSB→Texto/Audio (`action: "corregir"`,
ver `aws/rag_revision.py`): Bedrock propone glosas con lo que falta y sin lo
que sobra, usando solo señas del catálogo oficial; la Lambda rechaza
cualquier glosa inventada y vuelve a comparar la corrección con la frase.
Solo se guarda si deja menos errores que antes.

Escribe `docs/negocio/rag/glosas_correcciones.json` (frase → glosas
corregidas, las de antes y lo que aún falta o sobra).
`tool/build_rag_corpus.py` usa esas glosas en lugar de las de la caché de
traducción. Después, `tool/rag_revisar_glosas.py` vuelve a revisar las
frases corregidas (sus glosas cambiaron).
"""

from __future__ import annotations

import concurrent.futures
import datetime
import json
import os
import sys
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

from build_rag_corpus import CORRECCIONES, ROOT  # noqa: E402
from rag_revisar_glosas import CACHE, frases  # noqa: E402

TANDA = 8
HILOS = 2
REINTENTOS = 4


def main() -> int:
    with open(CACHE, encoding="utf-8") as f:
        revision = json.load(f)
    roles = {t: rol for t, _, rol in frases()}
    menores = "--menores" in sys.argv
    marcadas = [
        {"texto": t, "glosas": r["glosas"], "faltan": r["faltan"],
         "sobran": r["sobran"], "rol": roles.get(t, "sordo")}
        for t, r in sorted(revision.items())
        if t in roles and (r.get("faltan") or r.get("sobran"))
        and (menores or not r.get("leve"))
    ]
    correcciones = {}
    if os.path.exists(CORRECCIONES):
        with open(CORRECCIONES, encoding="utf-8") as f:
            correcciones = json.load(f)
    # Una frase ya corregida se revisa con sus glosas nuevas: si aún está
    # marcada, se intenta de nuevo sobre ellas.
    print(f"marcadas: {len(marcadas)}")
    if not marcadas:
        return 0
    from rag_indexar_embeddings import endpoint, llamar
    url = endpoint()
    hoy = datetime.date.today().isoformat()

    def corregir(tanda):
        r = {}
        for intento in range(REINTENTOS):
            try:
                r = llamar(url, {"action": "corregir", "items": tanda})
            except SystemExit as e:
                r = {"generated": False, "reason": str(e)}
            if r.get("generated") is True:
                break
            time.sleep(3 * 2 ** intento)
        return tanda, r

    aceptadas, rechazadas, fallos = 0, [], 0
    tandas = [marcadas[i:i + TANDA] for i in range(0, len(marcadas), TANDA)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=HILOS) as pool:
        for tanda, r in pool.map(corregir, tandas):
            if r.get("generated") is not True:
                fallos += len(tanda)
                print(f"  tanda sin corregir: {r.get('reason') or r}")
                continue
            for it, res in zip(tanda, r["items"]):
                if res["aceptada"]:
                    previa = correcciones.get(it["texto"], {})
                    correcciones[it["texto"]] = {
                        "glosas": res["glosas"],
                        "antes": previa.get("antes", it["glosas"]),
                        "faltan": res["faltan"], "sobran": res["sobran"],
                        "fecha": hoy,
                    }
                    aceptadas += 1
                else:
                    rechazadas.append((it["texto"], res["motivo"],
                                       res.get("propuesta")))
            with open(CORRECCIONES, "w", encoding="utf-8", newline="") as f:
                json.dump({k: correcciones[k] for k in sorted(correcciones)},
                          f, ensure_ascii=False, indent=1)
                f.write("\n")
    # Las rechazadas por glosas ajenas o ilegibles se reintentan de a una: en
    # tandas, el modelo a veces corre las respuestas un lugar.
    sueltas = [por for por in rechazadas
               if not por[1].startswith("no mejora")]
    por_texto_m = {it["texto"]: it for it in marcadas}
    for texto, _, _ in sueltas:
        _, r = corregir([por_texto_m[texto]])
        if r.get("generated") is not True:
            continue
        res = r["items"][0]
        rechazadas = [x for x in rechazadas if x[0] != texto]
        if res["aceptada"]:
            correcciones[texto] = {
                "glosas": res["glosas"],
                "antes": correcciones.get(texto, {}).get(
                    "antes", por_texto_m[texto]["glosas"]),
                "faltan": res["faltan"], "sobran": res["sobran"],
                "fecha": hoy}
            aceptadas += 1
        else:
            rechazadas.append((texto, res["motivo"], res.get("propuesta")))

    # Segunda pasada en el equipo: las propuestas que la Lambda rechazó se
    # validan con las reglas actuales de aws/rag_revision.py (pueden ser más
    # nuevas que las desplegadas) y se vuelven a comparar con «retrotraducir».
    sys.path.insert(0, os.path.join(ROOT, "aws"))
    import rag_revision as REV  # noqa: E402
    import rag_equivalencias as EQ  # noqa: E402
    catalogo = EQ.cargar_catalogo()
    por_texto = {it["texto"]: it for it in marcadas}
    revalidar = []
    for texto, motivo, propuesta in list(rechazadas):
        it = por_texto[texto]
        glosas, _ = (REV.glosas_validas(propuesta, texto, catalogo)
                     if isinstance(propuesta, list) else (None, []))
        if glosas:
            revalidar.append(({**it, "glosas": glosas}, it))
    for i in range(0, len(revalidar), TANDA):
        tanda = revalidar[i:i + TANDA]
        r = llamar(url, {"action": "retrotraducir", "items": [
            {"texto": c["texto"], "glosas": c["glosas"], "rol": c["rol"]}
            for c, _ in tanda]})
        if r.get("generated") is not True:
            continue
        for (cand, it), res in zip(tanda, r["items"]):
            antes = len(it["faltan"]) + len(it["sobran"])
            despues = len(res["faltan"]) + len(res["sobran"])
            if despues < antes and len(res["sobran"]) <= len(it["sobran"]):
                correcciones[it["texto"]] = {
                    "glosas": cand["glosas"], "antes": it["glosas"],
                    "faltan": res["faltan"], "sobran": res["sobran"],
                    "fecha": hoy}
                aceptadas += 1
                rechazadas = [x for x in rechazadas if x[0] != it["texto"]]
    # Lo que aún sobra en una corrección aceptada se quita (comprobado que la
    # frase no lo dice): también en las aceptadas por una Lambda anterior.
    for c in correcciones.values():
        if c.get("sobran"):
            c["glosas"] = REV.sin_sobras(c["glosas"], c["sobran"])
            c["sobran"] = []
    with open(CORRECCIONES, "w", encoding="utf-8", newline="") as f:
        json.dump({k: correcciones[k] for k in sorted(correcciones)},
                  f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"corregidas: {aceptadas} · sin corrección aceptable: "
          f"{len(rechazadas)} · sin respuesta: {fallos}")
    for texto, motivo, _ in rechazadas:
        print(f"  · «{texto}»: {motivo}")
    print(f"escrito: {os.path.relpath(CORRECCIONES, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
