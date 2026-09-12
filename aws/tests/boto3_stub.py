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





def install():
    """Instala el doble. Idempotente: llamarlo dos veces no cambia nada."""
    if "boto3" in sys.modules:
        return

    boto3 = types.ModuleType("boto3")
    boto3.client = lambda *a, **k: types.SimpleNamespace()
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
