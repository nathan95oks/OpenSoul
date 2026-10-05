"""Traduce a LSB la descripción de cada palabra sin seña propia.

    python tool/rag_descripciones_lsb.py            # solo lo que falta
    python tool/rag_descripciones_lsb.py --todo     # vuelve a traducir todo

La ventana «¿Qué es?» de una palabra en azul (`FOLIO_REAL`) explica la
palabra con señas que la persona ya conoce. Cada descripción de
`docs/negocio/rag/descripciones_sin_sena.json` se traduce con la misma Lambda
Texto→LSB que usan la app y `tool/rag_precalcular_glosas.py`
(`LSB_TEXT_API_URL` de `.env`), con la frase entera como contexto: no se
traduce palabra por palabra. No hay código nuevo que desplegar.

Escribe la caché revisable `docs/negocio/rag/descripciones_lsb_cache.json`.
`tool/build_rag_corpus.py` la lee sin red: marca las palabras que la Lambda
deletreó como señas a incorporar, descarta lo que no sea una glosa y pone la
secuencia en `assets/dictionary/senas_sin_sena.json` («descripcionLsb»). Se
puede interrumpir: guarda cada pocas frases.
"""

from __future__ import annotations

import concurrent.futures
import datetime
import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

import build_rag_corpus as B  # noqa: E402
import rag_precalcular_glosas as P  # noqa: E402

CACHE = os.path.join(B.RAG, "descripciones_lsb_cache.json")


def descripciones() -> list:
    """Las descripciones distintas que la app puede mostrar."""
    datos = B._leer(B.DESCRIPCIONES).get("palabras", {})
    vistas = []
    for dato in datos.values():
        texto = (dato.get("descripcion") or "").strip()
        if texto and "ver" not in dato and texto not in vistas:
            vistas.append(texto)
    return vistas


def guardar(cache: dict) -> None:
    with open(CACHE, "w", encoding="utf-8", newline="") as f:
        json.dump({k: cache[k] for k in sorted(cache)}, f,
                  ensure_ascii=False, indent=1)
        f.write("\n")


def main() -> int:
    cache = {} if "--todo" in sys.argv else B._leer(CACHE)
    todas = descripciones()
    pendientes = [t for t in todas if t not in cache]
    print(f"descripciones: {len(todas)} · ya traducidas: "
          f"{len(todas) - len(pendientes)} · pendientes: {len(pendientes)}")
    if not pendientes:
        return 0
    url = P.endpoint()
    hoy = datetime.date.today().isoformat()
    fallos = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=P.HILOS) as pool:
        futuros = {pool.submit(P.traducir, url, t): t for t in pendientes}
        for i, futuro in enumerate(concurrent.futures.as_completed(futuros), 1):
            texto = futuros[futuro]
            try:
                cache[texto] = {**futuro.result(), "traducido": hoy}
            except RuntimeError as e:
                fallos.append(str(e))
            if i % 10 == 0 or i == len(pendientes):
                guardar(cache)
                print(f"  {i}/{len(pendientes)}", flush=True)
    guardar(cache)
    for f in fallos:
        print(f"FALLO: {f}")
    print(f"listo: {len(cache)} en caché, {len(fallos)} fallos · "
          f"{B._rel(CACHE)}. Después: python tool/build_rag_corpus.py")
    return 1 if fallos else 0


if __name__ == "__main__":
    raise SystemExit(main())
