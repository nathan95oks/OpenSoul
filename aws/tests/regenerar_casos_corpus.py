"""Regenera `esperado_backend` e `lsb_icons` de casos_corpus.json.

El esperado NO se escribe a mano: se captura del motor real y luego se revisa.
Un esperado inventado documenta lo que uno cree que pasa, no lo que pasa.

    python3 aws/tests/regenerar_casos_corpus.py
"""
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(RAIZ, "aws"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install  # noqa: E402

install()
import lambda_function as L  # noqa: E402

CASOS = os.path.join(RAIZ, "aws", "tests", "casos_corpus.json")
DICC = os.path.join(RAIZ, "assets", "dictionary", "official_dictionary.json")


def main():
    with open(CASOS, encoding="utf-8") as f:
        data = json.load(f)
    with open(DICC, encoding="utf-8") as f:
        catalogo = {e["gloss"]: e for e in json.load(f)["entries"]}

    for caso in data["casos"]:
        desconocidas = [g for g in caso["glosas"] if g not in catalogo]
        if desconocidas:
            raise SystemExit(
                f'{caso["case_id"]}: glosas que no existen en el diccionario: '
                f"{desconocidas}"
            )
        analysis = L.analyze_glosses(caso["glosas"])
        ir = L.build_intermediate_representation(
            caso["glosas"], analysis, caso["contexto"])
        caso["esperado_backend"] = L.generate_base_sentence(
            ir, analysis, caso["contexto"])
        caso["lsb_icons"] = sorted(
            {catalogo[g]["semanticIcon"] for g in caso["glosas"]})

    with open(CASOS, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")

    for caso in data["casos"]:
        print(f'{caso["case_id"]}  {caso["esperado_backend"]}')


if __name__ == "__main__":
    main()
