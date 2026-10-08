"""Graba las respuestas reales de las Lambdas para el QA de Conversación.

    python tool/qa_capturar_lambdas.py

test/qa_conversacion_test.dart anota en test/qa/lambda_pendientes.json las
llamadas que todavía no tiene grabadas (el cuerpo exacto que manda la app).
Este script las envía a las Lambdas desplegadas de `.env` (LSB_TEXT_API_URL
para Texto→LSB, LSB_API_URL para LSB→Texto/Audio: desempate `route` y RAG
`consulta`) y guarda cada respuesta tal cual en test/qa/lambda_respuestas.json.
Hay que alternar prueba y captura hasta que no quede nada pendiente: una
respuesta abre la llamada siguiente (la traducción decide si hace falta el
desempate).
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PENDIENTES = os.path.join(ROOT, "test", "qa", "lambda_pendientes.json")
RESPUESTAS = os.path.join(ROOT, "test", "qa", "lambda_respuestas.json")


def entorno() -> dict:
    out = {}
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
        for linea in f:
            if "=" in linea and not linea.lstrip().startswith("#"):
                k, v = linea.strip().split("=", 1)
                out[k] = v.strip().strip('"')
    return out


def main() -> int:
    env = entorno()
    urls = {"texto": env["LSB_TEXT_API_URL"], "api": env["LSB_API_URL"]}
    if not os.path.exists(PENDIENTES):
        print("no hay pendientes: corre antes la prueba")
        return 0
    with open(PENDIENTES, encoding="utf-8") as f:
        pendientes = json.load(f)
    respuestas = {}
    if os.path.exists(RESPUESTAS):
        with open(RESPUESTAS, encoding="utf-8") as f:
            respuestas = json.load(f)
    fallidas = 0
    for i, (clave, p) in enumerate(sorted(pendientes.items()), 1):
        if clave in respuestas:
            continue
        pedido = urllib.request.Request(
            urls[p["lambda"]], data=p["cuerpo"].encode("utf-8"),
            headers={"Content-Type": "application/json"}, method="POST")
        try:
            with urllib.request.urlopen(pedido, timeout=60) as r:
                respuestas[clave] = {"estado": r.status,
                                     "cuerpo": r.read().decode("utf-8")}
        except urllib.error.HTTPError as e:
            # Un 4xx también es la respuesta real (p. ej. validación).
            respuestas[clave] = {"estado": e.code,
                                 "cuerpo": e.read().decode("utf-8")}
        except Exception as e:  # red: se reintenta en la siguiente pasada
            fallidas += 1
            print(f"  error: {e}")
            continue
        print(f"  {i}/{len(pendientes)} {p['lambda']}", flush=True)
    with open(RESPUESTAS, "w", encoding="utf-8", newline="\n") as f:
        json.dump(dict(sorted(respuestas.items())), f, ensure_ascii=False,
                  indent=1)
        f.write("\n")
    print(f"grabadas: {len(respuestas)} · fallidas: {fallidas}")
    return 1 if fallidas else 0


if __name__ == "__main__":
    sys.exit(main())
