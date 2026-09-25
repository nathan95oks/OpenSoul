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


def answer(question, option, state="afirmado", values=None):
    result = {"pregunta": question, "estado": state, "opciones": [option]}
    if values is not None:
        result["valores"] = {option: values}
    return result


class GuidedComposerV4(unittest.TestCase):
    def test_phone_is_literal_and_not_an_actor_gloss(self):
        guided = {
            "recorrido": "amenaza_digital",
            "proposito": "reply",
            "respuestas": [answer(
                "Q.DIG.REMITENTE", "solo_numero", values={"telefono": "70012345"})],
        }
        text = G.compose(guided)
        self.assertIn("nombre", text)
        self.assertIn("70012345", text)
        self.assertNotIn("celular", text.lower())

    def test_handler_uses_exact_guided_sentence_and_contract_v4(self):
        guided = {
            "recorrido": "engano_dinero",
            "proposito": "initiative",
            "respuestas": [
                answer("Q.DIN.MECANISMO", "banco"),
                answer("Q.DIN.MONTO", "monto", values={"monto": "150", "moneda": "Bs"}),
            ],
        }
        body = {
            "cards": ["BANCO", "BILLETES"],
            "context": "engano_dinero",
            "language": "es",
            "contractVersion": 4,
            "guided": guided,
        }
        response = L.lambda_handler(
            {"httpMethod": "POST", "body": json.dumps(body)}, None)
        payload = json.loads(response["body"])
        expected = G.compose(guided)
        self.assertEqual(200, response["statusCode"], payload)
        self.assertEqual(expected, payload["baseSentence"])
        self.assertEqual(expected, payload["generatedText"])
        self.assertEqual(4, payload["contractVersion"])
        self.assertFalse(payload["bedrockUsed"])

    def test_omission_does_not_become_no(self):
        omitted = {
            "recorrido": "denuncia_robo",
            "proposito": "reply",
            "respuestas": [{
                "pregunta": "Q.EVI.FACTURA",
                "estado": "omitido",
                "opciones": [],
            }],
        }
        self.assertEqual("", G.compose(omitted))


if __name__ == "__main__":
    unittest.main()
