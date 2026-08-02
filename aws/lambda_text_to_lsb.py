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
# Tabla del diccionario evolutivo (Fase 2). Si está definida, las glosas
# disponibles para el avatar se leen de DynamoDB (nuevas señas aprobadas en
# el portal quedan disponibles SIN redesplegar esta lambda). Vacía = solo
# el set estático de fallback.
DICTIONARY_TABLE = os.environ.get("DICTIONARY_TABLE", "")

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
    # --- Sustantivos Jurídicos Disponibles (Módulo Isaac) ---
    "ABOGADO", "POLICIA", "JUEZ", 
    
    # --- Pronombres y Posesivos Disponibles ---
    "YO", "TU", "EL", "ELLA", "NOSOTROS", "ELLOS", "ELLAS", "USTEDES", "MIO", "TUYO", "SUYO", "NUESTRO",
    
    # --- Alfabeto Dactilológico y Números (Para dactilología offline/fallback) ---
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
}

# Caché de proceso del mapa glosa → archivo de animación (warm starts).
_avatar_animations_cache = None


def get_avatar_animations() -> dict:
    """Mapa glosa → animationFile disponible para el avatar 3D.

    Fuente única (Fase 2): tabla del diccionario evolutivo en DynamoDB,
    donde cada ENTRY aprobada puede declarar su `animationFile`. El set
    estático AVAILABLE_GLOSSES queda como base garantizada (alfabeto
    dactilológico, números y señas fundacionales) y como fallback total
    si la tabla no está configurada o falla la consulta.
    """
    global _avatar_animations_cache
    if _avatar_animations_cache is not None:
        return _avatar_animations_cache

    animations = {g: f"{remove_accents(g)}.glb" for g in AVAILABLE_GLOSSES}

    if DICTIONARY_TABLE:
        try:
            from boto3.dynamodb.conditions import Key

            table = boto3.resource(
                "dynamodb", region_name=APP_REGION
            ).Table(DICTIONARY_TABLE)
            kwargs = {"KeyConditionExpression": Key("pk").eq("ENTRY")}
            while True:
                resp = table.query(**kwargs)
                for item in resp.get("Items", []):
                    if item.get("status") == "pending":
                        continue
                    animation = item.get("animationFile")
                    if animation:
                        animations[str(item["gloss"]).upper()] = str(animation)
                last = resp.get("LastEvaluatedKey")
                if not last:
                    break
                kwargs["ExclusiveStartKey"] = last
            logger.info(
                "Diccionario dinámico cargado: %d glosas con animación",
                len(animations),
            )
        except Exception as exc:  # noqa: BLE001 — nunca romper la traducción
            logger.warning("Fallo leyendo diccionario dinámico: %s", exc)

    _avatar_animations_cache = animations
    return animations


# ===================================================================
# MÓDULO 1: PROMPT ENGINEERING — Desambiguación Semántica Jurídica
# ===================================================================

LEGAL_DISAMBIGUATION_RULES = """
REGLAS DE DESAMBIGUACIÓN JURÍDICA Y PALABRAS POLISÉMICAS:
- "llama" (Verbo llamar / notificar): Se interpreta como la acción de convocar, citar o pedir presencia. Mapear a la glosa "LLAMAR".
  * Ejemplo: "Yo llamo al policía." -> ["YO", "POLICIA", "LLAMAR"]
- "llama" (Animal / Camélido): Objeto de propiedad o conflicto civil de ganadería. Mapear a la glosa "ANIMAL-LLAMA".
  * Ejemplo: "La llama es de ustedes." -> ["USTEDES", "ANIMAL-LLAMA"]
- "llama" (Fuego / Incendio): Elemento en caso de daños o peritajes. Mapear a la glosa "FUEGO-LLAMA".
  * Ejemplo: "El juez mira la llama." -> ["JUEZ", "FUEGO-LLAMA", "VER"] (Nota: la palabra "VER" no está en el diccionario, se deletreará).
"""

# Situaciones reconocidas de la conversación, con la etiqueta legible que se
# inyecta en el prompt. Deben coincidir con los contextos del catálogo de la
# app (`context_catalog.dart`) y con los `contexts` del diccionario.
SITUATION_LABELS = {
    "denuncia_robo": "denuncia de robo, hurto o asalto",
    "violencia": "denuncia de violencia o agresión",
    "accidente": "reporte de un accidente",
    "orientacion": "consulta de orientación o trámite legal",
    "tramite_id": "trámite de documentos de identidad",
    "perdida": "pérdida o extravío de objetos o documentos",
    "emergencia": "situación de emergencia",
    "otro": "declaración general",
}


def build_disambiguation_prompt(text: str, context: str = "legal", situation: str = None) -> str:
    """
    Construye el Prompt que se inyecta en Bedrock para que el modelo
    fundacional realice la desambiguación semántica y la reestructuración
    gramatical de Español (SVO) a LSB (OSV / SOV).

    [situation] es el contexto situacional vigente en la conversación
    ('denuncia_robo', 'violencia'…). Cuando llega, orienta al modelo hacia el
    vocabulario propio de esa situación. Es opcional: sin él, el prompt es
    exactamente el de siempre.
    """

    # Lista de glosas disponibles para que la IA solo use términos válidos
    # (incluye las señas nuevas aprobadas en el diccionario evolutivo).
    gloss_list = ", ".join(sorted(get_avatar_animations()))

    # Las reglas de desambiguación jurídica son el núcleo de este sistema y se
    # aplican en todo el dominio legal —que es el único de la aplicación—.
    # Antes se exigía `context == "legal"` exacto, de modo que cualquier otra
    # etiqueta las eliminaba en silencio y "llama" volvía a ser ambigua.
    context_instruction = "" if context == "general" else LEGAL_DISAMBIGUATION_RULES

    situation_instruction = ""
    if situation and situation in SITUATION_LABELS:
        situation_instruction = f"""
SITUACIÓN DE LA CONVERSACIÓN: {SITUATION_LABELS[situation]}.
La frase forma parte de un diálogo sobre esa situación. Ante dos glosas
igualmente válidas, prefiere la propia de este ámbito. No inventes contenido
que la frase no diga: la situación orienta el vocabulario, no lo añade.
"""

    prompt = f"""Eres un sistema experto en Lengua de Señas Boliviana (LSB) para entornos judiciales y de trámites.
{situation_instruction}

Tu tarea es recibir una frase en español y convertirla en un ARREGLO ORDENADO DE GLOSAS LSB.

REGLAS LINGÜÍSTICAS Y GRAMATICALES OBLIGATORIAS DE LSB:
1. ESTRUCTURA GRAMATICAL:
   - Usa estructura OSV (Objeto-Sujeto-Verbo) o SOV para las oraciones.
   - Para frases de identidad o profesión (Sujeto + Oficio), el orden obligatorio es SUJETO luego OFICIO (Ej: "Yo soy abogado" -> ["YO", "ABOGADO"], "Ellos son policías" -> ["ELLOS", "POLICIA"]). NO uses verbos auxiliares de ser/estar.

2. MANEJO EXACTO DE PRONOMBRES Y POSESIVOS EN LSB:
   - Pronombres Personales: "yo" -> "YO", "tú" -> "TU", "él/ella" -> "EL"/"ELLA", "nosotros" -> "NOSOTROS", "ellos/ellas" -> "ELLOS"/"ELLAS", "ustedes" -> "USTEDES".
   - Pronombres/Adjetivos Posesivos: "mi/mío" -> "MIO", "tu/tuyo" -> "TUYO", "su/suyo" -> "SUYO", "nuestro" -> "NUESTRO". ¡No los confundas con los personales!

3. SIMPLIFICACIÓN:
   - Elimina totalmente artículos (el, la, los, las, un, una), preposiciones (de, en, por, para, con, a) y conjunciones innecesarias.
   - Los verbos deben ir en INFINITIVO (Ej: "llamó" -> "LLAMAR", "miró" -> "VER").

4. REGLAS DE DESAMBIGUACIÓN DE "LLAMA":
{context_instruction}

5. REGLAS DACTILOLÓGICAS (DELETREO COMPLETO) EN LSB:
   - Los nombres propios de personas, apellidos, calles, marcas y siglas (ej: "Isaac", "Segip", "FELCC") deben deletrearse obligatoriamente letra por letra. Descomponlos en sus letras individuales en la lista de glosas (ej: "Isaac" -> ["I", "S", "A", "A", "C"], "Segip" -> ["S", "E", "G", "I", "P"]).
   - Los sustantivos comunes y verbos que NO estén en la lista de glosas disponibles (ej: "testigo", "discriminación") NO deben deletrearse letra por letra. Deben ser colocados como la palabra completa en mayúsculas en la lista de glosas (ej: "TESTIGO", "DISCRIMINACION") para mostrar la simulación en la interfaz.

6. MANEJO DE TIEMPOS VERBALES (PASADO, PRESENTE, FUTURO) EN LSB:
   - En LSB los verbos no se conjugan; se escriben siempre en INFINITIVO (ej: "llamé" / "llame" -> "LLAMAR", "comí" -> "COMER", "iré" -> "IR").
   - El tiempo de la oración se debe indicar agregando un MARCADOR TEMPORAL al inicio de la frase LSB:
     * Tiempo Pasado: Si la acción ocurrió en el pasado (ej. "llamé", "llamó", "llame" en contexto pasado), agrega obligatoriamente la glosa general "PASADO" (o "AYER"/"ANTES" si se menciona explícitamente) al inicio de la frase LSB.
       Ejemplo: "Yo llamé al policía" o "Yo llame al policía" (pasado) -> ["PASADO", "YO", "POLICIA", "LLAMAR"]
       Ejemplo: "Ayer yo llamé al policía" -> ["AYER", "YO", "POLICIA", "LLAMAR"]
     * Tiempo Futuro: Si la acción ocurrirá en el futuro (ej. "llamaré", "llamará"), agrega obligatoriamente la glosa general "FUTURO" (o "MAÑANA"/"DESPUES" si se menciona explícitamente) al inicio de la frase LSB.
       Ejemplo: "Yo llamaré al policía" -> ["FUTURO", "YO", "POLICIA", "LLAMAR"]
     * Tiempo Presente: Si la acción ocurre en el presente (ej. "llamo", "llama" actual), se puede agregar la glosa "AHORA" o "HOY" al inicio si es necesario para enfatizar el tiempo.
       Ejemplo: "Yo llamo al policía" -> ["AHORA", "YO", "POLICIA", "LLAMAR"]

GLOSAS DISPONIBLES EN EL DICCIONARIO DEL AVATAR:
[{gloss_list}]

FORMATO DE RESPUESTA (JSON estricto, sin explicaciones ni markdown fuera del bloque JSON):
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

    animations = get_avatar_animations()

    processed = []
    for gloss in raw_glosses:
        gloss_upper = gloss.upper().strip()
        animation_file = animations.get(gloss_upper)
        is_available = animation_file is not None

        processed.append({
            "gloss": gloss_upper,
            "available": is_available,
            "fallback": "dactilología" if not is_available else None,
            "animationFile": animation_file,
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


def generate_cache_key(text: str, situation: str = None) -> str:
    """
    Genera un hash MD5 determinista de la frase normalizada.

    La situación forma parte de la clave porque forma parte del resultado:
    la misma frase traducida bajo 'denuncia_robo' y bajo 'violencia' puede
    producir glosas distintas, y servir una por la otra desde el caché sería
    devolver la traducción de otra conversación.
    """
    normalized = text.lower().strip()
    normalized = re.sub(r'\s+', ' ', normalized)
    if situation:
        normalized = f"{normalized}|{situation}"
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
      { "text": "frase en español", "context": "legal",
        "situation": "denuncia_robo" }   # situation es opcional
    Retorna:
      { "glosses": [...], "glossDetails": [...], "disambiguation": [...],
        "situation": "denuncia_robo" }
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
    # Contexto situacional de la conversación. Opcional y validado: una
    # etiqueta desconocida se ignora en lugar de contaminar el prompt.
    situation = (body.get("situation") or "").strip().lower() or None
    if situation and situation not in SITUATION_LABELS:
        logger.warning("Situación desconocida ignorada: %s", situation)
        situation = None
    cache_key = generate_cache_key(text, situation)

    logger.info(
        "Texto recibido: '%s' | Contexto: %s | Situación: %s | Hash: %s",
        text, context_type, situation or "-", cache_key,
    )

    # 3. (FUTURO) Verificar caché en DynamoDB
    # cached = check_dynamodb_cache(cache_key)
    # if cached:
    #     logger.info("Cache HIT — devolviendo resultado precalculado")
    #     return build_response(200, {**cached, "cacheHit": True})

    # 4. Construir el Prompt de desambiguación semántica
    prompt = build_disambiguation_prompt(text, context_type, situation)
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
        "situation": situation,
        "cacheHit": False,
        "cacheKey": cache_key,
        **result,
    })
