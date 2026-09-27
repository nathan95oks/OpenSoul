"""Revisa que las glosas del corpus RAG digan lo mismo que su frase.

    python tool/rag_revisar_glosas.py              # solo lo nuevo o cambiado
    python tool/rag_revisar_glosas.py --todo       # vuelve a revisar todo

Para cada frase que la app muestra en LSB (respuestas de la persona sorda y
preguntas del funcionario de cada trámite), la Lambda LSB→Texto/Audio
(`action: "retrotraducir"`) traduce las glosas de vuelta al español con
Bedrock y compara su significado con la frase original usando Titan.

Escribe:

    docs/negocio/rag/revision_glosas.json   caché (frase → glosas, vuelta,
                                            similitud); se recalcula una frase
                                            cuando cambian sus glosas
    docs/negocio/rag/revision_glosas.md     las frases por debajo del umbral,
                                            de la menos parecida a la más

Una frase marcada no se corrige sola: se revisa y, si falta o sobra algo, se
arregla su traducción (por ejemplo, volviendo a precalcularla o corrigiendo
la frase en el escenario).
"""

from __future__ import annotations

import datetime
import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

from build_rag_corpus import RAG, ROOT, SALIDA, turnos_pregunta  # noqa: E402

CACHE = os.path.join(RAG, "revision_glosas.json")
INFORME = os.path.join(RAG, "revision_glosas.md")
TANDA = 8
# Primera medición con la Lambda real (2026-09-27, Nova 2 Lite + Titan v2):
# mediana 0.72, p25 0.61. No separa bien: muchas vueltas salen como glosas
# («Comprar mío nombre pasar») y bajan frases correctas, y una palabra
# añadida («mi casa» con CASO) no baja nada (0.79). Sirve para priorizar la
# revisión, no como filtro.
UMBRAL = 0.6


def frases() -> list:
    """(texto, glosas) de lo que la app muestra en LSB, sin repetir."""
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
                out.append((t["texto"], t["glosas"]))
    return out


def legibles(glosas: list) -> str:
    sys.path.insert(0, os.path.join(ROOT, "aws"))
    from rag_revision import legibles as unir  # noqa: E402
    return " · ".join(unir(glosas))


def informe(cache: dict, umbral: float) -> str:
    filas = sorted(cache.items(), key=lambda kv: kv[1]["similitud"])
    bajas = [(t, r) for t, r in filas if r["similitud"] < umbral]
    valores = [r["similitud"] for r in cache.values()]
    mediana = sorted(valores)[len(valores) // 2] if valores else 0
    lineas = [
        "# Revisión de glosas del corpus RAG",
        "",
        "Generado por `tool/rag_revisar_glosas.py`. No editar a mano.",
        "",
        "Bedrock traduce las glosas de cada frase de vuelta al español (sin "
        "ver la frase) y Titan compara su significado con la original.",
        "",
        "**Es una lista para priorizar, no un veredicto.** En la primera "
        "medición, de las 15 frases más bajas solo unas 3 tenían un problema "
        "real (p. ej. «Me la robaron.» → ROBAR · CELULAR): muchas vueltas "
        "salen escritas como glosas y bajan frases correctas, y una palabra "
        "añadida puede no bajar el parecido.",
        "",
        f"**{len(cache)} frases revisadas · mediana {mediana:.2f} · "
        f"{len(bajas)} por debajo de {umbral:.2f}.**",
        "",
        "| Similitud | Frase | Glosas | Vuelta al español |",
        "|---:|---|---|---|",
    ]
    for texto, r in bajas:
        celdas = [texto, legibles(r["glosas"]), r["vuelta"] or "—"]
        celdas = [c.replace("|", "/") for c in celdas]
        lineas.append(f"| {r['similitud']:.2f} | " + " | ".join(celdas) + " |")
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
    actuales = {t for t, _ in todas}
    cache = {t: r for t, r in cache.items() if t in actuales}
    pendientes = [(t, g) for t, g in todas
                  if t not in cache or cache[t]["glosas"] != g]
    print(f"frases: {len(todas)} · por revisar: {len(pendientes)}")
    if pendientes:
        from rag_indexar_embeddings import endpoint, llamar
        url = endpoint()
        hoy = datetime.date.today().isoformat()
        for i in range(0, len(pendientes), TANDA):
            tanda = pendientes[i:i + TANDA]
            r = llamar(url, {"action": "retrotraducir", "items": [
                {"texto": t, "glosas": g} for t, g in tanda]})
            if r.get("generated") is not True:
                guardar(cache)
                raise SystemExit(f"La Lambda no revisó: {r.get('reason') or r}")
            for (t, g), res in zip(tanda, r["items"]):
                cache[t] = {"glosas": g, "vuelta": res["vuelta"],
                            "similitud": res["similitud"], "fecha": hoy}
            guardar(cache)
            print(f"  {min(i + TANDA, len(pendientes))}/{len(pendientes)}",
                  flush=True)
    guardar(cache)
    with open(INFORME, "w", encoding="utf-8", newline="") as f:
        f.write(informe(cache, UMBRAL))
    bajas = sum(r["similitud"] < UMBRAL for r in cache.values())
    print(f"por debajo de {UMBRAL}: {bajas} · "
          f"{os.path.relpath(INFORME, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
