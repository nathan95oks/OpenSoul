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
    "AEROPUERTO": {"rol": "LUGAR", "es": "en el aeropuerto"},
    "AHORA": {"rol": "TIEMPO", "es": "ahora mismo"},
    "ALCALDIA": {"rol": "INSTITUCION", "es": "en la alcaldía"},
    "AMARILLO": {"rol": "DESCRIPTOR", "es": "de color amarillo"},
    "AMENAZAR": {"rol": "VERBO", "es": "amenazó", "agresor": "amenazó"},
    "ANEXO": {"rol": "DOCUMENTO", "es": "un anexo"},
    "ANO": {"rol": "TIEMPO", "es": "este año"},
    "ANOS_EDAD": {"rol": "DESCONOCIDO", "es": "tengo esa edad"},
    "ANOTAR": {"rol": "VERBO", "es": "quiero anotar"},
    "ANTEAYER": {"rol": "TIEMPO", "es": "anteayer"},
    "ANTERIORMENTE": {"rol": "TIEMPO", "es": "anteriormente"},
    "APELLIDO": {"rol": "DESCONOCIDO", "es": "mi apellido es"},
    "ARRESTAR": {"rol": "VERBO", "es": "arrestó", "agresor": "arrestó"},
    "ARTICULO": {"rol": "DOCUMENTO", "es": "el artículo"},
    "ASISTENCIA": {"rol": "URGENCIA", "es": "necesito asistencia"},
    "ASISTENTE": {"rol": "SERVICIO", "es": "un asistente"},
    "ATENDER": {"rol": "VERBO", "es": "necesito que me atiendan"},
    "AUDIENCIA": {"rol": "TRAMITE", "es": "una audiencia"},
    "AUTO": {"rol": "OBJETO", "es": "mi auto"},
    "AUTORIDAD": {"rol": "INSTITUCION", "es": "en la autoridad"},
    "AUXILIO": {"rol": "URGENCIA", "es": "necesito auxilio"},
    "AVANCE": {"rol": "TRAMITE", "es": "el avance de la investigación"},
    "AVENIDA": {"rol": "LUGAR", "es": "en la avenida"},
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
    "CONFESAR": {"rol": "VERBO", "es": "quiero confesar"},
    "CONFIANZA": {"rol": "ESTADO", "es": "tengo confianza"},
    "CONFIRMACION": {"rol": "DOCUMENTO", "es": "la confirmación"},
    "CONFUSION": {"rol": "ESTADO", "es": "estoy confundido"},
    "CONOCER": {"rol": "VERBO", "es": "conozco"},
    "CONSTANCIA": {"rol": "DOCUMENTO", "es": "una constancia"},
    "CONTEXTO": {"rol": "DOCUMENTO", "es": "el contexto"},
    "COORDINADOR": {"rol": "SERVICIO", "es": "un coordinador"},
    "COORDINAR": {"rol": "VERBO", "es": "quiero coordinar"},
    "COPIAR": {"rol": "VERBO", "es": "quiero copiar"},
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
    "DEFENSA_PUBLICA": {"rol": "INSTITUCION", "es": "en la Defensa Pública"},
    "DELGADO": {"rol": "DESCRIPTOR", "es": "delgado"},
    "DEPARTAMENTO": {"rol": "LUGAR", "es": "en el departamento"},
    "DESPACHO": {"rol": "INSTITUCION", "es": "en el despacho"},
    "DIA": {"rol": "TIEMPO", "es": "ese día"},
    "DINERO": {"rol": "OBJETO", "es": "mi dinero"},
    "DIRECCION": {"rol": "LUGAR", "es": "en esa dirección"},
    "DISCRIMINACION": {"rol": "VERBO", "es": "discriminó", "agresor": "discriminó"},
    "DOCTOR": {"rol": "SERVICIO", "es": "un doctor"},
    "DONDE": {"rol": "DESCONOCIDO", "es": "dónde"},
    "EDAD": {"rol": "DESCONOCIDO", "es": "tengo esa edad"},
    "EL": {"rol": "SUJETO", "es": "él"},
    "ELLA": {"rol": "SUJETO", "es": "ella"},
    "ELLOS": {"rol": "SUJETO", "es": "ellos"},
    "ENFERMERA": {"rol": "SERVICIO", "es": "una enfermera"},
    "ENTREGAR": {"rol": "VERBO", "es": "me entregaron"},
    "ESCRIBIR": {"rol": "VERBO", "es": "quiero escribir"},
    "ESTADO": {"rol": "DOCUMENTO", "es": "el estado del trámite"},
    "ESTOY_BIEN": {"rol": "DESCONOCIDO", "es": "estoy bien"},
    "EXIGIR": {"rol": "VERBO", "es": "quiero exigir"},
    "EXPAREJA": {"rol": "DESCRIPTOR", "es": "mi expareja", "persona": True},
    "EXPEDIENTE": {"rol": "TRAMITE", "es": "mi expediente"},
    "FALTA": {"rol": "ESTADO", "es": "por una falta"},
    "FAMILIAR": {"rol": "DESCRIPTOR", "es": "un familiar", "persona": True},
    "FARMACIA": {"rol": "LUGAR", "es": "en la farmacia"},
    "FECHA": {"rol": "TIEMPO", "es": "en esa fecha"},
    "FELCC": {"rol": "INSTITUCION", "es": "en la FELCC"},
    "FELCV": {"rol": "INSTITUCION", "es": "en la FELCV"},
    "FISCAL": {"rol": "INSTITUCION", "es": "en la fiscalía"},
    "FISCALIA": {"rol": "INSTITUCION", "es": "en la Fiscalía"},
    "FORMATO": {"rol": "DOCUMENTO", "es": "el formato"},
    "FORMULARIO": {"rol": "DOCUMENTO", "es": "el formulario"},
    "FOTOCOPIA": {"rol": "DOCUMENTO", "es": "una fotocopia"},
    "FOTOGRAFIA": {"rol": "OBJETO", "es": "una fotografía"},
    "GESTIONAR": {"rol": "VERBO", "es": "quiero gestionar"},
    "GRACIAS": {"rol": "DESCONOCIDO", "es": "gracias"},
    "GRUESO": {"rol": "DESCRIPTOR", "es": "grueso"},
    "HABLAR": {"rol": "VERBO", "es": "quiero hablar"},
    "HERIDA": {"rol": "URGENCIA", "es": "tengo una herida"},
    "HOJA": {"rol": "DOCUMENTO", "es": "una hoja"},
    "HOLA": {"rol": "DESCONOCIDO", "es": "hola"},
    "HOMBRE": {"rol": "DESCRIPTOR", "es": "un hombre", "persona": True},
    "HORA": {"rol": "TIEMPO", "es": "hace una hora"},
    "HOSPITAL": {"rol": "LUGAR", "es": "en el hospital"},
    "HOY": {"rol": "TIEMPO", "es": "hoy"},
    "IDENTIDAD": {"rol": "DESCONOCIDO", "es": "quiero identificarme"},
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
    "JUZGADO": {"rol": "INSTITUCION", "es": "en el juzgado de instrucción penal"},
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
    "NOMBRE": {"rol": "DESCONOCIDO", "es": "mi nombre es"},
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
    "PAGAR": {"rol": "VERBO", "es": "pagué"},
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
    "SEPAV": {"rol": "INSTITUCION", "es": "en el SEPAV"},
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
    "TRIBUNAL": {"rol": "INSTITUCION", "es": "en el tribunal"},
    "TRUFI": {"rol": "OBJETO", "es": "el trufi"},
    "TU": {"rol": "SUJETO", "es": "tú"},
    "UBICACION_GPS": {"rol": "LUGAR", "es": "en esta ubicación"},
    "USTEDES": {"rol": "SUJETO", "es": "ustedes"},
    "VARIAS_VECES": {"rol": "TIEMPO", "es": "varias veces"},
    "VECINO": {"rol": "DESCRIPTOR", "es": "un vecino", "persona": True},
    "VENTANILLA": {"rol": "INSTITUCION", "es": "en la ventanilla"},
    "VERDE": {"rol": "DESCRIPTOR", "es": "de color verde"},
    "VERGUENZA": {"rol": "ESTADO", "es": "siento vergüenza"},
    "VIDEOLLAMADA": {"rol": "OBJETO", "es": "por videollamada"},
    "VIOLACION": {"rol": "VERBO", "es": "violó", "agresor": "violó"},
    "VIOLENCIA": {"rol": "VERBO", "es": "ejerció violencia", "agresor": "ejerció violencia"},
    "WEBID": {"rol": "TRAMITE", "es": "mi WebID"},
    "WHATSAPP": {"rol": "OBJETO", "es": "por WhatsApp"},
    "YO": {"rol": "SUJETO", "es": "yo"},
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
    "FOTOGRAFIA", "MENSAJE", "COMPROBANTE", "CERTIFICADO", "RESPALDO",
    "VIDEOLLAMADA",
}
# La huida es lo que hizo el agresor DESPUÉS, no lo que me hizo. Como agresión
# producía "un hombre me salió corriendo": falso y agramatical.
_FLIGHT_VERBS = {"CORRER"}

# Dígitos de dactilología. Incluye el 0, que _CARDINALES no lleva a propósito:
# sirve para deletrear un NUREJ pero nunca es una cantidad. Sin el 0 aquí, un
# número como "1 0 2 4" se partía en trozos y el primer dígito se perdía.
_PREPOSICIONES = {"por", "en", "con", "a", "de"}

# Oficios epicenos: el lexema viene en masculino y concuerda si la persona
# además eligió MUJER. En una denuncia el género identifica a quien se busca.
_FEMENINO = {
    "un vecino": "una vecina",
    "un militar": "una militar",
    "un soldado": "una soldado",
    "un testigo": "una testigo",
    "un ladrón": "una ladrona",
    "un doctor": "una doctora",
    "un abogado": "una abogada",
}

# Glosas que admiten un nombre propio o una matrícula deletreada detrás.
# "Me robaron en la plaza" no sirve: el oficial necesita QUÉ plaza.
_ADMITE_DETALLE = {
    "PLAZA": "plaza", "CALLE": "calle", "AVENIDA": "avenida",
    "MERCADO": "mercado", "PARADA": "parada",
    "AUTO": "placa", "MOTOCICLETA": "placa", "MICRO": "placa",
    "TAXI": "placa", "TRUFI": "placa", "BICICLETA": "placa",
    # Un expediente sin su número no identifica nada. Se deletrea, igual que
    # una placa.
    "CASO": "numero", "CODIGO": "numero", "NUREJ": "numero",
    "WEBID": "numero", "EXPEDIENTE": "numero",
    # Fase 1: identidad. La edad se teclea entera, el nombre se deletrea.
    "EDAD": "edad", "ANOS_EDAD": "edad",
    "NOMBRE": "nombre", "APELLIDO": "apellido",
    "CARNET": "carnet",
}

_DIGITOS = set("0123456789")

# Cortesías y respuestas sueltas: encabezan, no son contenido del relato.
_MARKER_GLOSSES = {
    "HOLA", "GRACIAS", "PERMISO", "POR_FAVOR", "LO_SIENTO", "SI", "NO",
    "NO_SABER", "NO_PUEDO", "NO_RECUERDO", "NO_ENTIENDO", "PUEDE_REPETIR",
    "PUEDO", "SABER", "MAS_O_MENOS", "ESTOY_BIEN",
    # Fase 1: uno se identifica antes de contar nada, así que encabezan.
    "NOMBRE", "APELLIDO", "IDENTIDAD", "EDAD", "ANOS_EDAD",
}

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

# El verbo manda sobre el contexto: el contexto dice de qué trata el flujo,
# el verbo hacia dónde mira ESTA frase. Sin esto, consultar el estado de algo
# presentado "la semana pasada" salía como "dentro de una semana" solo porque
# el flujo de consulta apunta por defecto a un plazo.
_PAST_VERBS = {
    "SEGUIMIENTO", "COMPRENDER", "ACLARAR", "CONOCER", "RECORDAR",
    "OBSERVAR", "RECONOCER", "PERDER", "PAGAR", "ENTREGAR", "NARRAR",
    "CONFESAR", "IDENTIFICAR",
}

_FUTURE_VERBS = {
    "PRESENTAR", "CORREGIR", "PEDIR", "GESTIONAR", "RECOGER", "COPIAR",
    "IMPRIMIR", "COORDINAR", "SOLUCIONAR", "TRATAR", "EXIGIR",
}


def _time_direction_is_past(analysis: dict, context_type: str,
                            cards: list = ()) -> bool:
    """Réplica de `resolveAssemblerContext` + `_pastContexts` del cliente.

    'tramite' es el único id de UI ambiguo: se reparte entre pérdida (pasado)
    y gestión (futuro) según lo que la persona haya elegido, exactamente con
    el mismo criterio que el cliente —un objeto o la glosa PERDER.
    """
    # El verbo primero, en el orden en que la persona lo eligió.
    for card in cards:
        key = str(card).upper().strip()
        if key in _PAST_VERBS:
            return True
        if key in _FUTURE_VERBS:
            return False

    ctx = (context_type or "").strip().lower()
    if ctx in _PAST_CONTEXTS:
        return True
    if ctx == "tramite":
        if any(v["glosa"] == "PERDER" for v in analysis["verbos"]):
            return True
        # Un objeto solo indica pérdida si no se nombra además un documento o
        # un trámite: "corregir mi carnet y mi teléfono" es una gestión, no un
        # extravío, y su plazo mira hacia adelante.
        return bool(analysis["objetos"]) and not (
            analysis["documentos"] or analysis["tramites"])
    return False


def _resolve_time(analysis: dict, context_type: str, cards: list = ()) -> None:
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

    es_pasado = _time_direction_is_past(analysis, context_type, cards)
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


def _es_letra(g: str) -> bool:
    return len(g) == 1 and re.fullmatch(r"[A-ZÑ]", g) is not None


def _join_spelled_digits(cards: list) -> list:
    """Une rachas deletreadas: letras y dígitos. Espejo de `_joinSpelled`.

    Una racha es UNA palabra o UN número deletreado —"C,U,C,H,I,L,L,O" es
    "cuchillo"; "1,0,2,4" es un NUREJ— y debe conservarse entera. Un carácter
    aislado no se toca: si es un dígito tras una unidad de tiempo lo recoge la
    cadena temporal, y si no, es ruido que se descarta.

    CAMBIO: antes solo unía dígitos. Las letras nunca se juntaban, así que la
    dactilología del cliente y la del servidor no coincidían y un nombre propio
    llegaba partido en letras sueltas.
    """
    salida, i = [], 0
    normalizadas = [str(c).upper().strip() for c in cards]

    def racha(desde, pertenece):
        j = desde
        while j < len(normalizadas) and pertenece(normalizadas[j]):
            j += 1
        return j

    while i < len(normalizadas):
        for pertenece in (lambda g: g in _DIGITOS, _es_letra):
            if pertenece(normalizadas[i]):
                j = racha(i, pertenece)
                if j - i >= 2:
                    salida.append("".join(normalizadas[i:j]))
                    i = j
                    break
        else:
            salida.append(normalizadas[i])
            i += 1
            continue
        if i < len(normalizadas) and salida and salida[-1] != normalizadas[i]:
            continue
    return salida


def _extract_details(tokens: list, destino: dict) -> list:
    """Separa las rachas deletreadas que califican a la glosa anterior.

    Espejo de `_extractDetails` en el cliente. Una matrícula mezcla letras y
    dígitos y `_join_spelled_digits` junta cada tipo por separado, así que hay
    que reunir los tramos seguidos o la placa se parte en dos.
    """
    salida, i = [], 0
    while i < len(tokens):
        t = tokens[i]
        anterior = salida[-1] if salida else None
        es_racha = (len(t) > 1 and t not in GLOSS_LEXICON
                    and re.fullmatch(r"[A-ZÑ0-9]+", t) is not None)
        if (anterior in _ADMITE_DETALLE and anterior not in destino and es_racha):
            partes = [t]
            while i + 1 < len(tokens):
                sig = tokens[i + 1]
                if (len(sig) > 1 and sig not in GLOSS_LEXICON
                        and re.fullmatch(r"[A-ZÑ0-9]+", sig)):
                    partes.append(sig)
                    i += 1
                else:
                    break
            destino[anterior] = "".join(partes)
            i += 1
            continue
        salida.append(t)
        i += 1
    return salida


def _con_detalle(gloss: str, lexema: str, detalles: dict) -> str:
    """Engancha el detalle: "en la plaza Murillo", "mi auto con placa 234ABC"."""
    detalle = detalles.pop(gloss, None)
    if not detalle:
        return lexema
    etiqueta = _ADMITE_DETALLE.get(gloss)
    propio = f"{detalle[:1].upper()}{detalle[1:].lower()}"
    if etiqueta == "placa":
        return f"{lexema} con placa {detalle}"
    if etiqueta in ("numero", "carnet"):
        return f"{lexema} número {detalle}"
    if etiqueta == "edad":
        return f"tengo {detalle} años"
    if etiqueta == "nombre":
        return f"mi nombre es {propio}"
    if etiqueta == "apellido":
        return f"mi apellido es {propio}"
    return f"{lexema} {propio}"


def _resolve_gender(analysis: dict) -> set:
    """Concuerda los oficios epicenos y absorbe la glosa de género.

    VECINO + MUJER es "una vecina"; MILITAR + HOMBRE es "un militar", porque
    el masculino ya era la forma por defecto. Devuelve las glosas consumidas.
    """
    consumidas = set()
    personas = [d for d in analysis["descriptores"] if d.get("persona")]
    if len(personas) < 2:
        return consumidas
    formas = [p["es"] for p in personas]
    femenino = "una mujer" in formas
    masculino = "un hombre" in formas
    lleva_genero = any(f in _FEMENINO for f in formas
                       if f not in ("una mujer", "un hombre"))
    if not lleva_genero or not (femenino or masculino):
        return consumidas

    if femenino:
        for p in personas:
            p["es"] = _FEMENINO.get(p["es"], p["es"])
        sobra, glosa = "una mujer", "MUJER"
    else:
        sobra, glosa = "un hombre", "HOMBRE"

    analysis["descriptores"] = [d for d in analysis["descriptores"]
                                if d["es"] != sobra]
    consumidas.add(glosa)
    return consumidas


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
    negar_siguiente_verbo = False
    detalles = {}
    normalizadas = _extract_details(_join_spelled_digits(
        [str(c).upper().strip() for c in cards]), detalles)
    for indice, card in enumerate(normalizadas):
        key = card.upper().strip()

        # CAMBIO (paridad Dart): en LSB la negación es una seña aparte, no un
        # prefijo. NO delante de un verbo lo niega ("NO ENTREGAR" → "no me
        # entregaron"). Sin esto el NO quedaba suelto y el verbo se afirmaba,
        # que es decir lo contrario de lo que la persona quiso decir.
        if key == "NO" and indice + 1 < len(normalizadas):
            siguiente = GLOSS_LEXICON.get(normalizadas[indice + 1].upper().strip())
            if siguiente and siguiente["rol"] == "VERBO":
                negar_siguiente_verbo = True
                continue
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
            registro = {"glosa": key, **entry}
            # El detalle vale para cualquier rol: acotarlo a unos pocos dejaba
            # fuera los marcadores de Fase 1 —el nombre y la edad— y salía
            # "mi nombre es." sin el nombre.
            registro["es"] = _con_detalle(key, registro["es"], detalles)
            if rol == "VERBO" and negar_siguiente_verbo:
                registro["es"] = f'no {registro["es"]}'
                negar_siguiente_verbo = False
            analysis[dest].append(registro)
        elif key in _DIGITOS:
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
    ctx = (context_type or "").strip().lower()
    if ctx in ("accidente", "emergencia"):
        return "EMERGENCIA"
    # Misma regla para el relato de un hecho: el cliente enruta por contexto
    # (`'denuncia_robo' || 'violencia' => _composeIncident`). Sin esto, una
    # denuncia sin verbo de delito —una estafa, que el diccionario no puede
    # nombrar— caía en la plantilla de ESTADO y salía "Por un problema.",
    # perdiendo el dinero, el producto y el canal.
    # Fase 1 no narra un hecho: la declaración son los datos, que viajan como
    # marcadores y encabezan. Sin esta rama caía en la plantilla de solicitud
    # y salía "Necesito asistencia", que nadie pidió.
    if ctx == "identificacion":
        return "IDENTIFICACION"
    if ctx == "denuncia_robo":
        return "ROBO"
    if ctx == "violencia":
        return "AGRESION"

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
    _resolve_gender(analysis)
    _resolve_time(analysis, context_type, cards)

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
        "IDENTIFICACION": _gen_identificacion,
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
    # CAMBIO (paridad Dart): las cortesías y respuestas sueltas encabezan la
    # declaración ("No sé. No recuerdo. …"). El cliente las antepone; aquí
    # caían en "desconocidos" y salían como "hago referencia a no sé".
    marcadores = [d["es"] for d in analysis.get("desconocidos", [])
                  if d["glosa"] in _MARKER_GLOSSES or d["glosa"] in _ADMITE_DETALLE]
    if marcadores:
        analysis["desconocidos"] = [
            d for d in analysis["desconocidos"]
            if d["glosa"] not in _MARKER_GLOSSES
            and d["glosa"] not in _ADMITE_DETALLE]
        # EDAD y ANOS_EDAD son la misma respuesta: dicha una vez, la segunda
        # sonaría a tartamudeo.
        hay_edad = any(m.startswith("tengo ") and m.endswith(" años")
                       for m in marcadores)
        vistos, unicos = set(), []
        for m in marcadores:
            if m == "tengo esa edad" and hay_edad:
                continue
            if m not in vistos:
                vistos.add(m)
                unicos.append(m)
        cabecera = " ".join(f"{m[0].upper()}{m[1:]}." for m in unicos)
        sentence = f"{cabecera} {sentence}".strip()

    # Todos los roles que una plantilla puede dejarse: cubrir solo trámites
    # dejaba fuera documentos (ESTADO es DOCUMENTO, no TRAMITE) y servicios
    # (un intérprete pedido y no emitido). Cualquier glosa que el cliente
    # represente y el servidor no hace que se descarte la respuesta entera.
    # Un servicio pedido no es "una referencia": es una necesidad, y tiene su
    # propia oración.
    servicios = [x["es"] for x in analysis.get("servicios", [])
                 if _normalizar(x["es"]) not in _normalizar(sentence)]
    if servicios:
        sentence = sentence.rstrip(".") + f". Necesito {_join_es(servicios)}"

    residuo = [t["es"] for t in analysis.get("tramites", [])]
    residuo += [d["es"] for d in analysis.get("documentos", [])]
    residuo += [o["es"] for o in analysis.get("objetos", [])]
    residuo += [l["es"] for l in analysis.get("lugares", [])]
    residuo += [d["es"] for d in analysis.get("desconocidos", [])]
    faltan = [x for x in residuo if _normalizar(x) not in _normalizar(sentence)]
    # Sin relato al que añadir —Fase 1: los datos SON la declaración— el
    # residuo es la frase, no un apéndice: "Adicionalmente, hago referencia a
    # mi carnet" presupone algo dicho antes que aquí no existe.
    if faltan and not sentence.strip(" ."):
        sentence = " ".join(f"{x[0].upper()}{x[1:]}." for x in faltan)
        faltan = []
    if faltan:
        # Los complementos que ya traen su preposición ("por WhatsApp", "en esa
        # dirección") no encajan tras "hago referencia a": se adjuntan tal cual.
        preposicionales = [x for x in faltan
                           if x.split(" ")[0] in _PREPOSICIONES]
        nominales = [x for x in faltan if x not in preposicionales]
        if nominales:
            # "a el estado" no es español: preposición y artículo se contraen.
            cola = _join_es(nominales)
            prep = "al " + cola[3:] if cola.startswith("el ") else f"a {cola}"
            sentence = (sentence.rstrip(".")
                        + f". Adicionalmente, hago referencia {prep}")
        if preposicionales:
            sentence = sentence.rstrip(".") + " " + _join_es(preposicionales)

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
    """Objetos sustraídos o afectados, sin los canales.

    Un canal ("por WhatsApp") ya trae su preposición y no es un objeto
    directo: unirlo con "y" daba "me robó mi dinero, el producto y por
    WhatsApp". Se antepone la lista nominal y el canal se adjunta detrás.
    """
    objs = [o["es"] for o in analysis["objetos"]]
    nominales = [o for o in objs if o.split(" ")[0] not in _PREPOSICIONES]
    canales = [o for o in objs if o.split(" ")[0] in _PREPOSICIONES]
    texto = _join_es(nominales)
    if canales:
        texto = f"{texto} {_join_es(canales)}".strip()
    return texto

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

def _compose_action_report(analysis, is_formal):
    """Relato en 1ª persona a partir de los verbos que la persona eligió.

    El canal ("por WhatsApp") acompaña a la primera acción y lo nominal a la
    última: "Pagué por WhatsApp y no me entregaron el producto".
    """
    acciones = [v["es"] for v in analysis["verbos"]]
    objetos = [o["es"] for o in analysis["objetos"]]
    objetos += [d["es"] for d in analysis["documentos"]]
    analysis["objetos"] = []
    analysis["documentos"] = []

    canales = [o for o in objetos if o.split(" ")[0] in _PREPOSICIONES]
    nominales = [o for o in objetos if o not in canales]
    if canales:
        acciones[0] = f'{acciones[0]} {_join_es(canales)}'
    if nominales:
        acciones[-1] = f'{acciones[-1]} {_join_es(nominales)}'

    core = _join_es(acciones)
    lugar = _lugar_text(analysis)
    if lugar:
        core += f" {lugar}"
        analysis["lugares"] = []

    tiempo = analysis["tiempos"][0]["es"] if analysis["tiempos"] else None
    if tiempo:
        core = f"{tiempo[0].upper()}{tiempo[1:]}, {core[0].lower()}{core[1:]}"
        analysis["tiempos"] = []

    partes = [f"{core[0].upper()}{core[1:]}."]
    if analysis.get("evidencias"):
        partes.append(f'Como prueba tengo {_join_es([e["es"] for e in analysis["evidencias"]])}.')
        analysis["evidencias"] = []
    return " ".join(partes)


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
    # CAMBIO (paridad Dart): si no hay verbo de agresión pero sí verbos de
    # acción propios del relato (§2.4: "pagué", "no me entregaron"), el
    # complemento es de ellos. Sin esta rama el compositor inventaba un
    # agresor y un hurto —"Una persona me robó el producto"— que es
    # justamente la calificación jurídica que el corpus §8 prohíbe.
    if not any(v.get("agresor") for v in analysis["verbos"]) and analysis["verbos"]:
        return _compose_action_report(analysis, is_formal)

    subj = _agresor_text(analysis)
    verb = _agresor_verb(analysis, "robó" if robo else "agredió")
    # Un sujeto en aposición ("mi pareja, una mujer") necesita la coma de
    # cierre antes de seguir la cláusula.
    subj_clause = f"{subj}," if "," in subj else subj
    core = f"{subj_clause} me {verb}"

    objs = _objetos_text(analysis)
    if objs:
        core += f" {objs}"
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

def _gen_identificacion(ir, analysis, is_formal):
    """Fase 1: los datos SON la declaración.

    Nombre, apellido y edad viajan como marcadores y encabezan solos, así que
    aquí solo queda el documento. Sin frase de encuadre a propósito: el
    funcionario está esperando un dato, no un preámbulo.
    """
    documentos = [d["es"] for d in analysis["documentos"]]
    analysis["documentos"] = []
    return " ".join(f"{d[0].upper()}{d[1:]}." for d in documentos)


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

def build_generation_prompt(cards: list, analysis: dict, base_sentence: str,
                            context_type: str, is_formal: bool) -> str:
    """Prompt de redacción libre anclada a hechos verificados.

    El modelo NO traduce glosas: recibe el significado de cada una ya resuelto
    por el lexicón y la oración que el ensamblador determinista compuso con
    ellas. Sobre eso redacta. Así la fluidez la pone el modelo y la fidelidad
    la pone el código — que es el único de los dos en el que se puede confiar
    para una declaración que puede acabar en un expediente.
    """
    significados = []
    for card in cards:
        key = str(card).upper().strip()
        entry = GLOSS_LEXICON.get(key)
        if entry:
            significados.append(f'- {key}: {entry["es"]}')
    hechos = "\n".join(significados) or "- (sin glosas reconocidas)"

    registro = ("formal, legal y preciso, propio de un acta de denuncia"
                if is_formal else "claro, correcto y respetuoso")

    return f"""Eres quien redacta, en español de Bolivia, la declaración de una persona sorda en el ámbito PENAL Y JUDICIAL. Ella se comunica eligiendo señas; tú conviertes esas señas en la declaración que leerá o escuchará el funcionario que la recibe.

ÁMBITO: Ministerio Público (Fiscalía), FELCC y FELCV, juzgados de instrucción penal y tribunales, Defensa Pública y SEPAV. Cuando el texto nombre un lugar institucional, se refiere a una de estas dependencias, no a una oficina cualquiera. El registro es el de un acta de recepción de denuncia o de una diligencia preliminar.

REGISTRO: {registro}. Escribe con empatía y sin dramatizar. La persona puede estar asustada o herida: su declaración debe sonar digna, nunca infantil ni telegráfica.

SEÑAS QUE ELIGIÓ, con su significado ya resuelto:
{hechos}

HECHOS VERIFICADOS (composición literal de esas señas — es la verdad del caso):
"{base_sentence}"

REGLAS INNEGOCIABLES:
1. Di TODO lo que aparece en los hechos verificados. Si omites una seña, la persona pierde parte de su declaración y no puede saberlo.
2. NO añadas ningún hecho que no esté ahí: ni un lugar, ni una hora, ni un objeto, ni un motivo, ni una emoción. Si los hechos no dicen dónde ocurrió, tu texto tampoco lo dice.
3. NO califiques jurídicamente. Escribe lo que ocurrió, no cómo se llama el delito: nunca "estafa", "hurto agravado", "tentativa".
4. NO opines, no aconsejes, no consueles y no te dirijas a la persona. Solo su declaración.
5. Mantén la primera persona: es ella quien habla, no tú sobre ella.
6. Puedes —y debes— reordenar, unir oraciones, añadir los conectores que falten y elegir el verbo que suene más natural. Ahí está tu trabajo.
7. Pero conserva LITERALMENTE las palabras que nombran objetos, lugares, fechas, personas, documentos y cantidades. Si los hechos dicen "mi mochila" no escribas "mi bolso"; si dicen "en la calle" no escribas "en la vía pública". Un funcionario transcribe lo que lee, y un sinónimo cambia el acta.
8. Responde SOLO con la declaración, en texto plano, sin comillas, sin markdown y sin encabezados.

Declaración:"""


def _generation_is_safe(cards: list, generated: str, base: str) -> tuple:
    """Cobertura y no-invención. Espejo de `isBackendDegenerate` del cliente.

    Devuelve (es_segura, motivo). Comprueba lo que se puede comprobar: que
    cada seña elegida siga representada en el texto. Lo que no se puede
    comprobar por texto —un hecho inventado plausible— se acota en el prompt y
    se limita con el tope de longitud: un texto mucho más largo que los hechos
    verificados está adornando.
    """
    if not generated or not generated.strip():
        return False, "vacío"

    plano = _normalizar(generated)

    faltantes = []
    for card in cards:
        key = str(card).upper().strip()
        entry = GLOSS_LEXICON.get(key)
        if not entry:
            continue
        # Basta una palabra significativa del lexema, o su raíz: el modelo
        # puede decir "mi celular" donde el lexema dice "mi teléfono".
        palabras = [w for w in _normalizar(entry["es"]).split() if len(w) >= 4]
        raiz = _normalizar(key)[:4]
        if any(w in plano for w in palabras) or (len(raiz) >= 4 and raiz in plano):
            continue
        faltantes.append(key)

    if faltantes:
        return False, f"omite {', '.join(faltantes)}"

    # Adorno: el doble de palabras que los hechos verificados es reescritura,
    # más que eso es literatura.
    if len(generated.split()) > max(24, len(base.split()) * 2):
        return False, "demasiado largo frente a los hechos"

    return True, ""


def generate_with_bedrock(cards: list, analysis: dict, base_sentence: str,
                          context_type: str, institution_type: str = "") -> tuple:
    """Redacción final con Bedrock, anclada y validada.

    Devuelve (texto, validado). Ante cualquier duda —Bedrock apagado, error de
    red, cobertura incompleta— devuelve la oración determinista, que nunca
    miente aunque suene más seca.
    """
    if not ENABLE_BEDROCK:
        return base_sentence, False

    is_formal = _is_formal(context_type, institution_type)
    prompt = build_generation_prompt(
        cards, analysis, base_sentence, context_type, is_formal)

    try:
        request_body = _build_bedrock_request_body(prompt, max_tokens=400)
        response = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL_ID, contentType="application/json",
            accept="application/json", body=json.dumps(request_body),
        )
        texto = _parse_bedrock_response(json.loads(response["body"].read()))
    except Exception as e:  # noqa: BLE001 — cualquier fallo cae al determinista
        logger.warning("Generación con Bedrock falló: %s", e)
        return base_sentence, False

    texto = (texto or "").strip().strip('"').strip()
    seguro, motivo = _generation_is_safe(cards, texto, base_sentence)
    if not seguro:
        logger.warning("Generación descartada (%s): %.200r", motivo, texto)
        return base_sentence, False

    return texto, True


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
    _resolve_gender(analysis)
    _resolve_time(analysis, context_type, cards)

    intermediate = build_intermediate_representation(cards, analysis, context_type)

    base_sentence = generate_base_sentence(intermediate, analysis, context_type, institution_type)
    logger.info("Oración base generada: %s", base_sentence)

    # CAMBIO: el modelo REDACTA a partir de las glosas y de los hechos
    # verificados, en vez de pulir una frase ya hecha. La fluidez la pone el
    # modelo; la fidelidad, el ensamblador determinista, que sigue siendo
    # quien garantiza que ninguna seña se pierda.
    generated_text, generation_validated = generate_with_bedrock(
        cards, analysis, base_sentence, context_type, institution_type)

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
        # El servidor ya comprobó, con las mismas reglas que el cliente, que
        # el texto generado representa TODAS las glosas. El cliente lo usa
        # para no volver a exigir una coincidencia literal que una redacción
        # libre —"me sustrajo el celular" por ROBAR + TELEFONO— nunca cumple.
        # Es una promesa de nuestro propio código sobre la salida del modelo,
        # no una promesa del modelo.
        "coverageValidated": generation_validated,
    }

    put_cached_response(cache_key, response_payload, _audio_s3_key(cache_key))

    return build_response(200, response_payload)
