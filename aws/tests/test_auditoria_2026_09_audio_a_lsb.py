"""Regresión de la auditoría 2026-09 del módulo Audio/Texto -> LSB.

Convierte en pruebas los hallazgos de la auditoría del encargo "Audio/Texto ->
LSB": equivalencias falsas, cobertura ciega a negación/cifras, glosas
inventadas que sobrevivían con apariencia de traducción válida, desambiguación
de "auto" y el desfase servidor/cliente en I/K. Cada prueba corresponde a un
hallazgo concreto, no a una garantía general de calidad de traducción.

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


class EquivalenciasFalsas(unittest.TestCase):
    """Ficha B: una equivalencia ortográfica no es una equivalencia de
    significado. BILLETERA no es BILLETES; CORRER no es ESCAPAR."""

    def test_billetera_no_se_convierte_en_billetes(self):
        resultado = m.post_process_glosses(
            {"glosses": ["PERDER", "BILLETERA"]}, "Perdió la billetera",
        )
        self.assertNotIn("BILLETES", resultado["glosses"])
        self.assertEqual(resultado["glosses"][0], "PERDER")
        # Sin seña propia en el catálogo: se deletrea, no se descarta ni se
        # sustituye por un concepto distinto.
        self.assertEqual(resultado["glosses"][1:], list("BILLETERA"))

    def test_correr_no_se_convierte_en_escapar(self):
        resultado = m.post_process_glosses(
            {"glosses": ["CORRER"]}, "La persona corrió hasta la parada",
        )
        self.assertNotIn("ESCAPAR", resultado["glosses"])
        self.assertEqual(resultado["glosses"], list("CORRER"))

    def test_los_alias_retirados_ya_no_estan_en_la_tabla(self):
        self.assertNotIn("BILLETERA", m.GLOSS_ALIASES)
        self.assertNotIn("CORRER", m.GLOSS_ALIASES)


class FalsoAmigoFiscal(unittest.TestCase):
    """El corpus (M3) documenta que la seña "FISCAL" es un falso amigo: es el
    sentido escolar de "fiscal/público", no el funcionario del Ministerio
    Público, y prohíbe expresamente reutilizarla
    (docs/Corpus_Maestro_Unificado_LSB_v4_Auditado.md, filas 71/78). Ni el
    prompt debe pedirla para esa persona, ni post_process_glosses debe dejarla
    pasar como si fuera una seña real para ese sentido."""

    def test_la_regla_del_prompt_ya_no_pide_fiscal_para_el_funcionario(self):
        self.assertNotIn('"fiscal" (Autoridad judicial): Mapear a "FISCAL"',
                          m.LEGAL_DISAMBIGUATION_RULES)

    def test_prompt_distingue_llama_animal_de_llamar_verbo(self):
        # "La llama está en el campo" no debe forzarse a LLAMAR: no hay seña
        # del animal en el catálogo, y la del verbo cambiaría el hecho.
        self.assertIn('"llama" como SUSTANTIVO', m.LEGAL_DISAMBIGUATION_RULES)
        self.assertIn('NO la mapees a "LLAMAR"', m.LEGAL_DISAMBIGUATION_RULES)

    def test_fiscal_como_funcionario_no_es_una_glosa_real_del_catalogo(self):
        # FISCAL (a secas) no está en AVAILABLE_GLOSSES: si el modelo la
        # devolviera de todos modos, se deletrea en vez de presentarse como
        # si fuera la seña M3 (que es de otro sentido).
        self.assertNotIn("FISCAL", m._AVAILABLE_GLOSSES_NORM)
        resultado = m.post_process_glosses(
            {"glosses": ["YO", "FISCAL", "HABLAR"]}, "Yo hablé con el fiscal",
        )
        self.assertNotIn("FISCAL", resultado["glosses"])
        self.assertIn("F", resultado["glosses"])  # deletreado letra por letra


class ConceptoSinCatalogo(unittest.TestCase):
    """Ficha D: `post_process_glosses` ya no acepta una cadena con forma de
    glosa sin comprobar que esté documentada en AVAILABLE_GLOSSES."""

    def test_glosa_inventada_bien_formada_se_deletrea(self):
        resultado = m.post_process_glosses(
            {"glosses": ["ROBAR", "ROBOXYZ"]}, "da igual",
        )
        self.assertEqual(resultado["glosses"][0], "ROBAR")
        self.assertEqual(resultado["glosses"][1:], list("ROBOXYZ"))
        incidencia = next(
            i for i in resultado["fidelityFixes"]
            if i["accion"] == "concepto_sin_catalogo"
        )
        self.assertEqual(incidencia["palabra"], "ROBOXYZ")

    def test_glosa_real_no_se_deletrea(self):
        resultado = m.post_process_glosses({"glosses": ["ROBAR"]}, "da igual")
        self.assertEqual(resultado["glosses"], ["ROBAR"])
        self.assertEqual(resultado["fidelityFixes"], [])


class PerdidaDeNegacionYCifras(unittest.TestCase):
    """Ficha C/F: NO, SIN y NI dejaron de ser palabras función, y las cifras
    ahora se pueden perder de forma detectable."""

    def test_negacion_ausente_del_texto_no_genera_incidencia(self):
        resultado = m.post_process_glosses(
            {"glosses": ["PRESENTAR"]}, "Presente el documento",
        )
        self.assertFalse(
            any(i["accion"] == "negacion_perdida" for i in resultado["fidelityFixes"])
        )

    def test_representacion_completa_cuando_todo_esta_disponible(self):
        # PRESENTAR es una glosa real pero no está entre las ~41 señas ya
        # horneadas en 3D (AVAILABLE_3D_GLOSSES): cae en dactilología y por
        # eso su `representationStatus` es "partial", no "complete" — eso es
        # honesto, no un error. Para el caso "complete" hace falta una glosa
        # que sí tenga animación confirmada.
        resultado = m.post_process_glosses({"glosses": ["HOLA"]}, "Hola")
        self.assertEqual(resultado["representationStatus"], "complete")

    def test_no_en_el_texto_sin_glosa_de_negacion_se_marca(self):
        resultado = m.post_process_glosses(
            {"glosses": ["PRESENTAR"]}, "No presente el documento todavía",
        )
        self.assertTrue(
            any(i["accion"] == "negacion_perdida" for i in resultado["fidelityFixes"])
        )
        # Una pérdida de negación no recuperable también cuenta como
        # representación incompleta, aunque cada palabra por separado sí
        # tenga glosa.
        self.assertEqual(resultado["representationStatus"], "partial")

    def test_no_conservado_en_la_salida_no_genera_incidencia(self):
        resultado = m.post_process_glosses(
            {"glosses": ["PRESENTAR", "NO"]}, "No presente el documento todavía",
        )
        self.assertFalse(
            any(i["accion"] == "negacion_perdida" for i in resultado["fidelityFixes"])
        )

    def test_cifra_perdida_se_detecta_por_cada_digito(self):
        resultado = m.post_process_glosses(
            {"glosses": ["ENTREGAR", "COPIA"]}, "Entregue 2 copias, no 3",
        )
        acciones = [i["accion"] for i in resultado["fidelityFixes"]]
        self.assertIn("cifra_perdida", acciones)
        detalles = " ".join(
            i["detalle"] for i in resultado["fidelityFixes"]
            if i["accion"] == "cifra_perdida"
        )
        self.assertIn("'2'", detalles)
        self.assertIn("'3'", detalles)

    def test_cifra_conservada_no_genera_incidencia(self):
        # El dígito se conserva tal cual ("2"), no como palabra ("DOS"): ya
        # no hay alias de dígito a nombre (ver EquivalenciasFalsas más abajo
        # sobre por qué se retiró).
        resultado = m.post_process_glosses(
            {"glosses": ["2", "CERTIFICADO"]}, "Entregue 2 certificados",
        )
        self.assertFalse(
            any(i["accion"] == "cifra_perdida" for i in resultado["fidelityFixes"])
        )


class DesambiguacionAuto(unittest.TestCase):
    """Sección 5 del encargo: "auto" (vehículo / resolución) como caso
    insignia del contrato de aclaración pendiente."""

    def test_sin_evidencia_queda_pendiente_y_no_afirma_ningun_sentido(self):
        resultado = m.post_process_glosses({"glosses": ["TRAER"]}, "Traiga el auto")
        self.assertEqual(resultado["semanticStatus"], "needs_clarification")
        self.assertEqual(len(resultado["pendingClarifications"]), 1)
        pendiente = resultado["pendingClarifications"][0]
        self.assertEqual(pendiente["term"], "AUTO")
        self.assertEqual({o["id"] for o in pendiente["options"]},
                          {"vehiculo", "resolucion"})
        self.assertNotIn("RESOLUCIÓN", resultado["glosses"])
        self.assertNotIn("AUTO", resultado["glosses"])

    def test_contexto_judicial_resuelve_sin_preguntar(self):
        resultado = m.post_process_glosses(
            {"glosses": []}, "El juez emitió un auto",
        )
        self.assertEqual(resultado["glosses"], ["RESOLUCION"])
        self.assertEqual(resultado["pendingClarifications"], [])
        self.assertEqual(resultado["semanticStatus"], "resolved")

    def test_contexto_vehicular_resuelve_sin_preguntar_y_sin_inventar_sena(self):
        resultado = m.post_process_glosses(
            {"glosses": []}, "El auto está estacionado afuera",
        )
        self.assertNotIn("RESOLUCIÓN", resultado["glosses"])
        self.assertEqual(resultado["glosses"], list("AUTO"))
        self.assertEqual(resultado["pendingClarifications"], [])

    def test_sentido_ya_elegido_por_la_persona_se_respeta(self):
        resultado = m.post_process_glosses(
            {"glosses": []}, "Traiga el auto", {"AUTO": "resolucion"},
        )
        self.assertEqual(resultado["glosses"], ["RESOLUCION"])
        self.assertEqual(resultado["pendingClarifications"], [])

    def test_misma_frase_con_sentido_distinto_no_comparte_cache(self):
        clave_vehiculo = m.generate_cache_key("traiga el auto", None, {"AUTO": "vehiculo"})
        clave_resolucion = m.generate_cache_key("traiga el auto", None, {"AUTO": "resolucion"})
        clave_sin_resolver = m.generate_cache_key("traiga el auto", None, {})
        self.assertNotEqual(clave_vehiculo, clave_resolucion)
        self.assertNotEqual(clave_vehiculo, clave_sin_resolver)


class DisponibilidadDeAnimacion(unittest.TestCase):
    """Ficha E: la I y la K no están horneadas en el avatar 3D; el servidor
    ya no afirma lo contrario."""

    def test_i_y_k_no_estan_disponibles_en_3d(self):
        self.assertNotIn("I", m.AVAILABLE_3D_GLOSSES)
        self.assertNotIn("K", m.AVAILABLE_3D_GLOSSES)

    def test_i_y_k_siguen_siendo_letras_validas_del_catalogo(self):
        # Sin animación 3D, pero siguen siendo glosas reales (se deletrean).
        self.assertIn("I", m.AVAILABLE_GLOSSES)
        self.assertIn("K", m.AVAILABLE_GLOSSES)


class NombrePropioAlPrincipioDeFrase(unittest.TestCase):
    """Ficha F: un nombre que se repite en el texto no pierde su deletreo
    solo porque la primera mención abre la oración."""

    def test_nombre_repetido_protege_tambien_la_mencion_inicial(self):
        # La segunda mención de "Ana" está en medio de la frase (no abre
        # oración), así que también protege la primera, que si estuviera sola
        # sería indistinguible de cualquier palabra capitalizada por ir
        # primera.
        texto = "Ana vino y luego Ana declaró que perdió su documento."
        self.assertTrue(m._es_nombre_propio("Ana", texto))

    def test_nombre_unico_al_inicio_sigue_sin_poder_distinguirse(self):
        # Limitación conocida y documentada: sin diccionario de nombres, una
        # única mención al principio de la frase es indistinguible de
        # cualquier otra palabra capitalizada por ir primera.
        self.assertFalse(m._es_nombre_propio("Ana", "Ana vino"))

    def test_nombre_en_medio_de_la_frase_se_protege_como_antes(self):
        self.assertTrue(m._es_nombre_propio("Ana", "declaro que vino Ana"))
