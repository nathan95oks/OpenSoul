"""
Lambda: OpenSoul-TranslateToLSB
Módulo Isaac Rivero — Traducción de Español → Glosas LSB

Objetivo Específico 3:
  "Implementar el modelo de Procesamiento de Lenguaje Natural para la
   desambiguación semántica de términos polisémicos en contexto jurídico."

Flujo:
  1. Recibe JSON con `text` (frase en español) y `context` (legal/general)
  2. Genera Hash MD5 de la frase para verificar caché
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
import struct
import time

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


# Caché de resultados semánticos. Vacío = caché deshabilitada y la lambda
# funciona exactamente igual que antes, invocando Bedrock en cada petición.
CACHE_BUCKET = os.environ.get("S3_BUCKET", "")
CACHE_PREFIX = os.environ.get("APP_PREFIX", "text-to-lsb")
# Se versiona la clave para poder invalidar toda la caché de golpe cuando
# cambien las reglas del prompt: el texto de entrada sería el mismo, pero la
# traducción esperada ya no.
CACHE_VERSION = os.environ.get("CACHE_VERSION", "v2")
# Versión interna de las reglas deterministas. Forma parte de la clave aunque
# CACHE_VERSION esté fijada en las variables de entorno de Lambda, para que un
# despliegue de reglas nuevas nunca siga sirviendo traducciones antiguas.
TRANSLATION_RULESET_VERSION = "compound-glosses-v1"

# Animaciones del avatar. Todas las señas son clips dentro de UN solo .glb en
# S3, y el visor elige el clip por nombre. La lista de clips del propio archivo
# es la única fuente fiable de qué seña existe: una lista escrita a mano se
# desincroniza en cuanto se sube un .glb nuevo, y una glosa marcada como
# disponible sin clip real deja al avatar sin mostrar nada.
# Vacío = no se lee S3 y se usa AVAILABLE_3D_GLOSSES como antes.
ANIMATIONS_BUCKET = os.environ.get("ANIMATIONS_BUCKET", "")
ANIMATIONS_KEY = os.environ.get("ANIMATIONS_KEY", "avatar_test.glb")
# Cada cuánto se vuelve a leer la lista de clips, para que una seña recién
# subida aparezca sin redesplegar la lambda.
ANIMATIONS_TTL_SECONDS = int(os.environ.get("ANIMATIONS_TTL_SECONDS", "300"))

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
# DICCIONARIO DE GLOSAS DISPONIBLES EN EL AVATAR 3D
# Si la IA genera una glosa que NO está aquí, el sistema usará
# dactilología (deletreo) como fallback.
# ===================================================================
AVAILABLE_GLOSSES = {
    # GENERADO por tool/sync_vocabulary.dart — no editar a mano.
    # Fuente: assets/dictionary/official_dictionary.json
    # --- Cortesía (7) ---
    "DE_NADA", "GRACIAS", "HASTA_LUEGO", "HOLA", "LO_SIENTO", "PERMISO",
    "POR_FAVOR",
    # --- Respuesta (11) ---
    "COMPRENDER", "ESTAR_DE_ACUERDO", "MENTIRA", "NO", "NO_ESTAR_DE_ACUERDO", "NO_PUEDO",
    "NO_SABER", "PUEDO", "SABER", "TAL_VEZ", "VERDAD",
    # --- Preguntas (8) ---
    "AMBOS", "ELLA", "ELLOS", "NOSOTROS", "SUYO", "TUYO",
    "VARIOS", "YO",
    # --- Identificación (31) ---
    "ADULTO", "ALTO", "AMIGO", "ASOCIACIÓN_SORDOS", "BAJO", "COMPAÑERO",
    "COMUNIDAD_SORDA", "EDAD", "ESPOSA", "FLACO", "GORDO", "HERMANA",
    "HERMANO", "HIJA", "HIJO", "HOMBRE", "IDENTIDAD", "JEFE",
    "JOVEN", "LADRÓN", "MAMÁ", "MUJER", "NOMBRE", "OYENTE",
    "PAREJA", "PARIENTE", "SEPARADOS", "SEÑOR", "SORDO", "TESTIGO",
    "TRABAJADOR",
    # --- Instituciones (19) ---
    "ABOGADO", "ALCALDÍA", "ASISTENTE", "AUTORIDAD", "DOCTOR", "FELCC",
    "FELCV", "FISCALIA", "GOBIERNO", "HOSPITAL", "INSTITUCIÓN", "INTÉRPRETE",
    "JUEZ", "JUZGADO", "OFICIAL", "POLICÍA", "SEPDAVI", "SEPDEP",
    "ÓRGANO_JUDICIAL",
    # --- Conceptos jurídicos (12) ---
    "ASISTENCIA", "CONVOCAR", "DISCRIMINACIÓN", "INVESTIGACIÓN", "JUSTICIA", "LEY",
    "PLAZO", "PROHIBIDO", "RESOLUCIÓN", "RESULTADO", "TESTIMONIO", "TRÁMITE",
    # --- Acciones (87) ---
    "ABRIR", "ACEPTAR", "ACOMPAÑAR", "ANDAR", "ARREGLAR", "ARRESTAR",
    "ATENDER", "AUMENTAR", "AVISAR", "AYUDAR", "BOCA", "BRAZO",
    "BURLAR", "BUSCAR", "CABELLO", "CAMBIAR", "COMPRAR", "CONOCER",
    "CONTESTAR_DOS_VECES", "CONTINUAR", "CREER", "CURAR", "CUÁL", "CUÁNDO",
    "CUÁNTOS", "CÓMO", "DAR", "DECIDIR", "DEJAR", "DEVOLVER",
    "DIBUJAR", "DORMIR", "DÓNDE", "EMPEZAR", "ENCONTRARSE", "ENVIAR",
    "ESCONDER", "ESCRIBIR", "ESPERAR", "EVALUAR", "EXPLICAR", "FILMAR",
    "FUNCIONAR", "GANAR_DINERO", "GRATIS", "GRITAR", "GUARDAR", "HABLAR",
    "HACER", "IDENTIFICAR", "IGNORAR", "IR", "LEER", "LLAMAR",
    "LLEGAR", "LLEVAR", "MIRAR", "MOSTRAR", "MÍO", "NARRAR",
    "NECESITAR", "OBSERVAR", "ORGANIZAR", "OÍR", "PALABRA", "PEDIR",
    "PRESENTAR", "PROTEGER", "QUEJAR", "QUERER", "QUIÉN", "QUÉ",
    "RECHAZAR", "RECIBIR", "RECORDAR", "REUNIÓN", "TENER", "TERMINAR",
    "TOTAL", "TRAER", "TÚ", "VENDER", "VENIR", "VER",
    "VIVIR", "VOLVER", "ÉL",
    # --- Hechos y urgencia (20) ---
    "ABUSAR", "AMENAZAR", "AUXILIO", "BUENOS_DÍAS", "DAÑAR", "DOLOR",
    "ENGAÑAR", "ESCAPAR", "FRACTURA", "HERIDA", "HUESOS", "MALTRATAR",
    "MÁS_O_MENOS", "PEGAR", "PELEAR", "PERDER", "ROBAR", "SÍ",
    "URGENTE", "VIOLENCIA",
    # --- Descripción (15) ---
    "AZUL", "BUENO", "CARO", "CORTO", "DIFERENTE", "DIFÍCIL",
    "LENTO", "MAL", "MEJOR", "MUCHO", "NEGRO", "NUEVO",
    "OSCURO", "POCO", "ROJO",
    # --- Estado y emoción (4) ---
    "CONFIANZA", "MIEDO", "PREOCUPAR", "TRISTE",
    # --- Tiempo (43) ---
    "AHORA", "ANTEAYER", "AYER", "AÑO", "AÑO_PASADO", "AÚN",
    "CADA_DÍA", "DESCANSO", "DESPUÉS", "DURANTE", "DÍA", "FECHA",
    "FUTURO", "HASTA_MAÑANA", "HORA", "HOY", "JAMÁS", "JUEVES",
    "JULIO", "LIBRE", "LUEGO", "LUNES", "MARTES", "MARZO",
    "MAÑANA", "MES", "MINUTO", "MOMENTO", "OCUPADO", "PASADO",
    "PASADO_MAÑANA", "POSTERGAR", "PRIMERA_VEZ", "PRÓXIMO", "SEGUNDO", "SEMANA",
    "SIEMPRE", "SÁBADO", "TARDE", "TEMPRANO", "TODOS_LOS_DÍAS", "VIERNES",
    "ÚLTIMO",
    # --- Lugares (24) ---
    "ALLÁ", "ALLÍ", "AL_LADO", "AQUÍ", "ATRÁS", "AVENIDA",
    "BANCO", "BARRIO", "CALLE", "CASA", "CERCA", "COCHABAMBA",
    "DENTRO", "DIRECCIÓN", "ENFRENTE", "ESCUELA", "ESCUELA_NOCTURNA", "FUERA",
    "LEJOS", "MERCADO", "OFICINA", "PLAZA", "PROVINCIA", "TIENDA",
    # --- Documentos (8) ---
    "CARPETA", "CERTIFICADO", "FACTURA", "FOTOCOPIA", "LISTA", "PAPEL",
    "PÁGINA", "SELLO",
    # --- Objetos (20) ---
    "BILLETES", "BOLSA", "CAJA", "CELULAR", "CHAMARRA", "COMPUTADORA",
    "CÁMARA_FOTOGRÁFICA", "FOTOS", "GORRA", "INTERNET", "LENTES", "MEDICINA",
    "MICRO", "MOCHILA", "PANTALÓN", "POLERA", "PUERTA", "RAYOS_X",
    "TRUFI", "VIDEO",
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
# DICCIONARIO OFICIAL LSB (SINCRONIZADO CON EL CORPUS MAESTRO V4 AUDITADO)
# ===================================================================
OFFICIAL_LSB_CORPUS = AVAILABLE_GLOSSES

# ===================================================================
# DICCIONARIO DE GLOSAS CON ANIMACIÓN 3D DISPONIBLE (146 SEÑAS VERDES)
# ===================================================================
# Catálogo oficial de las 146 señas validadas con animación 3D
# (filas VERDES de la hoja de cálculo maestra).
# Es solo el RESPALDO: con ANIMATIONS_BUCKET configurado, lo que decide si una
# seña se muestra es la lista de clips del .glb en S3 (ver get_baked_clips).
# Todas las demás señas (amarillas, naranjas, blancas o no catalogadas)
# NO tienen animación horneada aún y se deletrean dactilológicamente.
AVAILABLE_3D_GLOSSES = {
    # 1. Comunicación básica, control del diálogo y cortesía (5)
    "HOLA", "PERMISO", "GRACIAS", "POR_FAVOR", "LO_SIENTO",
    # 2. Respuestas y confirmación (7)
    "SI", "SÍ", "NO", "PUEDO", "NO_PUEDO", "SABER", "NO_SABER", "COMPRENDER",
    "CONTESTAR", "CONTESTAR_DOS_VECES",
    # 3. Pronombres y referencia personal (7)
    "YO", "TU", "TÚ", "EL", "ÉL", "ELLA", "NOSOTROS", "USTEDES", "ELLOS", "COMO_ESTAS", "CÓMO_ESTÁS",
    # 4. Preguntas e interrogativos (9)
    "QUIEN", "QUIÉN", "DONDE", "DÓNDE", "COMO", "CÓMO", "POR_QUE", "POR_QUÉ",
    "QUE", "QUÉ", "CUAL", "CUÁL", "PARA_QUE", "PARA_QUÉ", "CUANTOS", "CUÁNTOS",
    "CUANDO", "CUÁNDO",
    # 5. Abecedario Dactilológico LSB (27 letras completas)
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "Ñ", "ENIE", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    # 6. Números LSB (dígitos y numerales 0 - 10)
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
    "CERO", "UNO", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE", "DIEZ",
    # 7. Identificación y personas (6)
    "NOMBRE", "HOMBRE", "MUJER", "IDENTIDAD", "TESTIGO", "SORDO",
    # 8. Instituciones y servicios (6)
    "ABOGADO", "INTERPRETE", "INTÉRPRETE", "JUEZ", "AUTORIDAD", "POLICIA", "POLICÍA", "HOSPITAL",
    # 9. Conceptos jurídicos y trámites (6)
    "ASISTENCIA", "INVESTIGACION", "INVESTIGACIÓN", "JUSTICIA", "RESOLUCION", "RESOLUCIÓN",
    "TESTIMONIO", "TRAMITE", "TRÁMITE",
    # 10. Acciones y verbos (28)
    "ACEPTAR", "ACOMPAÑAR", "ACOMPANAR", "ATENDER", "AYUDAR", "BUSCAR", "DAR",
    "ENVIAR", "ESCRIBIR", "ESPERAR", "EXPLICAR", "GUARDAR", "HABLAR", "LEER",
    "MOSTRAR", "NECESITAR", "OBSERVAR", "PROTEGER", "QUEJAR", "QUERER", "RECHAZAR",
    "RECIBIR", "RECORDAR", "ROBAR", "TRAER", "VENIR", "VER", "VOLVER",
    # 11. Hechos, urgencia y agresiones (7)
    "AMENAZAR", "DAÑAR", "DANAR", "ENGAÑAR", "ENGANAR", "HERIDA", "PEGAR",
    # 12. Descripción, estado y emoción (2)
    "LENTO", "MIEDO",
    # 13. Tiempo (10)
    "AHORA", "AYER", "AUN", "AÚN", "FECHA", "HORA", "HOY", "MAÑANA", "MANANA", "PRIMERA_VEZ", "SEMANA", "TARDE",
    # 14. Lugares (8)
    "ALLI", "ALLÍ", "AQUI", "AQUÍ", "AVENIDA", "CALLE", "CASA", "CERCA", "DENTRO", "OFICINA",
    # 15. Documentos (5)
    "CARPETA", "CERTIFICADO", "FACTURA", "FOTOCOPIA", "PAPEL",
    # 16. Objetos (4)
    "BILLETES", "CELULAR", "FOTOS", "VIDEO",
}

# ---------------------------------------------------------------------------
# Normalización ortográfica
# ---------------------------------------------------------------------------

def remove_accents(text: str) -> str:
    accents = {
        'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
        'Ü': 'U', 'Ñ': 'N'
    }
    for accented_char, unaccented_char in accents.items():
        text = text.replace(accented_char, unaccented_char)
    return text

def strip_gloss_accents(text: str) -> str:
    """Quita tildes y diéresis de una glosa conservando la Ñ."""
    for con, sin in (('Á', 'A'), ('É', 'E'), ('Í', 'I'), ('Ó', 'O'),
                     ('Ú', 'U'), ('Ü', 'U')):
        text = text.replace(con, sin)
    return text


# Normalización interna del catálogo 3D
_AVAILABLE_3D_GLOSSES_NORM = {
    strip_gloss_accents(g.upper().strip().replace(' ', '_'))
    for g in AVAILABLE_3D_GLOSSES
}

# Términos judiciales que requieren validación y deben deletrearse dactilológicamente
TERMS_TO_SPELL = {
    "ACTA", "CEDULA", "CÉDULA", "FIRMA", "FIRMAR", "DECLARACION",
    "DECLARACIÓN", "DECLARAR", "MINISTERIO_PUBLICO", "MINISTERIO PÚBLICO",
    "FELCC", "FELCV", "SEPDAVI", "SEPDEP", "NUREJ",
}

# Variantes con las que el modelo nombra una misma seña
GLOSS_ALIASES = {
    "PRIMERA VEZ": "PRIMERA_VEZ",
    "PRIMERA_VEZ": "PRIMERA_VEZ",
    "POR FAVOR": "POR_FAVOR",
    "PORFAVOR": "POR_FAVOR",
    "LO SIENTO": "LO_SIENTO",
    "NO PUEDO": "NO_PUEDO",
    "NO SABER": "NO_SABER",
    "ÓRGANO JUDICIAL": "ORGANO_JUDICIAL",
    "ORGANO JUDICIAL": "ORGANO_JUDICIAL",
    "ESTOY BIEN": "ESTOY_BIEN",
    "MÁS O MENOS": "MAS_O_MENOS",
    "MAS O MENOS": "MAS_O_MENOS",
    "¿COMO ESTAS?": "COMO_ESTAS",
    "COMO ESTAS": "COMO_ESTAS",
    "¿CÓMO ESTÁS?": "COMO_ESTAS",
    "CÓMO ESTÁS": "COMO_ESTAS",
    "¿POR QUE?": "POR_QUE",
    "POR QUE": "POR_QUE",
    "¿POR QUÉ?": "POR_QUE",
    "POR QUÉ": "POR_QUE",
    "PORQUE": "POR_QUE",
    "¿PARA QUE?": "PARA_QUE",
    "PARA QUE": "PARA_QUE",
    "¿PARA QUÉ?": "PARA_QUE",
    "PARA QUÉ": "PARA_QUE",
    "CONTESTAR": "CONTESTAR",
    "TELEFONO": "CELULAR",
    "FOTOGRAFIA": "FOTOS",
    "DELGADO": "FLACO",
}

# ---------------------------------------------------------------------------
# Clips horneados en el .glb del avatar
# ---------------------------------------------------------------------------
# Los numerales se hornearon con su nombre en letras (el catálogo los ofrece
# como dígitos) y la Ñ como "ENE". Mismo reparto que
# `AnimationUrlResolver.canonicalFor` / `animationNameOverrides` en el cliente.
_NUMERAL_CLIPS = {
    "0": "CERO", "1": "UNO", "2": "DOS", "3": "TRES", "4": "CUATRO",
    "5": "CINCO", "6": "SEIS", "7": "SIETE", "8": "OCHO", "9": "NUEVE",
    "10": "DIEZ",
}
_CLIP_ALIASES = {"ENE": "Ñ", "ENIE": "Ñ"}


def _clip_key(gloss: str) -> str:
    """Forma con la que se compara una glosa contra los clips del .glb.

    En S3 las animaciones están en mayúsculas con barra baja ('PRIMERA_VEZ')
    y si tienen la letra Ñ en palabras están como N (ej: ACOMPANAR, MANANA),
    mientras que la letra suelta 'Ñ' se resuelve a 'ENE'.
    """
    clave = strip_gloss_accents(gloss.upper().strip().replace(' ', '_'))
    if len(clave) > 1 and 'Ñ' in clave:
        clave = clave.replace('Ñ', 'N')
    return _NUMERAL_CLIPS.get(clave, clave)


def _clips_by_key(names) -> dict:
    """{clave de glosa: nombre real del clip} para una lista de clips."""
    mapa = {}
    for name in names:
        clave = _clip_key(name)
        mapa[_CLIP_ALIASES.get(clave, clave)] = name
        mapa[clave] = name
        # Si el clip viene con N (ej: ACOMPANAR), registrar también su alias con Ñ
        if len(clave) > 1 and 'N' in clave:
            mapa[clave.replace('N', 'Ñ')] = name
    return mapa


_GLB_JSON_CHUNK = 0x4E4F534A  # "JSON" en little-endian
_GLB_MAX_JSON_BYTES = 16 * 1024 * 1024


def read_glb_clip_names(bucket: str, key: str) -> list:
    """Nombres de las animaciones de un .glb en S3, sin descargarlo entero.

    Un GLB empieza por una cabecera de 12 bytes y un primer chunk JSON con la
    descripción de la escena, animaciones incluidas; la geometría y los
    keyframes van después, en el chunk binario, y son casi todo el peso. Con
    dos lecturas por rango se obtiene la lista de clips sin bajar ese binario.
    """
    head = s3.get_object(Bucket=bucket, Key=key, Range="bytes=0-19")["Body"].read()
    if len(head) < 20:
        raise ValueError("archivo demasiado corto para ser un GLB")
    magic, _version, _total = struct.unpack_from("<4sII", head, 0)
    chunk_len, chunk_type = struct.unpack_from("<II", head, 12)
    if magic != b"glTF" or chunk_type != _GLB_JSON_CHUNK:
        raise ValueError("no es un GLB válido")
    if not 0 < chunk_len <= _GLB_MAX_JSON_BYTES:
        raise ValueError(f"chunk JSON de tamaño inesperado: {chunk_len}")

    body = s3.get_object(
        Bucket=bucket, Key=key, Range=f"bytes=20-{20 + chunk_len - 1}",
    )["Body"].read()
    gltf = json.loads(body)
    return [a["name"] for a in gltf.get("animations", [])
            if isinstance(a, dict) and isinstance(a.get("name"), str)]


_STATIC_CLIPS = _clips_by_key(AVAILABLE_3D_GLOSSES)
_clips_cache = {"clips": None, "expires": 0.0}


def get_baked_clips() -> dict:
    """{clave de glosa: nombre del clip} de las señas que el avatar sí tiene.

    Con ANIMATIONS_BUCKET configurado se lee del propio .glb en S3 y se
    guarda ANIMATIONS_TTL_SECONDS en memoria del contenedor. Si S3 falla se
    usa la lista estática durante un minuto y se reintenta: una lectura
    fallida no debe dejar al avatar mudo, pero tampoco congelar la lista vieja.
    """
    if not ANIMATIONS_BUCKET:
        return _STATIC_CLIPS

    ahora = time.time()
    if _clips_cache["clips"] is not None and ahora < _clips_cache["expires"]:
        return _clips_cache["clips"]

    try:
        clips = _clips_by_key(read_glb_clip_names(ANIMATIONS_BUCKET, ANIMATIONS_KEY))
        ttl = ANIMATIONS_TTL_SECONDS
        logger.info("Clips leídos de s3://%s/%s: %d",
                    ANIMATIONS_BUCKET, ANIMATIONS_KEY, len(clips))
    except Exception as e:  # noqa: BLE001 — cualquier fallo cae al estático
        logger.warning("No se pudo leer la lista de clips del GLB (%s) — "
                       "se usa la lista estática", e)
        clips, ttl = _STATIC_CLIPS, 60

    _clips_cache["clips"] = clips
    _clips_cache["expires"] = ahora + ttl
    return clips


def plan_gloss_animation(gloss: str, clips: dict) -> tuple:
    """(detalle, pasos) para reproducir [gloss] en el avatar.

    Si la glosa tiene clip propio se muestra la seña. Si no, se deletrea letra
    por letra; cada letra usa su clip si existe y, si tampoco lo tiene, queda
    como placeholder (animationFile None) para que la palabra no pierda letras.
    """
    clip = clips.get(_clip_key(gloss))
    if clip:
        paso = {"gloss": gloss, "animationFile": ANIMATIONS_KEY,
                "animationName": clip, "sourceGloss": gloss}
        return {
            "gloss": gloss,
            "available": True,
            "fallback": None,
            "animationFile": ANIMATIONS_KEY,
            "animationName": clip,
            "spelledLetters": None,
        }, [paso]

    letras = _spell_out(gloss)
    pasos = []
    for letra in letras:
        clip_letra = clips.get(_clip_key(letra))
        pasos.append({
            "gloss": letra,
            "animationFile": ANIMATIONS_KEY if clip_letra else None,
            "animationName": clip_letra,
            "sourceGloss": gloss,
        })
    return {
        "gloss": gloss,
        "available": False,
        "fallback": "dactilología",
        "animationFile": None,
        "animationName": None,
        "spelledLetters": letras,
    }, pasos


# ===================================================================
# MÓDULO 1: PROMPT ENGINEERING — Desambiguación y Morfosintaxis LSB
# ===================================================================

LEGAL_DISAMBIGUATION_RULES = """
REGLAS DE DESAMBIGUACIÓN JURÍDICA Y POLISEMIA EN LSB:
- "llamar"/"llamo"/"llamé" como VERBO (llamar por teléfono, citar a alguien):
  Mapear a "LLAMAR". (Ej: "Yo llamo al policía" -> ["YO", "POLICÍA", "LLAMAR"])
- "llama" como SUSTANTIVO (el animal, "la llama del campo"): NO tiene seña
  propia en el catálogo. NO la mapees a "LLAMAR" — eso convertiría un animal
  en una acción de llamar, que la frase no dice. Déjala fuera de "glosses"
  para que se deletree.
- "fiscal" (funcionario del Ministerio Público): NO existe una seña
  documentada para esta persona — la única entrada "FISCAL" del corpus (M3)
  es un falso amigo: corresponde al sentido escolar de "fiscal/público" y el
  propio corpus PROHÍBE reutilizarla para el funcionario judicial
  (docs/Corpus_Maestro_Unificado_LSB_v4_Auditado.md, filas 71/78). NO mapees
  "fiscal" a "FISCAL". Déjalo fuera de "glosses" para que se deletree.
- "fiscalía" (la institución): Mapear a "FISCALIA" (el catálogo la marca ella
  misma como dactilológica, no como una seña propia — se deletreará igual).
- "policía" (Oficial o institución): Mapear a "POLICÍA".
- "teléfono / celular / móvil": Mapear a "CELULAR".
- "plata / dinero / efectivo": Mapear a "BILLETES".
- "carnet / cédula": Mapear a "PAPEL" + "IDENTIDAD".
- "fotos / fotografía": Mapear a "FOTOS".
- "huir / escapar": Mapear a "ESCAPAR".
- "correr" (desplazarse corriendo, SIN implicar huida ni delito): NO tiene
  seña propia en el catálogo. NO lo mapees a "ESCAPAR" ni a ningún otro verbo
  de fuga — eso afirmaría un hecho que la frase no dice. Déjalo fuera de
  "glosses" y repórtalo en "disambiguation" con "meaning": "sin_sena".
- "billetera" (objeto que guarda dinero, NO es el dinero en sí): NO tiene seña
  propia en el catálogo. NO lo mapees a "BILLETES" — eso afirmaría que se
  trata de dinero. Repórtalo igual que "correr".
- "primera vez": Mapear a "PRIMERA_VEZ" (es la seña oficial de tiempo/reincidencia en el catálogo).
"""

SITUATION_LABELS = {
    "denuncia_robo": "denuncia de robo, hurto o asalto",
    "violencia": "denuncia de violencia o agresión física/psicológica",
    "amenaza_digital": "amenazas por mensajes, llamadas o internet",
    "engano_dinero": "estafa, engaño económico o transferencias",
    "seguimiento": "consulta de estado de caso o resoluciones judiciales",
    "identificacion": "identificación del ciudadano y contacto",
    "preguntas": "preguntas y consultas directas del ciudadano sordo",
    "otro": "declaración general y testimonio",
}

def build_disambiguation_prompt(text: str, context: str = "legal", situation: str = None) -> str:
    """Construye el Prompt oficial con las reglas del Ministerio de Educación de Bolivia."""
    gloss_list = ", ".join(sorted(AVAILABLE_GLOSSES))
    safe_text = sanitize_prompt_text(text)

    situation_instruction = ""
    if situation and situation in SITUATION_LABELS:
        situation_instruction = f"SITUACIÓN CONVERSACIONAL: {SITUATION_LABELS[situation]}."

    prompt = f"""Eres el motor lingüístico oficial de traducción de Español a Lengua de Señas Boliviana (LSB),
fundamentado en el Manual Práctico de Enseñanza de Educación Bilingüe del Ministerio de Educación del Estado Plurinacional de Bolivia y el Corpus Maestro Unificado LSB v4.

{situation_instruction}

Tu misión es transformar la frase en español a un ARREGLO ORDENADO DE GLOSAS LSB oficiales siguiendo estrictamente estas reglas:

0. SEÑAS COMPUESTAS — MÁXIMA PRIORIDAD:
   - Si varias palabras consecutivas forman una glosa compuesta del catálogo,
     usa UNA sola glosa compuesta. Nunca la dividas en señas individuales ni
     deletrees una de sus partes.
   - Regla obligatoria: "cómo estás" / "como estas" -> ["COMO_ESTAS"].
     No devuelvas ["COMO", "ESTAS"] ni ["COMO", "ESTAR"].

1. SUPRESIÓN DE ELEMENTOS SIN VALOR LSB:
   - Elimina artículos (el, la, los, las, un, una, unos, unas).
   - Elimina preposiciones y conjunciones sin carga semántica (a, de, con, y, en, para, por, que).

2. NORMALIZACIÓN VERBAL:
   - En LSB los verbos van en INFINITIVO / FORMA BASE ('comí', 'como', 'comía' -> 'COMER', 'estudiaron' -> 'ESTUDIAR', 'ama' -> 'AMAR').
   - No uses verbos auxiliares de ser/estar para identidad (ej: 'Yo soy abogado' -> ['YO', 'ABOGADO']).

3. MORFOLOGÍA NEUTRA:
   - Sustantivos y adjetivos en forma canónica: singular/plural y género se
     neutralizan a la forma del catálogo ('trabajadores' -> ['TRABAJADOR'],
     'muchos' -> ['MUCHO']). Esto es solo forma gramatical: NUNCA cambies el
     concepto ni añadas una relación (parentesco, edad, cantidad) que la
     palabra original no afirma. 'niñas' es una edad, no una relación
     familiar: si no hay evidencia de que sean hijas de alguien, NO uses
     "HIJA" — dilo con un descriptor de edad o repórtalo como concepto sin
     seña si no hay uno adecuado en el catálogo.

4. ESTRUCTURA Y SINTAXIS LSB (ORDEN MORFOSINTÁCTICO CANÓNICO):
   - Estructura obligatoria: [TIEMPO] + [LUGAR] + [SUJETO / OBJETO] + [ADJETIVO] + [VERBO] + [NEGACIÓN / PREGUNTA].
   - Marcadores de tiempo siempre al inicio: 'Ayer llegué a la fiscalía' ->
     ['AYER', 'FISCALIA', 'LLEGAR']. NUNCA agregues "FISCALIA" (la
     institución) si la frase solo menciona a la persona ("el fiscal"), ni
     "FISCAL" para esa persona (ver la regla de "fiscal" más abajo): son
     conceptos distintos y agregar uno que la frase no dijo es información
     añadida, no traducción.
   - Marcadores de lugar van antes del sujeto u objeto: 'Me robaron el celular en la plaza' -> ['PLAZA', 'CELULAR', 'ROBAR'].
   - Negación al final de la cláusula: 'No puedo atender hoy' -> ['HOY', 'ATENDER', 'NO_PUEDO'] o ['HOY', 'ATENDER', 'PUEDO', 'NO'].
   - Preguntas e interrogativos al final: 
     - '¿Dónde ocurrió el robo?' -> ['ROBAR', 'DÓNDE'].
     - '¿Quién te agredió?' -> ['PEGAR', 'QUIÉN'].
     - '¿Cuándo debo volver a la fiscalía?' -> ['FISCALIA', 'VOLVER', 'CUÁNDO'].
     - '¿Cuántos días debo esperar?' -> ['DÍA', 'ESPERAR', 'CUÁNTOS'].

5. NÚMEROS Y DÍGITOS:
   - Convierte números a dígitos/glosas del catálogo: '1' -> '1', '2' -> '2', '5' -> '5'.

6. DELETREO DACTILOLÓGICO:
   - Los nombres propios, siglas sin seña y términos no catalogados deben deletrearse letra por letra: ['S', 'E', 'G', 'I', 'P'].

{LEGAL_DISAMBIGUATION_RULES}

CATÁLOGO DE GLOSAS OFICIALES PERMITIDAS (SOLO USAR ESTAS):
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


# Los alias se consultan por su forma sin tildes: el modelo escribe tanto
# "ÓRGANO JUDICIAL" como "ORGANO JUDICIAL", y mantener las dos variantes a mano
# en la tabla deja fuera la que se olvide.
_GLOSS_ALIASES_NORM = {
    strip_gloss_accents(clave.upper()): valor
    for clave, valor in GLOSS_ALIASES.items()
}


def canonical_gloss(gloss: str) -> str:
    """Glosa en su forma canónica: sin tildes y con el alias ya resuelto."""
    return _GLOSS_ALIASES_NORM.get(
        strip_gloss_accents(gloss.upper().strip()),
        strip_gloss_accents(gloss.upper().strip()),
    )


def _phrase_words(text: str) -> tuple:
    """Palabras comparables de una frase, sin tildes ni puntuación."""
    return tuple(re.findall(r"[A-ZÑ0-9]+", remove_accents(text.upper())))


# Las equivalencias multipalabra son reglas lingüísticas escritas por el
# proyecto, no inferencias de Bedrock. Solo se fuerzan cuando el GLB confirma
# que el clip de destino existe. Así una regla obsoleta jamás deja al avatar
# inmóvil y, a la vez, un clip como COMO_ESTAS gana a COMO + deletreo(ESTAS).
_MULTIWORD_GLOSS_RULES = tuple(sorted({
    (_phrase_words(source), canonical_gloss(target))
    for source, target in GLOSS_ALIASES.items()
    if len(_phrase_words(source)) > 1
}, key=lambda item: (-len(item[0]), item[0], item[1])))

# Variantes que el modelo puede producir después de lematizar un verbo. Se
# aceptan únicamente para colapsarlas hacia la regla compuesta ya verificada.
_COMPOUND_OUTPUT_VARIANTS = {
    "COMO_ESTAS": (("COMO", "ESTAS"), ("COMO", "ESTAR")),
}


def enforce_baked_compound_glosses(glosses: list, text: str,
                                    clips: dict) -> tuple:
    """Prioriza la seña compuesta más larga presente en texto y en el GLB.

    Devuelve (glosas, glosas_compuestas_verificadas). La segunda colección se
    entrega a la validación del catálogo: el alias aporta el significado y el
    GLB aporta evidencia de que la animación realmente existe.
    """
    input_words = _phrase_words(text)
    if not input_words:
        return list(glosses), set()

    matches = []
    occupied = set()
    for words, target in _MULTIWORD_GLOSS_RULES:
        if _clip_key(target) not in clips:
            continue
        width = len(words)
        for start in range(len(input_words) - width + 1):
            positions = set(range(start, start + width))
            if positions & occupied or input_words[start:start + width] != words:
                continue
            matches.append((start, words, target))
            occupied.update(positions)

    if not matches:
        return list(glosses), set()

    resultado = list(glosses)
    verificadas = set()
    for _start, words, target in sorted(matches):
        verificadas.add(target)

        # Para una entrada que es exactamente la expresión compuesta no se
        # permite que ninguna interpretación fragmentada de Bedrock sobreviva.
        if input_words == words:
            resultado = [target]
            continue

        keys = tuple(_clave(g) for g in resultado)
        target_key = _clave(target)

        # Si Bedrock ya respetó la glosa compuesta, no se duplica.
        if target_key in keys:
            continue

        patterns = _COMPOUND_OUTPUT_VARIANTS.get(target, (words,))
        replaced = False
        for pattern in patterns:
            width = len(pattern)
            for idx in range(len(keys) - width + 1):
                if keys[idx:idx + width] == pattern:
                    resultado[idx:idx + width] = [target]
                    replaced = True
                    break
            if replaced:
                break

        if not replaced:
            # El modelo puede omitir por completo una parte. La regla sigue
            # siendo obligatoria porque la frase se reconoció en la entrada y
            # el clip existe; se agrega antes que permitir un deletreo falso.
            resultado.append(target)

    return resultado, verificadas


# Forma admisible de una glosa: mayúsculas, dígitos, guiones y guion bajo.
# Cubre todo el diccionario canónico ('ANIMAL-LLAMA', 'PARTIDA_NACIMIENTO',
# el alfabeto dactilológico y los números) y nada más. Lista blanca: enumerar
# lo válido no tiene los agujeros de codificación que tiene prohibir lo malo.
#
# Incluye ÁÉÍÓÚÜ: aunque los alias ya no producen vocales acentuadas (ver
# GLOSS_ALIASES), una glosa que llega acentuada y no tiene alias —"MÉDICO",
# "DECLARACIÓN"— debe poder pasar este filtro para que `strip_gloss_accents`
# la normalice después; sin las vocales acentuadas aquí se rechazaba antes de
# llegar a normalizarse y la palabra desaparecía sin dejar rastro (auditoría
# 2026-09, clase GlosasAcentuadas).
_VALID_GLOSS = re.compile(r"^[A-ZÑÁÉÍÓÚÜ0-9][A-ZÑÁÉÍÓÚÜ0-9_-]{0,63}$")


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
#
# NO, SIN, O y NI NO están aquí a propósito (auditoría 2026-09, ficha C): son
# negación y alternancia con carga semántica propia y seña propia en el
# catálogo (NO, SIN no tiene seña pero SÍ cambia el hecho declarado — se deja
# como palabra reconocida para que su pérdida se detecte en vez de tratarse
# como una partícula vacía). Tratarlas como partículas vacías significaba que
# "no presente el documento" y "presente el documento" pasaban el control de
# cobertura igual de bien aunque el resultado hubiera perdido la negación.
_PALABRAS_FUNCION = frozenset("""
EL LA LOS LAS UN UNA UNOS UNAS AL DEL LO
DE EN POR PARA CON SOBRE ENTRE HASTA DESDE HACIA TRAS ANTE BAJO
U QUE QUE SE ME TE NOS LES LE SU MIS TUS SUS
ES SON ERA ERAN FUE FUERON SER ESTAR ESTA ESTAN HAY HABER HA HAN
MUY MAS TAN YA PERO SI
""".split())


def recognize_input(text: str) -> list:
    """Palabras con contenido de la frase, tal y como las escribió la persona.

    No normaliza más allá de separar palabras: es el registro de lo dicho, y
    cualquier arreglo posterior se compara contra esto.

    "SI" es la única entrada de _PALABRAS_FUNCION que cambia de significado
    con la tilde: "si" (condición) no tiene seña propia y se descarta, pero
    "sí" (afirmación) tiene su propia glosa (SÍ) y es contenido. Filtrar por
    la forma sin tilde perdía la afirmación igual que la condición; aquí se
    mira la palabra tal como se escribió, antes de quitarle la tilde, para no
    confundir una con otra (ver docs/Catalogo_Acepciones_Audio_a_LSB.md).
    Escrito sin tilde ("si" queriendo decir "sí"), sigue sin poder
    distinguirse sin ver la cláusula completa: limitación conocida.
    """
    resultado = []
    for w in _PALABRA.findall(text):
        if w.upper() == "SÍ":
            resultado.append(w)
            continue
        if remove_accents(w.upper()) not in _PALABRAS_FUNCION:
            resultado.append(w)
    return resultado


def _clave(palabra: str) -> str:
    return remove_accents(palabra.upper())


def _es_nombre_propio(palabra: str, text: str) -> bool:
    """Mayúscula inicial en alguna posición que no es principio de frase.

    Es la señal disponible sin diccionario de nombres. Se usa solo para
    *proteger* deletreos legítimos ("Isaac" -> I,S,A,A,C), nunca para crearlos.

    Antes solo miraba la PRIMERA aparición de la palabra en el texto: en
    "Ana vino. Ana declaró que..." la primera "Ana" abre oración y la función
    devolvía False para las dos, aunque la segunda aparición sí prueba que es
    un nombre. Ahora basta con que UNA aparición no esté al principio de una
    oración. Si el nombre solo aparece una vez y justo al principio ("Ana
    vino", sin nada más), sigue sin poder distinguirse de una palabra común
    capitalizada por ir primera: esa ambigüedad requiere un diccionario de
    nombres o el propio corpus, no una heurística de posición (ver
    docs/Catalogo_Acepciones_Audio_a_LSB.md).
    """
    if not palabra[:1].isupper():
        return False
    pos = 0
    while True:
        pos = text.find(palabra, pos)
        if pos == -1:
            return False
        if text[:pos].strip()[-1:] not in ("", ".", "?", "!"):
            return True
        pos += 1


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
    # TERMS_TO_SPELL se deletrea por norma, no por ortografía. La detección de
    # nombre propio depende de la mayúscula inicial, así que "felcc" escrito en
    # minúscula perdía su deletreo y volvía como FELCC, una seña que el avatar
    # no tiene; "FELCC" sí lo conservaba. El deletreo de estos términos no
    # depende de cómo los escriba quien declara.
    deletreables = {_clave(t) for t in TERMS_TO_SPELL}
    incidencias = []

    resultado, huerfanas, i = [], [], 0
    while i < len(glosses):
        if len(glosses[i]) == 1 and glosses[i].isalpha():
            j = i
            while j < len(glosses) and len(glosses[j]) == 1 and glosses[j].isalpha():
                j += 1
            racha = "".join(glosses[i:j])
            objetivo = next((w for w in palabras if _clave(w) == _clave(racha)), None)
            if objetivo and (_clave(objetivo) in propios
                             or _clave(objetivo) in deletreables):
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


# ---------------------------------------------------------------------------
# Pertenencia real al catálogo (auditoría 2026-09, ficha D)
# ---------------------------------------------------------------------------
# `_VALID_GLOSS` solo comprueba FORMA (mayúsculas, dígitos, guiones): una
# glosa inventada mientras tenga esa forma la pasaba igual que una real. Este
# conjunto es la pertenencia real, normalizada igual que `canonical_gloss`
# (sin tildes) para no rechazar por acento una glosa legítima ("CÓMO" del
# catálogo frente al "COMO" que produce `canonical_gloss`).
_AVAILABLE_GLOSSES_NORM = {strip_gloss_accents(g) for g in AVAILABLE_GLOSSES}


def _spell_out(word: str) -> list:
    """[word] deletreada letra por letra, preservando la Ñ.

    A diferencia de `_clave` (que usa `remove_accents` y por tanto convierte
    Ñ en N para comparar), aquí cada letra es una glosa dactilológica en sí
    misma: la Ñ deletreada tiene que seguir siendo Ñ. Los dígitos también se
    conservan: una cifra de varios dígitos ("25") se muestra dígito a dígito
    en vez de desaparecer.
    """
    return [c for c in strip_gloss_accents(word.upper()) if c.isalnum()]


def enforce_catalog_membership(glosses: list,
                               verified_animation_glosses=None) -> tuple:
    """Ninguna glosa que no esté en el catálogo sale como si fuera una seña real.

    Antes, `post_process_glosses` solo comprobaba FORMA: una glosa bien escrita
    pero inventada ("ROBOXYZ", o un alias retirado como "BILLETERA" tras la
    ficha B) se marcaba `available: false` y se ofrecía en dactilología de la
    palabra entera de todos modos, como si "no tener animación" y "no ser una
    seña documentada" fueran el mismo problema. Aquí se separan: lo que no
    está en el catálogo se deletrea letra por letra (con su propia glosa por
    letra, todas sí catalogadas) y se dice explícitamente que ese concepto no
    tiene seña, en vez de dejarlo pasar con apariencia de traducción válida.
    """
    verified_animation_glosses = {
        strip_gloss_accents(g.upper())
        for g in (verified_animation_glosses or ())
    }
    resultado, incidencias = [], []
    for gloss in glosses:
        clave = strip_gloss_accents(gloss.upper())
        if (clave in _AVAILABLE_GLOSSES_NORM
                or clave in verified_animation_glosses
                or len(clave) <= 1):
            resultado.append(gloss)
            continue
        resultado.extend(_spell_out(gloss))
        incidencias.append({
            "palabra": gloss,
            "accion": "concepto_sin_catalogo",
            "detalle": "No es una glosa documentada; se deletreó en vez de "
                       "inventar o forzar una seña parecida.",
        })
    return resultado, incidencias


# ---------------------------------------------------------------------------
# Desambiguación pendiente para términos polisémicos documentados
# (auditoría 2026-09, ficha "AUTO" — sección 5 del encargo)
# ---------------------------------------------------------------------------
# Reglas deterministas y locales, no otra llamada al modelo: para el conjunto
# reducido de términos aquí listados, la resolución de acepción se hace (o se
# pregunta) sin depender de que Bedrock la acierte, y sin poder ser anulada
# por lo que Bedrock haya devuelto. Ampliar esta tabla es la vía para cubrir
# más términos (BANCO, MÓVIL, EFECTIVO quedan pendientes — ver
# docs/Catalogo_Acepciones_Audio_a_LSB.md): cada uno necesita revisar primero
# si el catálogo tiene una seña distinta por acepción, que hoy no es el caso.
_AMBIGUOUS_TERMS = {
    "AUTO": {
        "question": '"auto" puede ser un vehículo o un documento judicial '
                     "(resolución). ¿Cuál de los dos se quiso decir?",
        "options": [
            {"id": "vehiculo", "label": "Vehículo"},
            {"id": "resolucion", "label": "Documento judicial (resolución)"},
        ],
        "context_signals": {
            "resolucion": {"JUEZ", "JUZGADO", "EMITIO", "EMITIR", "EMITIDO",
                           "RESOLUCION", "EXPEDIENTE", "SENTENCIA", "DICTO",
                           "DICTAR", "DICTAMINO"},
            "vehiculo": {"ESTACIONADO", "ESTACIONAR", "MANEJAR", "CONDUCIR",
                         "PLACA", "CHOFER", "CHOCO", "CHOCAR", "VOLANTE",
                         "GASOLINA", "ESTACIONO"},
        },
        # Seña resultante por acepción, o None si el catálogo no tiene una
        # seña propia para esa acepción (se deletrea en vez de fabricarla).
        "resolved_gloss": {"resolucion": "RESOLUCIÓN", "vehiculo": None},
    },
}


def resolve_ambiguous_terms(text: str, resolved_senses: dict = None) -> tuple:
    """Decide o pregunta el sentido de los términos de `_AMBIGUOUS_TERMS`.

    Devuelve (glosas_forzadas, ambigüedades_pendientes):
      - glosas_forzadas: {término: glosa_o_None} para los términos presentes
        en el texto cuyo sentido ya se pudo fijar (por `resolved_senses` o por
        una señal de contexto de un solo lado).
      - ambigüedades_pendientes: lista de preguntas para los términos
        presentes en el texto sin evidencia suficiente para elegir.
    """
    resolved_senses = resolved_senses or {}
    texto_norm = remove_accents(text.upper())
    señales = {remove_accents(w.upper()) for w in _PALABRA.findall(text)}

    forzadas, pendientes = {}, []
    for termino, spec in _AMBIGUOUS_TERMS.items():
        if not re.search(rf"\b{termino}\b", texto_norm):
            continue

        elegido = resolved_senses.get(termino) or resolved_senses.get(termino.lower())
        if elegido in spec["resolved_gloss"]:
            forzadas[termino] = spec["resolved_gloss"][elegido]
            continue

        lados = {lado for lado, palabras_lado in spec["context_signals"].items()
                  if palabras_lado & señales}
        if len(lados) == 1:
            forzadas[termino] = spec["resolved_gloss"][next(iter(lados))]
        else:
            pendientes.append({
                "term": termino,
                "question": spec["question"],
                "options": spec["options"],
                "resolved": False,
            })

    return forzadas, pendientes


# ---------------------------------------------------------------------------
# Pérdidas verificables de negación y cifras (auditoría 2026-09, ficha F)
# ---------------------------------------------------------------------------
# Dos comprobaciones deterministas y demostrables sobre la salida, igual que
# `repair_coverage`: no son un analizador semántico y no deciden si el resto
# de la traducción es fiel. Antes NO, SIN, O y NI eran palabras función (no se
# comprobaba su pérdida) y las cifras nunca entraban en `recognize_input`
# (su regex no incluye dígitos), así que ninguna de las dos pérdidas se podía
# detectar nunca, sin importar qué tan mal tradujera el modelo.
_NEGACION_GLOSAS = {"NO", "NO_PUEDO", "NO_SABER", "NO_ESTAR_DE_ACUERDO", "PROHIBIDO"}
_NEGACION_PALABRAS = {"NO", "SIN", "NI"}
_DIGITO_A_GLOSA = {
    "0": "CERO", "1": "UNO", "2": "DOS", "3": "TRES", "4": "CUATRO",
    "5": "CINCO", "6": "SEIS", "7": "SIETE", "8": "OCHO", "9": "NUEVE",
}


def detect_fidelity_losses(glosses: list, text: str) -> list:
    """Incidencias cuando el texto tenía negación o cifras que la salida no."""
    incidencias = []
    claves_salida = {_clave(g) for g in glosses}

    palabras_texto = {remove_accents(w.upper()) for w in _PALABRA.findall(text)}
    if palabras_texto & _NEGACION_PALABRAS and not (claves_salida & _NEGACION_GLOSAS):
        incidencias.append({
            "accion": "negacion_perdida",
            "detalle": "El texto tiene una negación (no/sin/ni) que ninguna "
                       "glosa de la traducción representa.",
        })

    for digito in sorted(set(re.findall(r"\d", text))):
        glosa_num = _DIGITO_A_GLOSA[digito]
        if _clave(glosa_num) not in claves_salida and digito not in claves_salida:
            incidencias.append({
                "accion": "cifra_perdida",
                "detalle": f"El texto tiene la cifra '{digito}' que no "
                           "aparece en la traducción.",
            })
    return incidencias


def post_process_glosses(bedrock_result: dict, text: str, resolved_senses: dict = None) -> dict:
    """
    Valida las glosas retornadas por Bedrock contra el diccionario
    del avatar y marca cuáles requieren dactilología.
    """
    raw_glosses = bedrock_result.get("glosses", [])
    disambiguation = list(bedrock_result.get("disambiguation", []))

    # Saneado de forma: lo que devuelve el modelo es tan poco confiable como lo
    # que entró. Se filtra antes de comprobar cobertura, para que la reparación
    # trabaje sobre glosas ya bien formadas.
    limpias = []
    for gloss in raw_glosses:
        if not isinstance(gloss, str):
            continue
        # Normalizar y resolver el alias va antes de validar la forma. Al
        # revés, una glosa acentuada ("MÉDICO", "DECLARACIÓN") no pasaba la
        # lista blanca y la palabra desaparecía de la traducción sin dejar
        # rastro, y ningún alias con espacio o tilde llegaba a aplicarse nunca.
        candidata = canonical_gloss(gloss)
        if not _VALID_GLOSS.match(candidata):
            logger.warning("Glosa descartada por formato: %.60r", gloss)
            continue
        limpias.append(candidata)

    # Fusión inteligente de bigramas conocidos (ej: "PRIMERA" + "VEZ" -> "PRIMERA_VEZ")
    fused = []
    idx = 0
    while idx < len(limpias):
        if (
            idx + 1 < len(limpias)
            and limpias[idx] == "PRIMERA"
            and limpias[idx + 1] == "VEZ"
        ):
            fused.append("PRIMERA_VEZ")
            idx += 2
        else:
            fused.append(limpias[idx])
            idx += 1
    limpias = fused

    # Reconocimiento rápido: si la frase incluye "primera vez" y no se incluyó, agregarla al inicio (tiempo)
    if re.search(r'\bprimera\s+vez\b', text, re.IGNORECASE) and "PRIMERA_VEZ" not in limpias:
        limpias.insert(0, "PRIMERA_VEZ")

    # Términos polisémicos documentados: la decisión (o la pregunta) manda
    # sobre lo que haya dicho Bedrock, no al revés.
    forzadas, pendientes = resolve_ambiguous_terms(text, resolved_senses)
    for termino, glosa_forzada in forzadas.items():
        glosa_norm = _clave(glosa_forzada) if glosa_forzada else None
        limpias = [g for g in limpias if _clave(g) != termino
                   and (glosa_norm is None or _clave(g) != glosa_norm)]
        # Si el catálogo no tiene seña para esta acepción (glosa_forzada es
        # None), se conserva el término tal cual para que se deletree más
        # abajo (`enforce_catalog_membership`) en vez de desaparecer: la
        # persona dijo "auto" y ese hecho no se pierde solo porque el avatar
        # no tenga la seña de vehículo.
        limpias.append(glosa_forzada or termino)
    for item in pendientes:
        termino = item["term"]
        # Ningún sentido se afirma mientras esté pendiente: se retira el
        # término tal cual y cualquier glosa que el modelo haya derivado de él
        # para alguna de sus acepciones documentadas.
        glosas_en_juego = {_clave(g) for g in
                           _AMBIGUOUS_TERMS[termino]["resolved_gloss"].values() if g}
        limpias = [g for g in limpias
                   if _clave(g) != termino and _clave(g) not in glosas_en_juego]
        disambiguation.append(item)

    # Las frases compuestas verificadas tienen prioridad absoluta sobre la
    # salida del modelo. La lista real de clips evita forzar una seña declarada
    # en una regla antigua pero ausente del GLB.
    clips = get_baked_clips()
    limpias, compuestas_verificadas = enforce_baked_compound_glosses(
        limpias, text, clips,
    )

    # Reconocimiento frente a generación: aquí se comprueba que la
    # representación no haya perdido ninguna palabra de lo que se dijo.
    raw_glosses, incidencias = repair_coverage(limpias, text)

    # Ninguna glosa que salga de aquí puede ser una invención: lo que no está
    # documentado se deletrea en vez de presentarse como una seña real.
    raw_glosses, incidencias_catalogo = enforce_catalog_membership(
        raw_glosses, compuestas_verificadas,
    )
    incidencias += incidencias_catalogo

    incidencias += detect_fidelity_losses(raw_glosses, text)
    if incidencias:
        logger.info("Fidelidad corregida: %s", incidencias)

    glosas_finales = []
    for gloss in raw_glosses:
        # Una palabra recuperada puede no tener forma de glosa (acentos, signos)
        # y no debe rotular una seña en pantalla si no la tiene.
        gloss_upper = canonical_gloss(gloss)
        if not _VALID_GLOSS.match(gloss_upper):
            logger.warning("Glosa descartada por formato: %.60r", gloss)
            continue
        glosas_finales.append(gloss_upper)

    # Dos estados distintos a propósito (sección 7 del encargo): un significado
    # pendiente de aclarar (`semanticStatus`) es un problema diferente de una
    # representación LSB incompleta (`representationStatus`). Resolver uno no
    # resuelve el otro, así que no comparten un solo campo de "éxito".
    return attach_animation_plan({
        "glosses": glosas_finales,
        "disambiguation": disambiguation,
        "pendingClarifications": pendientes,
        "semanticStatus": "needs_clarification" if pendientes else "resolved",
        # Reconocimiento: qué se dijo, separado de cómo se representa.
        "inputWords": recognize_input(text),
        "fidelityFixes": incidencias,
    })


def attach_animation_plan(result: dict) -> dict:
    """Añade a [result] cómo se reproduce cada glosa en el avatar.

    Va separado de la traducción porque cambia con otro ritmo: la traducción
    de una frase es estable y se cachea, pero qué señas tiene el avatar cambia
    cada vez que se sube un .glb nuevo. Por eso se recalcula también al servir
    desde caché — si no, una seña recién horneada seguiría deletreándose.

    `animationSequence` es la lista plana de pasos que el cliente reproduce en
    orden: una seña con clip es un paso; una palabra sin clip se expande en un
    paso por letra.
    """
    clips = get_baked_clips()
    detalles, secuencia = [], []
    for gloss in result.get("glosses", []):
        detalle, pasos = plan_gloss_animation(gloss, clips)
        detalles.append(detalle)
        secuencia.extend(pasos)

    perdida_no_recuperable = any(
        inc.get("accion") in ("negacion_perdida", "cifra_perdida")
        for inc in result.get("fidelityFixes", [])
    )
    incompleta = any(not d["available"] for d in detalles) or perdida_no_recuperable

    return {
        **result,
        "glossDetails": detalles,
        "animationSequence": secuencia,
        "representationStatus": "partial" if incompleta else "complete",
        "totalGlosses": len(detalles),
        "availableInAvatar": sum(1 for d in detalles if d["available"]),
        "requiresDactylology": sum(1 for d in detalles if not d["available"]),
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


def generate_cache_key(text: str, situation: str = None, resolved_senses: dict = None) -> str:
    """
    Genera un hash MD5 determinista de la frase normalizada.

    La situación y el sentido elegido para un término ambiguo forman parte de
    la clave porque forman parte del resultado: la misma frase traducida bajo
    'denuncia_robo' y bajo 'violencia', o con "auto" resuelto como vehículo o
    como resolución, puede producir glosas distintas — servir una por la otra
    desde el caché sería devolver la traducción de otra conversación o de otro
    significado ya elegido por otra persona.
    """
    normalized = text.lower().strip()
    normalized = re.sub(r'\s+', ' ', normalized)
    if situation:
        normalized = f"{normalized}|{situation}"
    if resolved_senses:
        senses_key = ",".join(f"{k}={v}" for k, v in sorted(resolved_senses.items()))
        normalized = f"{normalized}|senses:{senses_key}"
    # El modelo forma parte de la clave: cambiar BEDROCK_MODEL_ID cambia la
    # traducción, y servir la del modelo anterior sería devolver el resultado
    # de un sistema que ya no está en producción.
    seed = (f"{CACHE_VERSION}|{TRANSLATION_RULESET_VERSION}|"
            f"{BEDROCK_MODEL_ID}|{normalized}")
    return hashlib.md5(seed.encode("utf-8")).hexdigest()


# ---------------------------------------------------------------------------
# Caché de resultados semánticos (Amazon S3)
# ---------------------------------------------------------------------------
# En una ventanilla las mismas frases se repiten constantemente ("¿me permite
# su carnet?", "¿dónde ocurrió el hecho?"). Guardar el resultado indexado por
# el hash de la frase convierte esa repetición en una lectura de objeto, en
# lugar de una inferencia facturada de varios segundos.
#
# Se usa S3 porque el bucket ya existe y el volumen de escritura
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
        "situation": "denuncia_robo",     # opcional
        "resolvedSenses": {"AUTO": "vehiculo"} }  # opcional, ver
                                                    # `pendingClarifications`
    Retorna:
      { "glosses": [...], "glossDetails": [...], "disambiguation": [...],
        "pendingClarifications": [...], "semanticStatus": "resolved",
        "representationStatus": "complete", "situation": "denuncia_robo" }
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

    # Sentido ya elegido por la persona para un término ambiguo de una
    # solicitud anterior (p. ej. {"AUTO": "vehiculo"}), tras responder la
    # pregunta de `pendingClarifications`. Se valida su forma: no es un campo
    # libre que pueda inyectar una glosa arbitraria.
    resolved_senses_raw = body.get("resolvedSenses")
    resolved_senses = {}
    if isinstance(resolved_senses_raw, dict):
        for k, v in resolved_senses_raw.items():
            if isinstance(k, str) and isinstance(v, str) and len(k) <= 32 and len(v) <= 32:
                resolved_senses[k.strip().upper()] = v.strip().lower()

    cache_key = generate_cache_key(text, situation, resolved_senses)

    logger.info(
        "Texto recibido: '%s' | Contexto: %s | Situación: %s | Hash: %s",
        text, context_type, situation or "-", cache_key,
    )

    # 3. Verificar caché antes de gastar una invocación de Bedrock
    cached = check_cache(cache_key)
    if cached:
        logger.info("Cache HIT — respuesta servida desde caché: %s", cache_key)
        # La traducción sale de la caché, pero qué señas tiene el avatar se
        # comprueba ahora: el .glb puede haber cambiado desde que se guardó.
        return build_response(200, {**attach_animation_plan(cached), "cacheHit": True})

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
    result = post_process_glosses(bedrock_result, text, resolved_senses)

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
