"""Las respuestas grabadas de Texto→LSB, como las servirá la Lambda nueva.

    python tool/qa_simular_redespliegue.py
    RESPUESTAS_QA=test/qa/lambda_respuestas_redespliegue.json flutter test test/qa_conversacion_test.dart ...

Las frases del QA ya están en la caché S3 de la Lambda desplegada (se
grabaron con tool/qa_capturar_lambdas.py). Tras desplegar la versión nueva,
pedirlas otra vez es un acierto de caché: la Lambda repara la traducción
guardada con `repair_cached_translation` y rearma la lectura semántica con
`build_semantic_turn`. Este script hace exactamente eso con las mismas
funciones, sin red, para medir el QA antes de desplegar.

No simula a Bedrock: el desempate `route` y la consulta RAG remota se
quedan como se grabaron.
"""

from __future__ import annotations

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AWS = os.path.join(ROOT, "aws")
ORIGEN = os.path.join(ROOT, "test", "qa", "lambda_respuestas.json")
DESTINO = os.path.join(ROOT, "test", "qa", "lambda_respuestas_redespliegue.json")

sys.path.insert(0, AWS)
sys.path.insert(0, os.path.join(AWS, "tests"))
from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()
import lambda_text_to_lsb as T  # noqa: E402


def reparar(clave: str, grabada: dict) -> dict:
    if not clave.startswith("texto/") or grabada.get("estado") != 200:
        return grabada
    pedido = json.loads(clave.split("|", 1)[1])
    texto = pedido.get("text") or ""
    cuerpo = json.loads(grabada["cuerpo"])
    if not isinstance(cuerpo.get("glosses"), list):
        return grabada
    reparado = T.repair_cached_translation(cuerpo, texto)
    reparado["semanticTurn"] = T.build_semantic_turn(texto, reparado)
    return {**grabada, "cuerpo": json.dumps(reparado, ensure_ascii=False)}


def main() -> int:
    with open(ORIGEN, encoding="utf-8") as f:
        grabadas = json.load(f)
    salida = {k: reparar(k, v) for k, v in grabadas.items()}
    cambiadas = sum(1 for k in grabadas if salida[k] != grabadas[k])
    with open(DESTINO, "w", encoding="utf-8") as f:
        json.dump(salida, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print(f"{cambiadas} de {len(grabadas)} respuestas reparadas: "
          f"{os.path.relpath(DESTINO, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
