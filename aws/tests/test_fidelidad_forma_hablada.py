"""Lo que el español del oyente desmiente de la traducción (Texto→LSB).

Casos reales del QA de Conversación (2026-10-08, Lambda desplegada):
«buenas tardes» salía BUENOS_DÍAS, toda pregunta terminaba con PREGUNTA
deletreada y «¿Quiere denunciar…?» salía QUIÉN DENUNCIAR…
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()

import lambda_text_to_lsb as T  # noqa: E402


def glosas(texto, entrada):
    return T.enforce_spoken_form_fidelity(entrada, texto)[0]


class SaludoDicho(unittest.TestCase):
    def test_buenas_tardes_y_buenas_noches_no_son_buenos_dias(self):
        self.assertEqual(glosas("Buenas tardes, ¿en qué le ayudo?",
                                ["BUENOS_DIAS", "AYUDAR"]),
                         ["BUENAS_TARDES", "AYUDAR"])
        self.assertEqual(glosas("Buenas noches", ["BUENOS_DÍAS"]),
                         ["BUENAS_NOCHES"])
        # La glosa sale en su forma canónica (sin tilde), igual que el resto.
        self.assertEqual(glosas("Buenos días", ["BUENOS_DÍAS"]), ["BUENOS_DIAS"])

    def test_son_senas_de_modulo_y_no_se_deletrean(self):
        salida, incidencias = T.enforce_catalog_membership(
            ["BUENAS_TARDES", "BUENAS_NOCHES"])
        self.assertEqual(salida, ["BUENAS_TARDES", "BUENAS_NOCHES"])
        self.assertEqual(incidencias, [])


class MarcaDePregunta(unittest.TestCase):
    def test_se_retira_si_el_oyente_no_dijo_pregunta(self):
        self.assertEqual(glosas("¿Está herida?", ["HERIDA", "PREGUNTA"]),
                         ["HERIDA"])

    def test_tambien_ya_deletreada(self):
        self.assertEqual(glosas("¿Está herida?", ["HERIDA", *"PREGUNTA"]),
                         ["HERIDA"])

    def test_se_conserva_si_el_oyente_la_dijo(self):
        self.assertEqual(glosas("Tengo una pregunta", ["YO", "PREGUNTA"]),
                         ["YO", "PREGUNTA"])


class QuienPorQuiere(unittest.TestCase):
    def test_quiere_no_es_quien(self):
        self.assertEqual(
            glosas("¿Quiere denunciar acoso sexual?",
                   ["QUIEN", "DENUNCIAR", "ACOSO", "SEXUAL"]),
            ["QUERER", "DENUNCIAR", "ACOSO", "SEXUAL"])

    def test_quien_dicho_se_conserva(self):
        self.assertEqual(glosas("¿Quién le robó?", ["QUIEN", "ROBAR"]),
                         ["QUIEN", "ROBAR"])


class NegacionNoDicha(unittest.TestCase):
    """QA 2026-10-09: «¿La acosaron sexualmente?» salía con NO al final y el
    avatar preguntaba lo contrario."""

    def test_un_no_que_nadie_dijo_se_retira(self):
        self.assertEqual(
            glosas("¿La acosaron sexualmente?",
                   ["ACOSAR", "SEXUALMENTE", "ELLA", "NO"]),
            ["ACOSAR", "SEXUALMENTE", "ELLA"])
        self.assertEqual(glosas("¿Su hijo tiene heridas o dolor?",
                                ["HIJO", "HERIDA", "DOLOR", "TENER", "NO"]),
                         ["HIJO", "HERIDA", "DOLOR", "TENER"])

    def test_la_negacion_dicha_se_conserva(self):
        for texto, entrada in [
            ("¿Publicaron sus fotos sin su permiso?",
             ["FOTOS", "PUBLICAR", "PERMISO", "NO"]),
            ("No tengo testigos.", ["TESTIGO", "TENER", "NO"]),
            ("¿Le negaron la atención?", ["ATENDER", "NEGAR", "NO"]),
            ("Aquí está prohibido fumar.", ["AQUI", "FUMAR", "NO"]),
            ("No sé.", ["NO_SABER"]),
        ]:
            with self.subTest(texto=texto):
                self.assertEqual(glosas(texto, entrada), entrada)

    def test_no_saber_no_es_una_negacion_que_retirar(self):
        self.assertEqual(glosas("¿Sabe quién es su fiscal?",
                                ["FISCAL", "QUIEN", "NO_SABER"]),
                         ["FISCAL", "QUIEN", "NO_SABER"])


class PalabrasSinSenaPropia(unittest.TestCase):
    """QA 2026-10-09 (respuestas reales de la Lambda): se deletreaban
    partículas (F-U-E, C-O-N, E-S S-U) y palabras con una seña documentada
    en el catálogo (U-S-T-E-D, H-A-Y)."""

    def catalogo(self, entrada):
        return T.enforce_catalog_membership(
            [T.canonical_gloss(g) for g in entrada])[0]

    def test_una_particula_no_se_deletrea(self):
        self.assertEqual(self.catalogo(["QUIEN", "FUE", "NO_SABER"]),
                         ["QUIEN", "NO_SABER"])
        self.assertEqual(self.catalogo(["HABLAR", "CON", "ESTE", "MAESTRO"]),
                         ["HABLAR", *"MAESTRO"])

    def test_se_usa_la_sena_que_el_corpus_documenta(self):
        self.assertEqual(self.catalogo(["HAY", "TESTIGO"]), ["TENER", "TESTIGO"])
        self.assertEqual(self.catalogo(["USTED", "ENTENDER"]),
                         ["TU", "COMPRENDER"])
        self.assertEqual(self.catalogo(["SU", "PAREJA"]), ["SUYO", "PAREJA"])

    def test_una_palabra_de_contenido_sin_sena_se_sigue_deletreando(self):
        self.assertEqual(self.catalogo(["PUBLICAR"]), list("PUBLICAR"))


class RanurasDelEspanol(unittest.TestCase):
    def ranuras(self, texto, entrada):
        return T.build_semantic_turn(texto, {"glosses": entrada})["requestedSlots"]

    def test_un_quien_que_nadie_dijo_no_pide_persona(self):
        self.assertNotIn("person",
                         self.ranuras("¿Tiene testigos?", ["TESTIGO", "TENER", "QUIEN"]))
        self.assertNotIn("person",
                         self.ranuras("¿Alguien vio lo que pasó?", ["VER", "QUIEN"]))

    def test_lo_que_si_se_pregunta_se_conserva(self):
        self.assertEqual(self.ranuras("¿Quién le robó?", ["QUIEN", "ROBAR"]),
                         ["person"])
        self.assertEqual(self.ranuras("¿Dónde fue?", ["DONDE"]), ["place"])


if __name__ == "__main__":
    unittest.main()
