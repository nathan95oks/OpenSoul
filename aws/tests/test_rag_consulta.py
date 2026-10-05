"""RAG por significado (fase 2): módulo y acciones de la Lambda.

Los embeddings reales son de Bedrock (Titan). Aquí se usa uno falso y
determinista: bolsa de palabras con unos pocos sinónimos, suficiente para
probar el mecanismo (índice, huella, tandas, umbral, respuestas) sin red.
"""

import hashlib
import json
import math
import os
import re
import sys
import tempfile
import unicodedata
import unittest
from unittest import mock

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TESTS_DIR)

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()
sys.path.insert(0, os.path.join(TESTS_DIR, ".."))

import lambda_function as L  # noqa: E402
import rag_consulta as RAG  # noqa: E402

_SINONIMOS = {"peligro": "seguro", "ahorita": "ahora", "segura": "seguro"}
_VACIAS = {"en", "un", "una", "el", "la", "los", "las", "de", "del", "usted",
           "esta", "le", "lo", "su", "sus", "que", "o", "y", "a", "por", "se"}


def falso_embed(texto: str) -> list:
    plano = unicodedata.normalize("NFD", texto.lower())
    plano = "".join(c for c in plano if unicodedata.category(c) != "Mn")
    v = [0.0] * 512
    for w in re.findall(r"[a-zñ]+", plano):
        w = _SINONIMOS.get(w, w)
        if w in _VACIAS:
            continue
        v[int(hashlib.md5(w.encode()).hexdigest(), 16) % 512] += 1.0
    norma = math.sqrt(sum(x * x for x in v)) or 1.0
    return [x / norma for x in v]


CORPUS = RAG.cargar_corpus()
LISTA = RAG.entradas(CORPUS)


def indice_completo() -> dict:
    return {"vectores": {str(i): falso_embed(e["texto"])
                         for i, e in enumerate(LISTA)}}


class ModuloRag(unittest.TestCase):
    def test_corpus_corrupto_desactiva_rag_sin_error(self):
        with tempfile.NamedTemporaryFile("w", encoding="utf-8",
                                         suffix=".json", delete=False) as f:
            f.write("{no-json")
            ruta = f.name
        try:
            self.assertIsNone(RAG.cargar_corpus(ruta))
        finally:
            os.unlink(ruta)

    def test_indexa_preguntas_del_funcionario_con_respuestas_ofrecibles(self):
        self.assertGreater(len(LISTA), 200)
        for e in LISTA:
            self.assertTrue(e["texto"].strip())
            self.assertTrue(e["respuestas"])
            for r in e["respuestas"]:
                self.assertTrue(r["mostrable"])
                self.assertTrue(r["glosas"])

    def test_la_huella_cambia_si_cambia_el_corpus(self):
        otra = [dict(LISTA[0], texto=LISTA[0]["texto"] + " x")] + LISTA[1:]
        self.assertNotEqual(RAG.huella(LISTA), RAG.huella(otra))
        self.assertEqual(RAG.huella(LISTA), RAG.huella(list(LISTA)))

    def test_indexar_avanza_por_tandas_hasta_completar(self):
        indice, llamadas = {}, 0
        while len(indice.get("vectores", {})) < len(LISTA):
            indice = RAG.indexar(LISTA, indice, falso_embed, lote=100)
            llamadas += 1
        self.assertEqual(math.ceil(len(LISTA) / 100), llamadas)
        # Completo: una llamada más no calcula nada.
        with mock.patch.object(RAG, "_normalizar", side_effect=AssertionError):
            RAG.indexar(LISTA, indice, falso_embed)

    def test_encuentra_por_significado_lo_que_las_palabras_no(self):
        # «¿Está en peligro?» se pregunta en FELCV, Fiscalía, SLIM, DNA…: con
        # el tema de la conversación se queda en su institución.
        found = RAG.consultar("¿Usted está en peligro ahorita?", LISTA,
                              indice_completo(), falso_embed,
                              prefer_area="FELCV")
        self.assertTrue(found)
        self.assertTrue(all(s["scenarioId"].startswith("ESC-FELCV-")
                            for s in found), found)
        for s in found:
            self.assertTrue(s["glosses"])

    def test_sin_tema_una_pregunta_de_cualquier_ventanilla_no_elige(self):
        self.assertEqual(RAG.consultar("¿Usted está en peligro ahorita?", LISTA,
                                       indice_completo(), falso_embed), [])

    def test_no_mezcla_instituciones(self):
        found = RAG.consultar("¿Usted está en peligro ahorita?", LISTA,
                              indice_completo(), falso_embed, minimo=0.3,
                              limite=8, prefer_area="FELCV")
        self.assertTrue(found)
        areas = {s["scenarioId"].split("-")[1] for s in found}
        self.assertEqual(1, len(areas), found)

    def test_lo_que_no_se_parece_no_sugiere_nada(self):
        self.assertEqual([], RAG.consultar("¿Le gusta el fútbol?", LISTA,
                                           indice_completo(), falso_embed))
        self.assertEqual([], RAG.consultar("   ", LISTA, indice_completo(),
                                           falso_embed))


class AccionesLambda(unittest.TestCase):
    def setUp(self):
        L._RAG_STATE = None
        self.guardado = {}

        def leer(clave):
            return self.guardado.get(clave)

        def escribir(clave, cuerpo):
            self.guardado[clave] = json.loads(json.dumps(cuerpo))

        self.parches = [
            mock.patch.object(L, "read_cache_json", side_effect=leer),
            mock.patch.object(L, "write_cache_json", side_effect=escribir),
            mock.patch.object(L, "_titan_embed", side_effect=falso_embed),
            mock.patch.object(L, "ENABLE_BEDROCK", True),
        ]
        for p in self.parches:
            p.start()

    def tearDown(self):
        for p in self.parches:
            p.stop()
        L._RAG_STATE = None

    def llamar(self, cuerpo):
        r = L.lambda_handler({"body": json.dumps(cuerpo)}, None)
        return r["statusCode"], json.loads(r["body"])

    def test_sin_indice_responde_sin_resultado_no_error(self):
        status, body = self.llamar({"action": "consulta",
                                    "text": "¿Está en peligro?"})
        self.assertEqual(200, status)
        self.assertFalse(body["generated"])
        self.assertEqual("sin_indice", body["reason"])

    def test_indexar_por_tandas_y_luego_consultar(self):
        pendientes = None
        for _ in range(100):
            status, body = self.llamar({"action": "rag_indexar"})
            self.assertEqual(200, status)
            pendientes = body["pending"]
            if pendientes == 0:
                break
        self.assertEqual(0, pendientes)

        status, body = self.llamar({"action": "consulta",
                                    "text": "¿Usted está en peligro ahorita?",
                                    "preferArea": "FELCV",
                                    "limit": 3})
        self.assertEqual(200, status)
        self.assertTrue(body["generated"])
        self.assertLessEqual(len(body["suggestions"]), 3)
        self.assertTrue(body["suggestions"][0]["scenarioId"].startswith("ESC-FELCV-"))

    def test_informa_la_mejor_similitud_para_calibrar(self):
        self.guardado[L._rag_state()[1]] = indice_completo()
        _, body = self.llamar({"action": "consulta",
                               "text": "¿Le gusta el fútbol?"})
        self.assertTrue(body["generated"])
        self.assertEqual([], body["suggestions"])
        self.assertIn("score", body["best"])
        self.assertIn("scenarioId", body["best"])
        # Un umbral por petición, acotado, deja ver lo que hay debajo.
        _, bajo = self.llamar({"action": "consulta", "text": "¿Le gusta el fútbol?",
                               "minSimilarity": 0.3})
        self.assertEqual(0.3, bajo["minSimilarity"])
        _, fuera = self.llamar({"action": "consulta", "text": "¿Hola?",
                                "minSimilarity": 0.0})
        self.assertEqual(RAG.MIN_SIMILARITY, fuera["minSimilarity"])

    def test_validacion_y_fallos_del_modelo(self):
        status, _ = self.llamar({"action": "consulta"})
        self.assertEqual(400, status)
        status, _ = self.llamar({"action": "consulta", "text": "x" * 5000})
        self.assertEqual(400, status)

        self.guardado[L._rag_state()[1]] = indice_completo()
        with mock.patch.object(L, "_titan_embed", side_effect=RuntimeError("caído")):
            status, body = self.llamar({"action": "consulta", "text": "¿Hola?"})
        self.assertEqual(200, status)
        self.assertEqual("error_modelo", body["reason"])

        with mock.patch.object(L, "ENABLE_BEDROCK", False):
            _, body = self.llamar({"action": "consulta", "text": "¿Hola?"})
        self.assertEqual("bedrock_desactivado", body["reason"])


if __name__ == "__main__":
    unittest.main()
