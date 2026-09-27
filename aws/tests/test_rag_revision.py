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
        for palabra, glosa in (("Cuente", "CONTAR"), ("Entiendo", "ENTENDER"),
                               ("puede", "PODER"), ("otra", "OTRO"),
                               ("toda", "TODO")):
            self.assertTrue(REV.conjugada(palabra, [glosa]), palabra)
        self.assertFalse(REV.conjugada("casa", ["CASO"]))
        for palabra, glosa in (("dijeron", "DECIR"), ("Vine", "VENIR"),
                               ("podré", "PODER"), ("Haré", "HACER")):
            self.assertTrue(REV.conjugada(palabra, [glosa]), palabra)
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

    def test_una_sena_a_incorporar_que_la_frase_no_dice_sobra(self):
        ingles = REV.depurar(
            "¿Le dijeron que necesita treinta por ciento?",
            ["SENA_PENDIENTE:NEED", "SENA_PENDIENTE:THIRTY"], [], [])
        self.assertEqual(ingles["sobran"], ["NEED", "THIRTY"])
        calle = REV.depurar("Queda entre Antezana y Lanza.",
                            ["SENA_PENDIENTE:ANTERIOR", "SENA_PENDIENTE:LANZA"],
                            [], [])
        self.assertEqual(calle["sobran"], ["ANTERIOR"])

    def test_las_formas_de_una_palabra_no_son_inventadas(self):
        for palabra, texto in (
                ("ESTAR", "Estoy cerca."), ("SERVIR", "No sé si sirve."),
                ("USAR", "Sigue usando el sistema."),
                ("COSTO", "¿Cuánto cuesta?"), ("TODOS", "Quiero todas."),
                ("SOLO", "Corresponde solamente a 2025."),
                ("CUOTA", "¿Quiere un Plan Cuotas?"),
                ("LSB", "Necesito Lengua de Señas Boliviana.")):
            self.assertTrue(REV.de_la_frase(palabra, texto), palabra)
        self.assertFalse(REV.de_la_frase("ANTERIOR", "Queda en Antezana."))
        self.assertFalse(REV.de_la_frase("NEED", "¿Lo necesita?"))

    def test_lo_que_la_frase_dice_con_otra_forma_no_sobra(self):
        out = REV.depurar("Quiero revisar todo.", ["QUERER", "REVISAR"],
                          [], ["QUERER"])
        self.assertEqual(out["sobran"], [])

    def test_un_numero_con_letras_vale_en_cifras(self):
        ok, _ = REV.glosas_validas(["NECESITAR", "30"],
                                   "¿Necesita treinta por ciento?",
                                   {"NECESITAR": ""})
        self.assertEqual(ok, ["NECESITAR", "3", "0"])
        pegadas, _ = REV.glosas_validas(["PORCIENTO"], "Treinta por ciento.", {})
        self.assertEqual(pegadas, ["SENA_PENDIENTE:POR_CIENTO"])

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



class Correccion(unittest.TestCase):
    CAT = {"COMPRAR": "", "QUERER": "", "MÍO": "mi", "NOMBRE": "", "CASA": "",
           "TENER": "", "SÍ": "", "2": "", "0": "", "5": ""}
    AUTO = {**AUTO, "faltan": ["auto", "Quiero"], "sobran": []}

    def test_solo_valen_glosas_del_catalogo_y_palabras_de_la_frase(self):
        ok, malas = REV.glosas_validas(
            ["COMPRAR", "SENA_PENDIENTE:AUTO", "querer", "MIO", "NOMBRE"],
            self.AUTO["texto"], self.CAT)
        self.assertEqual(ok, ["COMPRAR", "SENA_PENDIENTE:AUTO", "QUERER",
                              "MÍO", "NOMBRE"])
        self.assertEqual(malas, [])
        # Una palabra que la frase no dice: se rechaza y se dice cuál.
        self.assertEqual(REV.glosas_validas(["AVION"], "Compré un auto.",
                                            self.CAT), (None, ["AVION"]))

    def test_una_palabra_de_la_frase_sin_marca_es_sena_a_incorporar(self):
        ok, _ = REV.glosas_validas(["COMPRAR", "AUTO"], "Compré un auto.",
                                   self.CAT)
        self.assertEqual(ok, ["COMPRAR", "SENA_PENDIENTE:AUTO"])

    def test_un_articulo_que_agrega_el_modelo_se_ignora(self):
        ok, _ = REV.glosas_validas(["COMPRAR", "UN", "AUTO"], "Compré un auto.",
                                   self.CAT)
        self.assertEqual(ok, ["COMPRAR", "SENA_PENDIENTE:AUTO"])

    def test_una_marca_sobre_una_sena_del_catalogo_es_la_sena(self):
        ok, _ = REV.glosas_validas(["SENA_PENDIENTE:COMPRAR"], "Compré.",
                                   self.CAT)
        self.assertEqual(ok, ["COMPRAR"])

    def test_la_sena_compuesta_gana_a_sus_partes(self):
        ok, _ = REV.glosas_validas(["NO", "SABER", "CASA"], "No sé de la casa.",
                                   {"NO": "", "SABER": "", "NO_SABER": "",
                                    "CASA": ""})
        self.assertEqual(ok, ["NO_SABER", "CASA"])

    def test_siglas_y_numeros_de_la_frase_se_deletrean(self):
        self.assertEqual(
            REV.glosas_validas(["NUREJ", "2025"], "Tengo el NUREJ de 2025.",
                               {})[0],
            [*"NUREJ", *"2025"])

    def test_se_acepta_si_deja_menos_errores(self):
        propuesta = [["COMPRAR", "SENA_PENDIENTE:AUTO", "QUERER", "MÍO",
                      "NOMBRE", "SENA_PENDIENTE:PASAR"]]
        out = REV.corregir([self.AUTO], self.CAT,
                           modelo(propuesta, [{"faltan": [], "sobran": []}]))
        self.assertTrue(out[0]["aceptada"])
        self.assertIn("SENA_PENDIENTE:AUTO", out[0]["glosas"])

    def test_lo_que_sobra_se_quita_de_la_correccion(self):
        self.assertEqual(
            REV.sin_sobras(["NECESITAR", "3", "0", "SENA_PENDIENTE:POR_CIENTO",
                            "NO"], ["NO"]),
            ["NECESITAR", "3", "0", "SENA_PENDIENTE:POR_CIENTO"])

    def test_cada_propuesta_va_a_su_frase_por_numero(self):
        texto = json.dumps([{"n": 2, "glosas": ["B"]}, {"n": 1, "glosas": ["A"]}])
        self.assertEqual(REV.propuestas_por_frase(texto, 3), [["A"], ["B"], None])
        self.assertEqual(REV.propuestas_por_frase('[["A"], ["B"]]', 2),
                         [["A"], ["B"]])

    def test_se_rechaza_si_no_mejora_o_inventa(self):
        igual = REV.corregir(
            [self.AUTO], self.CAT,
            modelo([["COMPRAR", "NOMBRE"]],
                   [{"faltan": ["auto", "Quiero"], "sobran": []}]))
        self.assertFalse(igual[0]["aceptada"])
        inventa = REV.corregir([self.AUTO], self.CAT,
                               modelo([["COMPRAR", "AVION"]], []))
        self.assertFalse(inventa[0]["aceptada"])
        self.assertIn("AVION", inventa[0]["motivo"])
        self.assertEqual(inventa[0]["propuesta"], ["COMPRAR", "AVION"])

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
