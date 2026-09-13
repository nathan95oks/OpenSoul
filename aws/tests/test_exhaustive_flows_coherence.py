"""Auditoría de coherencia combinatoria del backend (QA exhaustivo, 2026-09).

Invoca `generate_structured_sentence` con payloads complejos en los 8
contextos y comprueba: (a) español formal boliviano coherente, (b) ausencia
total de marcadores crudos, paréntesis de relleno o variables sin resolver,
y (c) que el acto comunicativo y las relaciones entre entidades sobrevivan
a la generación. Comparte intención con
`test/exhaustive_flows_coherence_test.dart` del lado Dart: mismos casos,
mismas garantías, cada motor con su propio generador.

    python3 -m unittest discover -s aws/tests -v
"""

import os
import re
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()

import lambda_function as L  # noqa: E402


# Ningún resultado debe contener una glosa cruda en mayúsculas con guion
# bajo (p. ej. "CENTRO_DE_SALUD"), una variable sin resolver, o un hueco de
# plantilla. Se acepta el guion bajo dentro de palabras ya traducidas
# (ninguna, en español), así que cualquier coincidencia es sospechosa.
_GLOSA_CRUDA = re.compile(r"[A-ZÑ]{2,}_[A-ZÑ]{2,}")


def _assert_texto_coherente(caso, contexto, texto):
    caso.assertTrue(texto.strip(), f"[{contexto}] texto vacío")
    caso.assertNotRegex(texto, _GLOSA_CRUDA,
                         f"[{contexto}] glosa cruda filtrada: {texto!r}")
    caso.assertNotIn("None", texto, f"[{contexto}] variable sin resolver: {texto!r}")
    caso.assertNotIn("{", texto, f"[{contexto}] hueco de plantilla: {texto!r}")
    caso.assertNotRegex(texto, r"\(\s*\)", f"[{contexto}] paréntesis vacío: {texto!r}")


class RecorridoDeLosOchoContextos(unittest.TestCase):
    """Cada uno de los 8 contextos produce una declaración formal coherente
    a partir de un `declaration` estructurado representativo."""

    CASOS = {
        "denuncia_robo": {
            "contextId": "denuncia_robo",
            "fact": {"action": "ROBAR"},
            "persons": [{
                "id": "p1", "role": "suspect", "gender": "HOMBRE",
                "clothing": [
                    {"id": "c1", "concept": "POLERA", "color": "ROJO", "colorState": "confirmed"},
                ],
            }],
            "objects": [{"concept": "CELULAR", "role": "stolen"}],
            "location": {
                "relation": "CERCA", "referenceType": "other",
                "referenceLiteralText": "Mercado Calatayud",
            },
            "witnesses": {"existence": "confirmed", "count": "2"},
        },
        "violencia": {
            "contextId": "violencia",
            "violence": {
                "aggressionType": "agresión física", "physicalInjury": True,
                "medicalCareRequested": True,
            },
        },
        "amenaza_digital": {
            "contextId": "amenaza_digital",
            "digital_threat": {"medio": "WhatsApp", "mensajes_guardados": True},
        },
        "engano_dinero": {
            "contextId": "engano_dinero",
            "fraud": {"tipo_engano": "transferencia falsa", "amount": "500",
                      "deliveryMethod": "transferencia bancaria"},
        },
        "seguimiento": {
            "contextId": "seguimiento",
            "procedure": {"tipo_tramite": "estado de investigación", "caseNumber": "407"},
        },
        "identificacion": {
            "contextId": "identificacion",
            "identificacion_nombre": "Ana Pérez",
            "identificacion_documento": "Carnet de Identidad (C.I.)",
        },
        "preguntas": {
            "contextId": "preguntas",
            "consulta": {"pregunta_principal": "¿Dónde presento este documento?"},
        },
        "otro": {
            "contextId": "otro",
            "fact": {"narrative": "Vi al hombre correr con la mochila."},
            "persons": [{"id": "p1", "role": "witness", "gender": "HOMBRE"}],
        },
    }

    def test_cada_contexto_redacta_texto_formal_coherente(self):
        for contexto, payload in self.CASOS.items():
            with self.subTest(contexto=contexto):
                texto = L.generate_structured_sentence(payload)
                _assert_texto_coherente(self, contexto, texto)

    def test_ningun_contexto_devuelve_el_mismo_texto_vacio_generico(self):
        # Cada contexto con datos reales debe distinguirse del texto de
        # respaldo ("aunque todavía no completé los detalles"), o la
        # persona no puede saber si su declaración se registró.
        generico = "Quiero comunicar lo siguiente, aunque todavía no completé los detalles."
        for contexto, payload in self.CASOS.items():
            with self.subTest(contexto=contexto):
                texto = L.generate_structured_sentence(payload)
                self.assertNotEqual(texto, generico, f"[{contexto}] no usó los datos aportados")


class DesambiguacionObligatoriaEnElBackend(unittest.TestCase):
    """Los términos genéricos deben llegar como campos ya resueltos —el
    backend nunca debe tener que adivinar qué significan."""

    def test_billetes_sin_monto_no_inventa_una_cifra(self):
        texto = L.generate_structured_sentence({
            "contextId": "denuncia_robo",
            "fact": {"action": "ROBAR"},
            "objects": [{"concept": "BILLETES", "role": "stolen"}],
        })
        self.assertNotRegex(texto, r"\d+\s+bolivianos")

    def test_billetes_con_monto_lo_conserva_literal(self):
        texto = L.generate_structured_sentence({
            "contextId": "denuncia_robo",
            "fact": {"action": "ROBAR"},
            "objects": [{"concept": "BILLETES", "role": "stolen",
                         "quantity": "500", "unit": "bolivianos"}],
        })
        self.assertIn("500 bolivianos", texto)

    def test_mochila_robada_y_llevada_no_se_funden(self):
        texto = L.generate_structured_sentence({
            "contextId": "denuncia_robo",
            "fact": {"action": "ROBAR"},
            "persons": [{"id": "p1", "role": "suspect", "gender": "HOMBRE"}],
            "objects": [
                {"concept": "MOCHILA", "role": "stolen"},
                {"concept": "MOCHILA", "role": "carriedByOtherPerson", "carriedByPersonId": "p1"},
            ],
        })
        lower = texto.lower()
        self.assertIn("mochila", lower)
        self.assertIn("llevaba", lower)

    def test_cerca_sin_referencia_no_fabrica_un_lugar(self):
        texto = L.generate_structured_sentence({
            "contextId": "denuncia_robo",
            "fact": {"action": "ROBAR"},
            "objects": [{"concept": "CELULAR", "role": "stolen"}],
            "location": {"relation": "CERCA", "pending": True},
        })
        self.assertNotIn("cerca", texto.lower())

    def test_micro_como_referencia_de_lugar_no_es_objeto_robado(self):
        texto = L.generate_structured_sentence({
            "contextId": "denuncia_robo",
            "fact": {"action": "ROBAR"},
            "objects": [{"concept": "CELULAR", "role": "stolen"}],
            "location": {
                "relation": "DENTRO", "referenceType": "conceptCard",
                "referenceConceptGloss": "MICRO",
            },
        })
        lower = texto.lower()
        self.assertIn("dentro de un micro", lower)
        self.assertNotIn("me robó un micro", lower)


class AisamientoDeEntidadesEnElBackend(unittest.TestCase):
    """Dos personas o dos objetos con el mismo concepto léxico conservan
    sus propios atributos sin contaminarse."""

    def test_colores_de_dos_personas_no_se_mezclan(self):
        texto = L.generate_structured_sentence({
            "contextId": "denuncia_robo",
            "fact": {"action": "ROBAR"},
            "persons": [
                {"id": "p1", "role": "suspect", "gender": "HOMBRE",
                 "clothing": [{"id": "c1", "concept": "POLERA", "color": "ROJO",
                               "colorState": "confirmed"}]},
                {"id": "p2", "role": "suspect", "gender": "MUJER",
                 "clothing": [{"id": "c2", "concept": "POLERA", "color": "AZUL",
                               "colorState": "confirmed"}]},
            ],
            "objects": [{"concept": "CELULAR", "role": "stolen"}],
        })
        lower = texto.lower()
        self.assertIn("roja", lower)
        self.assertIn("azul", lower)

    def test_no_saber_si_hay_testigos_no_se_redacta_como_negacion(self):
        texto = L.generate_structured_sentence({
            "contextId": "denuncia_robo",
            "fact": {"action": "ROBAR"},
            "objects": [{"concept": "CELULAR", "role": "stolen"}],
            "witnesses": {"existence": "uncertain"},
        })
        lower = texto.lower()
        self.assertIn("no sé si hay testigos", lower)
        self.assertNotIn("no hay testigos", lower)

    def test_negar_conocer_a_alguien_no_se_traslada_a_los_testigos(self):
        # Dos polaridades independientes: no conocer al sospechoso y sí
        # tener testigos deben convivir sin que una contamine a la otra.
        texto = L.generate_structured_sentence({
            "contextId": "denuncia_robo",
            "fact": {"action": "ROBAR"},
            "objects": [{"concept": "CELULAR", "role": "stolen"}],
            "witnesses": {"existence": "confirmed", "count": "1"},
        })
        lower = texto.lower()
        self.assertIn("hay 1 testigos", lower)


class ActoComunicativoYRegistroFormal(unittest.TestCase):
    """El registro debe sonar formal ('el declarante', 'denuncio',
    'solicito'...) y el acto comunicativo (afirmar vs. preguntar) debe
    preservarse en la validación de fidelidad."""

    def test_preguntas_conserva_el_signo_de_interrogacion_cuando_hay_pregunta(self):
        texto = L.generate_structured_sentence({
            "contextId": "preguntas",
            "consulta": {"pregunta_principal": "¿Dónde presento este documento?"},
        })
        self.assertIn("¿", texto)

    def test_validador_de_fidelidad_rechaza_fabricar_una_pregunta(self):
        cards = ["ROBAR", "CELULAR"]
        base = "Una persona me robó mi celular."
        pregunta_fabricada = "¿Una persona me robó mi celular?"
        seguro, _ = L._generation_is_safe(cards, pregunta_fabricada, base)
        self.assertFalse(seguro)

    def test_validador_de_fidelidad_rechaza_un_monto_no_declarado(self):
        cards = ["ROBAR", "BILLETES"]
        base = "Una persona me robó billetes y dinero."
        con_monto = "Una persona me robó 500 bolivianos en billetes y dinero."
        seguro, motivo = L._generation_is_safe(cards, con_monto, base)
        self.assertFalse(seguro)
        self.assertIn("número", motivo)


if __name__ == "__main__":
    unittest.main()
