"""SemanticFrame y realización Bedrock del camino guiado."""

import json
import os
import sys
import types
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()

import guided_composer as G  # noqa: E402
import lambda_function as L  # noqa: E402


def answer(question, options, state="afirmado", values=None):
    item = {"pregunta": question, "estado": state, "opciones": list(options)}
    if values is not None:
        item["valores"] = values
    return item


def guided(*answers):
    return {
        "recorrido": "denuncia_robo",
        "proposito": "standalone",
        "respuestas": list(answers),
    }


def robbery_phone_yesterday():
    return guided(
        answer("Q.HEC.QUE_OCURRIO", ["robar"]),
        answer("Q.ROB.QUE", ["celular"]),
        answer("Q.TIE.CUANDO", ["ayer"]),
    )


class _Body:
    def __init__(self, payload):
        self.payload = payload

    def read(self):
        return json.dumps(self.payload).encode("utf-8")


class _Bedrock:
    def __init__(self, text=None, error=None):
        self.text = text
        self.error = error
        self.calls = []

    def invoke_model(self, **kwargs):
        self.calls.append(kwargs)
        if self.error:
            raise self.error
        return {"body": _Body({
            "output": {"message": {"content": [{"text": self.text}]}}
        })}


class SemanticFrameCompleto(unittest.TestCase):
    def setUp(self):
        self.composer = G.Composer(G.load_bank())

    def test_grafo_produce_frame_sin_plantillas_espanolas(self):
        frame = self.composer.semantic_frame(
            robbery_phone_yesterday(), context="denuncia_robo")
        self.assertEqual(1, frame["version"])
        self.assertEqual(["ROBAR", "CELULAR", "AYER"], frame["lsbSequence"])
        self.assertEqual(3, len(frame["facts"]))
        self.assertEqual(3, len(frame["slots"]))
        self.assertTrue(any(r.get("patientRole") == "citizen"
                            for r in frame["roles"]))
        self.assertEqual([], frame["negations"])
        self.assertEqual([], frame["literals"])
        serialized = json.dumps(frame, ensure_ascii=False).lower()
        self.assertNotIn("me robaron", serialized)
        self.assertNotIn("frase", serialized)
        self.assertNotIn("etiqueta", serialized)

    def test_negaciones_desconocidos_y_literales_quedan_tipados(self):
        frame = self.composer.semantic_frame(guided(
            answer("Q.PER.CONOCE", ["no"], state="negado"),
            answer("Q.TES.EXISTE", ["no_sabe"], state="desconocido"),
            answer("Q.ROB.QUE", ["dinero"], values={
                "dinero": {"monto": "500", "moneda": "BOB"},
            }),
        ))
        self.assertEqual(1, len(frame["negations"]))
        self.assertEqual(1, len(frame["unknowns"]))
        self.assertEqual(
            {("monto", "500"), ("moneda", "BOB")},
            {(x["key"], x["value"]) for x in frame["literals"]},
        )


class FidelidadBedrockGuiado(unittest.TestCase):
    def setUp(self):
        self.original_runtime = L.bedrock_runtime
        self.original_enabled = L.ENABLE_BEDROCK
        L.ENABLE_BEDROCK = True
        self.composer = G.Composer(G.load_bank())
        self.guided = robbery_phone_yesterday()
        self.frame = self.composer.semantic_frame(
            self.guided, context="denuncia_robo")
        self.fallback = self.composer.compose(self.guided)

    def tearDown(self):
        L.bedrock_runtime = self.original_runtime
        L.ENABLE_BEDROCK = self.original_enabled

    def realize(self, text):
        fake = _Bedrock(text=text)
        L.bedrock_runtime = fake
        result = L.generate_spanish_from_semantic_frame(
            self.frame, self.fallback)
        return result, fake

    def test_conserva_robo_telefono_y_ayer(self):
        (text, used, mismatch), fake = self.realize(
            "Ayer me robaron el celular.")
        self.assertEqual("Ayer me robaron el celular.", text)
        self.assertTrue(used)
        self.assertFalse(mismatch)
        prompt = json.loads(fake.calls[0]["body"])["messages"][0]["content"][0]["text"]
        for key in ("lsbSequence", "intent", "facts", "roles", "slots",
                    "negations", "literals", "context"):
            self.assertIn(f'"{key}"', prompt)
        self.assertNotIn(self.fallback, prompt,
                         "Bedrock guided no debe recibir la frase fallback")

    def test_rechaza_fiscalia_inventada(self):
        (text, used, mismatch), _ = self.realize(
            "Ayer me robaron el celular en la Fiscalía.")
        self.assertEqual(self.fallback, text)
        self.assertFalse(used)
        self.assertTrue(mismatch)

    def test_institucion_confirmada_en_contexto_no_se_considera_inventada(self):
        frame = dict(self.frame)
        frame["institutionContext"] = "FISCALIA"
        ok, reason = L.semantic_frame_is_preserved(
            frame, "Ayer me robaron el celular en la Fiscalía.", self.fallback)
        self.assertTrue(ok, reason)

    def test_rechaza_si_convierte_no_en_afirmacion(self):
        frame = {
            "lsbSequence": ["NO", "ROBAR"],
            "facts": [{
                "id": "f1", "state": "negado", "concepts": ["ROBAR"],
                "effect": {"action": "ROBAR"},
            }],
            "roles": [], "slots": [],
            "negations": [{"factId": "f1", "scope": "fact"}],
            "unknowns": [], "literals": [],
        }
        ok, _ = L.semantic_frame_is_preserved(
            frame, "Me robaron el celular.",
            "No es cierto que me hayan robado el celular.")
        self.assertFalse(ok)

    def test_rechaza_cambio_de_500_bob(self):
        money = guided(
            answer("Q.HEC.QUE_OCURRIO", ["robar"]),
            answer("Q.ROB.QUE", ["dinero"], values={
                "dinero": {"monto": "500", "moneda": "BOB"},
            }),
        )
        frame = self.composer.semantic_frame(money)
        ok, _ = L.semantic_frame_is_preserved(
            frame, "Me robaron 50 BOB.", self.composer.compose(money))
        self.assertFalse(ok)

    def test_rechaza_objeto_confirmado_omitido(self):
        ok, _ = L.semantic_frame_is_preserved(
            self.frame, "Ayer me robaron.", self.fallback)
        self.assertFalse(ok)

    def test_fallo_de_bedrock_usa_fallback(self):
        L.bedrock_runtime = _Bedrock(error=RuntimeError("sin servicio"))
        text, used, mismatch = L.generate_spanish_from_semantic_frame(
            self.frame, self.fallback)
        self.assertEqual(self.fallback, text)
        self.assertFalse(used)
        self.assertFalse(mismatch)


class CacheYPollyGuiados(unittest.TestCase):
    def setUp(self):
        self.originals = {
            "get_cached_response": L.get_cached_response,
            "synthesize_audio": L.synthesize_audio,
            "bedrock_runtime": L.bedrock_runtime,
            "ENABLE_BEDROCK": L.ENABLE_BEDROCK,
            "analyze_glosses": L.analyze_glosses,
        }

    def tearDown(self):
        for key, value in self.originals.items():
            setattr(L, key, value)

    def body(self):
        return {
            "cards": ["ROBAR", "CELULAR", "AYER"],
            "context": "denuncia_robo",
            "language": "es",
            "contractVersion": 4,
            "guided": robbery_phone_yesterday(),
        }

    def test_cache_hit_no_llama_bedrock_ni_polly(self):
        calls = []
        L.get_cached_response = lambda _: {
            "generatedText": "Ayer me robaron el celular.",
            "baseSentence": "Me robaron el celular. Ocurrió ayer.",
            "audioUrl": "https://audio/cache.mp3",
            "cacheHit": True,
            "generationSource": "cache",
            "coverageValidated": True,
        }
        L.bedrock_runtime = types.SimpleNamespace(
            invoke_model=lambda **_: calls.append("bedrock"))
        L.synthesize_audio = lambda *_: calls.append("polly")
        response = L.lambda_handler({
            "httpMethod": "POST", "body": json.dumps(self.body())}, None)
        self.assertEqual(200, response["statusCode"])
        self.assertEqual([], calls)

    def test_polly_recibe_solo_el_texto_validado(self):
        spoken = []
        L.get_cached_response = lambda _: None
        L.ENABLE_BEDROCK = True
        L.bedrock_runtime = _Bedrock(text="Ayer me robaron el celular.")
        L.synthesize_audio = lambda text, _language: (
            spoken.append(text) or b"audio")
        response = L.lambda_handler({
            "httpMethod": "POST", "body": json.dumps(self.body())}, None)
        payload = json.loads(response["body"])
        self.assertEqual(200, response["statusCode"], payload)
        self.assertEqual([payload["generatedText"]], spoken)
        self.assertEqual("bedrock", payload["generationSource"])
        self.assertTrue(payload["coverageValidated"])
        self.assertIn("semanticFrame", payload)

    def test_guided_no_ejecuta_inferencia_legacy(self):
        L.get_cached_response = lambda _: None
        L.ENABLE_BEDROCK = False
        L.analyze_glosses = lambda *_: (_ for _ in ()).throw(
            AssertionError("guided no debe llamar analyze_glosses"))
        response = L.lambda_handler({
            "httpMethod": "POST", "body": json.dumps(self.body())}, None)
        self.assertEqual(200, response["statusCode"], response)

    def test_cache_key_incluye_orden_roles_y_literales_del_frame(self):
        base = {
            "lsbSequence": ["ROBAR", "CELULAR"],
            "facts": [{"id": "f1", "concepts": ["ROBAR", "CELULAR"]}],
            "roles": [{"factId": "f1", "actorRole": "suspect"}],
            "literals": [{"factId": "f1", "key": "monto", "value": "500"}],
        }
        changed_order = dict(base, lsbSequence=["CELULAR", "ROBAR"])
        changed_role = dict(base, roles=[{
            "factId": "f1", "actorRole": "victim",
        }])
        changed_literal = dict(base, literals=[{
            "factId": "f1", "key": "monto", "value": "50",
        }])
        key = L.generate_cache_key(
            "denuncia_robo", ["ROBAR", "CELULAR"], semantic_frame=base)
        for changed in (changed_order, changed_role, changed_literal):
            self.assertNotEqual(
                key,
                L.generate_cache_key(
                    "denuncia_robo", ["ROBAR", "CELULAR"],
                    semantic_frame=changed),
            )


if __name__ == "__main__":
    unittest.main()
