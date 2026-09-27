"""Control de glosas del corpus: módulo y acción `retrotraducir`.

Bedrock y Titan se simulan: se prueba que la vuelta al español se compare
con la frase original y que un fallo nunca sea un error.
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
import rag_revision as REV  # noqa: E402

AUTO = {"texto": "Compré un auto. Quiero pasarlo a mi nombre.",
        "glosas": ["COMPRAR", "MÍO", "NOMBRE", "SENA_PENDIENTE:PASAR"]}
CASA = {"texto": "Compré una casa.", "glosas": ["COMPRAR", "CASA"]}


def embed_palabras(texto):
    """Bolsa de palabras: parecido si comparten palabras."""
    vocab = ["compre", "auto", "casa", "nombre", "pasar", "mi", "quiero"]
    t = texto.lower().replace("é", "e")
    return [float(w in t) for w in vocab]


class Modulo(unittest.TestCase):
    def test_las_glosas_se_leen_como_las_ve_la_persona(self):
        self.assertEqual(
            REV.legibles(["YO", "SENA_PENDIENTE:FOLIO_REAL", *"NUREJ", "CASA"]),
            ["YO", "FOLIO REAL", "NUREJ", "CASA"])

    def test_el_prompt_no_lleva_la_frase_original(self):
        texto = REV.prompt([AUTO])
        self.assertIn("COMPRAR · MÍO · NOMBRE · PASAR", texto)
        self.assertNotIn("auto", texto)

    def test_una_palabra_perdida_baja_la_similitud(self):
        respuesta = json.dumps(["Compré. Quiero pasarlo a mi nombre.",
                                "Compré una casa."])
        out = REV.revisar([AUTO, CASA], lambda _: respuesta, embed_palabras)
        self.assertLess(out[0]["similitud"], out[1]["similitud"])
        self.assertEqual(out[1]["similitud"], 1.0)

    def test_una_respuesta_rota_es_similitud_cero(self):
        out = REV.revisar([CASA], lambda _: "no sé", embed_palabras)
        self.assertEqual(out, [{"texto": "Compré una casa.", "vuelta": "",
                                "similitud": 0.0}])

    def test_pedido_invalido(self):
        self.assertIsNotNone(REV.validar_pedido({"items": []})[1])
        self.assertIsNotNone(
            REV.validar_pedido({"items": [{"texto": "x", "glosas": []}]})[1])
        self.assertIsNone(REV.validar_pedido({"items": [CASA]})[1])


class Accion(unittest.TestCase):
    def llamar(self, cuerpo):
        r = L.lambda_handler({"body": json.dumps(cuerpo)}, None)
        return r["statusCode"], json.loads(r["body"])

    def test_la_lambda_devuelve_vuelta_y_similitud(self):
        cuerpo = {"output": {"message": {"content": [
            {"text": json.dumps(["Compré una casa."])}]}}}
        with mock.patch.object(L, "ENABLE_BEDROCK", True), \
                mock.patch.object(L.bedrock_runtime, "invoke_model",
                                  create=True, return_value={
                                      "body": io.BytesIO(
                                          json.dumps(cuerpo).encode())}), \
                mock.patch.object(L, "_titan_embed", embed_palabras):
            estado, datos = self.llamar({"action": "retrotraducir",
                                         "items": [CASA]})
        self.assertEqual(estado, 200)
        self.assertEqual(datos["items"][0]["vuelta"], "Compré una casa.")
        self.assertEqual(datos["items"][0]["similitud"], 1.0)

    def test_un_fallo_de_bedrock_no_es_un_error(self):
        with mock.patch.object(L, "ENABLE_BEDROCK", True), mock.patch.object(
                L.bedrock_runtime, "invoke_model", create=True,
                side_effect=RuntimeError("saturado")):
            estado, datos = self.llamar({"action": "retrotraducir",
                                         "items": [CASA]})
        self.assertEqual(estado, 200)
        self.assertFalse(datos["generated"])


if __name__ == "__main__":
    unittest.main()
