"""Construye el índice de significados del RAG en la Lambda desplegada.

    python tool/rag_indexar_embeddings.py

Llama a la Lambda LSB→Texto/Audio (`LSB_API_URL` de `.env`) con
`action: "rag_indexar"` hasta que no quede nada pendiente. Cada llamada
calcula como mucho una tanda de vectores (Titan, Bedrock) y los guarda en S3.

Hay que ejecutarlo después de cada despliegue que cambie el corpus: el índice
se identifica por una huella del corpus empaquetado, y uno nuevo empieza
vacío. Mientras no esté completo, la consulta responde «sin índice» y la app
sigue con la búsqueda por palabras.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV = os.path.join(ROOT, ".env")
INTENTOS = 5
MAX_LLAMADAS = 200


def endpoint() -> str:
    url = os.environ.get("LSB_API_URL")
    if not url and os.path.exists(ENV):
        with open(ENV, encoding="utf-8") as f:
            for linea in f:
                if linea.startswith("LSB_API_URL="):
                    url = linea.split("=", 1)[1].strip()
    if not url or not url.startswith("https://"):
        raise SystemExit("Falta LSB_API_URL (en .env o en el entorno).")
    return url


def llamar(url: str, cuerpo: dict) -> dict:
    datos = json.dumps(cuerpo).encode("utf-8")
    ultimo = None
    for intento in range(INTENTOS):
        pedido = urllib.request.Request(
            url, data=datos, method="POST",
            headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(pedido, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
            ultimo = e
            time.sleep(2 ** (intento + 1))
    raise SystemExit(f"La Lambda no respondió: {ultimo}")


def main() -> int:
    url = endpoint()
    for _ in range(MAX_LLAMADAS):
        r = llamar(url, {"action": "rag_indexar"})
        if r.get("generated") is False:
            print(f"La Lambda no puede indexar: {r.get('reason')}.")
            print("¿Está desplegado el paquete nuevo con el corpus y Bedrock activo?")
            return 1
        if "pending" not in r:
            print(f"Respuesta inesperada: {r}")
            return 1
        print(f"  indexadas {r['indexed']}/{r['total']}", flush=True)
        if r["pending"] == 0:
            print(f"Índice completo: {r['index']}")
            prueba = llamar(url, {"action": "consulta",
                                  "text": "¿Usted está en peligro ahorita?"})
            print(f"Prueba «¿Usted está en peligro ahorita?» → "
                  f"{[s['text'] for s in prueba.get('suggestions', [])]} "
                  f"({prueba.get('reason', 'ok')})")
            return 0
    print("Se alcanzó el máximo de llamadas sin completar el índice.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
