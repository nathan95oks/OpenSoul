"""Contrato compartido de lectura semántica entre Python y Dart."""

import json
import os
import sys
import unittest

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TESTS_DIR)

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()
sys.path.insert(0, os.path.join(TESTS_DIR, ".."))

import lambda_text_to_lsb as t2l  # noqa: E402


ROOT = os.path.dirname(os.path.dirname(TESTS_DIR))
# Fuente única: la app y esta Lambda se generan desde ella
# (tool/build_semantica_lsb.py).
SEMANTICA = os.path.join(ROOT, "docs", "negocio", "config", "semantica_lsb.json")
with open(SEMANTICA, encoding="utf-8") as f:
    CONTRACT = json.load(f)

sys.path.insert(0, os.path.join(ROOT, "tool"))
import build_semantica_lsb as generador  # noqa: E402


class GlossSemanticsParity(unittest.TestCase):
    def test_python_matches_shared_contract(self):
        self.assertEqual(CONTRACT["interrogativeSlots"],
                         t2l._SLOT_POR_INTERROGATIVO)
        self.assertEqual(CONTRACT["headSlots"], t2l._SLOT_POR_NUCLEO)
        self.assertEqual(set(CONTRACT["openInterrogatives"]),
                         t2l._INTERROGATIVOS_ABIERTOS)
        self.assertEqual(set(CONTRACT["negators"]), t2l._NEGADORES)

    def test_python_matches_shared_spoken_contract(self):
        self.assertEqual(CONTRACT["spokenInterrogativeSlots"],
                         t2l._SLOT_POR_INTERROGATIVO_HABLADO)
        self.assertEqual(set(CONTRACT["spokenOpenInterrogatives"]),
                         t2l._INTERROGATIVOS_ABIERTOS_HABLADOS)
        self.assertEqual(CONTRACT["spokenHeadSlots"], t2l._SLOT_POR_NUCLEO_HABLADO)
        self.assertEqual(CONTRACT["spokenWordSlots"], t2l._SLOT_POR_PALABRA)
        self.assertEqual(CONTRACT["spokenStemSlots"], t2l._SLOT_POR_RAIZ_HABLADA)
        self.assertEqual(CONTRACT["spokenAfterHowSlots"],
                         t2l._SLOT_TRAS_COMO_HABLADO)
        self.assertEqual(set(CONTRACT["spokenWearSlots"]["verbs"]),
                         t2l._VERBOS_DE_VESTIR)
        self.assertEqual(set(CONTRACT["spokenWearSlots"]["words"]),
                         t2l._PALABRAS_DE_VESTIR)
        self.assertEqual(set(CONTRACT["questionPrepositions"]),
                         t2l._PREPOSICIONES_INTERROGATIVAS)


class GeneratedFromSingleSource(unittest.TestCase):
    def test_la_fuente_es_valida(self):
        self.assertEqual([], generador.validar(generador.cargar()))

    def test_app_y_lambda_estan_al_dia(self):
        """Editar el JSON sin regenerar deja a la app y a la Lambda leyendo
        distinto: se detecta aquí, antes de empaquetar."""
        for ruta, esperado in generador.salidas(generador.cargar()).items():
            with self.subTest(ruta=os.path.relpath(ruta, ROOT)):
                with open(ruta, encoding="utf-8") as f:
                    self.assertEqual(esperado.replace(chr(13), ""), f.read())

    def test_una_ranura_desconocida_se_rechaza(self):
        d = generador.cargar()
        d["spokenStemSlots"]["TATUAJ"] = "tatuaje"
        self.assertTrue(any("tatuaje" in e for e in generador.validar(d)))


class SituationCuesConfiguration(unittest.TestCase):
    def test_covers_exactly_the_supported_situations(self):
        self.assertEqual(set(t2l.SITUATION_LABELS), set(t2l.SITUATION_CUES))

    def test_only_uses_glosses_the_backend_can_emit(self):
        configured = {
            gloss
            for cues in t2l.SITUATION_CUES.values()
            for gloss in cues["glosas"]
        }
        accepted = (t2l._AVAILABLE_GLOSSES_NORM
                    | t2l._AVAILABLE_3D_GLOSSES_NORM
                    | set(t2l._COMPOUND_SPECS))
        self.assertEqual(set(), configured - accepted)

    def test_every_situation_has_explicit_linguistic_evidence(self):
        for situation, cues in t2l.SITUATION_CUES.items():
            with self.subTest(situation=situation):
                self.assertTrue(cues["glosas"] or cues["raices"])
                self.assertTrue(all(root == root.lower() and root.strip()
                                    for root in cues["raices"]))


if __name__ == "__main__":
    unittest.main()
