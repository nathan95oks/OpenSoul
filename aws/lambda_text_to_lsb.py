"""
Lambda: OpenSoul-TranslateToLSB
Módulo Isaac Rivero — Traducción de Español → Glosas LSB

Objetivo Específico 3:
  "Implementar el modelo de Procesamiento de Lenguaje Natural para la
   desambiguación semántica de términos polisémicos en contexto jurídico."

Flujo:
  1. Recibe JSON con `text` (frase en español) y `context` (legal/general)
  2. Genera Hash MD5 de la frase para verificar caché (DynamoDB - futuro)
  3. Construye Prompt de desambiguación semántica para Bedrock
  4. Invoca Amazon Bedrock (Claude 3 Haiku) para análisis PLN
  5. Parsea la respuesta: extrae arreglo de glosas LSB
  6. Retorna JSON con glosses[] para que Flutter reproduzca animaciones 3D

Autor: Isaac Joel Rivero Peñarrieta — Proyecto de Grado OpenSoul (UCB)
"""

import json
import os
import hashlib
import logging
import re

import boto3
from botocore.exceptions import ClientError

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logger = logging.getLogger("text-to-lsb")
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------------------
# Variables de entorno (configurables en AWS Lambda → Configuration)
# ---------------------------------------------------------------------------
BEDROCK_MODEL_ID = os.environ.get(
    "BEDROCK_MODEL_ID", "global.amazon.nova-2-lite-v1:0"
)
APP_REGION = os.environ.get(
    "APP_REGION", os.environ.get("AWS_REGION", "us-east-1")
)

# ---------------------------------------------------------------------------
# Clientes AWS
# ---------------------------------------------------------------------------
bedrock_runtime = boto3.client("bedrock-runtime", region_name=APP_REGION)

# ---------------------------------------------------------------------------
# Encabezados CORS (para API Gateway → Flutter)
# ---------------------------------------------------------------------------
CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Content-Type": "application/json",
}

# ===================================================================
# DICCIONARIO DE GLOSAS DISPONIBLES EN EL AVATAR 3D
# Si la IA genera una glosa que NO está aquí, el sistema usará
# dactilología (deletreo) como fallback.
# ===================================================================
AVAILABLE_GLOSSES = {
    # --- Sustantivos Jurídicos ---
    "JUEZ", "ABOGADO", "POLICÍA", "FISCAL", "PERSONA", "HOMBRE", "MUJER",
    "VÍCTIMA", "TESTIGO", "CULPABLE", "INOCENTE", "DENUNCIA", "DOCUMENTO",
    "LEY", "DERECHO", "CÁRCEL", "TRIBUNAL", "CASA", "DINERO", "ROBO",
    # --- Verbos ---
    "DENUNCIAR", "ROBAR", "GOLPEAR", "DETENER", "FIRMAR", "DECLARAR",
    "PAGAR", "AYUDAR", "QUERER", "PODER", "TENER", "IR", "VER", "DECIR",
    "ENTENDER",
    # --- Pronombres y Conectores ---
    "YO", "TÚ", "ÉL", "ELLA", "NOSOTROS", "SÍ", "NO",
    "CUÁNDO", "DÓNDE", "QUÉ", "POR-QUÉ",
    "BUENO", "MALO", "GRANDE", "HOY", "AYER",
    # --- Números y Alfabeto Dactilológico (Para señas compuestas) ---
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
}


# ===================================================================
# MÓDULO 1: PROMPT ENGINEERING — Desambiguación Semántica Jurídica
# ===================================================================

def build_disambiguation_prompt(text: str, context: str) -> str:
    """
    Construye el Prompt que se inyecta en Bedrock para que el modelo
    fundacional realice la desambiguación semántica y la reestructuración
    gramatical de Español (SVO) a LSB (OSV).
    """

    # Lista de glosas disponibles para que la IA solo use términos válidos
    gloss_list = ", ".join(sorted(AVAILABLE_GLOSSES))

    context_instruction = ""
    if context == "legal":
        context_instruction = """
REGLAS DE DESAMBIGUACIÓN JURÍDICA Y SEÑAS COMPUESTAS:
- "Auto" = Resolución judicial (NO vehículo), salvo contexto de tránsito.
- "Fallo" = Sentencia o resolución judicial (NO error).
- "Causa" = Expediente o proceso judicial, NO razón.
- "Cargo" = Acusación formal, NO puesto de trabajo.
- REGLA DE SEÑA COMPUESTA: Algunas palabras en LSB se forman fusionando señas base. Si la palabra requiere una seña compuesta (por ejemplo, "Fiscal"), debes descomponerla en el arreglo usando las glosas base correspondientes. Ej: Para "Fiscal", devuelve ["F", "JUEZ"]. Para otras palabras compuestas, aplica el mismo principio lógico si conoces su estructura en LSB.
"""

    prompt = f"""Eres un sistema experto en Lengua de Señas Boliviana (LSB) para entornos judiciales.

Tu tarea es recibir una frase en español y convertirla en un ARREGLO ORDENADO DE GLOSAS LSB.

REGLAS LINGÜÍSTICAS OBLIGATORIAS:
1. La LSB usa estructura OSV (Objeto-Sujeto-Verbo). Reordena la frase.
2. Elimina artículos (el, la, los, las, un, una), preposiciones (de, en, por, para, con) y conjunciones innecesarias.
3. Los marcadores temporales (HOY, AYER) van AL INICIO del arreglo.
4. Usa solo verbos en INFINITIVO como glosa (DENUNCIAR, no "denunció").
5. Desambigua términos polisémicos y descompón palabras en SEÑAS COMPUESTAS si es lingüísticamente correcto en LSB.
6. Cada glosa debe ser UNA SOLA PALABRA o un término compuesto con guión (POR-QUÉ).
{context_instruction}

GLOSAS DISPONIBLES EN EL DICCIONARIO DEL AVATAR:
[{gloss_list}]

Si una palabra NO tiene equivalente en la lista, usa la palabra más cercana disponible.
Si no hay equivalente posible, incluye la palabra original en MAYÚSCULAS (el sistema usará dactilología).

FORMATO DE RESPUESTA (JSON estricto, sin explicaciones):
{{"glosses": ["GLOSA1", "GLOSA2", "GLOSA3"], "disambiguation": [{{"original": "palabra_ambigua", "meaning": "significado_elegido", "reason": "justificación_breve"}}]}}

FRASE A TRADUCIR: "{text}"
CONTEXTO: {context}"""

    return prompt


# ===================================================================
# MÓDULO 2: INVOCACIÓN DE AMAZON BEDROCK
# ===================================================================

def invoke_bedrock(prompt: str) -> dict:
    """
    Envía el prompt al modelo fundacional en Bedrock y parsea la respuesta.
    Utiliza la API 'converse', que soporta automáticamente cualquier modelo
    (Nova, Titan, Claude) sin preocuparnos por el formato del JSON interno.
    """
    logger.info("Invocando Bedrock con modelo: %s", BEDROCK_MODEL_ID)

    try:
        response = bedrock_runtime.converse(
            modelId=BEDROCK_MODEL_ID,
            messages=[
                {
                    "role": "user",
                    "content": [{"text": prompt}],
                }
            ],
            inferenceConfig={
                "maxTokens": 512,
                "temperature": 0.1,
            }
        )
    except Exception as e:
        logger.error("Error en converse API: %s", str(e))
        raise

    # La API converse estandariza la respuesta, siempre está en este formato:
    raw_text = response["output"]["message"]["content"][0]["text"].strip()

    logger.info("Respuesta cruda de Bedrock: %s", raw_text[:200])

    # Parsear el JSON embebido en la respuesta
    return parse_bedrock_json(raw_text)


def parse_bedrock_json(raw_text: str) -> dict:
    """
    Extrae el objeto JSON de la respuesta de Bedrock.
    Maneja casos donde el modelo envuelve el JSON en texto adicional.
    """
    # Intentar parsear directamente
    try:
        return json.loads(raw_text)
    except json.JSONDecodeError:
        pass

    # Buscar JSON embebido entre llaves
    match = re.search(r'\{[\s\S]*\}', raw_text)
    if match:
        try:
            return json.loads(match.group())
        except json.JSONDecodeError:
            pass

    # Fallback: devolver estructura mínima
    logger.warning("No se pudo parsear JSON de Bedrock, usando fallback")
    return {"glosses": [], "disambiguation": []}


# ===================================================================
# MÓDULO 3: POST-PROCESAMIENTO DE GLOSAS
# ===================================================================

def remove_accents(text: str) -> str:
    accents = {
        'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
        'Ü': 'U', 'Ñ': 'N'
    }
    for accented_char, unaccented_char in accents.items():
        text = text.replace(accented_char, unaccented_char)
    return text

def post_process_glosses(bedrock_result: dict) -> dict:
    """
    Valida las glosas retornadas por Bedrock contra el diccionario
    del avatar y marca cuáles requieren dactilología.
    """
    raw_glosses = bedrock_result.get("glosses", [])
    disambiguation = bedrock_result.get("disambiguation", [])

    processed = []
    for gloss in raw_glosses:
        gloss_upper = gloss.upper().strip()
        is_available = gloss_upper in AVAILABLE_GLOSSES
        
        filename = remove_accents(gloss_upper)

        processed.append({
            "gloss": gloss_upper,
            "available": is_available,
            "fallback": "dactilología" if not is_available else None,
            "animationFile": f"{filename}.glb" if is_available else None,
        })

    return {
        "glosses": [g["gloss"] for g in processed],
        "glossDetails": processed,
        "disambiguation": disambiguation,
        "totalGlosses": len(processed),
        "availableInAvatar": sum(1 for g in processed if g["available"]),
        "requiresDactylology": sum(1 for g in processed if not g["available"]),
    }


# ===================================================================
# MÓDULO 4: UTILIDADES
# ===================================================================

def build_response(status_code: int, body: dict) -> dict:
    """Construye la respuesta compatible con API Gateway Proxy Integration."""
    return {
        "statusCode": status_code,
        "headers": CORS_HEADERS,
        "body": json.dumps(body, ensure_ascii=False),
    }


def generate_cache_key(text: str) -> str:
    """Genera un hash MD5 determinista de la frase normalizada."""
    normalized = text.lower().strip()
    normalized = re.sub(r'\s+', ' ', normalized)
    return hashlib.md5(normalized.encode("utf-8")).hexdigest()


def validate_request(body: dict) -> tuple:
    """Valida los campos obligatorios del JSON de entrada."""
    if not isinstance(body, dict):
        return False, "El cuerpo debe ser un objeto JSON válido."

    text = body.get("text")
    if not text or not isinstance(text, str) or not text.strip():
        return False, "El campo 'text' es obligatorio y no puede estar vacío."

    if len(text.strip()) > 1000:
        return False, "El texto no puede exceder los 1000 caracteres."

    return True, None


# ===================================================================
# HANDLER PRINCIPAL — Punto de entrada de AWS Lambda
# ===================================================================

def lambda_handler(event, context):
    """
    Punto de entrada de la función Lambda.
    Recibe una petición HTTP POST con:
      { "text": "frase en español", "context": "legal" }
    Retorna:
      { "glosses": [...], "glossDetails": [...], "disambiguation": [...] }
    """

    # 0. Manejar preflight CORS
    http_method = event.get(
        "httpMethod",
        event.get("requestContext", {}).get("http", {}).get("method", "POST"),
    )
    if http_method == "OPTIONS":
        return build_response(200, {"message": "CORS preflight OK"})

    request_id = ""
    if context and hasattr(context, "aws_request_id"):
        request_id = context.aws_request_id
    logger.info("=== Nueva solicitud — request_id: %s ===", request_id)

    # 1. Parsear el body del evento
    try:
        raw_body = event.get("body", "{}")
        body = json.loads(raw_body) if isinstance(raw_body, str) else (raw_body or {})
    except (json.JSONDecodeError, TypeError):
        return build_response(400, {
            "error": "JSON_PARSE_ERROR",
            "message": "El JSON de la solicitud es inválido.",
        })

    # 2. Validar campos obligatorios
    is_valid, err_msg = validate_request(body)
    if not is_valid:
        return build_response(400, {
            "error": "VALIDATION_ERROR",
            "message": err_msg,
        })

    text = body["text"].strip()
    context_type = body.get("context", "legal").strip().lower()
    cache_key = generate_cache_key(text)

    logger.info("Texto recibido: '%s' | Contexto: %s | Hash: %s", text, context_type, cache_key)

    # 3. (FUTURO) Verificar caché en DynamoDB
    # cached = check_dynamodb_cache(cache_key)
    # if cached:
    #     logger.info("Cache HIT — devolviendo resultado precalculado")
    #     return build_response(200, {**cached, "cacheHit": True})

    # 4. Construir el Prompt de desambiguación semántica
    prompt = build_disambiguation_prompt(text, context_type)
    logger.info("Prompt construido (%d caracteres)", len(prompt))

    # 5. Invocar Amazon Bedrock
    try:
        bedrock_result = invoke_bedrock(prompt)
    except ClientError as e:
        error_code = e.response["Error"]["Code"]
        logger.error("Error de Bedrock [%s]: %s", error_code, str(e))
        return build_response(500, {
            "error": "BEDROCK_ERROR",
            "message": f"Error al invocar el modelo de IA: {error_code}",
        })
    except Exception as e:
        logger.error("Error inesperado invocando Bedrock: %s", str(e), exc_info=True)
        return build_response(500, {
            "error": "BEDROCK_ERROR",
            "message": "Error interno del motor de Procesamiento de Lenguaje Natural.",
        })

    # 6. Post-procesar las glosas
    result = post_process_glosses(bedrock_result)

    # 7. (FUTURO) Guardar en caché DynamoDB
    # save_to_dynamodb_cache(cache_key, result)

    # 8. Respuesta exitosa
    logger.info(
        "Traducción completada — %d glosas, %d disponibles en avatar",
        result["totalGlosses"],
        result["availableInAvatar"],
    )

    return build_response(200, {
        "originalText": text,
        "context": context_type,
        "cacheHit": False,
        "cacheKey": cache_key,
        **result,
    })
