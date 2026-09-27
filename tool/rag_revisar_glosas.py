"""Revisa que las glosas del corpus RAG digan lo mismo que su frase.

    python tool/rag_revisar_glosas.py              # solo lo nuevo o cambiado
    python tool/rag_revisar_glosas.py --todo       # vuelve a revisar todo

Para cada frase que la app muestra en LSB (respuestas de la persona sorda y
preguntas del funcionario de cada trámite), la Lambda LSB→Texto/Audio
(`action: "retrotraducir"`, ver `aws/rag_revision.py`):

- compara la frase con sus glosas y dice qué palabras faltan y qué glosas
  sobran (comprobado: solo cuenta lo que existe en la frase o en las
  glosas), y
- traduce las glosas de vuelta al español con Bedrock y compara su
  significado con la frase usando Titan (segunda señal).

Escribe:

    docs/negocio/rag/revision_glosas.json   caché (frase → glosas, vuelta,
                                            similitud); se recalcula una frase
                                            cuando cambian sus glosas
    docs/negocio/rag/revision_glosas.md     las frases con algo que falta o sobra,
                                            de la menos parecida a la más

Una frase marcada no se corrige sola: se revisa y, si falta o sobra algo, se
arregla su traducción (por ejemplo, volviendo a precalcularla o corrigiendo
la frase en el escenario).
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

from build_rag_corpus import RAG, ROOT, SALIDA, turnos_pregunta  # noqa: E402

CACHE = os.path.join(RAG, "revision_glosas.json")
INFORME = os.path.join(RAG, "revision_glosas.md")
TANDA = 8
# Tandas a la vez: cada una hace dos llamadas a Bedrock y dos embeddings por
# frase. Con 4, Bedrock devolvía error de saturación en casi todas.
HILOS = 2
# Una tanda que Bedrock rechaza por saturación se reintenta tras esperar.
REINTENTOS = 4
# El parecido de Titan no marca frases por sí solo: con 376 frases reales,
# las marcadas solo por parecido bajo (< 0.55) eran casi todas correctas
# («cédula» frente a «documento de identidad»). Ordena la lista y se muestra.


def frases() -> list:
    """(texto, glosas, rol) de lo que la app muestra en LSB, sin repetir."""
    with open(SALIDA, encoding="utf-8") as f:
        corpus = json.load(f)
    vistas, out = set(), []
    for e in corpus["escenarios"]:
        candidatas = [t for t in e["turnos"] if t["rol"] == "sordo"]
        candidatas += [r for p in e["variantes"] for r in p["respuestas"]]
        candidatas += turnos_pregunta(e)
        for t in candidatas:
            if t["mostrable"] and t.get("glosas") and t["texto"] not in vistas:
                vistas.add(t["texto"])
                out.append((t["texto"], t["glosas"],
                            t.get("rol", "sordo")))
    return out


def legibles(glosas: list) -> str:
    sys.path.insert(0, os.path.join(ROOT, "aws"))
    from rag_revision import legibles as unir  # noqa: E402
    return " · ".join(unir(glosas))


def depurar(r: dict) -> dict:
    """Aplica a un resultado guardado las reglas actuales de
    `aws/rag_revision.py` (p. ej. un verbo conjugado de una glosa no falta),
    sin volver a consultar la Lambda."""
    if "sobran" not in r:
        return r  # revisada con el método anterior: se revisará de nuevo
    sys.path.insert(0, os.path.join(ROOT, "aws"))
    from rag_revision import depurar as reglas  # noqa: E402
    return {**r, **reglas(r["texto"] if "texto" in r else r["_texto"],
                          r["glosas"], r["faltan"], r["sobran"])}


def a_revisar(r: dict) -> bool:
    return bool(r.get("faltan") or r.get("sobran"))


def _fila(texto: str, r: dict) -> str:
    s = r.get("similitud")
    celdas = [", ".join(r.get("faltan") or []) or "—",
              ", ".join(r.get("sobran") or []) or "—",
              f"{s:.2f}" if s is not None else "—",
              texto, legibles(r["glosas"]), r["vuelta"] or "—"]
    return "| " + " | ".join(c.replace("|", "/") for c in celdas) + " |"


def informe(cache: dict) -> str:
    def orden(kv):
        r = kv[1]
        s = r.get("similitud")
        return (-(len(r.get("faltan") or []) + len(r.get("sobran") or [])),
                s if s is not None else 1.0)

    bajas = sorted([(t, r) for t, r in cache.items() if a_revisar(r)],
                   key=orden)
    graves = [(t, r) for t, r in bajas if not r.get("leve")]
    leves = [(t, r) for t, r in bajas if r.get("leve")]
    valores = [r["similitud"] for r in cache.values()
               if r.get("similitud") is not None]
    mediana = sorted(valores)[len(valores) // 2] if valores else 0
    sin_vuelta = sum(r.get("similitud") is None for r in cache.values())
    cabecera = [
        "| Falta | Sobra | Parecido | Frase | Glosas | Vuelta al español |",
        "|---|---|---:|---|---|---|",
    ]
    lineas = [
        "# Revisión de glosas del corpus RAG",
        "",
        "Generado por `tool/rag_revisar_glosas.py`. No editar a mano.",
        "",
        "Para cada frase, Bedrock dice qué palabras no tienen glosa y qué "
        "glosas no están en la frase, y traduce las glosas de vuelta al "
        "español sin ver la frase; Titan compara el significado de esa "
        "vuelta con la original (el parecido ordena la lista; no marca por "
        "sí solo). Se descarta lo que no es un error "
        "comprobable: palabras que LSB no signa (artículos, preposiciones, "
        "«ser/estar»), verbos conjugados de una glosa, sujetos que el español "
        "calla (YO) y lo que la frase sí dice (SI/«Sí», números). Una marca "
        "pide revisar, no corrige nada.",
        "",
        f"**{len(cache)} frases revisadas · {len(graves)} para revisar · "
        f"{len(leves)} menores · parecido mediano {mediana:.2f} · "
        f"{sin_vuelta} vueltas no eran español y no se compararon.**",
        "",
        "## Para revisar",
        "",
        "Falta o sobra una palabra con significado. Dentro de cada grupo, "
        "primero las que más marcas tienen y el parecido más bajo.",
        "",
        *cabecera,
        *[_fila(t, r) for t, r in graves],
        "",
        "## Menores",
        "",
        "Solo falta un verbo auxiliar o de modo («quiero», «debe», "
        "«tengo»): la idea llega, el matiz no.",
        "",
        *cabecera,
        *[_fila(t, r) for t, r in leves],
    ]
    return "\n".join(lineas) + "\n"


def guardar(cache: dict) -> None:
    with open(CACHE, "w", encoding="utf-8", newline="") as f:
        json.dump({k: cache[k] for k in sorted(cache)}, f,
                  ensure_ascii=False, indent=1)
        f.write("\n")


def main() -> int:
    cache = {}
    if os.path.exists(CACHE) and "--todo" not in sys.argv:
        with open(CACHE, encoding="utf-8") as f:
            cache = json.load(f)
    todas = frases()
    actuales = {t for t, _, _ in todas}
    cache = {t: r for t, r in cache.items() if t in actuales}
    # Nuevas, con glosas cambiadas o revisadas antes de comparar faltas.
    pendientes = [(t, g, rol) for t, g, rol in todas
                  if t not in cache or cache[t]["glosas"] != g
                  or "sobran" not in cache[t]]
    print(f"frases: {len(todas)} · por revisar: {len(pendientes)}")
    if pendientes:
        from rag_indexar_embeddings import endpoint, llamar
        url = endpoint()
        hoy = datetime.date.today().isoformat()
        tandas = [pendientes[i:i + TANDA]
                  for i in range(0, len(pendientes), TANDA)]

        def revisar(tanda):
            r = {}
            for intento in range(REINTENTOS):
                try:
                    r = llamar(url, {"action": "retrotraducir", "items": [
                        {"texto": t, "glosas": g, "rol": rol}
                        for t, g, rol in tanda]})
                except SystemExit as e:  # `llamar` agotó sus reintentos
                    r = {"generated": False, "reason": str(e)}
                if r.get("generated") is True:
                    break
                time.sleep(3 * 2 ** intento)
            return tanda, r

        hechas, fallos = 0, 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=HILOS) as pool:
            for tanda, r in pool.map(revisar, tandas):
                if r.get("generated") is not True:
                    fallos += len(tanda)
                    print(f"  tanda sin revisar: {r.get('reason') or r}",
                          flush=True)
                    continue
                for (t, g, _), res in zip(tanda, r["items"]):
                    cache[t] = {"glosas": g, "vuelta": res["vuelta"],
                                "similitud": res["similitud"],
                                "faltan": res.get("faltan", []),
                                "sobran": res.get("sobran", []), "fecha": hoy}
                hechas += len(tanda)
                guardar(cache)
                print(f"  {hechas}/{len(pendientes)}", flush=True)
        if fallos:
            print(f"sin revisar (la Lambda no respondió): {fallos}; "
                  "vuelve a ejecutarlo para completarlas")
    cache = {t: depurar({**r, "_texto": t}) for t, r in cache.items()}
    for r in cache.values():
        r.pop("_texto", None)
    guardar(cache)
    with open(INFORME, "w", encoding="utf-8", newline="") as f:
        f.write(informe(cache))
    bajas = sum(a_revisar(r) for r in cache.values())
    print(f"para revisar: {bajas} · {os.path.relpath(INFORME, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
