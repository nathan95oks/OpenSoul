"""La fuente canónica de glosas es el Corpus Maestro Unificado LSB v4.

`assets/dictionary/official_dictionary.json` (lo que usa la app) y el banco
de ejecución `aws/question_bank.json` (lo que usan la app y la Lambda) no
pueden contener una glosa que no esté en la sección 12 del corpus, salvo los
mecanismos que el propio corpus autoriza: alfabeto dactilológico, números y
dactilología institucional d(SIGLA) de la sección 4.
"""

import json
import os
import sys
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tool"))

import corpus_dialogue as CD  # noqa: E402

DICCIONARIO = os.path.join(ROOT, "assets", "dictionary", "official_dictionary.json")
BANCO = os.path.join(ROOT, "aws", "question_bank.json")

# Sección 4 del corpus: «Usar d(FISCALÍA) / d(JUZGADO) / d(FELCC) …».
DACTILOLOGIA_INSTITUCIONAL = {"FISCALIA", "JUZGADO", "SEPDAVI", "SEPDEP", "FELCC", "FELCV"}


class CorpusMaestroV4(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.seccion12 = CD.load_corpus_glosses()
        with open(DICCIONARIO, encoding="utf-8") as f:
            cls.entradas = json.load(f)["entries"]
        cls.glosas_app = {e["gloss"] for e in cls.entradas}

    def es_mecanismo(self, e):
        g = e["gloss"]
        if e["categoryId"] == "Abecedario":
            return len(CD.norm(g)) == 1
        if e["categoryId"] == "Números":
            return g.isdigit()
        return g in DACTILOLOGIA_INSTITUCIONAL

    def test_la_seccion_12_tiene_303_glosas(self):
        self.assertEqual(303, len(self.seccion12))

    def test_el_diccionario_de_la_app_es_el_corpus_v4(self):
        fuera = [e["gloss"] for e in self.entradas
                 if CD.norm(e["gloss"]) not in self.seccion12 and not self.es_mecanismo(e)]
        self.assertEqual([], fuera)
        faltan = sorted(set(self.seccion12) - {CD.norm(g) for g in self.glosas_app})
        self.assertEqual([], faltan)

    def test_la_dactilologia_institucional_esta_en_la_seccion_4(self):
        pendientes = CD.load_pending_concepts()
        for sigla in DACTILOLOGIA_INSTITUCIONAL:
            self.assertIn(CD.norm(sigla), pendientes, sigla)

    def test_banco_de_ejecucion_solo_usa_glosas_del_corpus(self):
        with open(BANCO, encoding="utf-8") as f:
            banco = json.load(f)
        fuera = []
        for q in banco["preguntas"]:
            for o in q.get("opciones", []):
                fuera += [f"{q['id']}/{o['id']}: {g}" for g in o.get("glosas", [])
                          if g not in self.glosas_app]
            fuera += [f"{q['id']} (formulación): {g}" for g in q.get("noOfrecer", [])
                      if g not in self.glosas_app]
        self.assertEqual([], fuera)


if __name__ == "__main__":
    unittest.main()
