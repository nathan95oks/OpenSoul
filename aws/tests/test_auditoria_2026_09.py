"""Pruebas de los hallazgos corregidos en la auditoría 2026-09.

Cubre, contra el backend real (con sus dobles de AWS): normalización de
tildes en el lexicón, PERDER sin atribuir la pérdida a otra persona, que
NO+TESTIGO no fabrique una afirmación de robo, la relación espacial CERCA sin
una referencia vaga, el marcador de evidencia sin filtrarse como texto crudo,
el validador de fidelidad rechazando montos inventados y el cambio de
afirmación a pregunta, y el generador estructurado (`declaration`) para
`denuncia_robo`.

    python3 -m unittest discover -s aws/tests -v
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()

import lambda_function as L  # noqa: E402


def frase(context_type, cards):
    analysis = L.analyze_glosses(cards)
    L._resolve_gender(analysis)
    L._resolve_time(analysis, context_type, cards)
    ir = L.build_intermediate_representation(cards, analysis, context_type)
    return L.generate_base_sentence(ir, analysis, context_type)


class NormalizacionDeAcentos(unittest.TestCase):
    """El lexicón debe resolver la forma acentuada del diccionario canónico,
    no solo la forma sin tilde."""

    def test_dia_con_tilde_resuelve_igual_que_sin_tilde(self):
        self.assertIsNotNone(L.lexicon_lookup("DÍA"))
        self.assertEqual(L.lexicon_lookup("DÍA"), L.lexicon_lookup("DIA"))

    def test_policia_con_tilde_se_reconoce(self):
        self.assertIsNotNone(L.lexicon_lookup("POLICÍA"))

    def test_organo_judicial_con_tilde_se_reconoce(self):
        self.assertIsNotNone(L.lexicon_lookup("ÓRGANO_JUDICIAL"))

    def test_resolucion_con_tilde_se_reconoce(self):
        self.assertIsNotNone(L.lexicon_lookup("RESOLUCIÓN"))


class PerderNoAtribuyeAOtraPersona(unittest.TestCase):
    """PERDER no debe conjugarse como si otra persona hubiera actuado, ni
    siquiera dentro del contexto de denuncia_robo (auditoría 2026-09)."""

    def test_perder_mas_celular_no_dice_una_persona(self):
        texto = frase("denuncia_robo", ["PERDER", "CELULAR"])
        self.assertNotIn("una persona", texto.lower())
        self.assertNotIn("me perdí", texto.lower())

    def test_perder_enruta_a_perdida_incluso_en_denuncia_robo(self):
        analysis = L.analyze_glosses(["PERDER", "CELULAR"])
        tipo = L._detect_event_type(analysis, "denuncia_robo")
        self.assertEqual(tipo, "PERDIDA")


class NoTestigoNoFabricaRobo(unittest.TestCase):
    """Responder solo que no hay testigos no debe afirmar que hubo un robo
    (auditoría 2026-09, hallazgo NO+TESTIGO)."""

    def test_no_testigo_no_menciona_robo(self):
        texto = frase("denuncia_robo", ["NO", "TESTIGO"])
        self.assertNotIn("robó", texto.lower())
        self.assertIn("no hay testigos", texto.lower())

    def test_sin_contenido_del_hecho_el_contexto_no_fuerza_robo(self):
        analysis = L.analyze_glosses(["NO", "TESTIGO"])
        tipo = L._detect_event_type(analysis, "denuncia_robo")
        self.assertNotEqual(tipo, "ROBO")


class CercaSinReferenciaVaga(unittest.TestCase):
    """CERCA sin una referencia no debe fabricar 'cerca del lugar'
    (auditoría 2026-09)."""

    def test_cerca_sin_referencia_no_dice_del_lugar(self):
        texto = frase("denuncia_robo", ["ROBAR", "CELULAR", "CERCA"])
        self.assertNotIn("del lugar", texto.lower())

    def test_cerca_admite_detalle(self):
        self.assertIn("CERCA", L._ADMITE_DETALLE)
        self.assertIn("LEJOS", L._ADMITE_DETALLE)
        self.assertIn("DENTRO", L._ADMITE_DETALLE)
        self.assertIn("FUERA", L._ADMITE_DETALLE)
        self.assertIn("AL_LADO", L._ADMITE_DETALLE)


class MarcadorDeEvidenciaNoSeFiltra(unittest.TestCase):
    """PRUEBA_MARCADOR es un control estructural, no una palabra del relato
    (auditoría 2026-09)."""

    def test_prueba_marcador_no_aparece_como_texto_crudo(self):
        texto = frase("denuncia_robo", ["ROBAR", "CELULAR", "PRUEBA_MARCADOR", "FOTOS"])
        self.assertNotIn("prueba_marcador", texto.lower())
        self.assertNotIn("marcador", texto.lower())

    def test_objeto_tras_el_marcador_se_aporta_como_prueba(self):
        analysis = L.analyze_glosses(["ROBAR", "CELULAR", "PRUEBA_MARCADOR", "FOTOS"])
        evidencias = [e["glosa"] for e in analysis.get("evidencias", [])]
        self.assertIn("FOTOS", evidencias)
        objetos = [o["glosa"] for o in analysis["objetos"]]
        self.assertNotIn("FOTOS", objetos)


class ValidadorDeFidelidadMasEstricto(unittest.TestCase):
    """`_generation_is_safe` no debe aceptar montos inventados ni un cambio
    de afirmación a pregunta (auditoría 2026-09, hallazgo del validador)."""

    def test_rechaza_un_monto_inventado(self):
        cards = ["ROBAR", "BILLETES"]
        base = frase("denuncia_robo", cards)
        seguro, motivo = L._generation_is_safe(
            cards, "Una persona me robó 500 bolivianos en billetes.", base)
        self.assertFalse(seguro)
        self.assertIn("número", motivo)

    def test_rechaza_convertir_afirmacion_en_pregunta(self):
        cards = ["ROBAR", "CELULAR"]
        base = frase("denuncia_robo", cards)
        pregunta = "¿" + base.rstrip(".") + "?"
        seguro, motivo = L._generation_is_safe(cards, pregunta, base)
        self.assertFalse(seguro)

    def test_acepta_una_redaccion_natural_sin_montos_nuevos(self):
        cards = ["ROBAR", "CELULAR"]
        base = frase("denuncia_robo", cards)
        seguro, motivo = L._generation_is_safe(
            cards, "Quiero denunciar que una persona me robó mi celular.", base)
        self.assertTrue(seguro, motivo)


class ClaveDeCacheIncluyeMasContexto(unittest.TestCase):
    """Dos peticiones con las mismas glosas pero distinto institutionType,
    language o declaration no deben compartir caché (auditoría 2026-09)."""

    def test_institution_type_distinto_cambia_la_clave(self):
        a = L.generate_cache_key("denuncia_robo", ["ROBAR"], institution_type="entidad_publica")
        b = L.generate_cache_key("denuncia_robo", ["ROBAR"], institution_type="")
        self.assertNotEqual(a, b)

    def test_declaration_distinta_cambia_la_clave(self):
        a = L.generate_cache_key("denuncia_robo", ["ROBAR"],
                                  declaration={"location": {"relation": "CERCA"}})
        b = L.generate_cache_key("denuncia_robo", ["ROBAR"],
                                  declaration={"location": {"relation": "LEJOS"}})
        self.assertNotEqual(a, b)

    def test_mismos_parametros_misma_clave(self):
        a = L.generate_cache_key("denuncia_robo", ["ROBAR"], institution_type="x", language="es")
        b = L.generate_cache_key("denuncia_robo", ["ROBAR"], institution_type="x", language="es")
        self.assertEqual(a, b)


class GeneradorEstructurado(unittest.TestCase):
    """`generate_structured_sentence` — espejo Python de `assembleStructured`
    (auditoría 2026-09). Mismos casos que
    test/declaration_draft_assembler_test.dart en el cliente."""

    def test_perder_no_atribuye_a_otra_persona(self):
        texto = L.generate_structured_sentence({
            "fact": {"action": "PERDER"},
            "objects": [{"concept": "CELULAR", "role": "lost"}],
        })
        self.assertIn("perdí", texto.lower())
        self.assertNotIn("me robó", texto.lower())

    def test_cerca_con_mi_casa(self):
        texto = L.generate_structured_sentence({
            "fact": {"action": "ROBAR"},
            "objects": [{"concept": "CELULAR", "role": "stolen"}],
            "location": {"relation": "CERCA", "referenceType": "home"},
        })
        self.assertIn("cerca de mi casa", texto.lower())

    def test_fuera_con_texto_literal_conserva_mayusculas(self):
        texto = L.generate_structured_sentence({
            "fact": {"action": "ROBAR"},
            "objects": [{"concept": "CELULAR", "role": "stolen"}],
            "location": {
                "relation": "FUERA", "referenceType": "other",
                "referenceLiteralText": "Mercado Calatayud",
            },
        })
        self.assertIn("fuera de Mercado Calatayud", texto)

    def test_cerca_pendiente_no_inventa_lugar(self):
        texto = L.generate_structured_sentence({
            "fact": {"action": "ROBAR"},
            "objects": [{"concept": "CELULAR", "role": "stolen"}],
            "location": {"relation": "CERCA", "pending": True},
        })
        self.assertNotIn("cerca", texto.lower())

    def test_colores_por_prenda_no_se_mezclan(self):
        texto = L.generate_structured_sentence({
            "fact": {"action": "ROBAR"},
            "persons": [{
                "id": "p1", "role": "suspect", "gender": "HOMBRE",
                "clothing": [
                    {"id": "c1", "concept": "POLERA", "color": "ROJO", "colorState": "confirmed"},
                    {"id": "c2", "concept": "PANTALON", "color": "NEGRO", "colorState": "confirmed"},
                ],
            }],
            "objects": [{"concept": "CELULAR", "role": "stolen"}],
        })
        lower = texto.lower()
        self.assertIn("polera roja", lower)
        self.assertIn("pantalón negro", lower)
        self.assertIn("me robó mi celular", lower)

    def test_mochila_robada_y_mochila_llevada_son_distintas(self):
        texto = L.generate_structured_sentence({
            "fact": {"action": "ROBAR"},
            "persons": [{"id": "p1", "role": "suspect", "gender": "HOMBRE"}],
            "objects": [
                {"concept": "MOCHILA", "role": "stolen"},
                {"concept": "MOCHILA", "role": "carriedByOtherPerson", "carriedByPersonId": "p1"},
            ],
        })
        lower = texto.lower()
        self.assertIn("me robó", lower)
        self.assertIn("llevaba una mochila", lower)

    def test_500_bolivianos_conserva_monto(self):
        texto = L.generate_structured_sentence({
            "fact": {"action": "ROBAR"},
            "objects": [{"concept": "BILLETES", "role": "stolen",
                         "quantity": "500", "unit": "bolivianos"}],
        })
        self.assertIn("500 bolivianos en billetes", texto)

    def test_no_sabe_si_hay_testigos_no_dice_que_no_hay(self):
        texto = L.generate_structured_sentence({
            "fact": {"action": "ROBAR"},
            "objects": [{"concept": "CELULAR", "role": "stolen"}],
            "witnesses": {"existence": "uncertain"},
        })
        lower = texto.lower()
        self.assertIn("no sé si hay testigos", lower)
        self.assertNotIn("no hay testigos", lower)


if __name__ == "__main__":
    unittest.main()
