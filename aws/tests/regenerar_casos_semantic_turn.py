"""Regenera `semanticTurn` de casos_semantic_turn.json con la Lambda real.

Cada caso es una frase del oyente y las glosas que devolvería la traducción
(la salida de Bedrock ya normalizada). El `semanticTurn` esperado NO se
escribe a mano: se captura de `build_semantic_turn` y luego se revisa. Las
pruebas de Flutter leen este mismo archivo, así que el contrato App↔Lambda se
comprueba con la salida real del backend.

    python aws/tests/regenerar_casos_semantic_turn.py
"""
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(RAIZ, "aws"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install  # noqa: E402

install()
import lambda_text_to_lsb as T  # noqa: E402

CASOS = os.path.join(RAIZ, "aws", "tests", "casos_semantic_turn.json")


def capturar(casos):
    for caso in casos:
        caso["semanticTurn"] = T.build_semantic_turn(
            caso["texto"], {"glosses": caso["glosas"]})
    return casos


def main():
    with open(CASOS, encoding="utf-8") as f:
        data = json.load(f)
    data["casos"] = capturar(data["casos"])
    with open(CASOS, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"{len(data['casos'])} casos regenerados")


if __name__ == "__main__":
    main()
