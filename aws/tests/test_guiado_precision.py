"""Precisión del contrato guiado (v4) en la Lambda.

- Paridad: las intervenciones de `test/fixtures/guided/paridad.json` las
  redactó el compositor Dart; el de la Lambda tiene que producir exactamente
  el mismo texto y representar las mismas respuestas.
- Cobertura: ninguna respuesta confirmada desaparece del texto.
- Validación: el backend aplica las mismas reglas que el dominio del
  cliente (opciones existentes, máximos, Sí/No/No sé excluyentes, valores
  acotados) y rechaza lo que no las cumple.
- Compatibilidad: un cliente sin `guided` sigue funcionando.
"""

import copy
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()

import guided_composer as G  # noqa: E402
import lambda_function as L  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FIXTURE = os.path.join(ROOT, "test", "fixtures", "guided", "paridad.json")


def invoke(body):
    response = L.lambda_handler({"httpMethod": "POST", "body": json.dumps(body)}, None)
    return response["statusCode"], json.loads(response["body"])


def request(guided, cards=("ROBAR",)):
    return {
        "cards": list(cards),
        "context": guided.get("recorrido") or "general",
        "language": "es",
        "contractVersion": 4,
        "guided": guided,
    }


def answer(question, options, state="afirmado", values=None):
    a = {"pregunta": question, "estado": state, "opciones": list(options)}
    if values is not None:
        a["valores"] = values
    return a


def guided(*answers, journey="denuncia_robo"):
    return {"recorrido": journey, "proposito": "standalone", "respuestas": list(answers)}


class ParidadConElCliente(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(FIXTURE, encoding="utf-8") as f:
            cls.casos = json.load(f)
        cls.composer = G.Composer(G.load_bank())

    def test_hay_casos_de_los_ocho_recorridos(self):
        recorridos = {c["guided"]["recorrido"] for c in self.casos}
        self.assertEqual(8, len(recorridos))

    def test_mismo_texto_y_mismas_respuestas_representadas(self):
        for i, caso in enumerate(self.casos):
            with self.subTest(caso=i, recorrido=caso["guided"]["recorrido"]):
                texto, representadas = self.composer.compose_traced(caso["guided"])
                self.assertEqual(caso["texto"], texto)
                self.assertEqual(set(caso["representadas"]), representadas)

    def test_ningun_hecho_confirmado_se_pierde(self):
        for i, caso in enumerate(self.casos):
            with self.subTest(caso=i):
                _, representadas = self.composer.compose_traced(caso["guided"])
                self.assertLessEqual(
                    self.composer.confirmed_facts(caso["guided"]), representadas)

    def test_el_handler_devuelve_la_misma_frase_sin_ia(self):
        for caso in self.casos[:24]:
            with self.subTest(recorrido=caso["guided"]["recorrido"]):
                status, payload = invoke(request(caso["guided"], cards=["ROBAR"]))
                self.assertEqual(200, status, payload)
                self.assertEqual(caso["texto"], payload["generatedText"])
                self.assertEqual(caso["texto"], payload["baseSentence"])
                self.assertFalse(payload["bedrockUsed"])
                if caso["texto"]:
                    self.assertTrue(payload["coverageValidated"])


class ValoresYOmisiones(unittest.TestCase):
    def test_500_bs_se_conserva_exacto(self):
        g = guided(answer("Q.HEC.QUE_OCURRIO", ["robar"]),
                   answer("Q.ROB.QUE", ["dinero"],
                          values={"dinero": {"monto": "500", "moneda": "Bs"}}))
        self.assertEqual("Me robaron Bs 500.", G.compose(g))

    def test_pregunta_del_oyente_sin_su_rama_no_se_pierde(self):
        g = guided(answer("Q.ROB.QUE", ["celular"]))
        self.assertEqual("Me robaron el celular.", G.compose(g))

    def test_no_se_no_es_no(self):
        g = guided(answer("Q.PER.CONOCE", ["no_sabe"], state="desconocido"))
        texto = G.compose(g)
        self.assertIn("No sé si la conozco.", texto)
        self.assertNotIn("No conozco", texto)

    def test_solo_valores_escritos_sin_glosas(self):
        g = guided(answer("Q.ID.NOMBRE", ["nombre"],
                          values={"nombre": {"nombre": "María Quispe"}}),
                   journey="identificacion")
        status, payload = invoke(request(g, cards=[]))
        self.assertEqual(200, status, payload)
        self.assertEqual("Me llamo María Quispe.", payload["generatedText"])


class ValidacionDelContratoGuiado(unittest.TestCase):
    base = guided(answer("Q.HEC.QUE_OCURRIO", ["robar"]),
                  answer("Q.PER.CONOCE", ["si"]))

    def rechaza(self, g, cards=("ROBAR",)):
        status, payload = invoke(request(g, cards=cards))
        self.assertEqual(400, status, payload)
        self.assertEqual("VALIDATION_ERROR", payload["error"])

    def mutado(self, cambio):
        g = copy.deepcopy(self.base)
        cambio(g)
        return g

    def test_la_base_es_valida(self):
        status, payload = invoke(request(self.base))
        self.assertEqual(200, status, payload)

    def test_guided_no_objeto(self):
        body = request(self.base)
        body["guided"] = ["no", "es", "objeto"]
        status, _ = invoke(body)
        self.assertEqual(400, status)

    def test_recorrido_desconocido(self):
        self.rechaza(self.mutado(lambda g: g.update(recorrido="desconocido")))

    def test_proposito_desconocido(self):
        self.rechaza(self.mutado(lambda g: g.update(proposito="otro")))

    def test_pregunta_inexistente(self):
        self.rechaza(self.mutado(lambda g: g["respuestas"].append(
            answer("Q.NO.EXISTE", ["si"]))))

    def test_opcion_inexistente(self):
        self.rechaza(self.mutado(lambda g: g["respuestas"][1].update(opciones=["pareja"])))

    def test_si_y_no_a_la_vez(self):
        self.rechaza(self.mutado(lambda g: g["respuestas"][1].update(opciones=["si", "no"])))

    def test_no_se_con_otra_opcion(self):
        self.rechaza(self.mutado(lambda g: g["respuestas"].append(
            answer("Q.ROB.QUE", ["celular", "no_sabe"]))))

    def test_supera_el_maximo(self):
        self.rechaza(self.mutado(lambda g: g["respuestas"][0].update(
            opciones=["robar", "danar", "escapar"])))

    def test_estado_que_no_corresponde(self):
        self.rechaza(self.mutado(lambda g: g["respuestas"][1].update(
            opciones=["no"], estado="afirmado")))

    def test_omitida_con_opciones(self):
        self.rechaza(self.mutado(lambda g: g["respuestas"][1].update(estado="omitido")))

    def test_afirmada_sin_opciones(self):
        self.rechaza(self.mutado(lambda g: g["respuestas"][1].update(opciones=[])))

    def test_pregunta_repetida(self):
        self.rechaza(self.mutado(lambda g: g["respuestas"].append(
            answer("Q.PER.CONOCE", ["no"], state="negado"))))

    def test_valor_de_una_opcion_no_elegida(self):
        self.rechaza(self.mutado(lambda g: g["respuestas"][1].update(
            valores={"no": {"texto": "x"}})))

    def test_clave_de_valor_desconocida(self):
        g = guided(answer("Q.ROB.QUE", ["dinero"],
                          values={"dinero": {"monto": "5", "moneda": "Bs", "extra": "x"}}))
        self.rechaza(g)

    def test_valor_demasiado_largo(self):
        g = guided(answer("Q.ROB.QUE", ["otro"],
                          values={"otro": {"texto": "x" * 500}}))
        self.rechaza(g)

    def test_demasiadas_respuestas(self):
        g = guided(*[answer("Q.PER.CONOCE", ["si"]) for _ in range(70)])
        self.rechaza(g)

    def test_cards_vacio_sin_guided_sigue_rechazandose(self):
        status, _ = invoke({"cards": [], "context": "denuncia_robo"})
        self.assertEqual(400, status)


class CompatibilidadConClientesAnteriores(unittest.TestCase):
    def test_peticion_v1_sin_guided(self):
        status, payload = invoke({"cards": ["ROBAR", "CELULAR"], "context": "denuncia_robo"})
        self.assertEqual(200, status, payload)
        self.assertTrue(payload["generatedText"])

    def test_peticion_v3_con_declaration(self):
        body = {
            "cards": ["ROBAR", "CELULAR"],
            "context": "denuncia_robo",
            "contractVersion": 3,
            "declaration": {
                "contextId": "denuncia_robo",
                "facts": [{"id": "f1", "action": "ROBAR", "actorRole": "suspect"}],
                "objects": [{"id": "o1", "concept": "CELULAR", "role": "stolen"}],
                "injured": True,
                "willFileComplaint": "confirmed",
            },
        }
        status, payload = invoke(body)
        self.assertEqual(200, status, payload)
        base = payload["baseSentence"]
        # Lo que antes se descartaba en esta ruta ahora se redacta.
        self.assertIn("Estoy herido.", base)
        self.assertIn("Quiero presentar una denuncia formal.", base)
        self.assertNotIn("mis pertenencias", base)


if __name__ == "__main__":
    unittest.main()
