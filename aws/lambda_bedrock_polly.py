"""
Lambda: lsb-to-text-audio
Módulo OpenSoul — Traducción de glosas LSB → texto formal → audio

Flujo:
  1. Recibe JSON con `cards` (glosas LSB) y `context` (semántico)
  2. Construye prompt few-shot en español
  3. Invoca Amazon Bedrock (modelo Transformer fundacional)
  4. Sintetiza audio con Amazon Polly
  5. Almacena MP3 en Amazon S3
  6. Retorna JSON compatible con Lambda Proxy Integration

Autor: Nathanael Alba — Proyecto de Grado OpenSoul
"""

import json
import os
import hashlib
import logging
from datetime import datetime

import boto3
from botocore.exceptions import ClientError

# ---------------------------------------------------------------------------
# Logging estructurado
# ---------------------------------------------------------------------------
logger = logging.getLogger("lsb-to-text-audio")
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------------------
# Variables de entorno
# ---------------------------------------------------------------------------
S3_BUCKET = os.environ.get("S3_BUCKET", "opensoul-lsb-audio-dev")
APP_PREFIX = os.environ.get("APP_PREFIX", "lsb-to-text-audio")
VOICE_ID = os.environ.get("VOICE_ID", "Lupe")
BEDROCK_MODEL_ID = os.environ.get(
    "BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0"
)
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

# ---------------------------------------------------------------------------
# Clientes AWS — inicializados en cold-start para reutilización
# ---------------------------------------------------------------------------
bedrock_runtime = boto3.client("bedrock-runtime", region_name=AWS_REGION)
polly_client = boto3.client("polly", region_name=AWS_REGION)
s3_client = boto3.client("s3", region_name=AWS_REGION)

# ---------------------------------------------------------------------------
# Headers CORS reutilizables
# ---------------------------------------------------------------------------
CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Content-Type": "application/json",
}


# ===================================================================
# FUNCIONES AUXILIARES
# ===================================================================


def build_response(status_code: int, body: dict) -> dict:
    """
    Construye una respuesta compatible con API Gateway Lambda Proxy Integration.
    Incluye headers CORS en todas las respuestas.
    """
    return {
        "statusCode": status_code,
        "headers": CORS_HEADERS,
        "body": json.dumps(body, ensure_ascii=False),
    }


def generate_cache_key(context_type: str, cards: list) -> str:
    """
    Genera un hash determinista MD5 a partir de context + cards.
    Esto permite identificar solicitudes idénticas para futura implementación
    de caché con DynamoDB.
    """
    normalized = f"{context_type.lower().strip()}|{'|'.join(c.upper().strip() for c in cards)}"
    return hashlib.md5(normalized.encode("utf-8")).hexdigest()


def build_prompt(cards: list, context_type: str) -> str:
    """
    Construye el prompt few-shot en español para el modelo Bedrock.

    Estrategia:
      - Rol del sistema: traductor LSB experto en contexto jurídico
      - Ejemplos few-shot con pares entrada/salida reales
      - Instrucciones explícitas de formato y estilo
      - Entrada del usuario al final
    """
    # Instrucción base según el contexto
    if context_type.lower() == "legal":
        context_instruction = (
            "El contexto es JURÍDICO/ADMINISTRATIVO. Usa vocabulario formal, "
            "preciso y apropiado para declaraciones ante autoridades policiales "
            "o judiciales en Bolivia."
        )
    else:
        context_instruction = (
            "El contexto es GENERAL. Usa español neutro, claro y correcto "
            "gramaticalmente."
        )

    gloss_input = " ".join(cards)

    prompt = f"""Eres un traductor profesional especializado en Lengua de Señas Boliviana (LSB).
Tu tarea es convertir secuencias de glosas LSB en oraciones formales, coherentes y gramaticalmente correctas en español.

{context_instruction}

REGLAS ESTRICTAS:
1. Devuelve ÚNICAMENTE la oración traducida, sin explicaciones, introducciones ni comentarios.
2. No inventes hechos, personas ni circunstancias que no estén representados en las glosas.
3. Reorganiza las glosas en orden gramatical natural del español.
4. Mantén la precisión semántica de cada glosa.
5. Usa redacción breve, directa y en primera persona cuando corresponda.
6. Si el contexto es legal, emplea vocabulario jurídico formal.

EJEMPLOS:

Entrada LSB: YO DENUNCIAR ROBO
Salida: Deseo denunciar un robo.

Entrada LSB: YO MOCHILA HOMBRE QUITAR CORRER
Salida: Un hombre me quitó la mochila y huyó corriendo.

Entrada LSB: YO AYUDA NECESITAR POLICIA
Salida: Necesito ayuda y requiero asistencia policial.

Entrada LSB: DOCUMENTO PERDER YO TRAMITE NECESITAR
Salida: He perdido mi documento y necesito realizar un trámite.

Entrada LSB: HIJO ENFERMO HOSPITAL NECESITAR URGENTE
Salida: Mi hijo está enfermo y necesita atención hospitalaria urgente.

Entrada LSB: YO AGRESOR DESCRIBIR ALTO JOVEN
Salida: Deseo describir al agresor: es un hombre alto y joven.

Ahora traduce la siguiente entrada:

Entrada LSB: {gloss_input}
Salida:"""

    return prompt


def generate_text_with_bedrock(cards: list, context_type: str) -> str:
    """
    Invoca Amazon Bedrock con el prompt few-shot construido.

    Soporta la API de mensajes de Anthropic Claude (Messages API).
    El diseño permite cambiar de modelo modificando solo la variable de
    entorno BEDROCK_MODEL_ID y, si fuera necesario, la función
    _parse_bedrock_response.
    """
    prompt_text = build_prompt(cards, context_type)

    # ------------------------------------------------------------------
    # Construir el payload según el modelo
    # ------------------------------------------------------------------
    request_body = _build_bedrock_request_body(prompt_text)

    logger.info(
        "Invocando Bedrock",
        extra={
            "model_id": BEDROCK_MODEL_ID,
            "cards_count": len(cards),
            "context": context_type,
        },
    )

    response = bedrock_runtime.invoke_model(
        modelId=BEDROCK_MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(request_body),
    )

    response_body = json.loads(response["body"].read())
    generated_text = _parse_bedrock_response(response_body)

    logger.info("Texto generado por Bedrock: %s", generated_text)
    return generated_text


def _build_bedrock_request_body(prompt_text: str) -> dict:
    """
    Construye el body del request a Bedrock según el modelo configurado.

    Actualmente soporta:
      - Anthropic Claude (Messages API): claude-3-*, claude-v2, etc.
      - Amazon Titan Text
      - Meta Llama 3

    Para agregar otro modelo, basta añadir un nuevo bloque elif.
    """
    model_id_lower = BEDROCK_MODEL_ID.lower()

    if "anthropic" in model_id_lower or "claude" in model_id_lower:
        return {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 256,
            "temperature": 0.2,
            "top_p": 0.9,
            "messages": [
                {
                    "role": "user",
                    "content": prompt_text,
                }
            ],
        }
    elif "titan" in model_id_lower:
        return {
            "inputText": prompt_text,
            "textGenerationConfig": {
                "maxTokenCount": 256,
                "temperature": 0.2,
                "topP": 0.9,
                "stopSequences": [],
            },
        }
    elif "llama" in model_id_lower or "meta" in model_id_lower:
        return {
            "prompt": prompt_text,
            "max_gen_len": 256,
            "temperature": 0.2,
            "top_p": 0.9,
        }
    else:
        # Fallback: formato Anthropic Messages API
        logger.warning(
            "Modelo no reconocido (%s), usando formato Anthropic por defecto.",
            BEDROCK_MODEL_ID,
        )
        return {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 256,
            "temperature": 0.2,
            "top_p": 0.9,
            "messages": [{"role": "user", "content": prompt_text}],
        }


def _parse_bedrock_response(response_body: dict) -> str:
    """
    Extrae el texto generado del response de Bedrock según el modelo.

    Soporta:
      - Anthropic Claude: response_body["content"][0]["text"]
      - Amazon Titan: response_body["results"][0]["outputText"]
      - Meta Llama: response_body["generation"]
    """
    # Anthropic Claude
    if "content" in response_body and isinstance(response_body["content"], list):
        raw = response_body["content"][0].get("text", "").strip()
        return _clean_generated_text(raw)

    # Amazon Titan
    if "results" in response_body and isinstance(response_body["results"], list):
        raw = response_body["results"][0].get("outputText", "").strip()
        return _clean_generated_text(raw)

    # Meta Llama
    if "generation" in response_body:
        raw = response_body["generation"].strip()
        return _clean_generated_text(raw)

    logger.error("Estructura de respuesta Bedrock no reconocida: %s", response_body)
    raise ValueError("No se pudo extraer texto de la respuesta de Bedrock.")


def _clean_generated_text(text: str) -> str:
    """
    Limpia el texto generado por el modelo:
    - Elimina saltos de línea innecesarios
    - Toma solo la primera línea significativa (evita explicaciones extra)
    - Elimina prefijos comunes del modelo como "Salida:" o comillas
    """
    # Tomar solo la primera línea no vacía
    lines = [line.strip() for line in text.split("\n") if line.strip()]
    if not lines:
        return text.strip()

    result = lines[0]

    # Eliminar prefijos comunes que el modelo podría añadir
    prefixes_to_remove = ["Salida:", "Salida :", "Respuesta:", "Traducción:"]
    for prefix in prefixes_to_remove:
        if result.lower().startswith(prefix.lower()):
            result = result[len(prefix) :].strip()

    # Eliminar comillas envolventes si existen
    if (result.startswith('"') and result.endswith('"')) or (
        result.startswith("«") and result.endswith("»")
    ):
        result = result[1:-1].strip()

    return result


def synthesize_audio(text: str) -> bytes:
    """
    Sintetiza audio en español usando Amazon Polly.

    Usa el engine 'neural' para calidad superior y la voz configurada
    por variable de entorno (por defecto 'Lupe', español latinoamericano).
    """
    logger.info("Sintetizando audio con Polly — Voz: %s", VOICE_ID)

    response = polly_client.synthesize_speech(
        Text=text,
        OutputFormat="mp3",
        VoiceId=VOICE_ID,
        Engine="neural",
        LanguageCode="es-US",
    )

    audio_bytes = response["AudioStream"].read()
    logger.info("Audio sintetizado: %d bytes", len(audio_bytes))
    return audio_bytes


def upload_audio_to_s3(audio_bytes: bytes, cache_key: str) -> str:
    """
    Sube el archivo MP3 a S3 bajo el prefijo del módulo lsb-to-text-audio.

    Retorna la URL pública del objeto (requiere que el bucket permita
    acceso público o se use presigned URLs — configurable luego).
    """
    s3_key = f"{APP_PREFIX}/{cache_key}.mp3"

    logger.info("Subiendo audio a S3 — Bucket: %s, Key: %s", S3_BUCKET, s3_key)

    s3_client.put_object(
        Bucket=S3_BUCKET,
        Key=s3_key,
        Body=audio_bytes,
        ContentType="audio/mpeg",
    )

    # Generar URL del objeto
    audio_url = f"https://{S3_BUCKET}.s3.{AWS_REGION}.amazonaws.com/{s3_key}"

    logger.info("Audio disponible en: %s", audio_url)
    return audio_url


def validate_request(body: dict) -> tuple:
    """
    Valida la estructura del request body.
    Retorna (is_valid: bool, error_message: str | None).
    """
    if not isinstance(body, dict):
        return False, "El cuerpo de la solicitud debe ser un objeto JSON válido."

    cards = body.get("cards")

    if cards is None:
        return False, "El campo 'cards' es obligatorio."

    if not isinstance(cards, list):
        return False, "El campo 'cards' debe ser una lista de glosas."

    if len(cards) == 0:
        return False, "El campo 'cards' no puede estar vacío."

    # Validar que cada card sea un string no vacío
    for i, card in enumerate(cards):
        if not isinstance(card, str) or not card.strip():
            return False, f"La glosa en posición {i} no es válida."

    return True, None


# ===================================================================
# HANDLER PRINCIPAL
# ===================================================================


def lambda_handler(event, context):
    """
    Handler principal de la Lambda — lsb-to-text-audio.

    Compatible con API Gateway Lambda Proxy Integration.
    Soporta preflight CORS (OPTIONS) y procesamiento POST.
    """
    # ------------------------------------------------------------------
    # Preflight CORS
    # ------------------------------------------------------------------
    http_method = event.get("httpMethod", "POST")
    if http_method == "OPTIONS":
        return build_response(200, {"message": "CORS preflight OK"})

    request_id = ""
    if context and hasattr(context, "aws_request_id"):
        request_id = context.aws_request_id

    logger.info(
        "Solicitud recibida — request_id: %s, method: %s",
        request_id,
        http_method,
    )

    # ------------------------------------------------------------------
    # 1. Parsear y validar entrada
    # ------------------------------------------------------------------
    try:
        raw_body = event.get("body", "{}")
        if isinstance(raw_body, str):
            body = json.loads(raw_body)
        else:
            body = raw_body if raw_body else {}
    except (json.JSONDecodeError, TypeError) as e:
        logger.warning("JSON inválido en el body: %s", str(e))
        return build_response(400, {
            "error": "JSON_PARSE_ERROR",
            "message": "El cuerpo de la solicitud no es un JSON válido.",
        })

    is_valid, validation_error = validate_request(body)
    if not is_valid:
        logger.warning("Validación fallida: %s", validation_error)
        return build_response(400, {
            "error": "VALIDATION_ERROR",
            "message": validation_error,
        })

    cards = [card.strip().upper() for card in body["cards"]]
    context_type = body.get("context", "general").strip().lower()
    cache_key = generate_cache_key(context_type, cards)

    logger.info(
        "Procesando — cards: %s, context: %s, cache_key: %s",
        cards,
        context_type,
        cache_key,
    )

    # ------------------------------------------------------------------
    # 2. [FUTURO] Verificar caché en DynamoDB
    # ------------------------------------------------------------------
    # TODO: Implementar consulta a DynamoDB para verificar si cache_key
    #       ya tiene una traducción almacenada. Si existe, retornar
    #       directamente con cacheHit=True.
    #
    # Ejemplo futuro:
    # cached = check_dynamodb_cache(cache_key)
    # if cached:
    #     return build_response(200, {
    #         "generatedText": cached["generatedText"],
    #         "audioUrl": cached["audioUrl"],
    #         "cacheHit": True,
    #     })

    # ------------------------------------------------------------------
    # 3. Generar texto formal con Amazon Bedrock
    # ------------------------------------------------------------------
    try:
        generated_text = generate_text_with_bedrock(cards, context_type)
    except ClientError as e:
        error_code = e.response["Error"]["Code"]
        logger.error(
            "Error de Bedrock [%s]: %s",
            error_code,
            str(e),
            exc_info=True,
        )
        return build_response(500, {
            "error": "BEDROCK_ERROR",
            "message": "Error al generar texto con el modelo de lenguaje. Intente nuevamente.",
        })
    except Exception as e:
        logger.error("Error inesperado en Bedrock: %s", str(e), exc_info=True)
        return build_response(500, {
            "error": "BEDROCK_ERROR",
            "message": "Error interno al procesar la traducción.",
        })

    # ------------------------------------------------------------------
    # 4. Sintetizar audio con Amazon Polly
    # ------------------------------------------------------------------
    try:
        audio_bytes = synthesize_audio(generated_text)
    except ClientError as e:
        logger.error("Error de Polly: %s", str(e), exc_info=True)
        return build_response(500, {
            "error": "POLLY_ERROR",
            "message": "Error al sintetizar el audio. Intente nuevamente.",
        })
    except Exception as e:
        logger.error("Error inesperado en Polly: %s", str(e), exc_info=True)
        return build_response(500, {
            "error": "POLLY_ERROR",
            "message": "Error interno en la síntesis de voz.",
        })

    # ------------------------------------------------------------------
    # 5. Subir audio a Amazon S3
    # ------------------------------------------------------------------
    try:
        audio_url = upload_audio_to_s3(audio_bytes, cache_key)
    except ClientError as e:
        logger.error("Error de S3: %s", str(e), exc_info=True)
        return build_response(500, {
            "error": "S3_ERROR",
            "message": "Error al almacenar el archivo de audio. Intente nuevamente.",
        })
    except Exception as e:
        logger.error("Error inesperado en S3: %s", str(e), exc_info=True)
        return build_response(500, {
            "error": "S3_ERROR",
            "message": "Error interno al guardar el audio.",
        })

    # ------------------------------------------------------------------
    # 6. [FUTURO] Guardar en caché DynamoDB
    # ------------------------------------------------------------------
    # TODO: Guardar la traducción y URL de audio en DynamoDB para
    #       evitar re-procesamiento de solicitudes idénticas.
    #
    # Ejemplo futuro:
    # save_to_dynamodb_cache(cache_key, generated_text, audio_url)

    # ------------------------------------------------------------------
    # 7. Respuesta exitosa
    # ------------------------------------------------------------------
    logger.info(
        "Solicitud completada exitosamente — cache_key: %s, text_length: %d",
        cache_key,
        len(generated_text),
    )

    return build_response(200, {
        "generatedText": generated_text,
        "audioUrl": audio_url,
        "cacheHit": False,
    })
