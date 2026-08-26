"""Corpus penal judicial §4 — paridad servidor/cliente de las respuestas.

Cliente y servidor tienen que redactar IGUAL: si difieren, la declaración
cambia según haya cobertura de red o no. Y peor: el cliente descarta la
respuesta entera del backend cuando encuentra una glosa sin representar
(`isBackendDegenerate`), así que una omisión aquí anula la generación.

    python3 -m unittest discover -s aws/tests -v
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import lambda_function as L  # noqa: E402


def redactar(contexto, glosas):
    analisis = L.analyze_glosses(glosas)
    ir = L.build_intermediate_representation(glosas, analisis, contexto)
    return L.generate_base_sentence(ir, analisis, contexto)


class ElTestigoNoEsElAgresor(unittest.TestCase):
    """TESTIGO era DESCRIPTOR de persona y caía en `descriptores`, de donde
    `_agresor_text` saca al autor del delito: el acta recogía "Un testigo me
    robó". Acusar de un robo a quien solo lo presenció no es un error de
    estilo.
    """

    def test_el_testigo_tiene_su_propia_clausula(self):
        f = redactar("denuncia_robo", ["ROBAR", "TELEFONO", "TESTIGO"])
        self.assertIn("Hay un testigo", f)
        self.assertNotIn("testigo me", f)

    def test_la_respuesta_afirmativa_se_marca(self):
        self.assertIn("Sí, hay un testigo",
                      redactar("denuncia_robo", ["SI", "TESTIGO"]))

    def test_que_no_haya_testigos_tambien_se_declara(self):
        f = redactar("denuncia_robo", ["NO", "TESTIGO"])
        self.assertIn("No hay testigos", f)
        # Y nunca "No. Hay un testigo.", que se contradice en la misma frase.
        self.assertNotIn("No. Hay", f)


class PolaridadDeLaRespuesta(unittest.TestCase):
    """En LSB tanto el sí como el no son señas aparte. El backend solo
    trataba el NO; el SÍ quedaba como cortesía suelta y el verbo se afirmaba
    por su cuenta, que en las preguntas de sí o no es media respuesta.
    """

    def test_conocer_dice_a_quien_se_conoce(self):
        self.assertIn("Sí conozco a esa persona",
                      redactar("denuncia_robo", ["SI", "CONOCER"]))
        self.assertIn("No conozco a esa persona",
                      redactar("denuncia_robo", ["NO", "CONOCER"]))

    def test_desconocer_es_sena_propia_y_llega_al_mismo_texto(self):
        self.assertIn("No conozco a esa persona",
                      redactar("denuncia_robo", ["DESCONOCER"]))

    def test_la_denuncia_se_consiente_o_se_rechaza(self):
        self.assertIn("Sí quiero presentar una denuncia",
                      redactar("denuncia_robo", ["SI", "DENUNCIAR"]))
        self.assertIn("No quiero presentar una denuncia",
                      redactar("denuncia_robo", ["NO", "DENUNCIAR"]))


class NingunVerboSePierde(unittest.TestCase):
    """`_compose_incident` narra con el verbo de agresión y descartaba el
    resto: responder "¿conoce a la persona?" dentro de una denuncia perdía la
    respuesta, y el cliente descartaba TODA la redacción por cobertura.
    """

    def test_el_verbo_de_respuesta_sobrevive_al_relato(self):
        f = redactar("denuncia_robo", ["HOMBRE", "ROBAR", "TELEFONO", "CONOCER"])
        self.assertIn("Un hombre me robó mi teléfono", f)
        self.assertIn("Conozco a esa persona", f)

    def test_relato_completo_con_las_tres_respuestas(self):
        f = redactar("denuncia_robo",
                     ["HOMBRE", "ROBAR", "TELEFONO", "NO", "CONOCER",
                      "SI", "TESTIGO"])
        for trozo in ("Un hombre me robó mi teléfono",
                      "No conozco a esa persona",
                      "Sí, hay un testigo"):
            self.assertIn(trozo, f)


class CoberturaDeLasGlosasNuevas(unittest.TestCase):
    """Toda glosa que el cliente representa y el servidor no hace que la
    respuesta entera se descarte. Esta es la comprobación que lo detecta.
    """

    CASOS = [
        ("denuncia_robo", ["SI", "TESTIGO"]),
        ("denuncia_robo", ["NO", "TESTIGO"]),
        ("denuncia_robo", ["CONOCER"]),
        ("denuncia_robo", ["DESCONOCER"]),
        ("denuncia_robo", ["DENUNCIAR"]),
        ("violencia", ["MUJER", "MALTRATAR", "DESCONOCER", "TESTIGO"]),
        ("otro", ["ROBAR", "CONOCER", "ABOGADO"]),
        ("preguntas", ["CUANDO", "VOLVER"]),
    ]

    def test_las_glosas_nuevas_existen_en_el_lexicon(self):
        for g in ("DESCONOCER", "DENUNCIAR", "VOLVER", "TESTIGO", "CONOCER"):
            self.assertIn(g, L.GLOSS_LEXICON, g)

    def test_ninguna_glosa_desaparece_de_la_redaccion(self):
        for contexto, glosas in self.CASOS:
            with self.subTest(contexto=contexto, glosas=glosas):
                f = L._normalizar(redactar(contexto, glosas))
                for g in glosas:
                    # SÍ y NO se funden en la polaridad del verbo, así que su
                    # lexema no aparece literal: lo hace su prefijo.
                    if g in ("SI", "NO"):
                        continue
                    palabras = [w for w in L._normalizar(
                        L.GLOSS_LEXICON[g]["es"]).split() if len(w) >= 4]
                    self.assertTrue(
                        any(w in f for w in palabras),
                        f"{g} no aparece en «{f}»")
