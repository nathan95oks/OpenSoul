"""Doble de boto3 compartido por las pruebas de las Lambdas.

Las Lambdas crean sus clientes AWS al importarse, así que el doble tiene que
estar puesto ANTES del primer import. Vive aquí, y no dentro de cada archivo
de prueba, porque `sys.modules.setdefault` hace que gane el primero que se
ejecute: con un stub por archivo, el resultado dependía del orden de
descubrimiento de unittest y una suite dejaba a la otra sin su tabla falsa.

    from boto3_stub import install, fake_table
    install()          # antes de importar cualquier lambda_*
"""

import sys
import types





class _FakeBody:
    """Cuerpo de respuesta de Polly: solo necesita saber leerse."""

    def __init__(self, data=b"\x00audio-falso"):
        self._data = data

    def read(self):
        return self._data


def _fake_client(service=None, *a, **k):
    """Cliente falso con lo justo para recorrer el handler entero.

    Sin `synthesize_speech` el handler devolvía POLLY_ERROR y las pruebas que
    recorren la ruta completa no podían llegar a comprobar el texto. Un doble
    que solo cubre media ruta deja fuera justo lo que hay que verificar.
    """
    cliente = types.SimpleNamespace()
    cliente.synthesize_speech = lambda *args, **kwargs: {
        "AudioStream": _FakeBody(),
    }
    cliente.put_object = lambda *args, **kwargs: {}
    cliente.generate_presigned_url = lambda *args, **kwargs: (
        "https://s3.example/audio-falso.mp3")
    cliente.head_object = lambda *args, **kwargs: {}
    return cliente


def install():
    """Instala el doble. Idempotente: llamarlo dos veces no cambia nada."""
    if "boto3" in sys.modules:
        return

    boto3 = types.ModuleType("boto3")
    boto3.client = _fake_client
    boto3.resource = lambda *a, **k: types.SimpleNamespace()

    exceptions = types.ModuleType("botocore.exceptions")

    class ClientError(Exception):
        def __init__(self, *a, **k):
            super().__init__(*a)
            self.response = {"Error": {"Code": ""}}

    exceptions.ClientError = ClientError
    exceptions.BotoCoreError = Exception
    botocore = types.ModuleType("botocore")
    botocore.exceptions = exceptions

    sys.modules["boto3"] = boto3
    sys.modules["botocore"] = botocore
    sys.modules["botocore.exceptions"] = exceptions
