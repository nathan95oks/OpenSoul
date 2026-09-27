"""Precalcula las glosas LSB de las frases del usuario sordo del corpus RAG.

    python tool/rag_precalcular_glosas.py              # solo lo que falta
    python tool/rag_precalcular_glosas.py --todo       # vuelve a traducir todo

Llama a la Lambda Texto→LSB desplegada (`LSB_TEXT_API_URL` de `.env`) con la
misma petición que la app (`RemoteAudioDataSourceImpl`), una vez por frase
distinta que puede mostrarse (turnos y respuestas alternativas del usuario
sordo, según `assets/rag/escenarios_cbba.json`).

Escribe la caché revisable:

    docs/negocio/escenarios_tramites_cochabamba_RAG_glosas.json

`tool/build_rag_corpus.py` la lee sin red y pone las glosas en el corpus. Se
puede interrumpir: guarda cada pocas frases y la siguiente ejecución sigue
donde quedó.
"""

from __future__ import annotations

import concurrent.futures
import datetime
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORPUS = os.path.join(ROOT, "assets", "rag", "escenarios_cbba.json")
CACHE = os.path.join(
    ROOT, "docs", "negocio", "escenarios_tramites_cochabamba_RAG_glosas.json")
ENV = os.path.join(ROOT, ".env")

HILOS = 4
INTENTOS = 3
ESPERA = 30


def endpoint() -> str:
    url = os.environ.get("LSB_TEXT_API_URL")
    if not url and os.path.exists(ENV):
        with open(ENV, encoding="utf-8") as f:
            for linea in f:
                if linea.startswith("LSB_TEXT_API_URL="):
                    url = linea.split("=", 1)[1].strip()
    if not url or not url.startswith("https://"):
        raise SystemExit("Falta LSB_TEXT_API_URL (en .env o en el entorno).")
    return url


def frases() -> list:
    """Frases del usuario sordo que pueden mostrarse, sin repetir."""
    with open(CORPUS, encoding="utf-8") as f:
        corpus = json.load(f)
    vistas = []
    for e in corpus["escenarios"]:
        candidatas = [t for t in e["turnos"] if t["rol"] == "sordo"]
        candidatas += [r for p in e["variantes"] for r in p["respuestas"]]
        for t in candidatas:
            if t["mostrable"] and t["texto"] not in vistas:
                vistas.append(t["texto"])
    return vistas


def traducir(url: str, texto: str) -> dict:
    cuerpo = json.dumps({"text": texto, "context": "legal"}).encode("utf-8")
    ultimo = None
    for intento in range(INTENTOS):
        pedido = urllib.request.Request(
            url, data=cuerpo, method="POST",
            headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(pedido, timeout=ESPERA) as r:
                datos = json.loads(r.read().decode("utf-8"))
            glosas = datos.get("glosses")
            if not isinstance(glosas, list):
                raise ValueError(f"respuesta sin glosas: {str(datos)[:200]}")
            return {
                "glosas": [str(g) for g in glosas],
                "estado": datos.get("representationStatus"),
                "correcciones": [
                    {k: c.get(k) for k in ("palabra", "accion") if k in c}
                    for c in datos.get("fidelityFixes") or []
                    if isinstance(c, dict)
                ],
            }
        except (urllib.error.URLError, TimeoutError, ValueError,
                json.JSONDecodeError) as e:
            ultimo = e
            time.sleep(2 * (intento + 1))
    raise RuntimeError(f"«{texto}»: {ultimo}")


def guardar(cache: dict) -> None:
    ordenada = {k: cache[k] for k in sorted(cache)}
    with open(CACHE, "w", encoding="utf-8", newline="") as f:
        json.dump(ordenada, f, ensure_ascii=False, indent=1)
        f.write("\n")


def main() -> int:
    url = endpoint()
    cache = {}
    if os.path.exists(CACHE) and "--todo" not in sys.argv:
        with open(CACHE, encoding="utf-8") as f:
            cache = json.load(f)
    pendientes = [t for t in frases() if t not in cache]
    total = len(frases())
    print(f"frases: {total} · ya traducidas: {total - len(pendientes)} · "
          f"pendientes: {len(pendientes)}")
    hoy = datetime.date.today().isoformat()
    fallos = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=HILOS) as pool:
        futuros = {pool.submit(traducir, url, t): t for t in pendientes}
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
          f"{os.path.relpath(CACHE, ROOT)}")
    return 1 if fallos else 0


if __name__ == "__main__":
    raise SystemExit(main())
