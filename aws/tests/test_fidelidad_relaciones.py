"""El refinamiento no puede cambiar quién hizo qué.

Encontrar las mismas palabras no demuestra nada: «me robaron y yo escapé» y
«me robaron y el ladrón escapó» comparten todas y no dicen lo mismo. El
validador anterior solo comprobaba cobertura léxica, números inventados y el
acto comunicativo, así que un refinamiento que cambiara de protagonista
pasaba limpio.

Estas pruebas van contra `relations_are_preserved` y contra el validador
completo, usando los hechos que produce el cliente Flutter.

    python -m unittest discover -s aws/tests -v
"""

import json
import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()

import lambda_function as L  # noqa: E402

FIXTURES = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "..", "test", "fixtures", "contract"))


def hechos_de(nombre: str) -> list:
    with open(os.path.join(FIXTURES, nombre + ".json"), encoding="utf-8") as f:
        return L.normalize_facts(json.load(f)["declaration"])


class QuienEscapoSeConserva(unittest.TestCase):
    def test_el_refinamiento_no_puede_cambiar_de_protagonista(self):
        facts = hechos_de("robo_y_huida_victima")  # escapó la persona sorda
        ok, motivo = L.relations_are_preserved(
            facts, "Denuncio el robo de mi celular. El sospechoso se dio a la fuga.")
        self.assertFalse(ok, "Se cambió quién escapó y pasó el validador.")
        self.assertIn("escapo", motivo)

    def test_el_refinamiento_fiel_pasa(self):
        facts = hechos_de("robo_y_huida_victima")
        ok, _ = L.relations_are_preserved(
            facts, "Denuncio el robo de mi celular. Logré escapar.")
        self.assertTrue(ok)

    def test_lo_mismo_al_reves(self):
        facts = hechos_de("robo_y_huida_sospechoso")
        ok, _ = L.relations_are_preserved(
            facts, "Denuncio el robo de mi celular. Logré escapar.")
        self.assertFalse(ok)

    def test_una_huida_sin_aclarar_no_se_atribuye_pero_tampoco_se_rechaza(self):
        facts = hechos_de("huida_sin_aclarar")
        ok, _ = L.relations_are_preserved(
            facts, "Denuncio el robo de mi celular. Hubo una huida.")
        self.assertTrue(ok, "Sin protagonista declarado no hay nada que violar.")


class LaNegacionSeConserva(unittest.TestCase):
    def _negado(self, accion):
        return [{"id": "f1", "action": accion, "actorRole": "suspect",
                 "negated": True, "certainty": "confirmed", "objectIds": [],
                 "actorDetail": "", "lossType": ""}]

    def test_un_hecho_negado_no_puede_salir_afirmado(self):
        ok, motivo = L.relations_are_preserved(
            self._negado("ROBAR"), "Denuncio el robo de mi celular.")
        self.assertFalse(ok, motivo)
        self.assertIn("negado", motivo)

    def test_un_hecho_negado_con_su_negacion_pasa(self):
        ok, _ = L.relations_are_preserved(
            self._negado("ROBAR"), "No es cierto que me hayan robado.")
        self.assertTrue(ok)


class LaIncertidumbreSeConserva(unittest.TestCase):
    def _incierto(self, accion):
        return [{"id": "f1", "action": accion, "actorRole": "unknown",
                 "negated": False, "certainty": "uncertain", "objectIds": [],
                 "actorDetail": "", "lossType": ""}]

    def test_una_duda_no_se_convierte_en_afirmacion(self):
        ok, motivo = L.relations_are_preserved(
            self._incierto("ROBAR"), "Denuncio el robo de mi celular.")
        self.assertFalse(ok, motivo)
        self.assertIn("duda", motivo)

    def test_una_duda_expresada_como_duda_pasa(self):
        ok, _ = L.relations_are_preserved(
            self._incierto("ROBAR"),
            "No estoy seguro, pero creo que me robaron el celular.")
        self.assertTrue(ok)


class NoSeIntroduceUnRobo(unittest.TestCase):
    def test_escapar_solo_no_admite_un_texto_con_robo(self):
        facts = hechos_de("solo_escapar")
        ok, motivo = L.relations_are_preserved(
            facts, "Denuncio el robo de mis pertenencias. Logré escapar.")
        self.assertFalse(ok, motivo)
        self.assertIn("robo", motivo)

    def test_escapar_solo_con_un_texto_fiel_pasa(self):
        facts = hechos_de("solo_escapar")
        ok, _ = L.relations_are_preserved(facts, "Logré escapar.")
        self.assertTrue(ok)

    def test_una_perdida_no_se_vuelve_robo(self):
        facts = hechos_de("solo_perder")
        ok, motivo = L.relations_are_preserved(
            facts, "Me robaron el celular.")
        self.assertFalse(ok, motivo)


class ElValidadorCompletoIncluyeLasRelaciones(unittest.TestCase):
    """`_generation_is_safe` es lo que decide si se acepta el refinamiento."""

    def test_rechaza_un_refinamiento_que_cambia_de_protagonista(self):
        facts = hechos_de("robo_y_huida_victima")
        seguro, motivo = L._generation_is_safe(
            ["ROBAR", "ESCAPAR", "CELULAR"],
            "Denuncio el robo de mi celular. El sospechoso se dio a la fuga.",
            "Denuncio el robo de mi celular. Logré escapar.",
            facts,
        )
        self.assertFalse(seguro, motivo)

    def test_acepta_un_refinamiento_fiel(self):
        facts = hechos_de("robo_y_huida_victima")
        seguro, motivo = L._generation_is_safe(
            ["ROBAR", "ESCAPAR", "CELULAR"],
            "Denuncio el robo de mi celular y conseguí escapar.",
            "Denuncio el robo de mi celular. Logré escapar.",
            facts,
        )
        self.assertTrue(seguro, motivo)

    def test_sin_hechos_se_comporta_como_antes(self):
        seguro, _ = L._generation_is_safe(
            ["CELULAR"], "Me robaron el celular.", "Me robaron el celular.")
        self.assertTrue(seguro)

    def test_cuando_falla_se_conserva_la_oracion_determinista(self):
        # generate_with_bedrock devuelve la base ante cualquier duda; aquí se
        # comprueba el contrato de esa función con Bedrock apagado.
        texto, validado = L.generate_with_bedrock(
            ["ROBAR"], {}, "Denuncio el robo de mi celular.", "denuncia_robo")
        self.assertEqual(texto, "Denuncio el robo de mi celular.")
        self.assertFalse(validado)


class LaCacheNoConfundeMensajes(unittest.TestCase):
    def _clave(self, nombre):
        with open(os.path.join(FIXTURES, nombre + ".json"), encoding="utf-8") as f:
            body = json.load(f)
        return L.generate_cache_key(
            body["context"], body["cards"],
            body.get("institutionType", ""), body.get("language", ""),
            body.get("speechAct", ""), body.get("declaration"),
            body.get("contractVersion"))

    def test_quien_escapo_cambia_la_clave(self):
        self.assertNotEqual(self._clave("robo_y_huida_victima"),
                            self._clave("robo_y_huida_sospechoso"),
                            "Dos relatos distintos compartirían respuesta.")

    def test_la_negacion_cambia_la_clave(self):
        base = {"facts": [{"id": "f1", "action": "ROBAR", "negated": False}]}
        negado = {"facts": [{"id": "f1", "action": "ROBAR", "negated": True}]}
        self.assertNotEqual(
            L.generate_cache_key("denuncia_robo", ["ROBAR"], declaration=base),
            L.generate_cache_key("denuncia_robo", ["ROBAR"], declaration=negado))

    def test_la_certeza_cambia_la_clave(self):
        seguro = {"facts": [{"id": "f1", "action": "ROBAR",
                             "certainty": "confirmed"}]}
        dudoso = {"facts": [{"id": "f1", "action": "ROBAR",
                             "certainty": "uncertain"}]}
        self.assertNotEqual(
            L.generate_cache_key("denuncia_robo", ["ROBAR"], declaration=seguro),
            L.generate_cache_key("denuncia_robo", ["ROBAR"], declaration=dudoso))

    def test_la_version_del_generador_invalida_lo_anterior(self):
        # Lo cacheado por el generador con el fallo de ESCAPAR no puede
        # servirse tras desplegar la corrección.
        clave = L.generate_cache_key("denuncia_robo", ["ROBAR"])
        original = L.GENERATOR_VERSION
        try:
            L.GENERATOR_VERSION = original + 1
            self.assertNotEqual(clave,
                                L.generate_cache_key("denuncia_robo", ["ROBAR"]))
        finally:
            L.GENERATOR_VERSION = original

    def test_la_version_del_contrato_separa_las_respuestas(self):
        self.assertNotEqual(
            L.generate_cache_key("denuncia_robo", ["ROBAR"], contract_version=2),
            L.generate_cache_key("denuncia_robo", ["ROBAR"], contract_version=3))

    def test_dos_peticiones_identicas_comparten_clave(self):
        self.assertEqual(self._clave("solo_escapar"), self._clave("solo_escapar"))


class ElAudioCorrespondeAlTextoAceptado(unittest.TestCase):
    """Lo que se oye es lo que se aceptó, no lo que el modelo propuso."""

    def test_polly_recibe_el_texto_que_devuelve_la_respuesta(self):
        pedidos = []
        original = L.synthesize_audio

        def espia(texto, language):
            pedidos.append(texto)
            return original(texto, language)

        L.synthesize_audio = espia
        try:
            with open(os.path.join(FIXTURES, "robo_y_huida_victima.json"),
                      encoding="utf-8") as f:
                body = json.load(f)
            respuesta = L.lambda_handler(
                {"httpMethod": "POST", "body": json.dumps(body)}, None)
            datos = json.loads(respuesta["body"])
        finally:
            L.synthesize_audio = original

        self.assertEqual(len(pedidos), 1, pedidos)
        self.assertEqual(pedidos[0], datos.get("generatedText"),
                         "El audio se generó con un texto distinto del que se "
                         "devolvió para revisar.")

    def test_si_el_refinamiento_se_rechaza_se_oye_la_oracion_determinista(self):
        # Con Bedrock apagado (el doble no lo implementa) el texto aceptado es
        # el determinista, y es el que tiene que sonar.
        with open(os.path.join(FIXTURES, "solo_escapar.json"),
                  encoding="utf-8") as f:
            body = json.load(f)
        datos = json.loads(L.lambda_handler(
            {"httpMethod": "POST", "body": json.dumps(body)}, None)["body"])

        self.assertEqual(datos.get("generatedText"), datos.get("baseSentence"))
        self.assertNotIn("robo", (datos.get("generatedText") or "").lower())


if __name__ == "__main__":
    unittest.main()
