"""Casos del CORPUS CONVERSACIONAL PRELIMINAR contra el ensamblador Python.

Comparten archivo con la suite de Dart (`test/casos_corpus_test.dart`): el
esperado se captura del motor real con `regenerar_casos_corpus.py` y aquí se
congela. Si un cambio altera una salida, la prueba lo dice y hay que decidir
si la nueva redacción es mejor — no se regenera a ciegas.

    python3 -m unittest discover -s aws/tests -v
"""

import json
import os
import sys
import unittest

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(RAIZ, "aws"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install  # noqa: E402

_install()

import lambda_function as L  # noqa: E402

with open(os.path.join(RAIZ, "aws", "tests", "casos_corpus.json"),
          encoding="utf-8") as _f:
    CASOS = json.load(_f)["casos"]

with open(os.path.join(RAIZ, "assets", "dictionary", "official_dictionary.json"),
          encoding="utf-8") as _f:
    CATALOGO = {e["gloss"]: e for e in json.load(_f)["entries"]}


def frase(caso):
    analysis = L.analyze_glosses(caso["glosas"])
    ir = L.build_intermediate_representation(
        caso["glosas"], analysis, caso["contexto"])
    return L.generate_base_sentence(ir, analysis, caso["contexto"])


def por_id(case_id):
    return next(c for c in CASOS if c["case_id"] == case_id)


class CorpusIntegridad(unittest.TestCase):
    def test_hay_al_menos_quince_casos(self):
        self.assertGreaterEqual(len(CASOS), 15)

    def test_toda_glosa_citada_existe_en_el_diccionario(self):
        for caso in CASOS:
            for g in caso["glosas"]:
                self.assertIn(g, CATALOGO,
                              f'{caso["case_id"]} cita una glosa inexistente: {g}')

    def test_los_iconos_declarados_existen(self):
        reales = {e["semanticIcon"] for e in CATALOGO.values()}
        for caso in CASOS:
            for icono in caso["lsb_icons"]:
                self.assertIn(icono, reales, f'{caso["case_id"]}: {icono}')


class CorpusRedaccion(unittest.TestCase):
    """La salida no cambia sin que nadie se entere."""

    def test_cada_caso_redacta_lo_esperado(self):
        for caso in CASOS:
            with self.subTest(caso["case_id"]):
                self.assertEqual(frase(caso), caso["esperado_backend"])

    def test_ninguna_glosa_cruda_se_filtra(self):
        for caso in CASOS:
            with self.subTest(caso["case_id"]):
                self.assertNotIn("_", frase(caso))


class ReglasDeOro(unittest.TestCase):
    """Las seis reglas del sistema, cada una con su caso del corpus."""

    def test_cp002_la_huida_cierra_el_relato(self):
        texto = frase(por_id("CP-002")).lower()
        self.assertNotIn("me salió corriendo", texto)
        self.assertIn("en el mercado y salió corriendo", texto)

    def test_cp003_la_evidencia_no_es_el_botin(self):
        texto = frase(por_id("CP-003")).lower()
        self.assertNotIn("billetera y una fotografía", texto)
        self.assertIn("como prueba tengo una fotografía", texto)

    def test_cp004_seguro_es_estado_no_rasgo(self):
        texto = frase(por_id("CP-004")).lower()
        self.assertNotIn("expareja seguro", texto)
        self.assertIn("lugar seguro", texto)

    def test_cp005_ayer_manda_sobre_primera_vez(self):
        texto = frase(por_id("CP-005")).lower()
        self.assertTrue(texto.startswith("ayer"), texto)
        self.assertIn("es la primera vez", texto)

    def test_cp007_un_canal_digital_lleva_preposicion(self):
        texto = frase(por_id("CP-007")).lower()
        self.assertNotIn("amenazó whatsapp", texto)
        self.assertIn("por whatsapp", texto)

    def test_cp008_dos_urgencias_no_se_excluyen(self):
        texto = frase(por_id("CP-008")).lower()
        self.assertIn("herida", texto)
        self.assertIn("auxilio", texto)

    def test_cp011_una_racha_de_digitos_es_un_numero(self):
        # "1 0 2 4" es un NUREJ, no cuatro selecciones sueltas. El 0 no está
        # en _CARDINALES —nunca es cantidad— pero sí es dígito: sin eso la
        # racha se partía y el primer dígito se perdía.
        self.assertIn("1024", frase(por_id("CP-011")))

    def test_cp012_un_digito_huerfano_se_descarta(self):
        import re
        self.assertIsNone(re.search(r"\b7\b", frase(por_id("CP-012"))))

    def test_cp012_los_marcadores_encabezan(self):
        # Paridad: el cliente antepone "No sé. No recuerdo."; aquí caían en
        # "hago referencia a no sé".
        texto = frase(por_id("CP-012"))
        self.assertTrue(texto.startswith("No sé."), texto)

    def test_cp013_dos_instituciones_se_enlazan(self):
        texto = frase(por_id("CP-013")).lower()
        self.assertIn("fiscalía", texto)
        self.assertIn("despacho", texto)

    def test_cp014_el_plazo_mira_hacia_adelante(self):
        self.assertIn("dentro de tres días", frase(por_id("CP-014")).lower())

    def test_cp015_un_servicio_no_es_el_objeto_del_verbo(self):
        texto = frase(por_id("CP-015")).lower()
        self.assertNotIn("corregir un intérprete", texto)
        self.assertIn("necesito un intérprete", texto)


if __name__ == "__main__":
    unittest.main()
