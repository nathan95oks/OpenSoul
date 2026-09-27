"""Lectura semántica del turno (`semanticTurn`) de Audio/Texto→LSB.

Conversation consume lo que el oyente pidió sin volver a interpretarlo. Esa
lectura sale de la MISMA traducción: estas pruebas fijan que no hay otra
llamada a Bedrock, que frases distintas con el mismo significado dan la misma
lectura y que la respuesta normal del módulo no cambia.

    python -m unittest discover -s aws/tests -v
"""

import json
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import lambda_text_to_lsb as t2l  # noqa: E402

DENUNCIAS = {"denuncia_robo", "violencia", "amenaza_digital", "engano_dinero", "otro"}


def _lectura(texto, glosas):
    return t2l.build_semantic_turn(texto, {"glosses": glosas})


def _llamar(texto, glosas):
    """Recorre el handler con Bedrock simulado; devuelve (cuerpo, llamadas)."""
    with mock.patch.object(
        t2l, "invoke_bedrock",
        return_value={"glosses": glosas, "disambiguation": []},
    ) as modelo:
        respuesta = t2l.lambda_handler(
            {"body": json.dumps({"text": texto, "context": "legal"})}, None)
    return json.loads(respuesta["body"]), modelo.call_count


class LecturaDeterminista(unittest.TestCase):
    def test_frases_distintas_mismo_dato(self):
        """«¿Dónde fue?», «¿Dónde pasó?», «¿En qué lugar ocurrió?»: lugar."""
        for texto, glosas in (
            ("¿Dónde fue?", ["DONDE"]),
            ("¿Dónde pasó?", ["DONDE", "PASAR"]),
            ("¿En qué lugar ocurrió?", ["QUE"]),
            ("¿Dónde ocurrió?", ["DÓNDE"]),
        ):
            with self.subTest(texto=texto):
                lectura = _lectura(texto, glosas)
                self.assertEqual(lectura["requestedSlots"], ["place"])
                self.assertEqual(lectura["intent"], "askInformation")

    def test_dos_datos_en_orden(self):
        lectura = _lectura("¿A qué hora y dónde ocurrió?", ["HORA", "QUE", "DONDE"])
        self.assertEqual(lectura["requestedSlots"], ["time", "place"])

    def test_nombrar_denunciar_menciona_las_denuncias(self):
        lectura = _lectura("¿Quiere denunciar algo?", ["TU", "QUERER", "QUEJAR"])
        self.assertEqual(lectura["intent"], "mentionContext")
        self.assertEqual({m["id"] for m in lectura["mentionedContexts"]}, DENUNCIAS)
        self.assertEqual(lectura["requestedSlots"], [])

    def test_pregunta_abierta_por_el_motivo(self):
        lectura = _lectura(
            "Hola, ¿cómo está? ¿Qué viene a realizar?",
            ["HOLA", "COMO_ESTAS", "QUE", "VENIR", "HACER"],
        )
        self.assertEqual(lectura["intent"], "askPurpose")
        self.assertEqual(lectura["mentionedContexts"], [])

    def test_negacion(self):
        lectura = _lectura("¿No vio al ladrón?", ["NO", "VER", "LADRON"])
        self.assertEqual(lectura["negations"], ["NO"])
        self.assertIn("denuncia_robo", {m["id"] for m in lectura["mentionedContexts"]})

    def test_afirmacion_sin_pregunta(self):
        lectura = _lectura("El parqueo cierra a medianoche", ["CERRAR", "NOCHE"])
        self.assertEqual(lectura["intent"], "statement")
        self.assertEqual(lectura["requestedSlots"], [])

    def test_no_duplica_glosas_ni_sentidos(self):
        """Lo que la respuesta ya trae no se repite dentro de la lectura."""
        lectura = _lectura("¿Dónde fue?", ["DONDE"])
        self.assertNotIn("entities", lectura)
        self.assertNotIn("glosses", lectura)
        self.assertNotIn("resolvedSenses", lectura)
        self.assertEqual(lectura["version"], t2l.SEMANTIC_TURN_VERSION)


class DatoPedidoFrenteAlTema(unittest.TestCase):
    """El interrogativo dice qué quiere saber el oyente; el robo o el celular
    solo dicen de qué habla."""

    def test_el_interrogativo_manda_sobre_el_tema(self):
        for texto, glosas, ranuras in (
            ("¿Cuándo te robaron el celular?", ["CUANDO", "TU", "CELULAR", "ROBAR"], ["time"]),
            ("¿Dónde te robaron el celular?", ["DONDE", "TU", "CELULAR", "ROBAR"], ["place"]),
            ("¿Quién te robó el celular?", ["QUIEN", "TU", "CELULAR", "ROBAR"], ["person"]),
            ("¿Cuándo y dónde te robaron el celular?",
             ["CUANDO", "DONDE", "TU", "CELULAR", "ROBAR"], ["time", "place"]),
        ):
            with self.subTest(texto=texto):
                lectura = _lectura(texto, glosas)
                self.assertEqual(lectura["requestedSlots"], ranuras)
                self.assertEqual(lectura["intent"], "askInformation")
                self.assertEqual([m["id"] for m in lectura["mentionedContexts"]],
                                 ["denuncia_robo"])

    def test_la_traduccion_sin_interrogativo_no_pierde_el_dato(self):
        """Si la traducción no conserva CUANDO, el texto sigue diciéndolo."""
        for texto in ("¿Cuándo te robaron el celular?", "¿cuando te robaron el celular?"):
            with self.subTest(texto=texto):
                lectura = _lectura(texto, ["TU", "CELULAR", "ROBAR"])
                self.assertEqual(lectura["requestedSlots"], ["time"])

    def test_equivalentes_temporales(self):
        for texto, glosas in (("¿A qué hora fue?", ["HORA", "QUE"]),
                              ("¿A que hora fue?", ["QUE"]),
                              ("¿Cuándo ocurrió?", ["CUANDO"]),
                              ("Dígame, ¿cuándo fue?", ["DECIR", "CUANDO"])):
            with self.subTest(texto=texto):
                self.assertEqual(_lectura(texto, glosas)["requestedSlots"], ["time"])

    def test_cuando_conjuncion_no_es_pregunta_por_el_tiempo(self):
        self.assertEqual(_lectura("¿Me dijo que cuando llegó ya no estaba?",
                                  ["DECIR", "LLEGAR", "NO", "ESTAR"])["requestedSlots"], [])
        self.assertEqual(_lectura("Cuando llegué me robaron",
                                  ["LLEGAR", "ROBAR"])["requestedSlots"], [])

    def test_polar_sola_no_pide_dato(self):
        lectura = _lectura("¿Te robaron el celular?", ["TU", "CELULAR", "ROBAR"])
        self.assertEqual(lectura["requestedSlots"], [])
        self.assertEqual(_lectura("¿Qué te robaron?", ["QUE", "TU", "ROBAR"])["requestedSlots"], [])

    def test_polar_y_dato_en_la_misma_intervencion(self):
        lectura = _lectura("¿Te robaron el celular y cuándo fue?",
                           ["TU", "CELULAR", "ROBAR", "CUANDO"])
        self.assertEqual(lectura["requestedSlots"], ["time", "polarity"])
        # «¿Cuándo y dónde…?» son dos datos, no una confirmación.
        self.assertNotIn("polarity", _lectura(
            "¿Cuándo y dónde te robaron el celular?",
            ["CUANDO", "DONDE", "TU", "CELULAR", "ROBAR"])["requestedSlots"])

    def test_sin_segunda_llamada(self):
        cuerpo, llamadas = _llamar("¿Cuándo te robaron el celular?",
                                   ["TU", "CELULAR", "ROBAR"])
        self.assertEqual(llamadas, 1)
        self.assertEqual(cuerpo["semanticTurn"]["requestedSlots"], ["time"])


class ContratoConElCliente(unittest.TestCase):
    """Flutter lee `casos_semantic_turn.json` para probar el router con la
    lectura real. Si la Lambda cambia, el archivo tiene que regenerarse."""

    def test_los_casos_compartidos_son_la_salida_real(self):
        ruta = os.path.join(os.path.dirname(__file__), "casos_semantic_turn.json")
        with open(ruta, encoding="utf-8") as f:
            casos = json.load(f)["casos"]
        self.assertGreater(len(casos), 10)
        for caso in casos:
            with self.subTest(caso=caso["id"]):
                self.assertEqual(
                    caso["semanticTurn"],
                    t2l.build_semantic_turn(caso["texto"], {"glosses": caso["glosas"]}),
                    "Regenera con aws/tests/regenerar_casos_semantic_turn.py",
                )


class SinSegundaLlamada(unittest.TestCase):
    def test_una_sola_llamada_a_bedrock_por_turno(self):
        cuerpo, llamadas = _llamar("¿Dónde fue?", ["DONDE"])
        self.assertEqual(llamadas, 1, "La lectura no puede costar otra llamada.")
        self.assertEqual(cuerpo["semanticTurn"]["requestedSlots"], ["place"])
        self.assertEqual(cuerpo["glosses"], ["DONDE"])

    def test_la_respuesta_normal_del_modulo_no_cambia(self):
        cuerpo, _ = _llamar("Me robaron el celular", ["YO", "ROBAR", "CELULAR"])
        for campo in ("glosses", "disambiguation", "pendingClarifications",
                      "semanticStatus", "cacheHit"):
            self.assertIn(campo, cuerpo)
        self.assertEqual(cuerpo["semanticTurn"]["intent"], "mentionContext")

    def test_acierto_de_cache_trae_la_lectura_sin_bedrock(self):
        guardado = {"glosses": ["DONDE"], "disambiguation": [],
                    "pendingClarifications": [], "semanticStatus": "resolved"}
        with mock.patch.object(t2l, "check_cache", return_value=guardado), \
                mock.patch.object(t2l, "invoke_bedrock") as modelo:
            respuesta = t2l.lambda_handler(
                {"body": json.dumps({"text": "¿Dónde fue?"})}, None)
            modelo.assert_not_called()
        cuerpo = json.loads(respuesta["body"])
        self.assertTrue(cuerpo["cacheHit"])
        self.assertEqual(cuerpo["semanticTurn"]["requestedSlots"], ["place"])

    def test_la_lectura_no_se_guarda_en_la_cache_de_traduccion(self):
        with mock.patch.object(t2l, "save_to_cache") as guardar:
            _llamar("¿Dónde fue?", ["DONDE"])
        guardado = guardar.call_args[0][1]
        self.assertNotIn("semanticTurn", guardado)


if __name__ == "__main__":
    unittest.main()
