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
# Parecido de Titan por debajo del cual la vuelta ya no dice lo mismo. Solo
# cuenta cuando la vuelta es español (no las glosas copiadas); lo que falta
# o sobra se marca siempre.
UMBRAL = 0.5


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


def a_revisar(r: dict, umbral: float) -> bool:
    return bool(r.get("faltan") or r.get("sobran")) or (
        r.get("similitud") is not None and r["similitud"] < umbral)


def informe(cache: dict, umbral: float) -> str:
    def orden(kv):
        r = kv[1]
        s = r.get("similitud")
        return (-(len(r.get("faltan") or []) + len(r.get("sobran") or [])),
                s if s is not None else 1.0)

    bajas = sorted([(t, r) for t, r in cache.items() if a_revisar(r, umbral)],
                   key=orden)
    valores = [r["similitud"] for r in cache.values()
               if r.get("similitud") is not None]
    mediana = sorted(valores)[len(valores) // 2] if valores else 0
    sin_vuelta = sum(r.get("similitud") is None for r in cache.values())
    lineas = [
        "# Revisión de glosas del corpus RAG",
        "",
        "Generado por `tool/rag_revisar_glosas.py`. No editar a mano.",
        "",
        "Para cada frase, Bedrock dice qué palabras no tienen glosa y qué "
        "glosas no están en la frase (se comprueba que existan de verdad), y "
        "traduce las glosas de vuelta al español sin ver la frase; Titan "
        "compara el significado de esa vuelta con la original. Se listan las "
        "frases con algo que falta o sobra, o con una vuelta de significado "
        f"distinto (parecido < {umbral:.2f}). Una marca pide revisar, no "
        "corrige nada.",
        "",
        f"**{len(cache)} frases revisadas · {len(bajas)} para revisar · "
        f"parecido mediano {mediana:.2f} · {sin_vuelta} vueltas no eran "
        "español y no se compararon.**",
        "",
        "| Falta | Sobra | Parecido | Frase | Glosas | Vuelta al español |",
        "|---|---|---:|---|---|---|",
    ]
    for texto, r in bajas:
        s = r.get("similitud")
        celdas = [", ".join(r.get("faltan") or []) or "—",
                  ", ".join(r.get("sobran") or []) or "—",
                  f"{s:.2f}" if s is not None else "—",
                  texto, legibles(r["glosas"]), r["vuelta"] or "—"]
        lineas.append("| " + " | ".join(c.replace("|", "/") for c in celdas)
                      + " |")
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
                  or "faltan" not in cache[t]]
    print(f"frases: {len(todas)} · por revisar: {len(pendientes)}")
    if pendientes:
        from rag_indexar_embeddings import endpoint, llamar
        url = endpoint()
        hoy = datetime.date.today().isoformat()
        for i in range(0, len(pendientes), TANDA):
            tanda = pendientes[i:i + TANDA]
            r = llamar(url, {"action": "retrotraducir", "items": [
                {"texto": t, "glosas": g, "rol": rol} for t, g, rol in tanda]})
            if r.get("generated") is not True:
                guardar(cache)
                raise SystemExit(f"La Lambda no revisó: {r.get('reason') or r}")
            for (t, g, _), res in zip(tanda, r["items"]):
                cache[t] = {"glosas": g, "vuelta": res["vuelta"],
                            "similitud": res["similitud"],
                            "faltan": res.get("faltan", []),
                            "sobran": res.get("sobran", []), "fecha": hoy}
            guardar(cache)
            print(f"  {min(i + TANDA, len(pendientes))}/{len(pendientes)}",
                  flush=True)
    guardar(cache)
    with open(INFORME, "w", encoding="utf-8", newline="") as f:
        f.write(informe(cache, UMBRAL))
    bajas = sum(a_revisar(r, UMBRAL) for r in cache.values())
    print(f"para revisar: {bajas} · {os.path.relpath(INFORME, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
