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


class FakeTable:
    """Registra lo que se habría escrito en DynamoDB."""

    def __init__(self):
        self.items = []

    def put_item(self, Item):  # noqa: N803 — firma de boto3
        self.items.append(Item)

    def get_item(self, Key):  # noqa: N803
        return {}

    def query(self, **kwargs):
        return {"Items": []}


fake_table = FakeTable()


def install():
    """Instala el doble. Idempotente: llamarlo dos veces no cambia nada."""
    if "boto3" in sys.modules:
        return

    boto3 = types.ModuleType("boto3")
    boto3.client = lambda *a, **k: types.SimpleNamespace()
    boto3.resource = lambda *a, **k: types.SimpleNamespace(
        Table=lambda name: fake_table
    )

    conditions = types.ModuleType("boto3.dynamodb.conditions")

    class _Key:
        def __init__(self, name):
            self.name = name

        def eq(self, value):
            return (self.name, value)

    conditions.Key = _Key

    dynamodb_mod = types.ModuleType("boto3.dynamodb")
    dynamodb_mod.conditions = conditions
    boto3.dynamodb = dynamodb_mod

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
    sys.modules["boto3.dynamodb"] = dynamodb_mod
    sys.modules["boto3.dynamodb.conditions"] = conditions
    sys.modules["botocore"] = botocore
    sys.modules["botocore.exceptions"] = exceptions
