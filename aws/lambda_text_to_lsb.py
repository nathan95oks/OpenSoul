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

# Caché de resultados semánticos. Vacío = caché deshabilitada y la lambda
# funciona exactamente igual que antes, invocando Bedrock en cada petición.
CACHE_BUCKET = os.environ.get("S3_BUCKET", "")
CACHE_PREFIX = os.environ.get("APP_PREFIX", "text-to-lsb")
# Se versiona la clave para poder invalidar toda la caché de golpe cuando
# cambien las reglas del prompt: el texto de entrada sería el mismo, pero la
# traducción esperada ya no.
CACHE_VERSION = os.environ.get("CACHE_VERSION", "v1")

# ---------------------------------------------------------------------------
# Clientes AWS
# ---------------------------------------------------------------------------
bedrock_runtime = boto3.client("bedrock-runtime", region_name=APP_REGION)
s3 = boto3.client("s3", region_name=APP_REGION)

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
    # GENERADO por tool/sync_vocabulary.dart — no editar a mano.
    # Fuente: assets/dictionary/official_dictionary.json
    # --- Cortesía (5) ---
    "GRACIAS", "HOLA", "LO_SIENTO", "PERMISO", "POR_FAVOR",
    # --- Respuesta (11) ---
    "ESTOY_BIEN", "MAS_O_MENOS", "NO", "NO_ENTIENDO", "NO_PUEDO", "NO_RECUERDO",
    "NO_SABER", "PUEDE_REPETIR", "PUEDO", "SABER", "SI",
    # --- Preguntas (16) ---
    "COMO", "CUAL", "CUANDO", "CUANTOS", "DONDE", "EL",
    "ELLA", "ELLOS", "NOSOTROS", "PARA_QUE", "POR_QUE", "QUE",
    "QUIEN", "TU", "USTEDES", "YO",
    # --- Identificación (15) ---
    "ANOS_EDAD", "APELLIDO", "EDAD", "EXPAREJA", "FAMILIAR", "HOMBRE",
    "IDENTIDAD", "LADRON", "MILITAR", "MUJER", "NOMBRE", "PAREJA",
    "SOLDADO", "TESTIGO", "VECINO",
    # --- Instituciones (25) ---
    "ABOGADO", "ALCALDIA", "ASISTENTE", "AUTORIDAD", "COORDINADOR", "DEFENSA_PUBLICA",
    "DESPACHO", "DOCTOR", "ENFERMERA", "FELCC", "FELCV", "FISCAL",
    "FISCALIA", "INSTITUCION", "INTERPRETE", "JUEZ", "JUZGADO", "MINISTERIO",
    "OFICIAL", "OFICINA", "ORGANO_JUDICIAL", "POLICIA", "SEPAV", "TRIBUNAL",
    "VENTANILLA",
    # --- Conceptos jurídicos (26) ---
    "ACUERDO_SOCIAL", "ARTICULO", "AUDIENCIA", "AVANCE", "CASO", "CITACION",
    "CODIGO", "CONFIRMACION", "CONTEXTO", "ESTADO", "EXPEDIENTE", "INVESTIGACION",
    "JUICIO", "JUSTICIA", "LEY", "NORMA", "NOTIFICACION", "NUREJ",
    "PODER", "REGLAMENTO", "REQUISITO", "RESOLUCION", "SUBSANACION", "TESTIMONIO",
    "TRAMITE", "WEBID",
    # --- Acciones (36) ---
    "ACLARAR", "ACOMPANAR", "ANOTAR", "AVISAR", "CONFESAR", "CONOCER",
    "COORDINAR", "COPIAR", "CORREGIR", "CUMPLIR", "DECIDIR", "DENUNCIAR",
    "DESCONOCER", "ENTREGAR", "ESCRIBIR", "EXIGIR", "GESTIONAR", "IDENTIFICAR",
    "IMPRIMIR", "JURAR", "MOSTRAR", "NARRAR", "OBSERVAR", "PAGAR",
    "PEDIR", "PERDER", "PRESENTAR", "PROTEGER", "QUEJAR", "RECOGER",
    "RECONOCER", "RECORDAR", "SEGUIMIENTO", "SOLUCIONAR", "TRATAR", "VOLVER",
    # --- Hechos y urgencia (18) ---
    "ABUSAR", "ACCIDENTE", "AMENAZAR", "ARRESTAR", "ASISTENCIA", "AUXILIO",
    "CORRER", "CRISIS", "DANAR", "DISCRIMINACION", "HERIDA", "MALTRATAR",
    "PARAR", "ROBAR", "SALVAR", "SOBORNO", "VIOLACION", "VIOLENCIA",
    # --- Descripción (18) ---
    "AMARILLO", "AZUL", "BLANCO", "CAFE", "CELESTE", "CORRECTO",
    "DELGADO", "GRUESO", "INOCENTE", "LILA", "NARANJA", "NEGRO",
    "PELIGROSO", "PRESO", "ROJO", "ROSADO", "SEGURO", "VERDE",
    # --- Estado y emoción (11) ---
    "CONFIANZA", "CONFUSION", "FALTA", "MAL", "MIEDO", "PROBLEMA",
    "RAZON", "SITUACION", "SOSPECHA", "TEMOR", "VERGUENZA",
    # --- Tiempo (17) ---
    "AHORA", "ANO", "ANTEAYER", "ANTERIORMENTE", "AYER", "DIA",
    "FECHA", "HORA", "HOY", "MANANA", "MES", "MINUTO",
    "PASADO_MANANA", "PRIMERA_VEZ", "SEGUNDO", "SEMANA", "VARIAS_VECES",
    # --- Lugares (16) ---
    "AEROPUERTO", "AVENIDA", "CALLE", "CARCEL", "CASA", "CENTRO_DE_SALUD",
    "COCHABAMBA", "DEPARTAMENTO", "DIRECCION", "FARMACIA", "HOSPITAL", "MERCADO",
    "PARADA", "PISO", "PLAZA", "UBICACION_GPS",
    # --- Documentos (20) ---
    "ANEXO", "CARNET", "CARTA", "CERTIFICADO", "COMPROBANTE", "CONSTANCIA",
    "FORMATO", "FORMULARIO", "FOTOCOPIA", "HOJA", "LICENCIA", "LICENCIA_DECONDUCIR",
    "MEMORIAL", "OBSERVACION", "PAPEL", "PASAPORTE", "RESPALDO", "SELLO",
    "TEXTO", "TITULO",
    # --- Objetos (16) ---
    "AUTO", "BICICLETA", "BILLETERA", "CAMARA", "CUENTA", "DINERO",
    "FOTOGRAFIA", "MENSAJE", "MICRO", "MOCHILA", "MOTOCICLETA", "PRODUCTO",
    "TAXI", "TELEFONO", "TREN", "TRUFI",
    # --- Comunicación (7) ---
    "ACEPTAR", "ATENDER", "AYUDAR", "COMPRENDER", "HABLAR", "RECHAZAR",
    "RESPONDER",
    # --- Comunicación digital (2) ---
    "VIDEOLLAMADA", "WHATSAPP",
    # --- Integridad (1) ---
    "CORRUPTO",
    # --- Abecedario (27) ---
    "A", "B", "C", "D", "E", "F",
    "G", "H", "I", "J", "K", "L",
    "M", "N", "O", "P", "Q", "R",
    "S", "T", "U", "V", "W", "X",
    "Y", "Z", "Ñ",
    # --- Números (10) ---
    "0", "1", "2", "3", "4", "5",
    "6", "7", "8", "9",
}

# ===================================================================
# DICCIONARIO OFICIAL LSB (15 CATEGORÍAS — 210 GLOSAS VERIFICADAS)
# ===================================================================
OFFICIAL_LSB_CORPUS = {
    # 1. Comunicación básica y control del diálogo
    "HOLA", "PERMISO", "GRACIAS", "POR_FAVOR", "PUEDO", "NO_PUEDO", "SI", "NO",
    "LO_SIENTO", "HABLAR", "COMPRENDER", "ATENDER", "AYUDAR", "SABER", "NO_SABER",
    "ACEPTAR", "RECHAZAR", "RESPONDER",
    # 2. Preguntas y referencia personal
    "QUIEN", "DONDE", "COMO", "POR_QUE", "QUE", "CUAL", "PARA_QUE", "CUANTOS", "CUANDO",
    "YO", "TU", "EL", "ELLA", "NOSOTROS", "USTEDES", "ELLOS", "COMO_ESTAS",
    # 3. Identificación y personas
    "NOMBRE", "HOMBRE", "MUJER", "IDENTIDAD", "IDENTIFICAR", "VECINO", "LADRON",
    "TESTIGO", "INOCENTE", "MILITAR", "SOLDADO",
    # 4. Roles e instituciones
    "ABOGADO", "POLICIA", "JUEZ", "FISCAL", "AUTORIDAD", "OFICIAL", "INTERPRETE",
    "COORDINADOR", "ASISTENTE", "DOCTOR", "ENFERMERA", "INSTITUCION", "ORGANO_JUDICIAL",
    "MINISTERIO", "GOBIERNO", "ALCALDIA",
    # 5. Conceptos jurídicos y administrativos
    "LEY", "REGLAMENTO", "JUICIO", "JUSTICIA", "INVESTIGACION", "TRAMITE",
    "RESOLUCION", "NORMA", "ARTICULO", "TESTIMONIO", "ACUERDO_SOCIAL", "JURAR",
    "DIGNIDAD", "ETICA", "FIRME", "CONFIRMACION", "ESTADO", "CONTEXTO",
    # 6. Acciones del relato y del proceso
    "PRESENTAR", "ANOTAR", "MOSTRAR", "NARRAR", "OBSERVAR", "RECONOCER", "DECIDIR",
    "EXIGIR", "COORDINAR", "GESTIONAR", "TRATAR", "SOLUCIONAR", "PEDIR", "ESCRIBIR",
    "COPIAR", "RECOGER", "ACOMPANAR", "AVISAR", "PROTEGER", "ADMINISTRAR", "CUMPLIR",
    "QUEJAR", "CONFESAR",
    # 7. Hechos, seguridad y urgencia
    "AUXILIO", "ASISTENCIA", "PELIGROSO", "ARRESTAR", "ROBAR", "MALTRATAR", "VIOLENCIA",
    "VIOLACION", "ABUSAR", "CORRER", "PARAR", "AMENAZAR", "DANAR", "ACCIDENTE",
    "HERIDA", "PRESO", "CARCEL", "CRISIS", "SALVAR",
    # 8. Tiempo y secuencia
    "MES", "DIA", "SEMANA", "ANO", "AYER", "ANTEAYER", "HOY", "AHORA", "MANANA",
    "PASADO_MANANA", "FECHA", "SEGUNDO", "MINUTO", "HORA",
    # 9. Lugares y ubicación
    "CASA", "CALLE", "DIRECCION", "AVENIDA", "PLAZA", "HOSPITAL", "FARMACIA",
    "MERCADO", "AEROPUERTO", "COCHABAMBA", "UBICACION_GPS",
    # 10. Documentos y objetos frecuentes
    "FORMULARIO", "CARTA", "TEXTO", "TITULO", "LICENCIA", "LICENCIA_DE_CONDUCIR",
    "PASAPORTE", "PAPEL", "TELEFONO", "MOCHILA", "ARCHIVADOR", "FOTOCOPIA",
    "CARPETA", "SELLO", "DINERO",
    # 11. Transporte
    "AUTO", "MICRO", "TRUFI", "TAXI", "MOTOCICLETA", "TREN", "AVION", "BICICLETA",
    # 12. Estado, emoción y comprensión
    "TEMOR", "CONFUSION", "VERGUENZA", "CONFIANZA", "MAL", "ESTOY_BIEN",
    "MAS_O_MENOS", "PROBLEMA", "SITUACION", "CORRECTO", "FALTA", "RAZON",
    # 13. Descripción visual básica
    "ROJO", "AMARILLO", "CAFE", "AZUL", "BLANCO", "VERDE", "ROSADO", "NEGRO",
    "NARANJA", "CELESTE", "LILA", "DELGADO", "GRUESO",
    # 14. Comunicación digital
    "VIDEOLLAMADA", "WHATSAPP", "WIFI", "ZOOM",
    # 15. Integridad, organización y garantías
    "GARANTE", "AUTONOMIA", "CORRUPTO", "HONESTIDAD", "SOBORNO", "DISCRIMINACION",
    "PODER", "COMPROMISO", "PERSONERIA_JURIDICA", "DECRETO_SUPREMO",
    # Abecedario Dactilológico LSB (27)
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "Ñ", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    # Números LSB (10)
    "CERO", "UNO", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE", "DIEZ"
}

# ===================================================================
# DICCIONARIO DE GLOSAS DISPONIBLES EN EL AVATAR 3D
# ===================================================================
# Catálogo oficial de las 41 señas horneadas en 3D en avatar_test.glb
AVAILABLE_3D_GLOSSES = {
    # 1. Comunicación básica y control del diálogo (5)
    "HOLA", "PERMISO", "GRACIAS", "SI", "NO",
    # 2. Abecedario Dactilológico LSB (27 letras)
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "Ñ", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    # 3. Números LSB (10 dígitos)
    "CERO", "UNO", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE", "DIEZ"
}

# Términos judiciales que requieren validación y deben deletrearse dactilológicamente
TERMS_TO_SPELL = {
    "DENUNCIA", "DENUNCIAR", "DENUNCIANTE", "DENUNCIADO", "FISCALIA", "FISCALÍA",
    "JUZGADO", "COMISARIA", "COMISARÍA", "QUERELLA", "IMPUTACION", "IMPUTACIÓN",
    "IMPUTADO", "VICTIMA", "VÍCTIMA", "SOSPECHOSO", "DETENIDO", "ACTA",
    "CEDULA", "CÉDULA", "CEDULA_DE_IDENTIDAD", "FIRMA", "FIRMAR", "DECLARACION",
    "DECLARACIÓN", "DECLARAR", "FELCC", "FELCV", "MINISTERIO_PUBLICO", "MINISTERIO PÚBLICO"
}

# Variantes con las que el modelo nombra una misma seña
GLOSS_ALIASES = {
    "POR FAVOR": "POR_FAVOR",
    "PORFAVOR": "POR_FAVOR",
    "SÍ": "SI",
    "LO SIENTO": "LO_SIENTO",
    "NO PUEDO": "NO_PUEDO",
    "NO SABER": "NO_SABER",
    "¿CÓMO ESTÁS?": "COMO_ESTAS",
    "COMO ESTAS": "COMO_ESTAS",
    "ÓRGANO JUDICIAL": "ORGANO_JUDICIAL",
    "ORGANO JUDICIAL": "ORGANO_JUDICIAL",
    "LICENCIA DE CONDUCIR": "LICENCIA_DE_CONDUCIR",
    "UBICACIÓN GPS": "UBICACION_GPS",
    "ESTOY BIEN": "ESTOY_BIEN",
    "MÁS O MENOS": "MAS_O_MENOS",
    "0": "CERO", "1": "UNO", "2": "DOS", "3": "TRES", "4": "CUATRO",
    "5": "CINCO", "6": "SEIS", "7": "SIETE", "8": "OCHO", "9": "NUEVE", "10": "DIEZ"
}

def resolve_animation_file(gloss: str, animations: dict, text: str):
    """Archivo de animación para [gloss] (avatar_test.glb para 3D, None para placeholder)."""
    clean_gloss = gloss.upper().strip()
    if clean_gloss in AVAILABLE_3D_GLOSSES:
        return "avatar_test.glb"
    return animations.get(clean_gloss)

_avatar_animations_cache = None

def get_avatar_animations() -> dict:
    """Mapa glosa -> animationFile disponible para el avatar 3D."""
    global _avatar_animations_cache
    if _avatar_animations_cache is not None:
        return _avatar_animations_cache

    animations = {g: "avatar_test.glb" for g in AVAILABLE_3D_GLOSSES}
    _avatar_animations_cache = animations
    return animations


# ===================================================================
# MÓDULO 1: PROMPT ENGINEERING — Desambiguación y Morfosintaxis LSB
# ===================================================================

LEGAL_DISAMBIGUATION_RULES = """
REGLAS DE DESAMBIGUACIÓN JURÍDICA Y POLISEMIA EN LSB:
- "llama" (Verbo llamar / citar): Mapear a "LLAMAR". (Ej: "Yo llamo al policía" -> ["YO", "POLICIA", "LLAMAR"])
- "llama" (Animal / Camélido): Mapear a "ANIMAL" o "LLAMA". (Ej: "La llama es mía" -> ["MIO", "LLAMA"])
- "llama" (Fuego / Incendio): Mapear a "FUEGO". (Ej: "Miro la llama" -> ["FUEGO", "VER"])
- "fiscal" (Autoridad judicial): Mapear a "FISCAL".
"""

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
    """Construye el Prompt oficial con las reglas del Ministerio de Educación de Bolivia."""
    gloss_list = ", ".join(sorted(OFFICIAL_LSB_CORPUS))
    safe_text = sanitize_prompt_text(text)

    situation_instruction = ""
    if situation and situation in SITUATION_LABELS:
        situation_instruction = f"SITUACIÓN CONVERSACIONAL: {SITUATION_LABELS[situation]}."

    prompt = f"""Eres el motor lingüístico oficial de traducción de Español a Lengua de Señas Boliviana (LSB),
fundamentado en el Manual Práctico de Enseñanza de Educación Bilingüe del Ministerio de Educación del Estado Plurinacional de Bolivia.

{situation_instruction}

Tu misión es transformar la frase en español a un ARREGLO ORDENADO DE GLOSAS LSB oficiales siguiendo estrictamente estas reglas:

1. SUPRESIÓN DE ELEMENTOS SIN VALOR LSB:
   - Elimina artículos (el, la, los, las, un, una, unos, unas).
   - Elimina preposiciones y conjunciones sin carga semántica (a, de, con, y, en, para, por, que).

2. NORMALIZACIÓN VERBAL:
   - En LSB los verbos van en INFINITIVO / FORMA BASE ('comí', 'como', 'comía' -> 'COMER', 'estudiaron' -> 'ESTUDIAR', 'ama' -> 'AMAR').
   - No uses verbos auxiliares de ser/estar para identidad (ej: 'Yo soy abogado' -> ['YO', 'ABOGADO']).

3. MORFOLOGÍA NEUTRA:
   - Sustantivos y adjetivos en forma neutra singular ('niñas bonitas' -> ['NINA', 'BONITO'], 'muchas' -> ['MUCHO']).

4. ESTRUCTURA Y SINTAXIS LSB:
   - Orden canónico: [TIEMPO] + [SUJETO / OBJETO] + [ADJETIVO] + [VERBO] + [NEGACIÓN / PREGUNTA].
   - Marcadores de tiempo al inicio: 'Ayer hablé' -> ['AYER', 'YO', 'HABLAR'].
   - Partícula de negación al final: 'No puedo atender' -> ['ATENDER', 'PUEDO', 'NO'] o ['NO_PUEDO'].
   - Preguntas al final: '¿Quién es él?' -> ['EL', 'QUIEN'].

5. NÚMEROS:
   - Convierte números a su glosa textual: '1' -> 'UNO', '2' -> 'DOS', '5' -> 'CINCO', '10' -> 'DIEZ'.

6. DELETREO DACTILOLÓGICO:
   - Los nombres propios y términos sin seña formal (ej: 'FELCC', 'ACTA', 'DENUNCIA', 'JUZGADO') deben descomponerse en sus letras individuales: ['F', 'E', 'L', 'C', 'C'].

{LEGAL_DISAMBIGUATION_RULES}

CATÁLOGO DE GLOSAS OFICIALES PERMITIDAS:
[{gloss_list}]

FORMATO DE RESPUESTA (JSON estricto):
{{"glosses": ["GLOSA1", "GLOSA2", ...], "disambiguation": [{{"original": "palabra", "meaning": "significado_lsb", "reason": "justificación"}}]}}

<frase_a_traducir>
{safe_text}
</frase_a_traducir>"""

    return prompt


# ---------------------------------------------------------------------------
# Saneado de la entrada que viaja al modelo
# ---------------------------------------------------------------------------
# El texto lo escribe la persona oyente, así que es entrada no confiable que
# acaba dentro de un prompt (OWASP LLM01). No es un riesgo de ejecución —las
# animaciones no las elige el modelo, se resuelven contra el mapa del servidor
# en [post_process_glosses]—, pero sí de contenido: esta app redacta
# declaraciones destinadas a instituciones públicas, y una frase manipulada
# para alterar la traducción altera un documento.
#
# La defensa es en capas: delimitar la frase e instruir al modelo (arriba),
# neutralizar los delimitadores en el texto (aquí) y validar lo que vuelve
# (abajo). Ninguna basta sola.

_CONTROL_CHARS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


def sanitize_prompt_text(text: str) -> str:
    """Neutraliza lo que permitiría romper el bloque delimitado."""
    # Cerrar la etiqueta para escribir fuera de ella es la vía directa.
    cleaned = text.replace("<frase_a_traducir>", "").replace(
        "</frase_a_traducir>", ""
    )
    # Los caracteres de control no aportan nada a una frase en español y sí
    # sirven para ofuscar una inyección.
    cleaned = _CONTROL_CHARS.sub(" ", cleaned)
    # Un muro de saltos de línea empuja las reglas fuera de la ventana de
    # atención del modelo.
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned.strip()



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
                # Temperatura 0 y topP 1: en un dominio judicial la misma
                # frase debe producir siempre la misma traducción. Con 0.1 el
                # muestreo seguía abierto y el modelo descartaba glosas de
                # forma intermitente — "hola yo abogado" devolvía unas veces
                # HOLA·YO·ABOGADO y otras solo YO·ABOGADO.
                "temperature": 0,
                "topP": 1,
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

# Forma admisible de una glosa: mayúsculas, dígitos, guiones y guion bajo.
# Cubre todo el diccionario canónico ('ANIMAL-LLAMA', 'PARTIDA_NACIMIENTO',
# el alfabeto dactilológico y los números) y nada más. Lista blanca: enumerar
# lo válido no tiene los agujeros de codificación que tiene prohibir lo malo.
_VALID_GLOSS = re.compile(r"^[A-ZÑ0-9][A-ZÑ0-9_-]{0,63}$")


# ---------------------------------------------------------------------------
# Reconocimiento: qué escribió exactamente la persona
# ---------------------------------------------------------------------------
# Separado a propósito de la generación. El modelo decide *cómo se representa*
# una frase en LSB; no decide *qué se dijo*. Antes esa frontera no existía y el
# modelo se llevaba palabras por delante: "cuchillo" volvía como ['C'] y
# "carnet" como ['C','A','R','N','E','T'], deletreado pese a que la regla 5 del
# propio prompt reserva el deletreo para los nombres propios.

_PALABRA = re.compile(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}")

# Palabras que la LSB no signa y que por tanto pueden desaparecer sin que se
# pierda contenido. Se excluyen del control de cobertura para no reinyectarlas.
_PALABRAS_FUNCION = frozenset("""
EL LA LOS LAS UN UNA UNOS UNAS AL DEL LO
DE EN POR PARA CON SIN SOBRE ENTRE HASTA DESDE HACIA TRAS ANTE BAJO
Y O U NI QUE QUE SE ME TE NOS LES LE SU MIS TUS SUS
ES SON ERA ERAN FUE FUERON SER ESTAR ESTA ESTAN HAY HABER HA HAN
MUY MAS TAN YA PERO SI NO
""".split())


def recognize_input(text: str) -> list:
    """Palabras con contenido de la frase, tal y como las escribió la persona.

    No normaliza más allá de separar palabras: es el registro de lo dicho, y
    cualquier arreglo posterior se compara contra esto.
    """
    return [w for w in _PALABRA.findall(text)
            if remove_accents(w.upper()) not in _PALABRAS_FUNCION]


def _clave(palabra: str) -> str:
    return remove_accents(palabra.upper())


def _es_nombre_propio(palabra: str, text: str) -> bool:
    """Mayúscula inicial en posición que no es principio de frase.

    Es la señal disponible sin diccionario de nombres. Se usa solo para
    *proteger* deletreos legítimos ("Isaac" -> I,S,A,A,C), nunca para crearlos.
    """
    if not palabra[:1].isupper():
        return False
    pos = text.find(palabra)
    if pos <= 0:
        return False
    return text[:pos].strip()[-1:] not in ("", ".", "?", "!")


def _cubre(gloss: str, palabra: str) -> bool:
    """`gloss` representa a `palabra`.

    Admite la lematización que la LSB exige —"sustrajo" se signa SUSTRAER— con
    un prefijo común largo, en lugar de exigir igualdad y marcar como perdida
    una traducción correcta.
    """
    g, p = _clave(gloss), _clave(palabra)
    if g == p or g in p or p in g:
        return True
    comun = 0
    for a, b in zip(g, p):
        if a != b:
            break
        comun += 1
    return comun >= 4


def repair_coverage(glosses: list, text: str) -> tuple:
    """Devuelve (glosas, incidencias) reparando la pérdida de palabras.

    Repara solo los dos fallos que se pueden demostrar mirando la salida, y no
    intenta juzgar si una traducción es fiel:

      1. Un deletreo que reconstruye una palabra común se colapsa en la glosa
         entera —"carnet" volvía como C,A,R,N,E,T—, mientras que el de un
         nombre propio se respeta, que es para lo que existe la dactilología.
      2. Las letras sueltas que no reconstruyen nada son ruido y se descartan;
         si alguna era la inicial de una palabra de la frase, esa palabra se
         devuelve completa —"cuchillo" volvía como ['C'] y perdía el objeto
         del delito.

    Deliberadamente NO comprueba que cada palabra tenga glosa. La LSB omite
    partículas y lematiza los verbos, y ningún parecido de cadenas distingue
    esa traducción correcta de una pérdida: "detuvo" y DETENER comparten tres
    letras, "dijo" y DECIR solo una. Reinyectar por sospecha corrompería
    traducciones buenas, que es peor que el fallo que se arregla.
    """
    palabras = recognize_input(text)
    propios = {_clave(w) for w in palabras if _es_nombre_propio(w, text)}
    incidencias = []

    resultado, huerfanas, i = [], [], 0
    while i < len(glosses):
        if len(glosses[i]) == 1 and glosses[i].isalpha():
            j = i
            while j < len(glosses) and len(glosses[j]) == 1 and glosses[j].isalpha():
                j += 1
            racha = "".join(glosses[i:j])
            objetivo = next((w for w in palabras if _clave(w) == _clave(racha)), None)
            if objetivo and _clave(objetivo) in propios:
                resultado.extend(glosses[i:j])
            elif objetivo:
                resultado.append(_clave(objetivo))
                incidencias.append({"palabra": objetivo, "accion": "deletreo_colapsado"})
            else:
                for suelta in glosses[i:j]:
                    huerfanas.append(_clave(suelta))
                    incidencias.append({"palabra": suelta, "accion": "letra_descartada"})
            i = j
            continue
        resultado.append(glosses[i])
        i += 1

    # Una inicial huérfana es la huella de un deletreo truncado: la palabra que
    # empezaba por ahí se quedó sin representación y se devuelve entera.
    iniciales = set(huerfanas)
    for palabra in palabras:
        clave = _clave(palabra)
        if clave in propios or clave[:1] not in iniciales:
            continue
        if not any(_cubre(g, palabra) for g in resultado):
            resultado.append(clave)
            incidencias.append({"palabra": palabra, "accion": "palabra_recuperada"})

    # Salida vacía con entrada que sí decía algo: se devuelve lo dicho antes
    # que nada, para que el avatar no se quede mudo.
    if not resultado and palabras:
        for palabra in palabras:
            resultado.append(_clave(palabra))
            incidencias.append({"palabra": palabra, "accion": "palabra_recuperada"})

    return resultado, incidencias


def post_process_glosses(bedrock_result: dict, text: str) -> dict:
    """
    Valida las glosas retornadas por Bedrock contra el diccionario
    del avatar y marca cuáles requieren dactilología.
    """
    raw_glosses = bedrock_result.get("glosses", [])
    disambiguation = bedrock_result.get("disambiguation", [])

    animations = get_avatar_animations()

    # Saneado de forma: lo que devuelve el modelo es tan poco confiable como lo
    # que entró. Se filtra antes de comprobar cobertura, para que la reparación
    # trabaje sobre glosas ya bien formadas.
    limpias = []
    for gloss in raw_glosses:
        if not isinstance(gloss, str):
            continue
        candidata = gloss.upper().strip()
        if not _VALID_GLOSS.match(candidata):
            logger.warning("Glosa descartada por formato: %.60r", gloss)
            continue
        limpias.append(GLOSS_ALIASES.get(candidata, candidata))

    # Reconocimiento frente a generación: aquí se comprueba que la
    # representación no haya perdido ninguna palabra de lo que se dijo.
    raw_glosses, incidencias = repair_coverage(limpias, text)
    if incidencias:
        logger.info("Fidelidad corregida: %s", incidencias)

    processed = []
    for gloss in raw_glosses:
        # Una palabra recuperada puede no tener forma de glosa (acentos, signos)
        # y no debe rotular una seña en pantalla si no la tiene.
        gloss_upper = gloss.upper().strip()
        if not _VALID_GLOSS.match(gloss_upper):
            logger.warning("Glosa descartada por formato: %.60r", gloss)
            continue

        animation_file = resolve_animation_file(gloss_upper, animations, text)
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
        # Reconocimiento: qué se dijo, separado de cómo se representa.
        "inputWords": recognize_input(text),
        "fidelityFixes": incidencias,
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
    # El modelo forma parte de la clave: cambiar BEDROCK_MODEL_ID cambia la
    # traducción, y servir la del modelo anterior sería devolver el resultado
    # de un sistema que ya no está en producción.
    seed = f"{CACHE_VERSION}|{BEDROCK_MODEL_ID}|{normalized}"
    return hashlib.md5(seed.encode("utf-8")).hexdigest()


# ---------------------------------------------------------------------------
# Caché de resultados semánticos (Amazon S3)
# ---------------------------------------------------------------------------
# En una ventanilla las mismas frases se repiten constantemente ("¿me permite
# su carnet?", "¿dónde ocurrió el hecho?"). Guardar el resultado indexado por
# el hash de la frase convierte esa repetición en una lectura de objeto, en
# lugar de una inferencia facturada de varios segundos.
#
# Se usa S3 y no DynamoDB porque el bucket ya existe y el volumen de escritura
# del proyecto es moderado. La caché es *best effort*: si S3 no responde o el
# rol carece de permisos se registra el aviso y se sigue traduciendo. Una
# caché capaz de tumbar la traducción es peor que no tener caché.

def _cache_object_key(cache_key: str) -> str:
    return f"{CACHE_PREFIX.strip('/')}/cache/{cache_key}.json"


def check_cache(cache_key: str):
    """Devuelve el resultado precalculado, o None si no hay acierto."""
    if not CACHE_BUCKET:
        return None
    try:
        obj = s3.get_object(Bucket=CACHE_BUCKET, Key=_cache_object_key(cache_key))
        return json.loads(obj["Body"].read())
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code", "")
        # Sin s3:ListBucket, un objeto inexistente responde 403 en vez de 404:
        # los dos son un fallo de caché normal, no una incidencia.
        if code in ("NoSuchKey", "404", "AccessDenied", "403"):
            return None
        logger.warning("Caché ilegible (%s) — se continúa sin ella", code)
        return None
    except (ValueError, KeyError) as e:
        logger.warning("Entrada de caché corrupta en %s: %s", cache_key, e)
        return None


def save_to_cache(cache_key: str, payload: dict) -> None:
    """Persiste el resultado. Un fallo aquí nunca interrumpe la respuesta."""
    if not CACHE_BUCKET:
        return
    # Una traducción sin glosas es un tropiezo puntual del modelo, no un
    # resultado. Cachearla congelaría el fallo: esa frase no volvería a
    # traducirse nunca y el avatar se quedaría mudo para siempre ante ella.
    # Sin guardar, el siguiente intento vuelve a pasar por Bedrock.
    if not payload.get("glosses"):
        logger.warning("Resultado sin glosas — no se cachea: %s", cache_key)
        return
    try:
        s3.put_object(
            Bucket=CACHE_BUCKET,
            Key=_cache_object_key(cache_key),
            Body=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            ContentType="application/json",
        )
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code", "")
        logger.warning("No se pudo guardar en caché (%s) — se continúa", code)


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

    # 3. Verificar caché antes de gastar una invocación de Bedrock
    cached = check_cache(cache_key)
    if cached:
        logger.info("Cache HIT — respuesta servida desde caché: %s", cache_key)
        return build_response(200, {**cached, "cacheHit": True})

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
    result = post_process_glosses(bedrock_result, text)

    # 7. Guardar en caché para que la próxima vez sea una lectura

    # 8. Respuesta exitosa
    logger.info(
        "Traducción completada — %d glosas, %d disponibles en avatar",
        result["totalGlosses"],
        result["availableInAvatar"],
    )

    # `cacheHit` se añade fuera del payload persistido: al servir desde caché
    # el resto de la respuesta debe ser idéntico byte a byte, y solo ese campo
    # distingue una traducción recién calculada de una recuperada.
    payload = {
        "originalText": text,
        "context": context_type,
        "situation": situation,
        "cacheKey": cache_key,
        **result,
    }
    save_to_cache(cache_key, payload)

    return build_response(200, {**payload, "cacheHit": False})
