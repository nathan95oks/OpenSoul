"""Equivalencias con señas del catálogo: módulo y acción de la Lambda.

Bedrock se simula: lo que se prueba es que solo salgan glosas del catálogo
oficial, sea lo que sea lo que conteste el modelo.
"""

import io
import json
import os
import sys
import unittest
from unittest import mock

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TESTS_DIR)

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()
sys.path.insert(0, os.path.join(TESTS_DIR, ".."))

import lambda_function as L  # noqa: E402
import rag_equivalencias as EQ  # noqa: E402

DOCUMENTO = {"palabra": "DOCUMENTO", "ejemplos": ["Me falta un documento."]}
HIPOTECA = {"palabra": "HIPOTECA", "ejemplos": ["¿Mi casa tiene hipoteca?"]}


class Catalogo(unittest.TestCase):
    def test_solo_las_senas_oficiales(self):
        cat = EQ.cargar_catalogo()
        self.assertEqual(len(cat), 346)
        self.assertIn("el documento", cat["PAPEL"])
        # PAGAR y DENUNCIAR son reglas del ensamblador de texto, sin seña.
        self.assertNotIn("PAGAR", cat)
        self.assertNotIn("DENUNCIAR", cat)

    def test_el_prompt_lleva_el_catalogo_y_las_frases(self):
        texto = EQ.prompt([DOCUMENTO], EQ.cargar_catalogo())
        self.assertIn("- PAPEL: Papel; el documento", texto)
        self.assertIn("«Me falta un documento.»", texto)


class Validacion(unittest.TestCase):
    cat = {"PAPEL": "Papel; el documento", "CASA": "Casa"}

    def test_una_glosa_fuera_del_catalogo_se_descarta(self):
        respuesta = json.dumps([
            {"palabra": "DOCUMENTO", "sena": "papel", "razon": "sinónimo"},
            {"palabra": "HIPOTECA", "sena": "HIPOTECA", "razon": "inventada"},
        ])
        out = EQ.validar(respuesta, [DOCUMENTO, HIPOTECA], self.cat)
        self.assertEqual(out[0]["sena"], "PAPEL")
        self.assertIsNone(out[1]["sena"])
        self.assertEqual(out[1]["descartada"], "HIPOTECA")

    def test_una_respuesta_rota_no_propone_nada(self):
        out = EQ.validar("no sé", [DOCUMENTO], self.cat)
        self.assertEqual(out, [{"palabra": "DOCUMENTO", "sena": None,
                                "senas": None, "razon": "",
                                "descartada": None}])

    def test_una_palabra_sin_respuesta_queda_sin_sena(self):
        out = EQ.validar('[{"palabra": "OTRA", "sena": "CASA"}]',
                         [DOCUMENTO], self.cat)
        self.assertIsNone(out[0]["sena"])

    def test_pedido_invalido(self):
        self.assertIsNotNone(EQ.validar_pedido({"palabras": []})[1])
        self.assertIsNotNone(
            EQ.validar_pedido({"palabras": [{"palabra": "x<script>"}]})[1])
        palabras, error = EQ.validar_pedido({"palabras": [DOCUMENTO]})
        self.assertIsNone(error)
        self.assertEqual(palabras, [DOCUMENTO])


class Lexico(unittest.TestCase):
    """M1–M4 y los diccionarios: forma 1 (candidata) y forma 2 (combinación)."""

    lex = {"OFICINA": "Oficina [M3 · Lugares II]",
           "FISCAL": "Fiscal [M3 · Escuela]", "CASA": "Casa"}
    FISCALIA = {"palabra": "FISCALIA", "ejemplos": ["Voy a la fiscalía."]}

    def test_el_lexico_empaquetado_lleva_el_catalogo_y_los_modulos(self):
        lex = EQ.cargar_lexico()
        self.assertGreater(len(lex), 346)
        self.assertIn("el documento", lex["PAPEL"])
        self.assertIn("M3 · Escuela", lex["FISCAL"])

    def test_sin_lexico_usa_el_catalogo(self):
        self.assertEqual(EQ.cargar_lexico("/no/existe.json"),
                         EQ.cargar_catalogo())

    def test_una_combinacion_del_lexico_vale(self):
        out = EQ.validar(json.dumps([{"palabra": "FISCALIA",
                                      "senas": ["oficina", "FISCAL"]}]),
                         [self.FISCALIA], self.lex)
        self.assertEqual(out[0]["senas"], ["OFICINA", "FISCAL"])
        self.assertIsNone(out[0]["sena"])

    def test_una_combinacion_con_una_glosa_inventada_se_descarta_entera(self):
        out = EQ.validar(json.dumps([{"palabra": "FISCALIA",
                                      "senas": ["OFICINA", "FISCALIA"]}]),
                         [self.FISCALIA], self.lex)
        self.assertIsNone(out[0]["senas"])
        self.assertEqual(out[0]["descartada"], "OFICINA + FISCALIA")

    def test_mas_de_tres_senas_no_explican_una_palabra(self):
        out = EQ.validar(json.dumps([{"palabra": "FISCALIA", "senas": [
            "OFICINA", "FISCAL", "CASA", "OFICINA"]}]), [self.FISCALIA], self.lex)
        self.assertIsNone(out[0]["senas"])

    def test_la_candidata_va_con_su_tema(self):
        pedido = {**self.FISCALIA, "palabra": "FISCAL", "candidata": "FISCAL"}
        texto = EQ.prompt([pedido], self.lex)
        self.assertIn("candidata: FISCAL (Fiscal [M3 · Escuela])", texto)

    def test_una_candidata_invalida_se_rechaza(self):
        _, error = EQ.validar_pedido({"palabras": [
            {**self.FISCALIA, "candidata": "x; DROP"}]})
        self.assertIsNotNone(error)


class Accion(unittest.TestCase):
    def llamar(self, cuerpo):
        r = L.lambda_handler({"body": json.dumps(cuerpo)}, None)
        return r["statusCode"], json.loads(r["body"])

    def test_la_lambda_propone_solo_senas_del_catalogo(self):
        texto = json.dumps([
            {"palabra": "DOCUMENTO", "sena": "PAPEL", "razon": "«el documento»"},
            {"palabra": "HIPOTECA", "sena": "PRESTAMO", "razon": "parecida"},
        ])
        cuerpo = {"output": {"message": {"content": [{"text": texto}]}}}
        with mock.patch.object(L, "ENABLE_BEDROCK", True), mock.patch.object(
                L.bedrock_runtime, "invoke_model", create=True,
                return_value={"body": io.BytesIO(json.dumps(cuerpo).encode())}):
            estado, datos = self.llamar({"action": "equivalencias",
                                         "palabras": [DOCUMENTO, HIPOTECA]})
        self.assertEqual(estado, 200)
        self.assertTrue(datos["generated"])
        self.assertEqual([p["sena"] for p in datos["propuestas"]],
                         ["PAPEL", None])

    def test_un_fallo_de_bedrock_no_es_un_error(self):
        with mock.patch.object(L, "ENABLE_BEDROCK", True), mock.patch.object(
                L.bedrock_runtime, "invoke_model", create=True,
                side_effect=RuntimeError("saturado")):
            estado, datos = self.llamar({"action": "equivalencias",
                                         "palabras": [DOCUMENTO]})
        self.assertEqual(estado, 200)
        self.assertFalse(datos["generated"])

    def test_pedido_invalido_es_400(self):
        estado, _ = self.llamar({"action": "equivalencias", "palabras": "x"})
        self.assertEqual(estado, 400)


if __name__ == "__main__":
    unittest.main()
