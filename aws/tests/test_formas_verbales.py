"""Formas conjugadas con seña y verbos que cambian de sentido (2026-10).

Dictada sola, «va» volvía V-A; «van», «tiene», «da» o «venga» volvían
deletreadas aunque IR, TENER, DAR y VENIR tienen seña; «pasa» salía como IR
y «pasó» como PASADO. Cada prueba parte de lo que devolvió la Lambda
desplegada (13/10/2026) y comprueba lo que sale ahora.

    python3 -m unittest discover -s aws/tests -v
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import lambda_text_to_lsb as m  # noqa: E402


def traducir(glosas, texto):
    return m.post_process_glosses({"glosses": glosas}, texto)["glosses"]


class FormasConjugadasConSena(unittest.TestCase):
    def test_va_dictada_sola_es_ir_y_no_V_A(self):
        # La Lambda devolvía ['V', 'A'].
        self.assertEqual(traducir(["V", "A"], "va"), ["IR"])
        self.assertEqual(traducir(["VA"], "Va"), ["IR"])

    def test_otras_formas_de_ir(self):
        for forma in ("van", "vas", "vaya", "vamos", "voy", "iba"):
            with self.subTest(forma=forma):
                self.assertEqual(traducir([forma.upper()], forma), ["IR"])

    def test_formas_de_tener_venir_y_dar(self):
        self.assertEqual(traducir(["TIENE"], "tiene"), ["TENER"])
        self.assertEqual(traducir(["VENGA"], "venga"), ["VENIR"])
        self.assertEqual(traducir(["DA"], "da"), ["DAR"])
        self.assertEqual(traducir(["DIO"], "dio"), ["DAR"])

    def test_la_forma_solo_se_cambia_si_la_persona_la_dijo(self):
        # El modelo no puede traer «VA» de la nada.
        self.assertEqual(traducir(["VA", "CASA"], "la casa"), list("VA") + ["CASA"])

    def test_cada_lema_de_la_tabla_tiene_seña_en_el_catalogo(self):
        for forma, lema in m.FORMAS_VERBALES.items():
            with self.subTest(forma=forma):
                self.assertIn(lema, m._AVAILABLE_GLOSSES_NORM)

    def test_las_formas_ambiguas_no_estan(self):
        # «fue» es ir y ser; «ira» es un sustantivo.
        for forma in ("FUE", "FUERON", "IRA", "DE", "PASO"):
            self.assertNotIn(forma, m.FORMAS_VERBALES)


class IrAInfinitivo(unittest.TestCase):
    def test_voy_a_denunciar_es_futuro_no_ir(self):
        # Antes: [DENUNCIAR, IR].
        self.assertEqual(
            traducir(["DENUNCIAR", "IR"], "Voy a denunciar"),
            ["FUTURO"] + list("DENUNCIAR"),
        )

    def test_el_futuro_que_se_perdio_vuelve(self):
        # Antes solo salía EMPEZAR.
        self.assertEqual(traducir(["EMPEZAR"], "Ya va a empezar"),
                         ["FUTURO", "EMPEZAR"])

    def test_ir_a_un_lugar_sigue_siendo_ir(self):
        self.assertEqual(traducir(["IR", "CASA"], "Él va a la casa"),
                         ["IR", "CASA"])
        self.assertEqual(traducir(["IR"], "Voy a un bar"), ["IR"])


class PasarNoEsIrNiPasado(unittest.TestCase):
    def test_pasa_no_se_cambia_por_ir(self):
        self.assertEqual(traducir(["IR"], "pasa"), list("PASAR"))

    def test_paso_con_tilde_no_se_cambia_por_pasado(self):
        self.assertEqual(traducir(["PASADO"], "pasó"), list("PASAR"))

    def test_si_la_persona_dijo_ir_o_pasado_se_respeta(self):
        # «pasó» y «pasado» en la misma frase: PASADO es lo que dijo.
        self.assertEqual(traducir(["PASADO"], "el pasado pasó"), ["PASADO"])
        # «voy a pasar»: IR es el auxiliar del futuro y no queda como verbo.
        sale = traducir(["IR", "CASA"], "voy a pasar a la casa")
        self.assertEqual(sale[0], "FUTURO")
        self.assertNotIn("IR", sale)

    def test_que_esta_pasando_conserva_la_palabra(self):
        self.assertEqual(traducir(["QUE", "PASAR"], "¿Qué está pasando?"),
                         ["QUE"] + list("PASAR"))


class ComoEstasNoDicho(unittest.TestCase):
    def test_sigue_no_es_como_estas(self):
        # La Lambda devolvía COMO_ESTAS para «sigue».
        self.assertEqual(traducir(["COMO_ESTAS"], "sigue"), list("SIGUE"))

    def test_como_estas_dicho_se_conserva(self):
        self.assertEqual(traducir(["COMO_ESTAS"], "¿Cómo estás?"), ["COMO_ESTAS"])


if __name__ == "__main__":
    unittest.main()
