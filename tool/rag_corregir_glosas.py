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
                    rechazadas.append((it["texto"], res["motivo"]))
            with open(CORRECCIONES, "w", encoding="utf-8", newline="") as f:
                json.dump({k: correcciones[k] for k in sorted(correcciones)},
                          f, ensure_ascii=False, indent=1)
                f.write("\n")
    print(f"corregidas: {aceptadas} · sin corrección aceptable: "
          f"{len(rechazadas)} · sin respuesta: {fallos}")
    for texto, motivo in rechazadas:
        print(f"  · «{texto}»: {motivo}")
    print(f"escrito: {os.path.relpath(CORRECCIONES, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
