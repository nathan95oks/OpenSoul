"""Zona de cada palabra sin seña: módulo y acción `zonas`.

Titan y Bedrock se simulan: se prueba que la zona solo se asigne cuando las
dos señales coinciden y que un fallo nunca sea un error.
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
import rag_zonas as Z  # noqa: E402

ZONAS = {"Tiempo": ["ayer", "hoy", "mañana"],
         "Documentos": ["papel", "certificado", "folio"]}
BOLETA = {"palabra": "BOLETA", "ejemplos": ["Sí tengo mi última boleta."]}
SEMANA = {"palabra": "SEMANAL", "ejemplos": ["Pago semanal."]}


def embed(texto):
    """Tiempo si habla de días, Documentos si de papeles."""
    t = texto.lower()
    tiempo = any(w in t for w in ("ayer", "hoy", "semanal", "tiempo"))
    papel = any(w in t for w in ("papel", "boleta", "documentos"))
    return [float(tiempo), float(papel), 0.1]


def modelo(zonas):
    return lambda _prompt: json.dumps(
        [{"n": i + 1, "zona": z} for i, z in enumerate(zonas)])


class Catalogo(unittest.TestCase):
    def test_cada_sena_oficial_tiene_su_zona(self):
        zonas = Z.cargar_zonas()
        self.assertEqual(len(zonas), 346)
        self.assertEqual(zonas["PAPEL"], "Documentos")
        self.assertEqual(zonas["AYER"], "Tiempo")

    def test_el_deletreo_no_es_una_zona(self):
        descritas = Z.zonas_con_senas(Z.cargar_zonas(), {"PAPEL": ["papel"]})
        self.assertNotIn("Abecedario", descritas)
        self.assertIn("papel", descritas["Documentos"])


SENAS = {"AYER": "Tiempo", "HOY": "Tiempo", "PAPEL": "Documentos",
         "FACTURA": "Documentos", "CERTIFICADO": "Documentos"}
TEXTOS = {"AYER": "ayer", "HOY": "hoy", "PAPEL": "papel",
          "FACTURA": "factura papel", "CERTIFICADO": "certificado papel"}
VECTORES = {g: embed(t) for g, t in TEXTOS.items()}


class Clasificacion(unittest.TestCase):
    def test_con_las_dos_senales_de_acuerdo_hay_zona(self):
        out = Z.clasificar([BOLETA, SEMANA], ZONAS, VECTORES, SENAS, embed,
                           modelo(["Documentos", "Tiempo"]))
        self.assertEqual([o["zona"] for o in out], ["Documentos", "Tiempo"])
        self.assertIn("PAPEL", out[0]["vecinas"])

    def test_si_no_coinciden_no_hay_zona(self):
        out = Z.clasificar([BOLETA], ZONAS, VECTORES, SENAS, embed,
                           modelo(["Tiempo"]))
        self.assertIsNone(out[0]["zona"])
        self.assertEqual((out[0]["titan"], out[0]["bedrock"]),
                         ("Documentos", "Tiempo"))

    def test_una_zona_que_no_existe_no_vale(self):
        out = Z.clasificar([BOLETA], ZONAS, VECTORES, SENAS, embed,
                           modelo(["Finanzas"]))
        self.assertIsNone(out[0]["bedrock"])
        self.assertIsNone(out[0]["zona"])

    def test_titan_ve_la_palabra_en_su_frase(self):
        self.assertEqual(Z.texto_palabra(BOLETA),
                         "boleta: Sí tengo mi última boleta.")
        self.assertEqual(Z.textos_senas({"PAPEL": "Documentos"},
                                        {"PAPEL": ["Papel", "el documento"]}),
                         {"PAPEL": "papel: Papel; el documento"})

    def test_el_indice_de_senas_se_llena_por_tandas(self):
        indice = Z.indexar_senas(TEXTOS, {}, embed, lote=2)
        self.assertEqual(len(indice["vectores"]), 2)
        indice = Z.indexar_senas(TEXTOS, indice, embed, lote=10)
        self.assertEqual(len(indice["vectores"]), 5)


class Accion(unittest.TestCase):
    def llamar(self, cuerpo):
        r = L.lambda_handler({"body": json.dumps(cuerpo)}, None)
        return r["statusCode"], json.loads(r["body"])

    def test_la_lambda_clasifica(self):
        cuerpo = {"output": {"message": {"content": [
            {"text": json.dumps([{"n": 1, "zona": "Documentos"}])}]}}}
        with mock.patch.object(L, "ENABLE_BEDROCK", True), \
                mock.patch.object(L, "_ZONAS_LSB",
                                  (SENAS, ZONAS, TEXTOS, "clave")), \
                mock.patch.object(L, "read_cache_json",
                                  return_value={"vectores": VECTORES}), \
                mock.patch.object(L.bedrock_runtime, "invoke_model",
                                  create=True, return_value={
                                      "body": io.BytesIO(
                                          json.dumps(cuerpo).encode())}), \
                mock.patch.object(L, "_embed_zonas", embed):
            estado, datos = self.llamar({"action": "zonas",
                                         "palabras": [BOLETA]})
        self.assertEqual(estado, 200)
        self.assertEqual(datos["palabras"][0]["zona"], "Documentos")

    def test_pedido_invalido_es_400(self):
        estado, _ = self.llamar({"action": "zonas", "palabras": []})
        self.assertEqual(estado, 400)


if __name__ == "__main__":
    unittest.main()
