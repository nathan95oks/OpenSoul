"""
Lambda: translate-lsb-dev — Arquitectura Híbrida
Motor Inteligente Propio + Bedrock como Refinador Complementario

Flujo:
  1. Recibe glosas LSB desde la app Flutter
  2. Análisis semántico propio (clasifica roles gramaticales)
  3. Representación intermedia (estructura JSON semántica)
  4. Generación de oración base (reglas y plantillas propias)
  5. Refinamiento opcional con Bedrock (solo pulir redacción)
  6. Síntesis de audio con Polly → S3
  7. Respuesta JSON con baseSentence + generatedText

Dominio: Trámites y consultas ciudadanas en entidades públicas bolivianas
Autor: Nathanael Alba — Proyecto de Grado OpenSoul
"""

import json
import os
import hashlib
import logging
import re

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger("lsb-to-text-audio")
logger.setLevel(logging.INFO)

S3_BUCKET = os.environ.get("S3_BUCKET", "opensoul-lsb-audio-dev")
APP_PREFIX = os.environ.get("APP_PREFIX", "lsb-to-text-audio")
VOICE_ID = os.environ.get("VOICE_ID", "Lupe")
BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "global.amazon.nova-2-lite-v1:0").strip()
APP_REGION = os.environ.get("APP_REGION", os.environ.get("AWS_REGION", "us-east-1"))
ENABLE_BEDROCK = os.environ.get("ENABLE_BEDROCK", "true").lower() == "true"

bedrock_runtime = boto3.client("bedrock-runtime", region_name=APP_REGION)
polly_client = boto3.client("polly", region_name=APP_REGION)
s3_client = boto3.client("s3", region_name=APP_REGION)

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Content-Type": "application/json",
}

GLOSS_LEXICON = {
    # GENERADO por tool/sync_vocabulary.dart — no editar a mano.
    # Fuente: el lexicón del cliente, para que servidor y cliente
    # compongan la misma oración a partir de las mismas glosas.
    "ABOGADO": {"rol": "SERVICIO", "es": "un abogado"},
    "ABUSAR": {"rol": "VERBO", "es": "abusó sexualmente", "agresor": "abusó sexualmente"},
    "ACCIDENTE": {"rol": "URGENCIA", "es": "hubo un accidente"},
    "ACEPTAR": {"rol": "VERBO", "es": "acepto"},
    "ACLARAR": {"rol": "VERBO", "es": "quiero aclarar"},
    "ACOMPANAR": {"rol": "VERBO", "es": "necesito que me acompañen"},
    "ACUERDO_SOCIAL": {"rol": "DOCUMENTO", "es": "un acuerdo"},
    "ADMINISTRAR": {"rol": "VERBO", "es": "quiero administrar"},
    "AEROPUERTO": {"rol": "LUGAR", "es": "en el aeropuerto"},
    "AHORA": {"rol": "TIEMPO", "es": "ahora mismo"},
    "ALCALDIA": {"rol": "INSTITUCION", "es": "en la alcaldía"},
    "AMARILLO": {"rol": "DESCRIPTOR", "es": "de color amarillo"},
    "AMENAZAR": {"rol": "VERBO", "es": "amenazó", "agresor": "amenazó"},
    "ANEXO": {"rol": "DOCUMENTO", "es": "un anexo"},
    "ANO": {"rol": "TIEMPO", "es": "este año"},
    "ANOTAR": {"rol": "VERBO", "es": "quiero anotar"},
    "ANTEAYER": {"rol": "TIEMPO", "es": "anteayer"},
    "ANTERIORMENTE": {"rol": "TIEMPO", "es": "anteriormente"},
    "ARCHIVADOR": {"rol": "DOCUMENTO", "es": "el archivador"},
    "ARRESTAR": {"rol": "VERBO", "es": "arrestó", "agresor": "arrestó"},
    "ARTICULO": {"rol": "DOCUMENTO", "es": "el artículo"},
    "ASISTENCIA": {"rol": "URGENCIA", "es": "necesito asistencia"},
    "ASISTENTE": {"rol": "SERVICIO", "es": "un asistente"},
    "ATENDER": {"rol": "VERBO", "es": "necesito que me atiendan"},
    "AUDIENCIA": {"rol": "TRAMITE", "es": "una audiencia"},
    "AUTO": {"rol": "OBJETO", "es": "mi auto"},
    "AUTONOMIA": {"rol": "ESTADO", "es": "autónomo"},
    "AUTORIDAD": {"rol": "INSTITUCION", "es": "en la autoridad"},
    "AUXILIO": {"rol": "URGENCIA", "es": "necesito auxilio"},
    "AVENIDA": {"rol": "LUGAR", "es": "en la avenida"},
    "AVION": {"rol": "OBJETO", "es": "el avión"},
    "AVISAR": {"rol": "VERBO", "es": "quiero avisar"},
    "AYER": {"rol": "TIEMPO", "es": "ayer"},
    "AYUDAR": {"rol": "VERBO", "es": "necesito ayuda"},
    "AZUL": {"rol": "DESCRIPTOR", "es": "de color azul"},
    "BICICLETA": {"rol": "OBJETO", "es": "mi bicicleta"},
    "BILLETERA": {"rol": "OBJETO", "es": "mi billetera"},
    "BLANCO": {"rol": "DESCRIPTOR", "es": "de color blanco"},
    "CAFE": {"rol": "DESCRIPTOR", "es": "de color café"},
    "CALLE": {"rol": "LUGAR", "es": "en la calle"},
    "CAMARA": {"rol": "OBJETO", "es": "una cámara"},
    "CARCEL": {"rol": "LUGAR", "es": "en la cárcel"},
    "CARNET": {"rol": "DOCUMENTO", "es": "mi carnet de identidad"},
    "CARPETA": {"rol": "DOCUMENTO", "es": "la carpeta"},
    "CARTA": {"rol": "DOCUMENTO", "es": "la carta"},
    "CASA": {"rol": "LUGAR", "es": "en mi casa"},
    "CASO": {"rol": "TRAMITE", "es": "mi caso"},
    "CELESTE": {"rol": "DESCRIPTOR", "es": "de color celeste"},
    "CENTRO_DE_SALUD": {"rol": "LUGAR", "es": "en el centro de salud"},
    "CERTIFICADO": {"rol": "DOCUMENTO", "es": "un certificado"},
    "CITACION": {"rol": "TRAMITE", "es": "una citación"},
    "COCHABAMBA": {"rol": "LUGAR", "es": "en Cochabamba"},
    "CODIGO": {"rol": "TRAMITE", "es": "el código"},
    "COMO": {"rol": "DESCONOCIDO", "es": "cómo"},
    "COMPRENDER": {"rol": "VERBO", "es": "quiero comprender"},
    "COMPROBANTE": {"rol": "DOCUMENTO", "es": "un comprobante"},
    "COMPROMISO": {"rol": "ESTADO", "es": "comprometido"},
    "CONFESAR": {"rol": "VERBO", "es": "quiero confesar"},
    "CONFIANZA": {"rol": "ESTADO", "es": "tengo confianza"},
    "CONFIRMACION": {"rol": "DOCUMENTO", "es": "la confirmación"},
    "CONFUSION": {"rol": "ESTADO", "es": "estoy confundido"},
    "CONOCER": {"rol": "VERBO", "es": "conozco"},
    "CONSTANCIA": {"rol": "DOCUMENTO", "es": "una constancia"},
    "CONTEXTO": {"rol": "DOCUMENTO", "es": "el contexto"},
    "COORDINADOR": {"rol": "SERVICIO", "es": "un coordinador"},
    "COORDINAR": {"rol": "VERBO", "es": "quiero coordinar"},
    "COPIAR": {"rol": "VERBO", "es": "quiero una copia"},
    "CORRECTO": {"rol": "DESCRIPTOR", "es": "correcto"},
    "CORREGIR": {"rol": "VERBO", "es": "quiero corregir"},
    "CORRER": {"rol": "VERBO", "es": "salió corriendo", "agresor": "salió corriendo"},
    "CORRUPTO": {"rol": "DESCRIPTOR", "es": "corrupto"},
    "CRISIS": {"rol": "URGENCIA", "es": "es una crisis"},
    "CUAL": {"rol": "DESCONOCIDO", "es": "cuál"},
    "CUANDO": {"rol": "DESCONOCIDO", "es": "cuándo"},
    "CUANTOS": {"rol": "DESCONOCIDO", "es": "cuántos"},
    "CUENTA": {"rol": "OBJETO", "es": "mi cuenta"},
    "CUMPLIR": {"rol": "VERBO", "es": "quiero cumplir"},
    "DANAR": {"rol": "VERBO", "es": "dañó", "agresor": "dañó"},
    "DECIDIR": {"rol": "VERBO", "es": "quiero decidir"},
    "DECRETO_SUPREMO": {"rol": "DOCUMENTO", "es": "el decreto supremo"},
    "DELGADO": {"rol": "DESCRIPTOR", "es": "delgado"},
    "DEPARTAMENTO": {"rol": "LUGAR", "es": "en el departamento"},
    "DESPACHO": {"rol": "INSTITUCION", "es": "en el despacho"},
    "DIA": {"rol": "TIEMPO", "es": "ese día"},
    "DIGNIDAD": {"rol": "DESCRIPTOR", "es": "digno"},
    "DINERO": {"rol": "OBJETO", "es": "mi dinero"},
    "DIRECCION": {"rol": "LUGAR", "es": "en esa dirección"},
    "DISCRIMINACION": {"rol": "VERBO", "es": "discriminó", "agresor": "discriminó"},
    "DOCTOR": {"rol": "SERVICIO", "es": "un doctor"},
    "DONDE": {"rol": "DESCONOCIDO", "es": "dónde"},
    "EL": {"rol": "SUJETO", "es": "él"},
    "ELLA": {"rol": "SUJETO", "es": "ella"},
    "ELLOS": {"rol": "SUJETO", "es": "ellos"},
    "ENFERMERA": {"rol": "SERVICIO", "es": "una enfermera"},
    "ESCRIBIR": {"rol": "VERBO", "es": "quiero escribir"},
    "ESTADO": {"rol": "DOCUMENTO", "es": "el estado del trámite"},
    "ESTOY_BIEN": {"rol": "DESCONOCIDO", "es": "estoy bien"},
    "ETICA": {"rol": "DESCRIPTOR", "es": "ético"},
    "EXIGIR": {"rol": "VERBO", "es": "quiero exigir"},
    "EXPAREJA": {"rol": "DESCRIPTOR", "es": "mi expareja", "persona": True},
    "EXPEDIENTE": {"rol": "TRAMITE", "es": "mi expediente"},
    "FALTA": {"rol": "ESTADO", "es": "por una falta"},
    "FAMILIAR": {"rol": "DESCRIPTOR", "es": "un familiar", "persona": True},
    "FARMACIA": {"rol": "LUGAR", "es": "en la farmacia"},
    "FECHA": {"rol": "TIEMPO", "es": "en esa fecha"},
    "FIRME": {"rol": "DESCRIPTOR", "es": "firme"},
    "FISCAL": {"rol": "INSTITUCION", "es": "en la fiscalía"},
    "FORMATO": {"rol": "DOCUMENTO", "es": "el formato"},
    "FORMULARIO": {"rol": "DOCUMENTO", "es": "el formulario"},
    "FOTOCOPIA": {"rol": "DOCUMENTO", "es": "una fotocopia"},
    "FOTOGRAFIA": {"rol": "OBJETO", "es": "una fotografía"},
    "GARANTE": {"rol": "ESTADO", "es": "garante"},
    "GESTIONAR": {"rol": "VERBO", "es": "quiero gestionar"},
    "GOBIERNO": {"rol": "INSTITUCION", "es": "en el gobierno"},
    "GRACIAS": {"rol": "DESCONOCIDO", "es": "gracias"},
    "GRUESO": {"rol": "DESCRIPTOR", "es": "grueso"},
    "HABLAR": {"rol": "VERBO", "es": "quiero hablar"},
    "HERIDA": {"rol": "URGENCIA", "es": "tengo una herida"},
    "HOJA": {"rol": "DOCUMENTO", "es": "una hoja"},
    "HOLA": {"rol": "DESCONOCIDO", "es": "hola"},
    "HOMBRE": {"rol": "DESCRIPTOR", "es": "un hombre", "persona": True},
    "HONESTIDAD": {"rol": "DESCRIPTOR", "es": "honesto"},
    "HORA": {"rol": "TIEMPO", "es": "hace una hora"},
    "HOSPITAL": {"rol": "LUGAR", "es": "en el hospital"},
    "HOY": {"rol": "TIEMPO", "es": "hoy"},
    "IDENTIDAD": {"rol": "DESCRIPTOR", "es": "mi identidad", "persona": True},
    "IDENTIFICAR": {"rol": "VERBO", "es": "quiero identificar"},
    "IMPRIMIR": {"rol": "VERBO", "es": "quiero imprimir"},
    "INOCENTE": {"rol": "DESCRIPTOR", "es": "inocente"},
    "INSTITUCION": {"rol": "INSTITUCION", "es": "en la institución"},
    "INTERPRETE": {"rol": "SERVICIO", "es": "un intérprete de señas"},
    "INVESTIGACION": {"rol": "TRAMITE", "es": "una investigación"},
    "JUEZ": {"rol": "INSTITUCION", "es": "en el juzgado"},
    "JUICIO": {"rol": "TRAMITE", "es": "un juicio"},
    "JURAR": {"rol": "VERBO", "es": "quiero jurar"},
    "JUSTICIA": {"rol": "DOCUMENTO", "es": "la justicia"},
    "LADRON": {"rol": "DESCRIPTOR", "es": "un ladrón", "persona": True},
    "LEY": {"rol": "DOCUMENTO", "es": "la ley"},
    "LICENCIA": {"rol": "DOCUMENTO", "es": "mi licencia"},
    "LICENCIA_DECONDUCIR": {"rol": "DOCUMENTO", "es": "mi licencia de conducir"},
    "LILA": {"rol": "DESCRIPTOR", "es": "de color lila"},
    "LO_SIENTO": {"rol": "DESCONOCIDO", "es": "lo siento"},
    "MAL": {"rol": "ESTADO", "es": "me siento mal"},
    "MALTRATAR": {"rol": "VERBO", "es": "maltrató", "agresor": "maltrató"},
    "MANANA": {"rol": "TIEMPO", "es": "mañana"},
    "MAS_O_MENOS": {"rol": "DESCONOCIDO", "es": "más o menos"},
    "MEMORIAL": {"rol": "DOCUMENTO", "es": "un memorial"},
    "MENSAJE": {"rol": "OBJETO", "es": "un mensaje"},
    "MERCADO": {"rol": "LUGAR", "es": "en el mercado"},
    "MES": {"rol": "TIEMPO", "es": "este mes"},
    "MICRO": {"rol": "OBJETO", "es": "el micro"},
    "MIEDO": {"rol": "ESTADO", "es": "tengo miedo"},
    "MILITAR": {"rol": "DESCRIPTOR", "es": "un militar", "persona": True},
    "MINISTERIO": {"rol": "INSTITUCION", "es": "en el ministerio"},
    "MINUTO": {"rol": "TIEMPO", "es": "hace unos minutos"},
    "MOCHILA": {"rol": "OBJETO", "es": "mi mochila"},
    "MOSTRAR": {"rol": "VERBO", "es": "quiero mostrar"},
    "MOTOCICLETA": {"rol": "OBJETO", "es": "mi motocicleta"},
    "MUJER": {"rol": "DESCRIPTOR", "es": "una mujer", "persona": True},
    "NARANJA": {"rol": "DESCRIPTOR", "es": "de color naranja"},
    "NARRAR": {"rol": "VERBO", "es": "quiero narrar"},
    "NEGRO": {"rol": "DESCRIPTOR", "es": "de color negro"},
    "NO": {"rol": "DESCONOCIDO", "es": "no"},
    "NOMBRE": {"rol": "DESCRIPTOR", "es": "mi nombre", "persona": True},
    "NORMA": {"rol": "DOCUMENTO", "es": "la norma"},
    "NOSOTROS": {"rol": "SUJETO", "es": "nosotros"},
    "NOTIFICACION": {"rol": "TRAMITE", "es": "una notificación"},
    "NO_ENTIENDO": {"rol": "DESCONOCIDO", "es": "no entiendo"},
    "NO_PUEDO": {"rol": "DESCONOCIDO", "es": "no puedo"},
    "NO_RECUERDO": {"rol": "DESCONOCIDO", "es": "no recuerdo"},
    "NO_SABER": {"rol": "DESCONOCIDO", "es": "no sé"},
    "NUREJ": {"rol": "TRAMITE", "es": "mi NUREJ"},
    "OBSERVACION": {"rol": "DOCUMENTO", "es": "una observación"},
    "OBSERVAR": {"rol": "VERBO", "es": "quiero observar"},
    "OFICIAL": {"rol": "INSTITUCION", "es": "en el oficial"},
    "OFICINA": {"rol": "INSTITUCION", "es": "en la oficina"},
    "ORGANO_JUDICIAL": {"rol": "INSTITUCION", "es": "en el órgano judicial"},
    "PAPEL": {"rol": "DOCUMENTO", "es": "el papel"},
    "PARADA": {"rol": "LUGAR", "es": "en la parada"},
    "PARAR": {"rol": "VERBO", "es": "se detuvo", "agresor": "se detuvo"},
    "PARA_QUE": {"rol": "DESCONOCIDO", "es": "para qué"},
    "PAREJA": {"rol": "DESCRIPTOR", "es": "mi pareja", "persona": True},
    "PASADO_MANANA": {"rol": "TIEMPO", "es": "pasado mañana"},
    "PASAPORTE": {"rol": "DOCUMENTO", "es": "mi pasaporte"},
    "PEDIR": {"rol": "VERBO", "es": "quiero solicitar"},
    "PELIGROSO": {"rol": "DESCRIPTOR", "es": "peligroso"},
    "PERDER": {"rol": "VERBO", "es": "perdí"},
    "PERMISO": {"rol": "DESCONOCIDO", "es": "con permiso"},
    "PERSONERIA_JURIDICA": {"rol": "DOCUMENTO", "es": "la personería jurídica"},
    "PISO": {"rol": "LUGAR", "es": "en el piso"},
    "PLAZA": {"rol": "LUGAR", "es": "en la plaza"},
    "PODER": {"rol": "DOCUMENTO", "es": "un poder notarial"},
    "POLICIA": {"rol": "INSTITUCION", "es": "en la policía"},
    "POR_FAVOR": {"rol": "DESCONOCIDO", "es": "por favor"},
    "POR_QUE": {"rol": "DESCONOCIDO", "es": "por qué"},
    "PRESENTAR": {"rol": "VERBO", "es": "quiero presentar"},
    "PRESO": {"rol": "DESCRIPTOR", "es": "detenido"},
    "PRIMERA_VEZ": {"rol": "TIEMPO", "es": "es la primera vez"},
    "PROBLEMA": {"rol": "ESTADO", "es": "por un problema"},
    "PRODUCTO": {"rol": "OBJETO", "es": "el producto"},
    "PROTEGER": {"rol": "VERBO", "es": "necesito protección"},
    "PRUEBA": {"rol": "OBJETO", "es": "una prueba"},
    "PUEDE_REPETIR": {"rol": "DESCONOCIDO", "es": "¿puede repetir?"},
    "PUEDO": {"rol": "DESCONOCIDO", "es": "sí puedo"},
    "QUE": {"rol": "DESCONOCIDO", "es": "qué"},
    "QUEJAR": {"rol": "VERBO", "es": "quiero presentar una queja"},
    "QUIEN": {"rol": "DESCONOCIDO", "es": "quién"},
    "RAZON": {"rol": "ESTADO", "es": "por esa razón"},
    "RECHAZAR": {"rol": "VERBO", "es": "rechazo"},
    "RECOGER": {"rol": "VERBO", "es": "quiero recoger"},
    "RECONOCER": {"rol": "VERBO", "es": "quiero reconocer"},
    "RECORDAR": {"rol": "VERBO", "es": "recuerdo"},
    "REGLAMENTO": {"rol": "DOCUMENTO", "es": "el reglamento"},
    "REQUISITO": {"rol": "TRAMITE", "es": "un requisito"},
    "RESOLUCION": {"rol": "DOCUMENTO", "es": "la resolución"},
    "RESPALDO": {"rol": "DOCUMENTO", "es": "un respaldo"},
    "RESPONDER": {"rol": "VERBO", "es": "quiero responder"},
    "ROBAR": {"rol": "VERBO", "es": "robó", "agresor": "robó"},
    "ROJO": {"rol": "DESCRIPTOR", "es": "de color rojo"},
    "ROSADO": {"rol": "DESCRIPTOR", "es": "de color rosado"},
    "SABER": {"rol": "DESCONOCIDO", "es": "sí sé"},
    "SALVAR": {"rol": "VERBO", "es": "me salvó", "agresor": "me salvó"},
    "SEGUIMIENTO": {"rol": "VERBO", "es": "quiero seguir"},
    "SEGUNDO": {"rol": "TIEMPO", "es": "hace un segundo"},
    "SEGURO": {"rol": "ESTADO", "es": "me encuentro en un lugar seguro"},
    "SELLO": {"rol": "DOCUMENTO", "es": "el sello"},
    "SEMANA": {"rol": "TIEMPO", "es": "esta semana"},
    "SI": {"rol": "DESCONOCIDO", "es": "sí"},
    "SITUACION": {"rol": "ESTADO", "es": "por esta situación"},
    "SOBORNO": {"rol": "VERBO", "es": "ofreció un soborno", "agresor": "ofreció un soborno"},
    "SOLDADO": {"rol": "DESCRIPTOR", "es": "un soldado", "persona": True},
    "SOLUCIONAR": {"rol": "VERBO", "es": "quiero solucionar"},
    "SOSPECHA": {"rol": "ESTADO", "es": "tengo una sospecha"},
    "SUBSANACION": {"rol": "TRAMITE", "es": "una subsanación"},
    "TAXI": {"rol": "OBJETO", "es": "el taxi"},
    "TELEFONO": {"rol": "OBJETO", "es": "mi teléfono"},
    "TEMOR": {"rol": "ESTADO", "es": "siento temor"},
    "TESTIGO": {"rol": "DESCRIPTOR", "es": "un testigo", "persona": True},
    "TESTIMONIO": {"rol": "DOCUMENTO", "es": "mi testimonio"},
    "TEXTO": {"rol": "DOCUMENTO", "es": "el texto"},
    "TITULO": {"rol": "DOCUMENTO", "es": "mi título"},
    "TRAMITE": {"rol": "TRAMITE", "es": "un trámite"},
    "TRATAR": {"rol": "VERBO", "es": "quiero tratar"},
    "TREN": {"rol": "OBJETO", "es": "el tren"},
    "TRUFI": {"rol": "OBJETO", "es": "el trufi"},
    "TU": {"rol": "SUJETO", "es": "tú"},
    "UBICACION_GPS": {"rol": "LUGAR", "es": "en esta ubicación"},
    "USTEDES": {"rol": "SUJETO", "es": "ustedes"},
    "VARIAS_VECES": {"rol": "TIEMPO", "es": "varias veces"},
    "VECINO": {"rol": "DESCRIPTOR", "es": "un vecino", "persona": True},
    "VENTANILLA": {"rol": "INSTITUCION", "es": "en la ventanilla"},
    "VERDE": {"rol": "DESCRIPTOR", "es": "de color verde"},
    "VERGUENZA": {"rol": "ESTADO", "es": "siento vergüenza"},
    "VIDEOLLAMADA": {"rol": "OBJETO", "es": "una videollamada"},
    "VIOLACION": {"rol": "VERBO", "es": "violó", "agresor": "violó"},
    "VIOLENCIA": {"rol": "VERBO", "es": "ejerció violencia", "agresor": "ejerció violencia"},
    "WEBID": {"rol": "TRAMITE", "es": "mi WebID"},
    "WHATSAPP": {"rol": "OBJETO", "es": "WhatsApp"},
    "WIFI": {"rol": "OBJETO", "es": "wifi"},
    "YO": {"rol": "SUJETO", "es": "yo"},
    "ZOOM": {"rol": "OBJETO", "es": "Zoom"},
}

# ===================================================================
# COMPOSICIÓN DE TIEMPO — paridad 1:1 con LocalSentenceAssembler (Dart)
# ===================================================================
# Una unidad de tiempo no cierra la respuesta: encadena a una cantidad.
# [SEMANA]+[2] no es "esta semana" más un dos huérfano, es "hace dos semanas".
#
# La dirección NO la elige la persona: el diccionario no tiene PASADO ni
# FUTURO —se verificó, no existe ningún marcador de dirección— así que la
# aporta el flujo, que ya sabe si narra un hecho consumado o pide un plazo.
#
# Si esto no existiera, el servidor devolvería "esta semana" y perdería el
# dígito; `isBackendDegenerate` en el cliente detectaría la glosa no
# representada y descartaría la respuesta entera. La paridad no es estética.

# Género y formas de cada unidad. El género importa para la cantidad 1
# ("hace UNA semana" pero "hace UN día"); el plural, para el resto.
_TIME_UNITS = {
    "MINUTO": {"femenino": False, "singular": "minuto", "plural": "minutos"},
    "HORA":   {"femenino": True,  "singular": "hora",   "plural": "horas"},
    "DIA":    {"femenino": False, "singular": "día",    "plural": "días"},
    "SEMANA": {"femenino": True,  "singular": "semana", "plural": "semanas"},
    "MES":    {"femenino": False, "singular": "mes",    "plural": "meses"},
    "ANO":    {"femenino": False, "singular": "año",    "plural": "años"},
}

_CARDINALES = {
    "1": "un", "2": "dos", "3": "tres", "4": "cuatro", "5": "cinco",
    "6": "seis", "7": "siete", "8": "ocho", "9": "nueve",
}

# Contextos que narran un hecho ya ocurrido. Incluye los dos juegos de
# nombres: el cliente manda el id de UI ('tramite', 'consulta') mientras que
# su motor local trabaja con el contexto ya resuelto ('perdida',
# 'tramite_id'). Sin ambos, un documento perdido saldría "hace dos semanas"
# en el cliente y "dentro de dos semanas" en el servidor.
# Espejo de _inherentEvidence / _flightVerbs en el cliente.
# Nadie roba una fotografía ni daña un certificado: se aportan para acreditar.
_INHERENT_EVIDENCE = {
    "FOTOGRAFIA", "PRUEBA", "MENSAJE", "COMPROBANTE", "CERTIFICADO", "RESPALDO",
}
# La huida es lo que hizo el agresor DESPUÉS, no lo que me hizo. Como agresión
# producía "un hombre me salió corriendo": falso y agramatical.
_FLIGHT_VERBS = {"CORRER"}

# Reincidencia, no fecha. Espejo de _frequencyGlosses en el cliente: sin esta
# separación PRIMERA_VEZ ocupaba el complemento temporal y desplazaba a AYER,
# con lo que la denuncia perdía cuándo ocurrió el hecho.
_FREQUENCY_GLOSSES = {
    "PRIMERA_VEZ": "Es la primera vez que ocurre",
    "VARIAS_VECES": "Ha ocurrido varias veces",
    "ANTERIORMENTE": "Ya había ocurrido anteriormente",
}

_PAST_CONTEXTS = {
    "denuncia_robo", "violencia", "accidente", "emergencia", "otro", "perdida",
}


def _time_direction_is_past(analysis: dict, context_type: str) -> bool:
    """Réplica de `resolveAssemblerContext` + `_pastContexts` del cliente.

    'tramite' es el único id de UI ambiguo: se reparte entre pérdida (pasado)
    y gestión (futuro) según lo que la persona haya elegido, exactamente con
    el mismo criterio que el cliente —un objeto o la glosa PERDER.
    """
    ctx = (context_type or "").strip().lower()
    if ctx in _PAST_CONTEXTS:
        return True
    if ctx == "tramite":
        if analysis["objetos"]:
            return True
        return any(v["glosa"] == "PERDER" for v in analysis["verbos"])
    return False


def _resolve_time(analysis: dict, context_type: str) -> None:
    """Funde unidad + cantidad en un único complemento temporal ya redactado.

    Deja `analysis["tiempos"]` con una sola entrada para que los generadores
    no cambien: siguen leyendo `tiempos[0]["es"]` como siempre.
    """
    unidad = analysis.pop("_tiempo_unidad", None)
    cantidad = analysis.pop("_tiempo_cantidad", None)
    if not unidad:
        return

    spec = _TIME_UNITS[unidad]

    # Unidad sin cantidad: la cadena quedó abierta y se resuelve con la forma
    # deíctica del propio lexema ("esta semana"), que sigue siendo válida.
    if not cantidad:
        entry = GLOSS_LEXICON.get(unidad)
        if entry and not analysis["tiempos"]:
            analysis["tiempos"].insert(0, {"glosa": unidad, **entry})
        return

    if cantidad == "1":
        cardinal = "una" if spec["femenino"] else "un"
        medida = spec["singular"]
    else:
        cardinal = _CARDINALES[cantidad]
        medida = spec["plural"]

    es_pasado = _time_direction_is_past(analysis, context_type)
    direccion = "hace" if es_pasado else "dentro de"

    # Se antepone: es el complemento temporal principal del relato.
    analysis["tiempos"].insert(0, {
        "glosa": unidad,
        "rol": "TIEMPO",
        "es": f"{direccion} {cardinal} {medida}",
        # Los generadores de trámite lo consultan para no narrar un plazo en
        # pasado ("Ocurrió dentro de dos semanas").
        "futuro": not es_pasado,
    })


def _join_spelled_digits(cards: list) -> list:
    """Une rachas de dígitos en un solo número. Espejo de `_joinSpelled`.

    Una racha es UN número deletreado —el NUREJ, un teléfono— y debe
    conservarse entero ("1","2","3" → "123"). Un dígito aislado no se toca:
    si sigue a una unidad de tiempo lo recoge la cadena temporal, y si no, es
    ruido que se descarta.
    """
    salida, i = [], 0
    normalizadas = [str(c).upper().strip() for c in cards]
    while i < len(normalizadas):
        if normalizadas[i] in _CARDINALES:
            j = i
            while j < len(normalizadas) and normalizadas[j] in _CARDINALES:
                j += 1
            if j - i >= 2:
                salida.append("".join(normalizadas[i:j]))
                i = j
                continue
        salida.append(normalizadas[i])
        i += 1
    return salida


def analyze_glosses(cards: list) -> dict:
    """
    Clasifica cada glosa por su rol semántico usando el lexicón.
    Detecta el tipo de evento basado en la combinación de verbos,
    documentos, trámites e instituciones.
    """
    analysis = {
        "sujetos": [], "verbos": [], "documentos": [], "tramites": [],
        "tiempos": [], "instituciones": [], "descriptores": [], "urgencias": [],
        "servicios": [], "estados": [], "objetos": [], "lugares": [],
        # Descriptores de la persona AGREDIDA (tras el marcador VICTIMA en el
        # flujo de testigo). Se separan para no fundirlos con el agresor.
        "victima_descriptores": [],
        "evidencias": [],
        "huida": None,
        "frecuencia": None,
        "desconocidos": [],
    }

    # Tras el marcador VICTIMA, los descriptores describen a la persona
    # agredida (no al agresor). Mantiene la coherencia del relato de testigo.
    victim_mode = False
    for card in _join_spelled_digits(cards):
        key = card.upper().strip()
        if key == "VICTIMA":
            victim_mode = True
            continue

        # CAMBIO (paridad Dart): reincidencia antes que tiempo.
        if key in _FREQUENCY_GLOSSES:
            analysis.setdefault("frecuencia", None)
            if not analysis["frecuencia"]:
                analysis["frecuencia"] = _FREQUENCY_GLOSSES[key]
            continue

        # CAMBIO (paridad Dart): material probatorio, venga de donde venga.
        # Sin esto una fotografía acababa como botín del robo o como lo dañado:
        # "me robó mi motocicleta y una fotografía".
        if key in _INHERENT_EVIDENCE:
            entry = GLOSS_LEXICON.get(key)
            if entry:
                analysis.setdefault("evidencias", []).append({"glosa": key, **entry})
            continue

        # CAMBIO (paridad Dart): huida del agresor, no agresión contra mí.
        if key in _FLIGHT_VERBS:
            entry = GLOSS_LEXICON.get(key)
            if entry:
                analysis["huida"] = entry["es"]
            continue

        # CAMBIO (paridad Dart): el rol de cantidad es POSICIONAL, no léxico.
        # Un dígito solo cuenta como cantidad si viene detrás de una unidad de
        # tiempo que aún no la tiene. Fuera de esa posición sigue siendo
        # dactilología —el número de un NUREJ, un teléfono— y cae en
        # "desconocidos", que es donde debe estar.
        if (key in _CARDINALES
                and analysis.get("_tiempo_unidad")
                and not analysis.get("_tiempo_cantidad")):
            analysis["_tiempo_cantidad"] = key
            continue

        # Una unidad de tiempo abre la cadena en vez de cerrar la respuesta.
        if key in _TIME_UNITS:
            analysis.setdefault("_tiempo_unidad", key)
            continue

        entry = GLOSS_LEXICON.get(key)
        if entry and entry["rol"] == "DESCRIPTOR" and victim_mode:
            analysis["victima_descriptores"].append({"glosa": key, **entry})
            continue
        if entry:
            rol = entry["rol"]
            mapping = {
                "SUJETO": "sujetos", "VERBO": "verbos",
                "DOCUMENTO": "documentos", "TRAMITE": "tramites",
                "TIEMPO": "tiempos", "INSTITUCION": "instituciones",
                "DESCRIPTOR": "descriptores", "URGENCIA": "urgencias",
                "SERVICIO": "servicios", "ESTADO": "estados",
                "OBJETO": "objetos", "LUGAR": "lugares",
            }
            dest = mapping.get(rol, "desconocidos")
            analysis[dest].append({"glosa": key, **entry})
        elif key in _CARDINALES:
            # CAMBIO (paridad Dart): dígito huérfano —sin unidad de tiempo
            # delante— no significa nada por sí solo. Emitirlo producía
            # "Adicionalmente, hago referencia a 2" en una declaración que
            # puede acabar en un expediente.
            continue
        else:
            analysis["desconocidos"].append({"glosa": key, "rol": "DESCONOCIDO", "es": key.lower()})

    analysis["tipo_evento"] = _detect_event_type(analysis)
    analysis["perspectiva"] = _detect_perspective(analysis)

    return analysis

def _detect_event_type(analysis: dict, context_type: str = "") -> str:
    # CAMBIO (paridad Dart): el cliente NO deduce la plantilla, la elige el
    # contexto — `'accidente' || 'emergencia' => _composeEmergency`. Aquí se
    # deducía por heurística y ganaba la rama equivocada: con
    # [MAL, DOCTOR, AHORA] el servicio (DOCTOR) se evaluaba antes que el
    # estado y caía en "SOLICITUD", cuyo generador ignora los estados. El
    # resultado era "Solicito un doctor ahora mismo": un trámite, no una
    # urgencia vital, y el estado de salud desaparecía de la declaración.
    if (context_type or "").strip().lower() in ("accidente", "emergencia"):
        return "EMERGENCIA"

    verbos = [v["glosa"] for v in analysis["verbos"]]
    tramites = [t["glosa"] for t in analysis["tramites"]]
    documentos = [d["glosa"] for d in analysis["documentos"]]

    # CAMBIO: estas dos ramas enumeraban glosas a mano y quedaron obsoletas
    # con la sustitución del corpus: de las 32 que nombraba esta función, 24 ya
    # no existen (GOLPEAR, SECUESTRAR, ASALTAR, EMPUJAR…), y de los 13 verbos
    # de agresión reales solo ROBAR y AMENAZAR figuraban. El resto —MALTRATAR,
    # ABUSAR, VIOLACION, DISCRIMINACION, DANAR, VIOLENCIA— caía a "GENERAL",
    # cuyo generador ignora descriptores y lugares: una denuncia de violencia
    # perdía al agresor y el domicilio y salía como "Maltrató.".
    #
    # Ahora se deduce del propio lexicón. El flag `agresor` lo emite
    # tool/sync_vocabulary.dart para todo verbo de rol `verboAgresion`, así que
    # un verbo nuevo del corpus se clasifica solo, sin tocar esta lista.
    if "ROBAR" in verbos:
        return "ROBO"
    if any(v.get("agresor") for v in analysis["verbos"]):
        return "AGRESION"

    if any(v in ["TRAMITAR", "RENOVAR", "INSCRIBIR", "REGISTRAR"] for v in verbos):
        return "TRAMITE"
    if any(v in ["CONSULTAR", "PREGUNTAR"] for v in verbos):
        return "CONSULTA"
    if any(v in ["PAGAR"] for v in verbos) or any(t in ["PAGO"] for t in tramites):
        return "PAGO"
    if any(v in ["SOLICITAR", "PEDIR", "NECESITAR", "AYUDA", "AYUDAR"] for v in verbos):
        return "SOLICITUD"
    if any(v in ["RECOGER", "ENTREGAR"] for v in verbos):
        return "ENTREGA"
    if any(v in ["DENUNCIAR", "QUEJAR"] for v in verbos) or any(t in ["RECLAMO", "QUEJA", "DENUNCIA"] for t in tramites):
        return "RECLAMO"
    if any(v in ["PERDER"] for v in verbos):
        return "PERDIDA"
    if any(v in ["FIRMAR", "CORREGIR", "VERIFICAR"] for v in verbos):
        return "GESTION"
    if analysis["urgencias"] or any(v in ["EMERGENCIA"] for v in verbos):
        return "EMERGENCIA"
    if tramites:
        return "TRAMITE"
    if documentos:
        return "SOLICITUD"
    if analysis["servicios"]:
        return "SOLICITUD"
    if analysis["estados"]:
        return "ESTADO"
    return "GENERAL"

def _detect_perspective(analysis: dict) -> str:
    for s in analysis["sujetos"]:
        if s.get("perspectiva") == "1P":
            return "PRIMERA_PERSONA"
    return "PRIMERA_PERSONA"  

def build_intermediate_representation(cards: list, analysis: dict, context_type: str) -> dict:
    # CAMBIO (paridad Dart): cierra la cadena temporal antes de generar.
    # Va aquí, y no en analyze_glosses, porque la dirección depende del
    # contexto; y aquí, y no en el handler, porque es el único paso que
    # SIEMPRE precede a la generación: en el handler, cualquier otro punto de
    # entrada perdía el complemento temporal en silencio.
    _resolve_time(analysis, context_type)

    # CAMBIO: se reevalúa aquí porque `analyze_glosses` no conoce el contexto
    # y la plantilla depende de él (ver _detect_event_type).
    analysis["tipo_evento"] = _detect_event_type(analysis, context_type)

    return {
        "roles": {
            "sujeto": analysis["sujetos"][0]["glosa"] if analysis["sujetos"] else None,
            "verbo_principal": analysis["verbos"][0]["glosa"] if analysis["verbos"] else None,
            "documento": [d["glosa"] for d in analysis["documentos"]] if analysis["documentos"] else None,
            "tramite": [t["glosa"] for t in analysis["tramites"]] if analysis["tramites"] else None,
            "tiempo": analysis["tiempos"][0]["glosa"] if analysis["tiempos"] else None,
            "institucion": [i["glosa"] for i in analysis["instituciones"]] if analysis["instituciones"] else None,
            "descriptores": [d["glosa"] for d in analysis["descriptores"]] if analysis["descriptores"] else None,
            "servicios": [s["glosa"] for s in analysis["servicios"]] if analysis["servicios"] else None,
            "urgencia": analysis["urgencias"][0]["glosa"] if analysis["urgencias"] else None,
            "estados": [e["glosa"] for e in analysis["estados"]] if analysis["estados"] else None,
            "objetos": [o["glosa"] for o in analysis["objetos"]] if analysis["objetos"] else None,
            "lugar": [l["glosa"] for l in analysis["lugares"]] if analysis["lugares"] else None,
        },
        "tipo_evento": analysis["tipo_evento"],
        "perspectiva": analysis["perspectiva"],
        "contexto": context_type,
        "total_glosas": len(cards),
        "glosas_originales": cards,
        "glosas_reconocidas": len(cards) - len(analysis["desconocidos"]),
    }

_FORMAL_INSTITUTIONS = {"entidad_publica", "formal", "legal", "ciudadano", "judicial"}

_FORMAL_CONTEXTS = {
    "ciudadano", "formal", "legal",
    "denuncia_robo", "violencia", "accidente", "emergencia",
    "otro", "orientacion", "tramite_id", "perdida",
}

_VOICE_BY_LANG = {
    "es-bo": ("Lupe", "es-US"),
    "es-mx": ("Mia", "es-MX"),
    "es-us": ("Lupe", "es-US"),
    "es":    ("Lupe", "es-US"),
}

def _is_formal(context_type: str, institution_type: str = "") -> bool:
    """True si la solicitud corresponde a una gestión formal/entidad pública."""
    return (institution_type.lower() in _FORMAL_INSTITUTIONS
            or context_type.lower() in _FORMAL_CONTEXTS)

def generate_base_sentence(ir: dict, analysis: dict, context_type: str,
                           institution_type: str = "") -> str:
    """
    Genera una oración base en español usando reglas gramaticales propias
    y plantillas por tipo de evento. Este es el NÚCLEO del sistema.
    Orientado a trámites y consultas ciudadanas en entidades públicas.
    """
    tipo = ir["tipo_evento"]
    is_formal = _is_formal(context_type, institution_type)

    generators = {
        "ROBO": _gen_robo,
        "AGRESION": _gen_agresion,
        "TRAMITE": _gen_tramite,
        "CONSULTA": _gen_consulta,
        "PAGO": _gen_pago,
        "SOLICITUD": _gen_solicitud,
        "ENTREGA": _gen_entrega,
        "RECLAMO": _gen_reclamo,
        "PERDIDA": _gen_perdida,
        "GESTION": _gen_gestion,
        "EMERGENCIA": _gen_emergencia,
        "ESTADO": _gen_estado,
    }

    gen_func = generators.get(tipo, _gen_general)
    sentence = gen_func(ir, analysis, is_formal)

    # CAMBIO: red de seguridad de estados. Solo 2 de los 13 generadores leen
    # `estados`; los otros 11 los descartaban en silencio, así que un "me
    # siento mal" desaparecía de la declaración según qué plantilla tocara.
    # Se resuelve en UN punto —como `_ensureCoverage` en el cliente— en vez de
    # repetir la regla en cada plantilla, que es lo que dejó el agujero.
    sentence = _append_unused_states(sentence, analysis, is_formal)
    # CAMBIO: evidencia y huida sobreviven a cualquier plantilla, igual que los
    # estados. Once de los trece generadores no las leen.
    if analysis.get("evidencias"):
        pruebas = _join_es([e["es"] for e in analysis["evidencias"]])
        if _normalizar(pruebas) not in _normalizar(sentence):
            sentence = sentence.rstrip(".") + f". Como prueba tengo {pruebas}"
    if analysis.get("huida"):
        huida = analysis["huida"]
        if _normalizar(huida) not in _normalizar(sentence):
            sentence = sentence.rstrip(".") + f". {huida[0].upper()}{huida[1:]}"
    if analysis.get("frecuencia"):
        frec = analysis["frecuencia"]
        if _normalizar(frec) not in _normalizar(sentence):
            sentence = sentence.rstrip(".") + f". {frec}"

    # CAMBIO: trámites y glosas desconocidas que ninguna plantilla recogió.
    # _gen_solicitud, por ejemplo, lee documentos pero no trámites, así que un
    # NUREJ se perdía; y los "desconocidos" —un número deletreado, una palabra
    # fuera del corpus— no se emitían en ninguna plantilla, mientras que el
    # cliente sí los conserva. Toda glosa que el cliente represente y el
    # servidor no hace que la respuesta entera se descarte.
    residuo = [t["es"] for t in analysis.get("tramites", [])]
    residuo += [d["es"] for d in analysis.get("desconocidos", [])]
    faltan = [x for x in residuo if _normalizar(x) not in _normalizar(sentence)]
    if faltan:
        sentence = (sentence.rstrip(".")
                    + f". Adicionalmente, hago referencia a {_join_es(faltan)}")

    sentence = re.sub(r'\s+', ' ', sentence).strip()
    # CAMBIO: varios generadores devuelven la frase en minúscula porque la
    # construyen a partir del lexema del verbo ("quiero solicitar…"). Se
    # normaliza en un único punto —igual que `_asSentence` en el cliente— en
    # vez de repetir la regla en cada plantilla.
    if sentence:
        sentence = sentence[0].upper() + sentence[1:]
    if sentence and not sentence.endswith('.'):
        sentence += '.'

    return sentence

def _append_unused_states(sentence: str, analysis: dict, is_formal: bool) -> str:
    """Ningún estado físico o emocional puede perderse.

    En un accidente, "me siento mal" es el núcleo del parte: omitirlo degrada
    una urgencia vital a un trámite. Y en cualquier contexto, una glosa que la
    persona eligió y no aparece hace que el cliente descarte la respuesta
    entera por cobertura incompleta.
    """
    if not analysis["estados"]:
        return sentence

    plano = _normalizar(sentence)
    clausulas, adjuntos = [], []
    for estado in analysis["estados"]:
        texto = estado.get("formal", estado["es"]) if is_formal else estado["es"]
        if _normalizar(texto) in plano:
            continue  # el generador ya lo integró
        # Los motivos ("por un problema", "por esta situación") no son una
        # oración: se pegan a la anterior. El resto sí lo es.
        (adjuntos if texto.startswith("por ") else clausulas).append(texto)

    if adjuntos:
        sentence = sentence.rstrip(".") + " " + _join_es(adjuntos)
    for texto in clausulas:
        sentence = sentence.rstrip(".") + ". " + texto[0].upper() + texto[1:]
    return sentence


def _normalizar(texto: str) -> str:
    tabla = str.maketrans("áéíóúÁÉÍÓÚñÑ", "aeiouAEIOUnN")
    return texto.translate(tabla).lower()


def _get_time_institution(analysis, is_formal):
    """Complemento de tiempo + institución, sin artículos ni nexos duplicados.

    CAMBIO: antes anteponía `i.get('prep', 'en')` al lexema. Pero el lexema
    del backend se genera desde el cliente y YA trae la preposición dentro
    ("en la fiscalía"), y las claves `prep`/`art`/`formal` dejaron de emitirse
    cuando `tool/sync_vocabulary.dart` pasó a generar el GLOSS_LEXICON. El
    `.get(..., 'en')` caía siempre al valor por defecto y producía
    "En EN LA fiscalía EN EN EL despacho".

    Y unía las instituciones con un espacio: la segunda quedaba pegada sin
    nexo. Ahora se enlazan con `_join_es`, que ya pone la coma y la "y".
    """
    parts = []
    for t in analysis["tiempos"]:
        parts.append(t["es"])
    instituciones = [i["es"] for i in analysis["instituciones"]]
    if instituciones:
        parts.append(_join_es(instituciones))
    return " ".join(p for p in parts if p)

def _get_urgency(analysis, is_formal):
    """CAMBIO: devolvía solo `urgencias[0]` y el resto se perdía.

    Con HERIDA y AUXILIO juntos salía "Tengo una herida" y el auxilio —lo más
    apremiante de la denuncia— desaparecía. Mismo patrón de índice [0] que ya
    se corrigió en lugares e instituciones.
    """
    return _join_es([u["es"] for u in analysis["urgencias"]])

def _get_documents_text(analysis, is_formal):
    if not analysis["documentos"]:
        return ""
    # CAMBIO: mismo defecto que en las instituciones. El lexema ya trae su
    # determinante ("un certificado", "mi carnet de identidad") y el
    # `.get("art", "el")` lo duplicaba: "el un certificado".
    return _join_es([d["es"] for d in analysis["documentos"]])

def _get_tramite_text(analysis, is_formal):
    if not analysis["tramites"]:
        return ""
    # CAMBIO: idéntico al anterior — "el un trámite".
    return analysis["tramites"][0]["es"]



def _join_es(items):
    items = [i for i in items if i]
    if not items:
        return ""
    if len(items) == 1:
        return items[0]
    return ", ".join(items[:-1]) + " y " + items[-1]

def _objetos_text(analysis):
    objs = [o["es"] for o in analysis["objetos"] if not o.get("arma")]
    return _join_es(objs)

def _arma_text(analysis):
    for o in analysis["objetos"]:
        if o.get("arma"):
            return f'con {o["es"]}'
    return ""

def _a_destino(complemento: str) -> str:
    """Convierte un complemento locativo en destino. Paridad con `_toDestino`.

    Las instituciones se lexicalizan como complemento de "estar" ("en la
    fiscalía"), pero "acudir" rige "a": "acudir en la fiscalía" no es español.
    """
    if complemento.startswith("en el "):
        return "al " + complemento[6:]
    if complemento.startswith("en la "):
        return "a la " + complemento[6:]
    if complemento.startswith("en "):
        return "a " + complemento[3:]
    return complemento


def _lugar_text(analysis):
    """CAMBIO: devolvía solo `lugares[0]` y el resto se perdía.

    Con dos lugares elegidos, el segundo no aparecía en la oración y la red de
    cobertura del cliente lo soltaba al final ("…hago constar en la plaza").
    """
    return _join_es([l["es"] for l in analysis["lugares"]])

def _agresor_text(analysis):
    personas = [d for d in analysis["descriptores"] if d.get("persona")]
    rasgos = [d for d in analysis["descriptores"] if not d.get("persona")]
    if personas:
        # Un descriptor "mi X" (PAREJA, EXPAREJA, FAMILIAR…) ya es una frase
        # nominal completa y específica, no un rasgo apilable como "un joven".
        # Pegarlo detrás de "una mujer" da "una mujer mi pareja" (agramatical).
        # Si hay alguno, ese manda: es más informativo que un género/edad
        # genérico y no hace falta repetir ambos.
        relacionales = [p["es"] for p in personas if p["es"].startswith("mi ")]
        if relacionales:
            otros = [p["es"] for p in personas if not p["es"].startswith("mi ")]
            base = _join_es(relacionales) if not otros else f'{_join_es(relacionales)}, {", ".join(otros)}'
        else:
            # Varios descriptores de persona (género + edad + relación) describen a
            # UNA misma persona, no a varias: se concatenan como una sola frase
            # nominal. El primero conserva su artículo ("una mujer") y el resto se
            # anexa como modificador sin artículo ("una mujer" + "un joven" →
            # "una mujer joven"). Antes solo se usaba personas[0] y se perdía el resto.
            base = personas[0]["es"]
            for p in personas[1:]:
                base += " " + re.sub(r'^(un|una|unos|unas)\s+', '', p["es"])
    else:
        base = "una persona"
    if rasgos:
        base += " " + _join_es([r["es"] for r in rasgos])
    return base

def _agresor_verb(analysis, default):
    for v in analysis["verbos"]:
        if v.get("agresor"):
            return v["agresor"]
    return default

def _compose_incident(analysis, is_formal, robo):
    """Relato de incidente con agresor en 3ª persona (robo / violencia)."""
    subj = _agresor_text(analysis)
    verb = _agresor_verb(analysis, "robó" if robo else "agredió")
    # Un sujeto en aposición ("mi pareja, una mujer") necesita la coma de
    # cierre antes de seguir la cláusula.
    subj_clause = f"{subj}," if "," in subj else subj
    core = f"{subj_clause} me {verb}"

    objs = _objetos_text(analysis)
    if objs:
        core += f" {objs}"
    arma = _arma_text(analysis)
    if arma:
        core += f" {arma}"
    lugar = _lugar_text(analysis)
    if lugar:
        core += f" {lugar}"
    # CAMBIO (paridad Dart): la huida cierra el relato, después del lugar —
    # "…me robó mi motocicleta en el mercado y salió corriendo".
    if analysis.get("huida"):
        core += f' y {analysis["huida"]}'
        analysis["huida"] = None

    tiempo = analysis["tiempos"][0]["es"] if analysis["tiempos"] else None
    sentence = core
    if tiempo:
        sentence = f"{tiempo[0].upper()}{tiempo[1:]}, {core[0].lower()}{core[1:]}"
    sentence = sentence[0].upper() + sentence[1:]

    parts = [f"{sentence}."]
    if analysis["estados"]:
        est = _join_es([e.get("formal", e["es"]) if is_formal else e["es"]
                        for e in analysis["estados"]])
        if est:
            parts.append(f"{est[0].upper()}{est[1:]}.")
    urg = _get_urgency(analysis, is_formal)
    if urg:
        parts.append(f"{urg[0].upper()}{urg[1:]}.")
    # CAMBIO (paridad Dart): la evidencia es su propia oración, no el objeto
    # directo de la agresión.
    if analysis.get("evidencias"):
        pruebas = _join_es([e["es"] for e in analysis["evidencias"]])
        parts.append(f"Como prueba tengo {pruebas}.")
        analysis["evidencias"] = []
    if analysis["servicios"]:
        svc = _join_es([s.get("formal", s["es"]) if is_formal else s["es"]
                        for s in analysis["servicios"]])
        parts.append(f"Necesito {svc}.")
    # CAMBIO (Tarea 2): el relato de incidente no leía las instituciones. Con
    # DISCRIMINACION + OFICIAL, la institución no aparecía en ninguna parte y
    # la red de cobertura del cliente la soltaba como "…hago constar en el
    # oficial" —o descartaba la respuesta entera—. Ahora cierra el relato con
    # el destino, que es lo que la persona quiere decir al nombrarla.
    instituciones = _join_es(
        [_a_destino(i["es"]) for i in analysis["instituciones"]])
    if instituciones:
        parts.append(f"Quiero acudir {instituciones}.")
    return " ".join(parts)

def _gen_robo(ir, analysis, is_formal):
    """Genera oración para denuncia de robo / asalto."""
    return _compose_incident(analysis, is_formal, robo=True)

def _gen_agresion(ir, analysis, is_formal):
    """Genera oración para violencia / agresión física o psicológica."""
    return _compose_incident(analysis, is_formal, robo=False)

def _gen_tramite(ir, analysis, is_formal):
    """Genera oración para trámites administrativos."""
    verbo = analysis["verbos"][0] if analysis["verbos"] else None
    doc_text = _get_documents_text(analysis, is_formal)
    tramite_text = _get_tramite_text(analysis, is_formal)
    tp = _get_time_institution(analysis, is_formal)

    if verbo and doc_text:
        v_text = verbo.get("formal", verbo.get("1p", verbo["es"])) if is_formal else verbo.get("1p", verbo["es"])
        base = f"{v_text} {doc_text}"
    elif verbo and tramite_text:
        v_text = verbo.get("formal", verbo.get("1p", verbo["es"])) if is_formal else verbo.get("1p", verbo["es"])
        base = f"{v_text} {tramite_text}" if "trámite" not in v_text.lower() else v_text
    elif tramite_text:
        base = f"Necesito realizar {tramite_text}" if not is_formal else f"Deseo realizar {tramite_text}"
    elif doc_text:
        base = f"Necesito tramitar {doc_text}" if not is_formal else f"Deseo tramitar {doc_text}"
    else:
        base = "Necesito realizar un trámite" if not is_formal else "Deseo realizar un trámite administrativo"

    if tp:
        base += f" {tp}"
    return base

def _gen_consulta(ir, analysis, is_formal):
    """Genera oración para consultas ciudadanas."""
    verbo = analysis["verbos"][0] if analysis["verbos"] else None
    doc_text = _get_documents_text(analysis, is_formal)
    tramite_text = _get_tramite_text(analysis, is_formal)
    tp = _get_time_institution(analysis, is_formal)

    if verbo and doc_text:
        base = f"Deseo consultar sobre {doc_text}" if is_formal else f"Quiero preguntar sobre {doc_text}"
    elif verbo and tramite_text:
        base = f"Deseo consultar sobre {tramite_text}" if is_formal else f"Quiero preguntar sobre {tramite_text}"
    elif analysis["servicios"]:
        svc = analysis["servicios"][0]
        svc_text = svc.get("formal", svc["es"]) if is_formal else svc["es"]
        base = f"Deseo consultar sobre {svc_text}" if is_formal else f"Quiero preguntar sobre {svc_text}"
    else:
        base = "Deseo realizar una consulta" if is_formal else "Tengo una pregunta"

    if tp:
        base += f" {tp}"
    return base

def _gen_pago(ir, analysis, is_formal):
    """Genera oración para pagos en entidades públicas."""
    doc_text = _get_documents_text(analysis, is_formal)
    tramite_text = _get_tramite_text(analysis, is_formal)
    tp = _get_time_institution(analysis, is_formal)

    if doc_text:
        base = f"Deseo realizar el pago de {doc_text}" if is_formal else f"Necesito pagar {doc_text}"
    elif tramite_text:
        base = f"Deseo realizar el pago correspondiente a {tramite_text}" if is_formal else f"Necesito pagar {tramite_text}"
    else:
        base = "Deseo realizar un pago" if is_formal else "Necesito hacer un pago"

    if tp:
        base += f" {tp}"
    return base

def _gen_solicitud(ir, analysis, is_formal):
    """Genera oración para solicitudes generales."""
    servicios = analysis["servicios"]
    verbo = analysis["verbos"][0] if analysis["verbos"] else None
    doc_text = _get_documents_text(analysis, is_formal)
    urg = _get_urgency(analysis, is_formal)
    tp = _get_time_institution(analysis, is_formal)

    parts = []
    if verbo and doc_text:
        v_text = verbo.get("formal", verbo.get("1p", verbo["es"])) if is_formal else verbo.get("1p", verbo["es"])
        parts.append(f"{v_text} {doc_text}")
    elif verbo:
        v_text = verbo.get("formal", verbo.get("1p", verbo["es"])) if is_formal else verbo.get("1p", verbo["es"])
        parts.append(v_text.capitalize())

    if servicios:
        svc_texts = [s.get("formal", s["es"]) if is_formal else s["es"] for s in servicios]
        if parts:
            parts.append("y solicito " + ", ".join(svc_texts))
        else:
            parts.append("Solicito " + ", ".join(svc_texts))

    if urg:
        parts.append(urg)

    base = " ".join(parts) if parts else "Necesito asistencia"
    if tp:
        base += f" {tp}"
    return base

def _gen_entrega(ir, analysis, is_formal):
    """Genera oración para entrega/recogida de documentos."""
    verbo = analysis["verbos"][0] if analysis["verbos"] else None
    doc_text = _get_documents_text(analysis, is_formal)
    tp = _get_time_institution(analysis, is_formal)

    if verbo and doc_text:
        v_text = verbo.get("formal", verbo.get("1p", verbo["es"])) if is_formal else verbo.get("1p", verbo["es"])
        base = f"{v_text} {doc_text}"
    elif verbo:
        v_text = verbo.get("formal", verbo.get("1p", verbo["es"])) if is_formal else verbo.get("1p", verbo["es"])
        base = f"{v_text} un documento"
    elif doc_text:
        base = f"Necesito retirar {doc_text}" if not is_formal else f"Deseo retirar {doc_text}"
    else:
        base = "Necesito retirar un documento" if not is_formal else "Deseo retirar un documento"

    if tp:
        base += f" {tp}"
    return base

def _gen_reclamo(ir, analysis, is_formal):
    """Genera oración para reclamos y quejas ciudadanas."""
    verbo = analysis["verbos"][0] if analysis["verbos"] else None
    tramite_text = _get_tramite_text(analysis, is_formal)
    servicios = analysis["servicios"]
    tp = _get_time_institution(analysis, is_formal)

    if verbo and verbo["glosa"] == "DENUNCIAR":
        base = verbo.get("formal", verbo.get("1p", verbo["es"])) if is_formal else verbo.get("1p", verbo["es"])
    elif tramite_text:
        base = f"Deseo presentar {tramite_text}" if is_formal else f"Quiero presentar {tramite_text}"
    else:
        base = "Deseo presentar un reclamo" if is_formal else "Quiero hacer un reclamo"

    if servicios:
        svc = servicios[0]
        svc_text = svc.get("formal", svc["es"]) if is_formal else svc["es"]
        base += f" sobre el servicio de {svc_text}"

    if tp:
        base += f" {tp}"
    return base

def _gen_perdida(ir, analysis, is_formal):
    """Genera oración para pérdida de documentos."""
    doc_text = _get_documents_text(analysis, is_formal)
    servicios = analysis["servicios"]
    tp = _get_time_institution(analysis, is_formal)

    if doc_text:
        base = f"He extraviado {doc_text}" if is_formal else f"Perdí {doc_text}"
    else:
        base = "He extraviado un documento personal" if is_formal else "Perdí un documento"

    tramites = analysis["tramites"]
    if tramites:
        t = tramites[0]
        t_text = t.get("formal", t["es"]) if is_formal else t["es"]
        base += f" y necesito {t_text}"
    elif servicios:
        svc = servicios[0]
        base += f" y requiero {svc.get('formal', svc['es'])}" if is_formal else f" y necesito {svc['es']}"

    if tp:
        base += f" {tp}"
    return base

def _gen_gestion(ir, analysis, is_formal):
    """Genera oración para gestiones (firmar, corregir, verificar)."""
    verbo = analysis["verbos"][0] if analysis["verbos"] else None
    doc_text = _get_documents_text(analysis, is_formal)
    tp = _get_time_institution(analysis, is_formal)

    if verbo and doc_text:
        v_text = verbo.get("formal", verbo.get("1p", verbo["es"])) if is_formal else verbo.get("1p", verbo["es"])
        base = f"{v_text} {doc_text}"
    elif verbo:
        v_text = verbo.get("formal", verbo.get("1p", verbo["es"])) if is_formal else verbo.get("1p", verbo["es"])
        base = v_text.capitalize()
    else:
        base = "Necesito realizar una gestión"

    if tp:
        base += f" {tp}"
    return base

def _gen_emergencia(ir, analysis, is_formal):
    """Genera oración para situaciones de emergencia."""
    sujeto = analysis["sujetos"][0] if analysis["sujetos"] else None
    servicios = analysis["servicios"]
    estados = analysis["estados"]

    if sujeto and sujeto["glosa"] != "YO":
        subj = sujeto["es"].capitalize()
    else:
        subj = None

    parts = []
    if subj and estados:
        est = estados[0]
        parts.append(f"{subj} se encuentra {est.get('formal', est['es'])}" if is_formal else f"{subj} está {est['es']}")
    elif estados:
        est = estados[0]
        parts.append(est.get("formal", est["es"]).capitalize() if is_formal else est["es"].capitalize())

    if servicios:
        svc = servicios[0]
        svc_text = svc.get("formal", svc["es"]) if is_formal else svc["es"]
        # CAMBIO: "de forma urgente" sobra cuando la persona ya eligió un
        # marcador temporal ("ahora mismo"): salía "un doctor de forma urgente
        # ahora mismo". El cliente redacta "Necesito un doctor." y deja que el
        # tiempo hable por sí solo.
        apremio = "" if analysis["tiempos"] else " de forma urgente"
        parts.append(f"y necesita {svc_text}{apremio}" if subj
                     else f"Necesito {svc_text}{apremio}")
    else:
        parts.append("Se requiere atención inmediata" if is_formal else "Es urgente")

    # CAMBIO: los tramos son oraciones independientes y se unían con un
    # espacio, produciendo "Me siento mal Se requiere atención inmediata".
    # Además se perdían la urgencia, el lugar y el tiempo: el generador de
    # emergencia no los leía y el cliente descartaba la respuesta entera por
    # cobertura incompleta.
    urgencia = _get_urgency(analysis, is_formal)
    if urgencia:
        parts.append(urgencia)

    if not parts:
        return "Se presenta una situación de emergencia"

    # Cada tramo es una oración propia: se separan con punto y cada una abre
    # en mayúscula. El lugar y el tiempo NO lo son —son complementos— y se
    # adjuntan a la última, con espacio.
    oraciones = [p.strip().rstrip(".") for p in parts if p.strip()]
    oraciones = [o[0].upper() + o[1:] for o in oraciones if o]

    complementos = [c for c in (_lugar_text(analysis),
                                _get_time_institution(analysis, is_formal)) if c]
    if complementos:
        oraciones[-1] = " ".join([oraciones[-1], *complementos])

    return ". ".join(oraciones)

def _gen_estado(ir, analysis, is_formal):
    """Genera oración para expresar estado personal."""
    estados = analysis["estados"]
    if estados:
        est = estados[0]
        return est.get("formal", est["es"]).capitalize() if is_formal else est["es"].capitalize()
    return "Me encuentro en una situación que requiere asistencia"

def _gen_general(ir, analysis, is_formal):
    """Fallback: construye oración uniendo los componentes detectados."""
    parts = []

    for v in analysis["verbos"]:
        parts.append(v.get("1p", v["es"]))
    for d in analysis["documentos"]:
        parts.append(f'{d.get("art", "")} {d["es"]}'.strip())
    for t in analysis["tramites"]:
        parts.append(t.get("formal", t["es"]) if is_formal else t["es"])
    for s in analysis["servicios"]:
        svc_text = s.get("formal", s["es"]) if is_formal else s["es"]
        parts.append(svc_text)

    tp = _get_time_institution(analysis, is_formal)
    if tp:
        parts.append(tp)

    if parts:
        sentence = parts[0].capitalize()
        if len(parts) > 1:
            sentence += " " + " ".join(parts[1:])
        return sentence

    all_es = []
    for cat in ["sujetos", "verbos", "documentos", "tramites", "tiempos", "instituciones", "servicios"]:
        for item in analysis[cat]:
            all_es.append(item["es"])
    for item in analysis["desconocidos"]:
        all_es.append(item["es"])

    return " ".join(all_es).capitalize() if all_es else " ".join(ir["glosas_originales"]).capitalize()

def refine_with_bedrock(base_sentence: str, context_type: str,
                        institution_type: str = "") -> str:
    """
    Envía la oración BASE (ya generada por el motor propio) a Bedrock
    para refinamiento de redacción. NO traduce glosas — solo pule.
    Si falla, retorna la oración base sin modificar (fallback elegante).
    Utiliza Few-shot Prompting para guiar el refinamiento.
    """
    if not ENABLE_BEDROCK:
        logger.info("Bedrock deshabilitado, usando oración base directamente.")
        return base_sentence

    logger.info("Refinando con modelo Bedrock: %s", BEDROCK_MODEL_ID)

    is_formal = _is_formal(context_type, institution_type)

    polisemia_rules = (" Si detectas la palabra 'Auto', asume que es una 'Resolución Judicial' "
                       "y no un vehículo, a menos que el contexto indique transporte.")

    ctx_instruction = ("Contexto de trámites y consultas ciudadanas en entidades públicas: "
                       "usa vocabulario formal, respetuoso y preciso propio de gestiones administrativas."
                       if is_formal
                       else "Contexto general: usa español claro y correcto.")

    prompt = f"""Eres un asistente que mejora la redacción de declaraciones en español formal boliviano para trámites en entidades públicas.
{ctx_instruction}
{polisemia_rules if is_formal else ""}

Te daré UNA sola "oración base". Devuelve esa MISMA oración con una redacción más fluida y formal, conservando exactamente su significado.

REGLAS ESTRICTAS:
1. Refina ÚNICAMENTE la oración base que aparece al final. NO inventes hechos, personas, objetos, lugares ni trámites que no estén en ella.
2. Conserva el mismo evento y los mismos elementos: si habla de un robo, sigue siendo un robo; NO lo cambies por un pago, un banco ni una factura.
3. Responde SOLO con la oración refinada, en una sola línea, sin etiquetas, sin markdown (nada de **, #) y sin comillas.
4. Si ya está bien redactada, devuélvela igual.

Estos ejemplos son SOLO de estilo (NO copies su contenido):
- "Necesito tramitar el carnet de identidad en el SEGIP." -> "Deseo realizar el trámite de mi carnet de identidad en las oficinas del SEGIP."
- "Un hombre me robó el celular en la calle." -> "Un hombre me sustrajo el teléfono celular en la vía pública."

Oración base a refinar:
"{base_sentence}"

Tu respuesta (solo la oración refinada):"""

    try:
        request_body = _build_bedrock_request_body(prompt)
        response = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL_ID, contentType="application/json",
            accept="application/json", body=json.dumps(request_body),
        )
        response_body = json.loads(response["body"].read())
        refined = _parse_bedrock_response(response_body)
        if not _refinement_is_safe(base_sentence, refined):
            logger.warning(
                "Refinamiento DESCARTADO por divergencia (posible alucinación): '%s' → '%s'",
                base_sentence, refined,
            )
            return base_sentence
        logger.info("Bedrock refinó: '%s' → '%s'", base_sentence, refined)
        return refined
    except Exception as e:
        logger.warning("Bedrock falló, usando oración base como fallback: %s", str(e))
        return base_sentence

def _build_bedrock_request_body(prompt_text: str, max_tokens: int = 256) -> dict:
    model_id_lower = BEDROCK_MODEL_ID.lower()
    if "nova" in model_id_lower:
        return {"messages": [{"role": "user", "content": [{"text": prompt_text}]}],
                "inferenceConfig": {"maxTokens": max_tokens, "temperature": 0.2, "topP": 0.9}}
    elif "anthropic" in model_id_lower or "claude" in model_id_lower:
        return {"anthropic_version": "bedrock-2023-05-31", "max_tokens": max_tokens,
                "temperature": 0.2, "top_p": 0.9,
                "messages": [{"role": "user", "content": prompt_text}]}
    elif "titan" in model_id_lower:
        return {"inputText": prompt_text,
                "textGenerationConfig": {"maxTokenCount": max_tokens, "temperature": 0.2, "topP": 0.9, "stopSequences": []}}
    elif "llama" in model_id_lower or "meta" in model_id_lower:
        return {"prompt": prompt_text, "max_gen_len": max_tokens, "temperature": 0.2, "top_p": 0.9}
    else:
        return {"anthropic_version": "bedrock-2023-05-31", "max_tokens": max_tokens,
                "temperature": 0.2, "top_p": 0.9,
                "messages": [{"role": "user", "content": prompt_text}]}

def _refinement_is_safe(base: str, refined: str) -> bool:
    """Defensa anti-alucinación del backend (espejo del `isBackendDegenerate`
    del cliente). Acepta el refinamiento solo si conserva contenido de la
    oración base; si no comparte ninguna palabra significativa, casi seguro el
    modelo alucinó (p. ej. copió un ejemplo del prompt) y se descarta."""
    trans = str.maketrans("áéíóúüñ", "aeiouun")

    def content_words(s: str) -> set:
        s = s.lower().translate(trans)
        return {w for w in re.findall(r"[a-z]+", s) if len(w) >= 4}

    base_w = content_words(base)
    if not base_w:
        return True
    refined_w = content_words(refined)
    if not refined_w:
        return False
    return len(base_w & refined_w) >= 1

def _parse_bedrock_response(response_body: dict) -> str:
    if "output" in response_body and isinstance(response_body.get("output"), dict):
        raw = (response_body["output"].get("message", {})
               .get("content", [{}])[0].get("text", "").strip())
    elif "content" in response_body and isinstance(response_body["content"], list):
        raw = response_body["content"][0].get("text", "").strip()
    elif "results" in response_body and isinstance(response_body["results"], list):
        raw = response_body["results"][0].get("outputText", "").strip()
    elif "generation" in response_body:
        raw = response_body["generation"].strip()
    else:
        raise ValueError("Respuesta Bedrock no reconocida")

    labels = ("oracion refinada", "oración refinada", "salida", "respuesta",
              "resultado", "texto refinado", "oracion", "oración")
    result = ""
    for line in raw.split("\n"):
        l = line.replace("*", "").replace("#", "").replace("`", "").strip()
        if not l:
            continue
        low = l.lower()
        if low.rstrip(":").strip() in labels:
            continue
        for lab in labels:
            if low.startswith(lab) and ":" in l:
                l = l.split(":", 1)[1].strip()
                break
        if l:
            result = l
            break
    if not result:
        result = raw.replace("*", "").replace("#", "").strip()
    if result.startswith('"') and result.endswith('"'):
        result = result[1:-1].strip()
    return result

def synthesize_audio(text: str, language: str = "es") -> bytes:
    default_voice, default_lang = _VOICE_BY_LANG.get(language.lower(), (VOICE_ID, "es-US"))
    voice_id = os.environ.get("VOICE_ID") or default_voice
    lang_code = default_lang
    logger.info("Sintetizando audio con Polly — Voz: %s, Idioma: %s", voice_id, lang_code)
    response = polly_client.synthesize_speech(
        Text=text, OutputFormat="mp3", VoiceId=voice_id,
        Engine="neural", LanguageCode=lang_code,
    )
    audio_bytes = response["AudioStream"].read()
    logger.info("Audio sintetizado: %d bytes", len(audio_bytes))
    return audio_bytes

def _audio_s3_key(cache_key: str) -> str:
    return f"{APP_PREFIX}/{cache_key}.mp3"

def _cache_s3_key(cache_key: str) -> str:
    return f"{APP_PREFIX}/cache/{cache_key}.json"

def _presign_audio(s3_key: str) -> str:
    """URL prefirmada (válida 1 h) — se regenera en cada respuesta porque las
    firmas caducan; por eso la caché guarda la clave S3, no la URL firmada."""
    return s3_client.generate_presigned_url(
        'get_object',
        Params={'Bucket': S3_BUCKET, 'Key': s3_key},
        ExpiresIn=3600,
    )

def upload_audio_to_s3(audio_bytes: bytes, cache_key: str) -> str:
    s3_key = _audio_s3_key(cache_key)
    logger.info("Subiendo audio a S3 — Bucket: %s, Key: %s", S3_BUCKET, s3_key)
    s3_client.put_object(Bucket=S3_BUCKET, Key=s3_key, Body=audio_bytes, ContentType="audio/mpeg")
    presigned_url = _presign_audio(s3_key)
    logger.info("Url prefirmada generada exitosamente")
    return presigned_url

def get_cached_response(cache_key: str):
    """Devuelve la respuesta cacheada (con audioUrl prefirmado fresco) o None."""
    try:
        obj = s3_client.get_object(Bucket=S3_BUCKET, Key=_cache_s3_key(cache_key))
        data = json.loads(obj["Body"].read())
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code", "")
        if code not in ("NoSuchKey", "404", "NotFound"):
            logger.warning("No se pudo leer la caché %s: %s", cache_key, e)
        return None
    except Exception as e:
        logger.warning("Caché ilegible %s: %s", cache_key, e)
        return None

    audio_key = data.pop("audioKey", None)
    data["audioUrl"] = _presign_audio(audio_key) if audio_key else None
    data["cacheHit"] = True
    return data

def put_cached_response(cache_key: str, payload: dict, audio_key: str) -> None:
    """Guarda la respuesta (sin la URL firmada efímera) para futuros aciertos."""
    try:
        body = {k: v for k, v in payload.items() if k not in ("audioUrl", "cacheHit")}
        body["audioKey"] = audio_key
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=_cache_s3_key(cache_key),
            Body=json.dumps(body, ensure_ascii=False).encode("utf-8"),
            ContentType="application/json",
        )
    except Exception as e:
        logger.warning("No se pudo escribir la caché %s: %s", cache_key, e)

def build_response(status_code: int, body: dict) -> dict:
    return {"statusCode": status_code, "headers": CORS_HEADERS,
            "body": json.dumps(body, ensure_ascii=False)}

def generate_cache_key(context_type: str, cards: list) -> str:
    normalized = f"{context_type.lower().strip()}|{'|'.join(c.upper().strip() for c in cards)}"
    return hashlib.md5(normalized.encode("utf-8")).hexdigest()

# ---------------------------------------------------------------------------
# Cotas de entrada
# ---------------------------------------------------------------------------
# El endpoint es público y cada invocación consume Bedrock (por token) y Polly
# (por carácter). Sin un techo, `cards` era una lista sin límite de longitud ni
# de tamaño por elemento: una sola petición podía inflar el prompt hasta agotar
# el presupuesto de la cuenta. Su gemela `lambda_text_to_lsb` ya acotaba el
# texto a 1000 caracteres; esta no acotaba nada.
#
# Los valores salen del uso real: una declaración guiada rara vez pasa de una
# docena de glosas, y la glosa más larga del diccionario canónico
# ('PARTIDA_NACIMIENTO') tiene 18 caracteres.
MAX_CARDS = 64
MAX_CARD_LENGTH = 64
MAX_CONTEXT_LENGTH = 64


def validate_request(body: dict) -> tuple:
    if not isinstance(body, dict):
        return False, "El cuerpo de la solicitud debe ser un objeto JSON válido."
    cards = body.get("cards")
    if cards is None:
        return False, "El campo 'cards' es obligatorio."
    if not isinstance(cards, list):
        return False, "El campo 'cards' debe ser una lista de glosas."
    if len(cards) == 0:
        return False, "El campo 'cards' no puede estar vacío."
    if len(cards) > MAX_CARDS:
        return False, f"No se admiten más de {MAX_CARDS} glosas por solicitud."
    for i, card in enumerate(cards):
        if not isinstance(card, str) or not card.strip():
            return False, f"La glosa en posición {i} no es válida."
        if len(card) > MAX_CARD_LENGTH:
            return False, (
                f"La glosa en posición {i} excede los "
                f"{MAX_CARD_LENGTH} caracteres."
            )

    context_type = body.get("context")
    if context_type is not None:
        if not isinstance(context_type, str):
            return False, "El campo 'context' debe ser una cadena."
        if len(context_type) > MAX_CONTEXT_LENGTH:
            return False, "El campo 'context' es demasiado largo."
    return True, None

# ===================================================================
# SUGERENCIA GENERATIVA DE OPCIONES
# ===================================================================
# El flujo guiado ofrecía las tarjetas de la categoría de la zona ordenadas por
# prioridad. Ante "¿Qué pasó?" en un robo eso proponía ARRESTAR y ASISTENCIA
# —que no responden la pregunta— y enterraba ROBAR por orden alfabético. Era un
# árbol de decisión escrito a mano, no un sistema capaz de reaccionar a lo que
# venga de la conversación.
#
# Aquí el modelo elige y ordena, pero **solo dentro del vocabulario que el
# cliente le entrega**. Esa restricción no se le pide en el prompt: se aplica
# después, descartando lo que no venga en `candidates`. Una glosa inventada no
# puede sobrevivir a esa comprobación, que es lo que exige el control de
# alucinaciones.

MAX_SUGERENCIAS = 8


def invoke_bedrock_json(prompt: str) -> dict:
    """Invoca el modelo y devuelve el JSON que trae en su respuesta.

    Reutiliza los mismos ayudantes que el refinamiento —el cuerpo por familia
    de modelo y el desempaquetado— para no duplicar el conocimiento de qué
    forma tiene cada proveedor.
    """
    respuesta = bedrock_runtime.invoke_model(
        modelId=BEDROCK_MODEL_ID,
        contentType="application/json",
        accept="application/json",
        # Un JSON con la pregunta y hasta ocho glosas no cabe en los 256
        # tokens que basta para refinar una frase; truncado, deja de ser JSON
        # y la sugerencia se descartaba entera sin que se notara.
        body=json.dumps(_build_bedrock_request_body(prompt, max_tokens=800)),
    )
    crudo = _parse_bedrock_response(json.loads(respuesta["body"].read()))
    # El modelo suele envolver el JSON en explicaciones o en un bloque de
    # markdown; se extrae el objeto en lugar de exigir una salida limpia.
    inicio, fin = crudo.find("{"), crudo.rfind("}")
    if inicio < 0 or fin <= inicio:
        raise ValueError("la respuesta no contiene un objeto JSON")
    return json.loads(crudo[inicio:fin + 1])


def build_suggestion_prompt(context_type, selected, candidates, question):
    """Prompt para elegir las siguientes opciones y redactar su pregunta."""
    contexto = f"La persona está en el contexto '{context_type}'."
    if question:
        contexto += (
            f"\nUna persona oyente acaba de decirle: «{question}». "
            "Las opciones deben servir para RESPONDER a eso."
        )
    if selected:
        contexto += f"\nYa eligió, en orden: {', '.join(selected)}."
    else:
        contexto += "\nTodavía no ha elegido nada."

    return f"""Eres un asistente de una aplicación que ayuda a una persona sorda boliviana a construir una declaración en una institución pública.

{contexto}

Tu tarea es elegir las siguientes GLOSAS que conviene ofrecerle y redactar la pregunta que las presenta.

REGLAS:
1. Elige como máximo {MAX_SUGERENCIAS} glosas, ordenadas de más a menos probable.
2. SOLO puedes usar glosas de la lista de disponibles. No inventes ninguna, no traduzcas, no cambies su escritura.
3. No repitas glosas ya elegidas.
4. La pregunta va en segunda persona, es corta y concreta: "¿Quién te robó?", "¿Dónde ocurrió?".
5. Si la persona ya dijo lo esencial, ofrece glosas que añadan detalle útil para la declaración.

GLOSAS DISPONIBLES:
{', '.join(candidates)}

FORMATO (JSON estricto, sin texto alrededor):
{{"question": "...", "options": ["GLOSA1", "GLOSA2"]}}"""


def suggest_options(body):
    """Devuelve la pregunta y las opciones siguientes, validadas contra el corpus."""
    context_type = (body.get("context") or "general").strip().lower()
    selected = [str(c).strip().upper() for c in (body.get("selected") or [])]
    candidates = [str(c).strip().upper() for c in (body.get("candidates") or [])]
    question = (body.get("question") or "").strip()

    if not candidates:
        return build_response(400, {
            "error": "VALIDATION_ERROR",
            "message": "candidates es obligatorio: el modelo solo elige dentro de él.",
        })

    disponibles = [c for c in candidates if c not in selected]
    if not disponibles:
        return build_response(200, {"question": "", "options": [], "generated": False})

    try:
        prompt = build_suggestion_prompt(context_type, selected, disponibles, question)
        crudo = invoke_bedrock_json(prompt)
    except Exception as e:  # noqa: BLE001 — cualquier fallo cae al orden del cliente
        logger.warning("Sugerencia no generada (%s) — el cliente usará su orden", e)
        return build_response(200, {"question": "", "options": [], "generated": False})

    permitidas = set(disponibles)
    opciones, vistas = [], set()
    for o in crudo.get("options", []):
        if not isinstance(o, str):
            continue
        g = o.strip().upper()
        # La comprobación que hace inofensiva una alucinación: si el modelo se
        # inventa una seña, aquí desaparece.
        if g in permitidas and g not in vistas:
            opciones.append(g)
            vistas.add(g)
        elif g not in permitidas:
            logger.info("Glosa descartada por no estar en el corpus: %.40r", o)

    if not opciones:
        return build_response(200, {"question": "", "options": [], "generated": False})

    return build_response(200, {
        "question": str(crudo.get("question", "")).strip()[:120],
        "options": opciones[:MAX_SUGERENCIAS],
        "generated": True,
    })


def lambda_handler(event, context):
    http_method = event.get("httpMethod", event.get("requestContext", {}).get("http", {}).get("method", "POST"))
    if http_method == "OPTIONS":
        return build_response(200, {"message": "CORS preflight OK"})

    request_id = context.aws_request_id if context and hasattr(context, "aws_request_id") else ""
    logger.info("Solicitud recibida — request_id: %s", request_id)

    try:
        raw_body = event.get("body", "{}")
        body = json.loads(raw_body) if isinstance(raw_body, str) else (raw_body or {})
    except (json.JSONDecodeError, TypeError) as e:
        return build_response(400, {"error": "JSON_PARSE_ERROR", "message": "JSON inválido."})

    # La sugerencia de opciones no valida `cards`: su entrada es otra.
    if (body.get("action") or "").strip().lower() == "suggest":
        return suggest_options(body)

    is_valid, err = validate_request(body)
    if not is_valid:
        return build_response(400, {"error": "VALIDATION_ERROR", "message": err})

    cards = [c.strip().upper() for c in body["cards"]]
    context_type = body.get("context", "general").strip().lower()
    institution_type = (body.get("institutionType") or "").strip().lower()
    language = (body.get("language") or "es").strip()
    cache_key = generate_cache_key(context_type, cards)
    logger.info(
        "Procesando — cards: %s, context: %s, institutionType: %s, language: %s, cache_key: %s",
        cards, context_type, institution_type, language, cache_key,
    )

    cached = get_cached_response(cache_key)
    if cached is not None:
        logger.info("Cache HIT — respuesta servida desde caché: %s", cache_key)
        return build_response(200, cached)
    logger.info("Cache MISS — procesando pipeline completo: %s", cache_key)

    analysis = analyze_glosses(cards)
    logger.info("Análisis semántico: tipo_evento=%s", analysis["tipo_evento"])

    # CAMBIO (paridad Dart): cierra la cadena temporal antes de generar. Debe
    # ir aquí y no en analyze_glosses porque la dirección depende del contexto.
    _resolve_time(analysis, context_type)

    intermediate = build_intermediate_representation(cards, analysis, context_type)

    base_sentence = generate_base_sentence(intermediate, analysis, context_type, institution_type)
    logger.info("Oración base generada: %s", base_sentence)

    try:
        generated_text = refine_with_bedrock(base_sentence, context_type, institution_type)
    except Exception as e:
        logger.warning("Refinamiento con Bedrock falló, usando oración base: %s", str(e))
        generated_text = base_sentence

    bedrock_used = generated_text != base_sentence

    try:
        audio_bytes = synthesize_audio(generated_text, language)
    except ClientError as e:
        logger.error("Error de Polly: %s", str(e), exc_info=True)
        return build_response(500, {"error": "POLLY_ERROR", "message": "Error al sintetizar el audio."})
    except Exception as e:
        logger.error("Error inesperado en Polly: %s", str(e), exc_info=True)
        return build_response(500, {"error": "POLLY_ERROR", "message": "Error interno en síntesis de voz."})

    try:
        audio_url = upload_audio_to_s3(audio_bytes, cache_key)
    except ClientError as e:
        logger.error("Error de S3: %s", str(e), exc_info=True)
        return build_response(500, {"error": "S3_ERROR", "message": "Error al almacenar el audio."})
    except Exception as e:
        logger.error("Error inesperado en S3: %s", str(e), exc_info=True)
        return build_response(500, {"error": "S3_ERROR", "message": "Error interno al guardar audio."})

    logger.info("Completado — base: '%s' | final: '%s' | bedrock: %s", base_sentence, generated_text, bedrock_used)

    gloss_sequence = []
    for card in cards:
        entry = GLOSS_LEXICON.get(card.upper())
        gloss_sequence.append({
            "gloss": card.upper(),
            "videoKey": f"lsb-videos/{card.upper()}.mp4",
            "recognized": entry is not None,
            "rol": entry["rol"] if entry else "DESCONOCIDO",
        })

    response_payload = {
        "baseSentence": base_sentence,
        "generatedText": generated_text,
        "intermediateRepresentation": intermediate,
        "glossSequence": gloss_sequence,
        "audioUrl": audio_url,
        "cacheHit": False,
        "bedrockUsed": bedrock_used,
    }

    put_cached_response(cache_key, response_payload, _audio_s3_key(cache_key))

    return build_response(200, response_payload)
