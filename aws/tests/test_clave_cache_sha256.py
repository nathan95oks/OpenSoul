"""Las claves de caché de las dos Lambdas son SHA-256, no MD5.

La clave se calcula sobre lo que manda cualquiera a un endpoint público: con
MD5 (colisiones prácticas desde 2004; RFC 6151) dos pedidos distintos podrían
compartir clave y la caché serviría la traducción o el audio de otra persona.
"""

import hashlib
import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()

import lambda_function as L  # noqa: E402
import lambda_text_to_lsb as T  # noqa: E402


class ClaveDeCacheSha256(unittest.TestCase):
    def es_sha256(self, clave: str) -> None:
        self.assertRegex(clave, r"^[0-9a-f]{64}$")

    def test_tarjetas_a_texto_y_audio(self):
        self.es_sha256(L.generate_cache_key("denuncia_robo", ["ROBAR"]))

    def test_texto_a_lsb(self):
        clave = T.generate_cache_key("me robaron el celular")
        self.es_sha256(clave)
        semilla = (f"{T.CACHE_VERSION}|{T.TRANSLATION_RULESET_VERSION}|"
                   f"{T.BEDROCK_MODEL_ID}|me robaron el celular")
        self.assertEqual(clave, hashlib.sha256(semilla.encode("utf-8")).hexdigest())
        self.assertNotEqual(clave, hashlib.md5(semilla.encode("utf-8")).hexdigest())


if __name__ == "__main__":
    unittest.main()
