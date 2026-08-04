"""
Lambda: OpenSoul-Dictionary
Fase 2 — Diccionario evolutivo LSB (fuente única de vocabulario).

API (API Gateway HTTP API o REST, proxy integration):

  GET  /dictionary
      Devuelve el documento completo del diccionario en el MISMO contrato
      que `assets/dictionary/official_dictionary.json` de la app:
        { "version": N, "dialect": "...", "categoryOrder": [...],
          "entries": [ {...LsbCard...} ] }
      Solo entradas `official` y `community` (nunca `pending`).
      La app lo consume vía RemoteLexiconDataSource y solo lo aplica si
      `version` supera a su copia local (offline-first).

  POST /dictionary/proposals
      Registra una propuesta de la comunidad (nueva palabra/seña/contexto).
      Se almacena como PROPOSAL con estado `pending`. NUNCA modifica el
      diccionario ni la versión: la aprobación ocurre exclusivamente en el
      Portal Web de validación (Fase 4), que al aprobar escribe la ENTRY
      y aumenta `version` en el item META.

Modelo de datos (tabla DynamoDB, on-demand):
  pk = "META"      sk = "DICTIONARY"        → version, dialect, categoryOrder
  pk = "ENTRY"     sk = "<status>#<gloss>"  → campos de LsbCard + status
  pk = "PROPOSAL"  sk = "<isoDate>#<uuid>"  → propuesta pendiente

Variables de entorno:
  DICTIONARY_TABLE  (default: OpenSoul-Dictionary)
  APP_REGION        (default: us-east-1)
"""

import json
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key

DICTIONARY_TABLE = os.environ.get("DICTIONARY_TABLE", "OpenSoul-Dictionary")
APP_REGION = os.environ.get("APP_REGION", os.environ.get("AWS_REGION", "us-east-1"))

dynamodb = boto3.resource("dynamodb", region_name=APP_REGION)
table = dynamodb.Table(DICTIONARY_TABLE)

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Content-Type": "application/json",
}

# Campos admitidos en una propuesta (todo lo demás se descarta) y su forma.
#
# La allowlist de nombres ya estaba, pero los VALORES se copiaban tal cual:
# `item[field] = body[field]` aceptaba cualquier tipo JSON y cualquier tamaño.
# Como el endpoint es público y sin autenticación, una propuesta podía llegar
# con un `description` de cientos de KB o un `contexts` anidado hasta el límite
# de 400 KB por item de DynamoDB — almacenamiento y coste ilimitados escritos
# por cualquiera, y datos con los que después tiene que lidiar el portal de
# validación.
#
# Formato: campo → (tipo, longitud máxima). Para listas, la longitud aplica a
# cada elemento y MAX_LIST_ITEMS al número de elementos.
MAX_LIST_ITEMS = 12
PROPOSAL_FIELDS = {
    "word": (str, 80),
    "gloss": (str, 80),
    "displayText": (str, 120),
    "categoryId": (str, 60),
    "subcategoryId": (str, 60),
    "contexts": (list, 40),
    "description": (str, 600),
    "videoUrl": (str, 500),
    "dialect": (str, 40),
    "proposedBy": (str, 120),
}

# Tope del cuerpo entero, antes incluso de parsearlo.
MAX_BODY_BYTES = 16 * 1024


def _clean_field(name: str, value):
    """Valor admisible para [name], o `None` si no lo es.

    Lista blanca estricta de tipo y tamaño: lo que no encaja se descarta en
    lugar de truncarse, para que una propuesta malformada no se guarde a
    medias y parezca legítima en el portal.
    """
    expected, limit = PROPOSAL_FIELDS[name]

    if expected is str:
        if not isinstance(value, str):
            return None
        cleaned = value.strip()
        return cleaned[:limit] if cleaned else None

    if expected is list:
        if not isinstance(value, list):
            return None
        items = [
            v.strip()[:limit]
            for v in value[:MAX_LIST_ITEMS]
            if isinstance(v, str) and v.strip()
        ]
        return items or None

    return None


class _DecimalEncoder(json.JSONEncoder):
    """DynamoDB devuelve números como Decimal; el contrato usa int."""

    def default(self, o):
        if isinstance(o, Decimal):
            return int(o) if o % 1 == 0 else float(o)
        return super().default(o)


def _response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": CORS_HEADERS,
        "body": json.dumps(body, ensure_ascii=False, cls=_DecimalEncoder),
    }


def _method_and_path(event: dict) -> tuple:
    """Compatible con payloads de REST API (v1) y HTTP API (v2)."""
    ctx = event.get("requestContext", {})
    http = ctx.get("http", {})
    method = http.get("method") or event.get("httpMethod") or "GET"
    path = http.get("path") or event.get("path") or "/"
    return method.upper(), path


def _query_all(pk: str) -> list:
    items = []
    kwargs = {"KeyConditionExpression": Key("pk").eq(pk)}
    while True:
        resp = table.query(**kwargs)
        items.extend(resp.get("Items", []))
        last = resp.get("LastEvaluatedKey")
        if not last:
            return items
        kwargs["ExclusiveStartKey"] = last


def get_dictionary() -> dict:
    meta = table.get_item(Key={"pk": "META", "sk": "DICTIONARY"}).get("Item", {})

    entries = []
    for item in _query_all("ENTRY"):
        if item.get("status") == "pending":
            continue
        entry = {k: v for k, v in item.items() if k not in ("pk", "sk")}
        entries.append(entry)

    return _response(200, {
        "version": meta.get("version", 1),
        "dialect": meta.get("dialect", "cochabamba"),
        "categoryOrder": meta.get("categoryOrder", []),
        "entries": entries,
    })


def create_proposal(raw_body: str) -> dict:
    raw_body = raw_body or "{}"
    # Se mide antes de parsear: un JSON de megabytes no debe llegar siquiera
    # a construirse en memoria.
    if len(raw_body.encode("utf-8")) > MAX_BODY_BYTES:
        return _response(413, {"error": "Propuesta demasiado grande"})

    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError:
        return _response(400, {"error": "JSON inválido"})
    if not isinstance(body, dict):
        return _response(400, {"error": "El cuerpo debe ser un objeto JSON"})

    word = _clean_field("word", body.get("word")) or _clean_field(
        "gloss", body.get("gloss")
    )
    if not word:
        return _response(400, {"error": "Se requiere 'word' o 'gloss'"})

    now = datetime.now(timezone.utc).isoformat()
    proposal_id = str(uuid.uuid4())
    item = {
        "pk": "PROPOSAL",
        "sk": f"{now}#{proposal_id}",
        "id": proposal_id,
        "status": "pending",
        "createdAt": now,
    }
    for field in PROPOSAL_FIELDS:
        if field not in body or body[field] is None:
            continue
        cleaned = _clean_field(field, body[field])
        if cleaned is not None:
            item[field] = cleaned
    # 'word' se fija al final: ni siquiera un 'word' inválido en el cuerpo
    # puede sustituir al valor ya validado.
    item["word"] = word

    table.put_item(Item=item)
    return _response(201, {"id": proposal_id, "status": "pending"})


def lambda_handler(event, context):
    method, path = _method_and_path(event)

    if method == "OPTIONS":
        return _response(204, {})
    if method == "GET":
        return get_dictionary()
    if method == "POST" and path.rstrip("/").endswith("proposals"):
        return create_proposal(event.get("body"))

    return _response(404, {"error": f"Ruta no soportada: {method} {path}"})
