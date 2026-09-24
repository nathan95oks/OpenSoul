"""El JSON que produce Flutter, pasado por el handler de verdad.

Los ficheros de `test/fixtures/contract/` los escribe
`test/contract_fixtures_test.dart` con el mismo constructor de cuerpo que usa
la aplicación (`RemoteTranslationDataSourceImpl.buildRequestBody`). Aquí no se
escribe JSON a mano: se carga lo que el cliente manda y se invoca
`lambda_handler`, que es lo que corre en producción.

Esta es la prueba que faltaba. Los dos fallos más caros del contrato
—`actorRole` frente a `actor_role`, y la puerta que descartaba el
`declaration` fuera de `denuncia_robo`— sobrevivieron porque cada lado se
probaba con su propio formato: el backend pasaba sus pruebas con JSON escrito
a mano que el cliente nunca enviaba.

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


def cargar(nombre: str) -> dict:
    ruta = os.path.join(FIXTURES, nombre + ".json")
    with open(ruta, encoding="utf-8") as f:
        return json.load(f)


def invocar(body: dict) -> dict:
    """Pasa el cuerpo por el handler tal cual llega de API Gateway."""
    respuesta = L.lambda_handler({"httpMethod": "POST", "body": json.dumps(body)}, None)
    return json.loads(respuesta["body"])


def frase(nombre: str) -> str:
    """La oración determinista que el backend produce para ese fixture."""
    body = cargar(nombre)
    return L.generate_structured_sentence(body["declaration"])


class FixturesExisten(unittest.TestCase):
    def test_los_fixtures_estan_generados(self):
        self.assertTrue(
            os.path.isdir(FIXTURES),
            "Faltan los fixtures. Ejecuta: flutter test test/contract_fixtures_test.dart")
        generados = [f for f in os.listdir(FIXTURES) if f.endswith(".json")]
        self.assertGreaterEqual(len(generados), 8, generados)


class EscaparNoEsRobo(unittest.TestCase):
    """ESCAPAR sola describe una huida, no una sustracción."""

    def test_solo_escapar_no_denuncia_un_robo(self):
        texto = frase("solo_escapar")
        self.assertNotIn("robo", texto.lower(),
                         f"Se inventó un robo que nadie declaró: {texto!r}")
        self.assertNotIn("Denuncio", texto)

    def test_solo_escapar_relata_la_huida(self):
        texto = frase("solo_escapar")
        self.assertIn("escapar", texto.lower(), texto)

    def test_solo_perder_no_denuncia_un_robo(self):
        texto = frase("solo_perder")
        self.assertIn("perdido", texto.lower(), texto)
        self.assertNotIn("Denuncio el robo", texto)

    def test_el_handler_completo_tampoco_inventa_el_robo(self):
        # No solo el generador: la ruta entera, con validación y caché.
        datos = invocar(cargar("solo_escapar"))
        texto = (datos.get("generatedText") or datos.get("baseSentence") or "")
        self.assertNotIn("Denuncio el robo", texto, datos)


class QuienEscapo(unittest.TestCase):
    """«Me robaron y yo escapé» no es «me robaron y el ladrón escapó»."""

    def test_huida_del_sospechoso(self):
        texto = frase("robo_y_huida_sospechoso")
        self.assertIn("Denuncio el robo", texto)
        self.assertIn("El sospechoso se dio a la fuga.", texto, texto)

    def test_huida_de_la_propia_persona(self):
        texto = frase("robo_y_huida_victima")
        self.assertIn("Denuncio el robo", texto)
        self.assertIn("Logré escapar.", texto, texto)
        self.assertNotIn("El sospechoso se dio a la fuga", texto,
                         "Se atribuyó la huida a quien no la hizo.")

    def test_los_dos_relatos_no_dicen_lo_mismo(self):
        self.assertNotEqual(frase("robo_y_huida_sospechoso"),
                            frase("robo_y_huida_victima"))

    def test_huida_sin_aclarar_no_se_la_atribuye_a_nadie(self):
        texto = frase("huida_sin_aclarar")
        self.assertIn("Denuncio el robo", texto)
        self.assertNotIn("El sospechoso se dio a la fuga", texto)
        self.assertNotIn("Logré escapar", texto)
        self.assertIn("sin precisar", texto, texto)


class NombresDelContrato(unittest.TestCase):
    """El campo que el cliente escribe es el que el backend lee."""

    def test_el_cliente_envia_actorRole_en_camelCase(self):
        decl = cargar("robo_y_huida_sospechoso")["declaration"]
        self.assertIn("actorRole", decl["facts"][1],
                      "Si el cliente dejara de enviarlo, esta prueba avisa.")

    def test_el_backend_lee_el_nombre_que_el_cliente_envia(self):
        decl = cargar("robo_y_huida_sospechoso")["declaration"]
        hechos = L.normalize_facts(decl)
        escapar = [h for h in hechos if h["action"] == "ESCAPAR"]
        self.assertEqual(len(escapar), 1)
        self.assertEqual(escapar[0]["actorRole"], "suspect")

    def test_un_papel_desconocido_no_se_interpreta_a_ojo(self):
        hechos = L.normalize_facts(
            {"facts": [{"action": "ESCAPAR", "actorRole": "sospechozo"}]})
        self.assertEqual(hechos[0]["actorRole"], "unknown")

    def test_los_papeles_validos_son_un_conjunto_cerrado(self):
        for crudo, esperado in [
            ("suspect", "suspect"), ("sospechoso", "suspect"),
            ("victim", "victim"), ("yo", "victim"),
            ("thirdParty", "thirdParty"), ("tercero", "thirdParty"),
            (None, "unknown"), ("", "unknown"), ("cualquier cosa", "unknown"),
        ]:
            self.assertEqual(L.normalize_actor_role(crudo), esperado, crudo)
            self.assertIn(L.normalize_actor_role(crudo), L.ACTOR_ROLES)


class EstructuradoFueraDeDenunciaRobo(unittest.TestCase):
    """Un `declaration` vale en cualquier contexto, no solo en denuncia_robo."""

    def test_violencia_usa_la_declaracion_estructurada(self):
        body = cargar("violencia_estructurada")
        self.assertEqual(body["context"], "violencia")
        self.assertTrue(L.has_structured_declaration(body))

    def test_el_handler_no_la_descarta_por_el_contexto(self):
        body = cargar("violencia_estructurada")
        datos = invocar(body)
        texto = (datos.get("generatedText") or datos.get("baseSentence") or "")
        self.assertIn("agresión", texto.lower(), datos)

    def test_el_detector_no_esta_ensombrecido(self):
        # Se llamaba igual que la variable local del handler y nunca corría.
        self.assertTrue(callable(L.has_structured_declaration))
        self.assertFalse(hasattr(L, "uses_structured"))


class BorradoresAntiguos(unittest.TestCase):
    """Lo guardado con el contrato anterior se sigue redactando igual."""

    def test_el_borrador_antiguo_tal_cual_conserva_la_huida(self):
        texto = frase("borrador_antiguo_tal_cual")
        self.assertIn("Denuncio el robo", texto)
        self.assertIn("El sospechoso se dio a la fuga.", texto, texto)

    def test_migrado_y_sin_migrar_dicen_lo_mismo(self):
        self.assertEqual(frase("borrador_antiguo_migrado"),
                         frase("borrador_antiguo_tal_cual"))

    def test_el_handler_acepta_las_dos_formas(self):
        for nombre in ("borrador_antiguo_tal_cual", "borrador_antiguo_migrado"):
            datos = invocar(cargar(nombre))
            self.assertNotIn("error", datos, f"{nombre}: {datos}")


if __name__ == "__main__":
    unittest.main()
