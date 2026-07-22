"""
Seed del diccionario evolutivo (Fase 2).

Crea (opcionalmente) la tabla DynamoDB y la puebla desde la MISMA fuente
canónica que empaqueta la app: `assets/dictionary/official_dictionary.json`.
Así el asset, la tabla y la API comparten un único contrato de datos.

Uso (con credenciales AWS configuradas):

    python3 aws/seed_dictionary.py --create-table
    python3 aws/seed_dictionary.py                # solo re-sembrar datos
    python3 aws/seed_dictionary.py --table MiTabla --region us-east-1

Idempotente: re-ejecutar sobreescribe META y las ENTRY existentes.
Las PROPOSAL nunca se tocan.
"""

import argparse
import json
import sys
from pathlib import Path

import boto3

DEFAULT_TABLE = "OpenSoul-Dictionary"
DEFAULT_REGION = "us-east-1"
DICTIONARY_JSON = (
    Path(__file__).resolve().parent.parent
    / "assets" / "dictionary" / "official_dictionary.json"
)


def ensure_table(client, name: str) -> None:
    existing = client.list_tables()["TableNames"]
    if name in existing:
        print(f"Tabla '{name}' ya existe — no se recrea.")
        return
    print(f"Creando tabla '{name}' (on-demand)…")
    client.create_table(
        TableName=name,
        AttributeDefinitions=[
            {"AttributeName": "pk", "AttributeType": "S"},
            {"AttributeName": "sk", "AttributeType": "S"},
        ],
        KeySchema=[
            {"AttributeName": "pk", "KeyType": "HASH"},
            {"AttributeName": "sk", "KeyType": "RANGE"},
        ],
        BillingMode="PAY_PER_REQUEST",
    )
    client.get_waiter("table_exists").wait(TableName=name)
    print("Tabla activa.")


def seed(table, doc: dict) -> None:
    entries = doc.get("entries", [])
    with table.batch_writer(overwrite_by_pkeys=["pk", "sk"]) as batch:
        batch.put_item(Item={
            "pk": "META",
            "sk": "DICTIONARY",
            "version": int(doc.get("version", 1)),
            "dialect": doc.get("dialect", "cochabamba"),
            "categoryOrder": doc.get("categoryOrder", []),
        })
        for entry in entries:
            status = entry.get("status", "official")
            item = {"pk": "ENTRY", "sk": f"{status}#{entry['gloss']}", **entry}
            # DynamoDB no admite strings vacíos en algunos contextos antiguos
            # y nunca admite None: se limpian.
            item = {k: v for k, v in item.items() if v is not None}
            batch.put_item(Item=item)
    print(f"Sembradas {len(entries)} entradas + META (versión {doc.get('version')}).")


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed del diccionario LSB")
    parser.add_argument("--table", default=DEFAULT_TABLE)
    parser.add_argument("--region", default=DEFAULT_REGION)
    parser.add_argument("--create-table", action="store_true")
    args = parser.parse_args()

    if not DICTIONARY_JSON.exists():
        print(f"No existe {DICTIONARY_JSON}", file=sys.stderr)
        return 1
    doc = json.loads(DICTIONARY_JSON.read_text(encoding="utf-8"))

    client = boto3.client("dynamodb", region_name=args.region)
    if args.create_table:
        ensure_table(client, args.table)

    table = boto3.resource("dynamodb", region_name=args.region).Table(args.table)
    seed(table, doc)
    return 0


if __name__ == "__main__":
    sys.exit(main())
