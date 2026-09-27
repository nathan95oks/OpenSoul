"""Control de glosas del corpus: módulo y acción `retrotraducir`.

Bedrock y Titan se simulan: se prueba que lo que falta o sobra se compruebe
contra la frase y las glosas, que una vuelta escrita como glosas no se
compare y que un fallo nunca sea un error.
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
        "glosas": ["COMPRAR", "MÍO", "NOMBRE", "SENA_PENDIENTE:PASAR"],
        "rol": "sordo"}
CASA = {"texto": "Tengo deuda antigua de mi casa.",
        "glosas": ["SENA_PENDIENTE:CASO", "SENA_PENDIENTE:DEUDA", "MÍO", "CASA"],
        "rol": "sordo"}


def embed_palabras(texto):
    """Bolsa de palabras: parecido si comparten palabras."""
    vocab = ["compre", "auto", "casa", "nombre", "pasar", "deuda", "tengo"]
    t = texto.lower().replace("é", "e")
    return [float(w in t) for w in vocab]


def modelo(comparacion, vueltas):
    """Bedrock simulado: la primera llamada compara, la segunda traduce."""
    respuestas = iter([json.dumps(comparacion), json.dumps(vueltas)])
    return lambda _prompt: next(respuestas)


class Legibles(unittest.TestCase):
    def test_las_glosas_se_leen_como_las_ve_la_persona(self):
        self.assertEqual(
            REV.legibles(["YO", "SENA_PENDIENTE:FOLIO_REAL", *"NUREJ", "CASA"]),
            ["YO", "FOLIO REAL", "NUREJ", "CASA"])

    def test_la_vuelta_no_ve_la_frase_y_la_comparacion_si(self):
        self.assertNotIn("auto", REV.prompt_vuelta([AUTO]))
        self.assertIn("(habla la persona sorda) COMPRAR · MÍO · NOMBRE · PASAR",
                      REV.prompt_vuelta([AUTO]))
        self.assertIn("«Compré un auto.", REV.prompt_comparar([AUTO]))


class Comparacion(unittest.TestCase):
    def test_lo_que_falta_y_sobra_existe_de_verdad(self):
        texto = json.dumps([
            {"faltan": ["auto", "Quiero", "avión", "un"], "sobran": ["COCHE"]},
            {"faltan": ["Tengo"], "sobran": ["CASO", "PERRO"]},
        ])
        out = REV.comparaciones(texto, [AUTO, CASA])
        # «avión» no está en la frase, «un» no se signa, COCHE y PERRO no
        # están en las glosas: se descartan.
        self.assertEqual(out[0], {"faltan": ["auto", "Quiero"], "sobran": [],
                                  "leve": False})
        self.assertEqual(out[1], {"faltan": ["Tengo"], "sobran": ["CASO"],
                                  "leve": False})

    def test_un_verbo_conjugado_de_una_glosa_no_falta(self):
        copia = {"texto": "Sí. Perdimos la copia anterior.",
                 "glosas": ["SI", "SENA_PENDIENTE:COPIA", "PERDER"]}
        out = REV.comparaciones(
            json.dumps([{"faltan": ["Perdimos", "anterior"]}]), [copia])
        self.assertEqual(out[0]["faltan"], ["anterior"])
        self.assertTrue(REV.conjugada("Iré", ["MAÑANA", "IR"]))
        self.assertFalse(REV.conjugada("Quiero", ["SABER"]))

    def test_una_respuesta_rota_no_marca_nada(self):
        self.assertEqual(REV.comparaciones("no sé", [AUTO]),
                         [{"faltan": [], "sobran": [], "leve": False}])

    def test_lo_que_no_es_un_error_comprobable_se_descarta(self):
        # YO: sujeto que el español calla; SI y 2/0/5: están en la frase;
        # «soy», «entre»: LSB no los signa.
        out = REV.depurar(
            "Sí, soy titular desde 2025 entre otros.",
            ["SI", "YO", "2", "0", "5", "OTRO", "CASA"],
            ["soy", "entre", "titular"], ["YO", "SI", "2", "CASA"])
        self.assertEqual(out, {"faltan": ["titular"], "sobran": ["CASA"],
                               "leve": False})

    def test_solo_un_auxiliar_que_falta_es_menor(self):
        out = REV.depurar("Quiero confirmar.", ["CONFIRMAR"], ["Quiero"], [])
        self.assertEqual(out, {"faltan": ["Quiero"], "sobran": [], "leve": True})
        grave = REV.depurar("No recuerdo.", ["RECORDAR"], ["No"], [])
        self.assertFalse(grave["leve"])


class Vuelta(unittest.TestCase):
    def test_las_glosas_copiadas_no_son_espanol(self):
        self.assertFalse(REV.es_espanol("PAPEL IDENTIDAD NUEVO NECESITAR",
                                        ["PAPEL", "IDENTIDAD", "NUEVO"]))
        self.assertFalse(REV.es_espanol("Comprar mío nombre pasar",
                                        AUTO["glosas"]))
        self.assertFalse(REV.es_espanol("Llamar", ["LLAMAR"]))
        self.assertTrue(REV.es_espanol("Fue robo.", ["ROBAR"]))
        self.assertTrue(REV.es_espanol("Sí.", ["SI"]))
        self.assertTrue(REV.es_espanol("Compré. Quiero pasarlo a mi nombre.",
                                       AUTO["glosas"]))

    def test_revisar_une_comparacion_y_parecido(self):
        out = REV.revisar(
            [AUTO, CASA],
            modelo([{"faltan": ["auto"], "sobran": []},
                    {"faltan": [], "sobran": ["CASO"]}],
                   ["Comprar mío nombre pasar",
                    "Tengo una deuda antigua de mi casa."]),
            embed_palabras)
        self.assertEqual(out[0]["faltan"], ["auto"])
        self.assertIsNone(out[0]["similitud"], "la vuelta eran glosas")
        self.assertEqual(out[1]["sobran"], ["CASO"])
        self.assertEqual(out[1]["similitud"], 1.0)

    def test_pedido_invalido(self):
        self.assertIsNotNone(REV.validar_pedido({"items": []})[1])
        self.assertIsNotNone(
            REV.validar_pedido({"items": [{"texto": "x", "glosas": []}]})[1])
        items, error = REV.validar_pedido({"items": [
            {"texto": "Sí.", "glosas": ["SI"], "rol": "otro"}]})
        self.assertIsNone(error)
        self.assertIsNone(items[0]["rol"])


class Accion(unittest.TestCase):
    def llamar(self, cuerpo):
        r = L.lambda_handler({"body": json.dumps(cuerpo)}, None)
        return r["statusCode"], json.loads(r["body"])

    def test_la_lambda_devuelve_faltas_y_parecido(self):
        textos = iter([json.dumps([{"faltan": ["auto"], "sobran": []}]),
                       json.dumps(["Compré. Quiero pasarlo a mi nombre."])])

        def invoke_model(**_):
            cuerpo = {"output": {"message": {"content": [
                {"text": next(textos)}]}}}
            return {"body": io.BytesIO(json.dumps(cuerpo).encode())}

        with mock.patch.object(L, "ENABLE_BEDROCK", True), \
                mock.patch.object(L.bedrock_runtime, "invoke_model",
                                  create=True, side_effect=invoke_model), \
                mock.patch.object(L, "_titan_embed", embed_palabras):
            estado, datos = self.llamar({"action": "retrotraducir",
                                         "items": [AUTO]})
        self.assertEqual(estado, 200)
        item = datos["items"][0]
        self.assertEqual(item["faltan"], ["auto"])
        self.assertIsNotNone(item["similitud"])

    def test_un_fallo_de_bedrock_no_es_un_error(self):
        with mock.patch.object(L, "ENABLE_BEDROCK", True), mock.patch.object(
                L.bedrock_runtime, "invoke_model", create=True,
                side_effect=RuntimeError("saturado")):
            estado, datos = self.llamar({"action": "retrotraducir",
                                         "items": [AUTO]})
        self.assertEqual(estado, 200)
        self.assertFalse(datos["generated"])


if __name__ == "__main__":
    unittest.main()
