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
    "0": {"rol": "VERBO", "es": "0"},
    "1": {"rol": "VERBO", "es": "1"},
    "2": {"rol": "VERBO", "es": "2"},
    "3": {"rol": "VERBO", "es": "3"},
    "4": {"rol": "VERBO", "es": "4"},
    "5": {"rol": "VERBO", "es": "5"},
    "6": {"rol": "VERBO", "es": "6"},
    "7": {"rol": "VERBO", "es": "7"},
    "8": {"rol": "VERBO", "es": "8"},
    "9": {"rol": "VERBO", "es": "9"},
    "A": {"rol": "VERBO", "es": "a"},
    "ABOGADO": {"rol": "SERVICIO", "es": "un abogado"},
    "ABRIR": {"rol": "VERBO", "es": "abrí"},
    "ABUSAR": {"rol": "VERBO", "es": "cometió abusos", "agresor": "cometió abusos"},
    "ACEPTAR": {"rol": "VERBO", "es": "acepto"},
    "ACOMPAÑAR": {"rol": "VERBO", "es": "acompañar"},
    "ADULTO": {"rol": "DESCRIPTOR", "es": "adulto", "persona": True},
    "AHORA": {"rol": "TIEMPO", "es": "ahora mismo"},
    "ALCALDIA": {"rol": "INSTITUCION", "es": "en la alcaldía"},
    "ALLA": {"rol": "LUGAR", "es": "allá"},
    "ALLI": {"rol": "LUGAR", "es": "allí"},
    "ALTO": {"rol": "DESCRIPTOR", "es": "alto"},
    "AL_LADO": {"rol": "LUGAR", "es": "al lado"},
    "AMBOS": {"rol": "SUJETO", "es": "ambos"},
    "AMENAZAR": {"rol": "VERBO", "es": "amenazó", "agresor": "amenazó"},
    "AMIGO": {"rol": "DESCRIPTOR", "es": "un amigo", "persona": True},
    "ANDAR": {"rol": "VERBO", "es": "caminaba"},
    "ANOS_EDAD": {"rol": "DESCONOCIDO", "es": "tengo esa edad"},
    "ANTEAYER": {"rol": "TIEMPO", "es": "anteayer"},
    "APELLIDO": {"rol": "DESCONOCIDO", "es": "mi apellido es"},
    "AQUI": {"rol": "LUGAR", "es": "aquí"},
    "ARREGLAR": {"rol": "VERBO", "es": "quiero corregir"},
    "ARRESTAR": {"rol": "VERBO", "es": "arrestaron"},
    "ASISTENCIA": {"rol": "DOCUMENTO", "es": "asistencia"},
    "ASISTENTE": {"rol": "SERVICIO", "es": "un asistente"},
    "ASOCIACION_SORDOS": {"rol": "DESCRIPTOR", "es": "la asociación de sordos", "persona": True},
    "ATENDER": {"rol": "VERBO", "es": "atender"},
    "ATRAS": {"rol": "LUGAR", "es": "atrás"},
    "AUDIENCIA": {"rol": "TRAMITE", "es": "una audiencia"},
    "AUMENTAR": {"rol": "VERBO", "es": "quiero agregar información"},
    "AUN": {"rol": "TIEMPO", "es": "aún"},
    "AUTO": {"rol": "OBJETO", "es": "mi auto"},
    "AUTORIDAD": {"rol": "INSTITUCION", "es": "la autoridad"},
    "AUXILIO": {"rol": "URGENCIA", "es": "auxilio urgente"},
    "AVENIDA": {"rol": "LUGAR", "es": "en la avenida"},
    "AVISAR": {"rol": "VERBO", "es": "avisar"},
    "AYER": {"rol": "TIEMPO", "es": "ayer"},
    "AYUDAR": {"rol": "VERBO", "es": "necesito ayuda"},
    "AZUL": {"rol": "DESCRIPTOR", "es": "de color azul"},
    "AÑO": {"rol": "TIEMPO", "es": "año"},
    "AÑO_PASADO": {"rol": "TIEMPO", "es": "el año pasado"},
    "B": {"rol": "VERBO", "es": "b"},
    "BAJO": {"rol": "DESCRIPTOR", "es": "bajo"},
    "BANCO": {"rol": "LUGAR", "es": "en el banco"},
    "BARRIO": {"rol": "LUGAR", "es": "en el barrio"},
    "BICICLETA": {"rol": "OBJETO", "es": "mi bicicleta"},
    "BILLETERA": {"rol": "OBJETO", "es": "mi billetera"},
    "BILLETES": {"rol": "OBJETO", "es": "billetes y dinero"},
    "BOCA": {"rol": "OBJETO", "es": "la boca"},
    "BOLSA": {"rol": "OBJETO", "es": "mi bolsa"},
    "BRAZO": {"rol": "OBJETO", "es": "el brazo"},
    "BUENO": {"rol": "DESCRIPTOR", "es": "bueno"},
    "BUENOS_DIAS": {"rol": "DESCONOCIDO", "es": "buenos días"},
    "BURLAR": {"rol": "VERBO", "es": "se burlaron"},
    "BUSCAR": {"rol": "VERBO", "es": "quiero buscar"},
    "C": {"rol": "VERBO", "es": "c"},
    "CABELLO": {"rol": "OBJETO", "es": "el cabello"},
    "CADA_DIA": {"rol": "TIEMPO", "es": "cada día"},
    "CAJA": {"rol": "OBJETO", "es": "la caja"},
    "CALLE": {"rol": "LUGAR", "es": "en la calle"},
    "CAMARA_FOTOGRAFICA": {"rol": "OBJETO", "es": "una cámara fotográfica"},
    "CAMBIAR": {"rol": "VERBO", "es": "cambié"},
    "CARNET": {"rol": "DESCONOCIDO", "es": "mi carnet de identidad"},
    "CARO": {"rol": "DESCRIPTOR", "es": "costoso"},
    "CARPETA": {"rol": "DOCUMENTO", "es": "la carpeta de documentos"},
    "CASA": {"rol": "LUGAR", "es": "en mi casa"},
    "CELULAR": {"rol": "OBJETO", "es": "mi celular"},
    "CENTRO_DE_SALUD": {"rol": "LUGAR", "es": "en el centro de salud"},
    "CERCA": {"rol": "LUGAR", "es": "cerca"},
    "CERTIFICADO": {"rol": "DOCUMENTO", "es": "un certificado"},
    "CHAMARRA": {"rol": "OBJETO", "es": "mi chamarra"},
    "COCHABAMBA": {"rol": "LUGAR", "es": "en Cochabamba"},
    "COMO": {"rol": "DESCONOCIDO", "es": "cómo"},
    "COMPAÑERO": {"rol": "DESCRIPTOR", "es": "un compañero", "persona": True},
    "COMPRAR": {"rol": "VERBO", "es": "compré"},
    "COMPRENDER": {"rol": "DESCONOCIDO", "es": "comprender"},
    "COMPROBANTE": {"rol": "OBJETO", "es": "un comprobante"},
    "COMPUTADORA": {"rol": "OBJETO", "es": "una computadora"},
    "COMUNIDAD_SORDA": {"rol": "DESCRIPTOR", "es": "la comunidad sorda", "persona": True},
    "CONFIANZA": {"rol": "ESTADO", "es": "tengo confianza"},
    "CONOCER": {"rol": "VERBO", "es": "conozco a esa persona"},
    "CONSTANCIA": {"rol": "DOCUMENTO", "es": "una constancia"},
    "CONTESTAR_DOS_VECES": {"rol": "VERBO", "es": "contesté dos veces"},
    "CONTINUAR": {"rol": "VERBO", "es": "continúa"},
    "CONVOCAR": {"rol": "TRAMITE", "es": "una citación"},
    "COPIAR": {"rol": "VERBO", "es": "copié"},
    "CORRER": {"rol": "VERBO", "es": "salió corriendo", "agresor": "salió corriendo"},
    "CORTO": {"rol": "DESCRIPTOR", "es": "corto"},
    "CREER": {"rol": "VERBO", "es": "creo"},
    "CUAL": {"rol": "DESCONOCIDO", "es": "cuál"},
    "CUANDO": {"rol": "DESCONOCIDO", "es": "cuándo"},
    "CUANTOS": {"rol": "DESCONOCIDO", "es": "cuántos"},
    "CURAR": {"rol": "VERBO", "es": "curar"},
    "D": {"rol": "VERBO", "es": "d"},
    "DAR": {"rol": "VERBO", "es": "entregué"},
    "DAÑAR": {"rol": "VERBO", "es": "dañó", "agresor": "dañó"},
    "DECIDIR": {"rol": "VERBO", "es": "decidí"},
    "DEFENSA_PUBLICA": {"rol": "INSTITUCION", "es": "en la Defensa Pública"},
    "DEJAR": {"rol": "VERBO", "es": "dejé"},
    "DELGADO": {"rol": "DESCRIPTOR", "es": "delgado"},
    "DENTRO": {"rol": "LUGAR", "es": "dentro"},
    "DENUNCIAR": {"rol": "VERBO", "es": "quiero presentar una denuncia"},
    "DESCANSO": {"rol": "TIEMPO", "es": "en horario de descanso"},
    "DESCONOCER": {"rol": "VERBO", "es": "no conozco a esa persona"},
    "DESPUES": {"rol": "TIEMPO", "es": "después"},
    "DEVOLVER": {"rol": "VERBO", "es": "quiero que devuelvan"},
    "DE_NADA": {"rol": "DESCONOCIDO", "es": "de nada"},
    "DIA": {"rol": "TIEMPO", "es": "día"},
    "DIBUJAR": {"rol": "VERBO", "es": "dibujé"},
    "DIFERENTE": {"rol": "DESCRIPTOR", "es": "diferente"},
    "DIFICIL": {"rol": "DESCRIPTOR", "es": "difícil"},
    "DINERO": {"rol": "OBJETO", "es": "mi dinero"},
    "DIRECCION": {"rol": "LUGAR", "es": "en mi dirección"},
    "DISCRIMINACION": {"rol": "DOCUMENTO", "es": "discriminación"},
    "DOCTOR": {"rol": "SERVICIO", "es": "un doctor"},
    "DOLOR": {"rol": "URGENCIA", "es": "dolor físico"},
    "DONDE": {"rol": "DESCONOCIDO", "es": "dónde"},
    "DORMIR": {"rol": "VERBO", "es": "dormía"},
    "DURANTE": {"rol": "TIEMPO", "es": "durante ese tiempo"},
    "E": {"rol": "VERBO", "es": "e"},
    "EDAD": {"rol": "DESCONOCIDO", "es": "tengo esa edad"},
    "EL": {"rol": "SUJETO", "es": "él"},
    "ELLA": {"rol": "SUJETO", "es": "ella"},
    "ELLOS": {"rol": "SUJETO", "es": "ellos"},
    "EMPEZAR": {"rol": "VERBO", "es": "empezó"},
    "ENCONTRARSE": {"rol": "VERBO", "es": "me encontré"},
    "ENFRENTE": {"rol": "LUGAR", "es": "enfrente"},
    "ENGAÑAR": {"rol": "VERBO", "es": "engañó y estafó", "agresor": "engañó y estafó"},
    "ENTREGAR": {"rol": "VERBO", "es": "me entregaron"},
    "ENVIAR": {"rol": "VERBO", "es": "envié"},
    "ESCAPAR": {"rol": "VERBO", "es": "escapó", "agresor": "escapó"},
    "ESCONDER": {"rol": "VERBO", "es": "escondió"},
    "ESCRIBIR": {"rol": "VERBO", "es": "quiero escribir"},
    "ESCUELA": {"rol": "LUGAR", "es": "en la escuela"},
    "ESCUELA_NOCTURNA": {"rol": "LUGAR", "es": "en la escuela nocturna"},
    "ESPERAR": {"rol": "VERBO", "es": "esperar"},
    "ESPOSA": {"rol": "DESCRIPTOR", "es": "mi esposa", "persona": True},
    "ESTADO": {"rol": "TRAMITE", "es": "el estado"},
    "ESTAR_DE_ACUERDO": {"rol": "DESCONOCIDO", "es": "estoy de acuerdo"},
    "EVALUAR": {"rol": "VERBO", "es": "evaluar"},
    "EXPAREJA": {"rol": "DESCRIPTOR", "es": "mi expareja", "persona": True},
    "EXPEDIENTE": {"rol": "DOCUMENTO", "es": "el expediente"},
    "EXPLICAR": {"rol": "VERBO", "es": "quiero explicar"},
    "F": {"rol": "VERBO", "es": "f"},
    "FACTURA": {"rol": "DOCUMENTO", "es": "la factura"},
    "FALTA": {"rol": "VERBO", "es": "perdí"},
    "FECHA": {"rol": "TIEMPO", "es": "en la fecha indicada"},
    "FELCC": {"rol": "INSTITUCION", "es": "en la FELCC"},
    "FELCV": {"rol": "INSTITUCION", "es": "en la FELCV"},
    "FILMAR": {"rol": "VERBO", "es": "filmé"},
    "FISCALIA": {"rol": "INSTITUCION", "es": "en la Fiscalía"},
    "FLACO": {"rol": "DESCRIPTOR", "es": "delgado"},
    "FORMULARIO": {"rol": "DOCUMENTO", "es": "un formulario"},
    "FOTOCOPIA": {"rol": "DOCUMENTO", "es": "una fotocopia"},
    "FOTOGRAFIA": {"rol": "OBJETO", "es": "una fotografía"},
    "FOTOS": {"rol": "OBJETO", "es": "fotografías"},
    "FRACTURA": {"rol": "URGENCIA", "es": "una fractura"},
    "FUERA": {"rol": "LUGAR", "es": "fuera"},
    "FUNCIONAR": {"rol": "VERBO", "es": "funciona"},
    "FUTURO": {"rol": "TIEMPO", "es": "en el futuro"},
    "G": {"rol": "VERBO", "es": "g"},
    "GANAR_DINERO": {"rol": "VERBO", "es": "gané dinero"},
    "GESTIONAR": {"rol": "VERBO", "es": "quiero gestionar"},
    "GOBIERNO": {"rol": "INSTITUCION", "es": "el gobierno"},
    "GORDO": {"rol": "DESCRIPTOR", "es": "de contextura gruesa"},
    "GORRA": {"rol": "OBJETO", "es": "mi gorra"},
    "GRACIAS": {"rol": "DESCONOCIDO", "es": "muchas gracias"},
    "GRATIS": {"rol": "DESCRIPTOR", "es": "gratuito"},
    "GRITAR": {"rol": "VERBO", "es": "gritó"},
    "GRUESO": {"rol": "DESCRIPTOR", "es": "grueso"},
    "GUARDAR": {"rol": "VERBO", "es": "guardé"},
    "H": {"rol": "VERBO", "es": "h"},
    "HABLAR": {"rol": "VERBO", "es": "quiero hablar"},
    "HACER": {"rol": "VERBO", "es": "hice"},
    "HASTA_LUEGO": {"rol": "DESCONOCIDO", "es": "hasta luego"},
    "HASTA_MAÑANA": {"rol": "DESCONOCIDO", "es": "hasta mañana"},
    "HERIDA": {"rol": "URGENCIA", "es": "una herida"},
    "HERMANA": {"rol": "DESCRIPTOR", "es": "mi hermana", "persona": True},
    "HERMANO": {"rol": "DESCRIPTOR", "es": "mi hermano", "persona": True},
    "HIJA": {"rol": "DESCRIPTOR", "es": "mi hija", "persona": True},
    "HIJO": {"rol": "DESCRIPTOR", "es": "mi hijo", "persona": True},
    "HOLA": {"rol": "DESCONOCIDO", "es": "hola"},
    "HOMBRE": {"rol": "DESCRIPTOR", "es": "un hombre", "persona": True},
    "HORA": {"rol": "TIEMPO", "es": "hora"},
    "HOSPITAL": {"rol": "INSTITUCION", "es": "en el hospital"},
    "HOY": {"rol": "TIEMPO", "es": "hoy"},
    "HUESOS": {"rol": "URGENCIA", "es": "los huesos"},
    "I": {"rol": "VERBO", "es": "i"},
    "IDENTIDAD": {"rol": "DESCONOCIDO", "es": "mi carnet de identidad"},
    "IDENTIFICAR": {"rol": "VERBO", "es": "puedo identificar"},
    "IGNORAR": {"rol": "VERBO", "es": "me ignoraron"},
    "INSTITUCION": {"rol": "INSTITUCION", "es": "en la institución"},
    "INTERNET": {"rol": "OBJETO", "es": "por internet"},
    "INTERPRETE": {"rol": "SERVICIO", "es": "un intérprete de LSB"},
    "INVESTIGACION": {"rol": "TRAMITE", "es": "la investigación de mi caso"},
    "IR": {"rol": "VERBO", "es": "fui"},
    "J": {"rol": "VERBO", "es": "j"},
    "JAMAS": {"rol": "TIEMPO", "es": "jamás"},
    "JEFE": {"rol": "DESCRIPTOR", "es": "mi jefe", "persona": True},
    "JOVEN": {"rol": "DESCRIPTOR", "es": "joven", "persona": True},
    "JUEVES": {"rol": "TIEMPO", "es": "el jueves"},
    "JUEZ": {"rol": "INSTITUCION", "es": "el juez"},
    "JULIO": {"rol": "TIEMPO", "es": "en julio"},
    "JUSTICIA": {"rol": "DOCUMENTO", "es": "la justicia"},
    "JUZGADO": {"rol": "INSTITUCION", "es": "en el juzgado"},
    "K": {"rol": "VERBO", "es": "k"},
    "L": {"rol": "VERBO", "es": "l"},
    "LADRON": {"rol": "DESCRIPTOR", "es": "un ladrón", "persona": True},
    "LEER": {"rol": "VERBO", "es": "quiero leer"},
    "LEJOS": {"rol": "LUGAR", "es": "lejos"},
    "LENTES": {"rol": "OBJETO", "es": "mis lentes"},
    "LENTO": {"rol": "DESCRIPTOR", "es": "despacio"},
    "LEY": {"rol": "DOCUMENTO", "es": "la ley"},
    "LIBRE": {"rol": "TIEMPO", "es": "libre"},
    "LISTA": {"rol": "DOCUMENTO", "es": "la lista"},
    "LLAMAR": {"rol": "VERBO", "es": "llamé"},
    "LLEGAR": {"rol": "VERBO", "es": "llegué"},
    "LLEVAR": {"rol": "VERBO", "es": "llevaba"},
    "LO_SIENTO": {"rol": "DESCONOCIDO", "es": "lo siento"},
    "LUEGO": {"rol": "TIEMPO", "es": "luego"},
    "LUNES": {"rol": "TIEMPO", "es": "el lunes"},
    "M": {"rol": "VERBO", "es": "m"},
    "MAL": {"rol": "DESCRIPTOR", "es": "mal"},
    "MALTRATAR": {"rol": "VERBO", "es": "maltrató", "agresor": "maltrató"},
    "MAMA": {"rol": "DESCRIPTOR", "es": "mi mamá", "persona": True},
    "MARTES": {"rol": "TIEMPO", "es": "el martes"},
    "MARZO": {"rol": "TIEMPO", "es": "en marzo"},
    "MAS_O_MENOS": {"rol": "DESCONOCIDO", "es": "más o menos"},
    "MAÑANA": {"rol": "TIEMPO", "es": "mañana"},
    "MEDICINA": {"rol": "OBJETO", "es": "medicinas"},
    "MEJOR": {"rol": "DESCRIPTOR", "es": "mejor"},
    "MEMORIAL": {"rol": "DOCUMENTO", "es": "un memorial"},
    "MENSAJE": {"rol": "OBJETO", "es": "un mensaje"},
    "MENTIRA": {"rol": "DESCONOCIDO", "es": "es mentira"},
    "MERCADO": {"rol": "LUGAR", "es": "en el mercado"},
    "MES": {"rol": "TIEMPO", "es": "mes"},
    "MICRO": {"rol": "OBJETO", "es": "un micro"},
    "MIEDO": {"rol": "ESTADO", "es": "tengo miedo"},
    "MILITAR": {"rol": "DESCRIPTOR", "es": "un militar", "persona": True},
    "MINUTO": {"rol": "TIEMPO", "es": "minuto"},
    "MIO": {"rol": "SUJETO", "es": "mi"},
    "MIRAR": {"rol": "VERBO", "es": "vi"},
    "MOCHILA": {"rol": "OBJETO", "es": "mi mochila"},
    "MOMENTO": {"rol": "TIEMPO", "es": "en ese momento"},
    "MOSTRAR": {"rol": "VERBO", "es": "puedo mostrar"},
    "MOTOCICLETA": {"rol": "OBJETO", "es": "mi motocicleta"},
    "MUCHO": {"rol": "DESCRIPTOR", "es": "mucho"},
    "MUJER": {"rol": "DESCRIPTOR", "es": "una mujer", "persona": True},
    "N": {"rol": "VERBO", "es": "n"},
    "NARRAR": {"rol": "VERBO", "es": "quiero relatar"},
    "NECESITAR": {"rol": "VERBO", "es": "necesitar"},
    "NEGRO": {"rol": "DESCRIPTOR", "es": "de color negro"},
    "NO": {"rol": "DESCONOCIDO", "es": "no"},
    "NOMBRE": {"rol": "DESCONOCIDO", "es": "mi nombre es"},
    "NOSOTROS": {"rol": "SUJETO", "es": "nosotros"},
    "NOTIFICACION": {"rol": "DOCUMENTO", "es": "la notificación"},
    "NO_ENTIENDO": {"rol": "DESCONOCIDO", "es": "no entiendo"},
    "NO_ESTAR_DE_ACUERDO": {"rol": "DESCONOCIDO", "es": "no estoy de acuerdo"},
    "NO_PUEDO": {"rol": "DESCONOCIDO", "es": "no puedo"},
    "NO_RECUERDO": {"rol": "DESCONOCIDO", "es": "no recuerdo"},
    "NO_SABER": {"rol": "DESCONOCIDO", "es": "no sé"},
    "NUEVO": {"rol": "DESCRIPTOR", "es": "nuevo"},
    "NUREJ": {"rol": "DOCUMENTO", "es": "el NUREJ"},
    "O": {"rol": "VERBO", "es": "o"},
    "OBSERVACION": {"rol": "DOCUMENTO", "es": "una observación"},
    "OBSERVAR": {"rol": "VERBO", "es": "observé"},
    "OCUPADO": {"rol": "TIEMPO", "es": "ocupado"},
    "OFICIAL": {"rol": "SERVICIO", "es": "un oficial"},
    "OFICINA": {"rol": "LUGAR", "es": "en la oficina"},
    "OIR": {"rol": "VERBO", "es": "escuché"},
    "ORGANIZAR": {"rol": "VERBO", "es": "organicé"},
    "ORGANO_JUDICIAL": {"rol": "INSTITUCION", "es": "en el Órgano Judicial"},
    "OSCURO": {"rol": "DESCRIPTOR", "es": "oscuro"},
    "OYENTE": {"rol": "DESCRIPTOR", "es": "oyente", "persona": True},
    "P": {"rol": "VERBO", "es": "p"},
    "PAGAR": {"rol": "VERBO", "es": "pagué"},
    "PAGINA": {"rol": "DOCUMENTO", "es": "la página"},
    "PALABRA": {"rol": "VERBO", "es": "palabra"},
    "PANTALON": {"rol": "OBJETO", "es": "mi pantalón"},
    "PAPEL": {"rol": "DOCUMENTO", "es": "el documento"},
    "PARADA": {"rol": "LUGAR", "es": "en la parada"},
    "PAREJA": {"rol": "DESCRIPTOR", "es": "mi pareja", "persona": True},
    "PARIENTE": {"rol": "DESCRIPTOR", "es": "un pariente", "persona": True},
    "PASADO": {"rol": "TIEMPO", "es": "en el pasado"},
    "PASADO_MAÑANA": {"rol": "TIEMPO", "es": "pasado mañana"},
    "PASAPORTE": {"rol": "DOCUMENTO", "es": "mi pasaporte"},
    "PEDIR": {"rol": "VERBO", "es": "solicito"},
    "PEGAR": {"rol": "VERBO", "es": "golpeó y pegó", "agresor": "golpeó y pegó"},
    "PELEAR": {"rol": "VERBO", "es": "inició una pelea", "agresor": "inició una pelea"},
    "PERDER": {"rol": "VERBO", "es": "perdí"},
    "PERMISO": {"rol": "DESCONOCIDO", "es": "con permiso"},
    "PLAZA": {"rol": "LUGAR", "es": "en la plaza"},
    "PLAZO": {"rol": "TRAMITE", "es": "el plazo"},
    "POCO": {"rol": "DESCRIPTOR", "es": "poco"},
    "POLERA": {"rol": "OBJETO", "es": "mi polera"},
    "POLICIA": {"rol": "INSTITUCION", "es": "en la policía"},
    "POR_FAVOR": {"rol": "DESCONOCIDO", "es": "por favor"},
    "POSTERGAR": {"rol": "TIEMPO", "es": "postergar"},
    "PREOCUPAR": {"rol": "ESTADO", "es": "estoy preocupado"},
    "PRESENTAR": {"rol": "VERBO", "es": "quiero presentar"},
    "PRIMERA_VEZ": {"rol": "TIEMPO", "es": "la primera vez"},
    "PRODUCTO": {"rol": "OBJETO", "es": "el producto"},
    "PROHIBIDO": {"rol": "DOCUMENTO", "es": "prohibido"},
    "PROTEGER": {"rol": "VERBO", "es": "necesito protección"},
    "PROVINCIA": {"rol": "LUGAR", "es": "en la provincia"},
    "PROXIMO": {"rol": "TIEMPO", "es": "el próximo"},
    "PUEDO": {"rol": "DESCONOCIDO", "es": "puedo"},
    "PUERTA": {"rol": "OBJETO", "es": "la puerta"},
    "Q": {"rol": "VERBO", "es": "q"},
    "QUE": {"rol": "DESCONOCIDO", "es": "qué"},
    "QUEJAR": {"rol": "VERBO", "es": "quejar"},
    "QUERER": {"rol": "VERBO", "es": "querer"},
    "QUIEN": {"rol": "DESCONOCIDO", "es": "quién"},
    "R": {"rol": "VERBO", "es": "r"},
    "RAYOS_X": {"rol": "OBJETO", "es": "placas de rayos X"},
    "RECHAZAR": {"rol": "VERBO", "es": "rechazo"},
    "RECIBIR": {"rol": "VERBO", "es": "recibí"},
    "RECORDAR": {"rol": "VERBO", "es": "recuerdo"},
    "RESOLUCION": {"rol": "DOCUMENTO", "es": "una resolución"},
    "RESPALDO": {"rol": "OBJETO", "es": "un respaldo"},
    "RESULTADO": {"rol": "DOCUMENTO", "es": "el resultado"},
    "REUNION": {"rol": "VERBO", "es": "reunión"},
    "ROBAR": {"rol": "VERBO", "es": "robó", "agresor": "robó"},
    "ROJO": {"rol": "DESCRIPTOR", "es": "de color rojo"},
    "S": {"rol": "VERBO", "es": "s"},
    "SABADO": {"rol": "TIEMPO", "es": "el sábado"},
    "SABER": {"rol": "DESCONOCIDO", "es": "sé"},
    "SEGUNDO": {"rol": "TIEMPO", "es": "segundo"},
    "SEGURO": {"rol": "ESTADO", "es": "me encuentro en un lugar seguro"},
    "SELLO": {"rol": "DOCUMENTO", "es": "un sello oficial"},
    "SEMANA": {"rol": "TIEMPO", "es": "semana"},
    "SEPARADOS": {"rol": "DESCRIPTOR", "es": "separados", "persona": True},
    "SEPDAVI": {"rol": "INSTITUCION", "es": "en el SEPDAVI"},
    "SEPDEP": {"rol": "INSTITUCION", "es": "en el SEPDEP"},
    "SEÑOR": {"rol": "DESCRIPTOR", "es": "el señor", "persona": True},
    "SI": {"rol": "DESCONOCIDO", "es": "sí"},
    "SIEMPRE": {"rol": "TIEMPO", "es": "siempre"},
    "SOLUCIONAR": {"rol": "VERBO", "es": "quiero solucionar"},
    "SOPORTE": {"rol": "DOCUMENTO", "es": "soporte"},
    "SORDO": {"rol": "DESCRIPTOR", "es": "una persona sorda", "persona": True},
    "SOSPECHA": {"rol": "ESTADO", "es": "tengo una sospecha"},
    "SUYO": {"rol": "SUJETO", "es": "suyo"},
    "T": {"rol": "VERBO", "es": "t"},
    "TAL_VEZ": {"rol": "DESCONOCIDO", "es": "tal vez"},
    "TARDE": {"rol": "TIEMPO", "es": "por la tarde"},
    "TAXI": {"rol": "OBJETO", "es": "un taxi"},
    "TELEFONO": {"rol": "OBJETO", "es": "mi teléfono"},
    "TEMOR": {"rol": "ESTADO", "es": "tengo temor"},
    "TEMPRANO": {"rol": "TIEMPO", "es": "temprano"},
    "TENER": {"rol": "VERBO", "es": "tener"},
    "TERMINAR": {"rol": "VERBO", "es": "terminó"},
    "TESTIGO": {"rol": "TESTIGO", "es": "un testigo"},
    "TESTIMONIO": {"rol": "DOCUMENTO", "es": "mi testimonio"},
    "TIENDA": {"rol": "LUGAR", "es": "en la tienda"},
    "TODOS_LOS_DIAS": {"rol": "TIEMPO", "es": "todos los días"},
    "TOTAL": {"rol": "VERBO", "es": "total"},
    "TRABAJADOR": {"rol": "DESCRIPTOR", "es": "un trabajador", "persona": True},
    "TRAER": {"rol": "VERBO", "es": "puedo traer"},
    "TRAMITE": {"rol": "TRAMITE", "es": "un trámite"},
    "TRISTE": {"rol": "ESTADO", "es": "estoy triste"},
    "TRUFI": {"rol": "OBJETO", "es": "un trufi"},
    "TU": {"rol": "SUJETO", "es": "tú"},
    "TUYO": {"rol": "SUJETO", "es": "su"},
    "U": {"rol": "VERBO", "es": "u"},
    "ULTIMO": {"rol": "TIEMPO", "es": "el último"},
    "URGENTE": {"rol": "URGENCIA", "es": "de manera urgente"},
    "V": {"rol": "VERBO", "es": "v"},
    "VARIOS": {"rol": "SUJETO", "es": "varios"},
    "VECINO": {"rol": "DESCRIPTOR", "es": "un vecino", "persona": True},
    "VENDER": {"rol": "VERBO", "es": "vendí"},
    "VENIR": {"rol": "VERBO", "es": "vine"},
    "VENTANILLA": {"rol": "LUGAR", "es": "en la ventanilla"},
    "VER": {"rol": "VERBO", "es": "vi"},
    "VERDAD": {"rol": "DESCONOCIDO", "es": "es verdad"},
    "VIDEO": {"rol": "OBJETO", "es": "un video"},
    "VIDEOLLAMADA": {"rol": "OBJETO", "es": "una videollamada"},
    "VIERNES": {"rol": "TIEMPO", "es": "el viernes"},
    "VIOLENCIA": {"rol": "URGENCIA", "es": "un hecho de violencia"},
    "VIVIR": {"rol": "VERBO", "es": "vivo"},
    "VOLVER": {"rol": "VERBO", "es": "debo volver"},
    "W": {"rol": "VERBO", "es": "w"},
    "WHATSAPP": {"rol": "OBJETO", "es": "por WhatsApp"},
    "X": {"rol": "VERBO", "es": "x"},
    "Y": {"rol": "VERBO", "es": "y"},
    "YO": {"rol": "SUJETO", "es": "yo"},
    "Z": {"rol": "VERBO", "es": "z"},
    "Ñ": {"rol": "VERBO", "es": "ñ"},
}

# GLOSS_LEXICON se generó con claves sin tilde, pero el diccionario canónico
# del cliente (assets/dictionary/official_dictionary.json) usa la forma con
# tilde: DÓNDE, CUÁNDO, POLICÍA, RESOLUCIÓN, DÍA, ÓRGANO_JUDICIAL... Sin
# normalizar antes de buscar, cualquier glosa acentuada caía en
# "desconocidos" aunque el lexicón sí la tuviera, con otra ortografía
# (auditoría 2026-09). Espejo de `_stripGlossAccents` en
# local_sentence_assembler.dart: la Ñ se conserva, solo se quitan tildes de
# vocales.
_ACCENT_TABLE = str.maketrans("ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛ", "AAAAEEEEIIIIOOOOUUUU")


def _lexicon_key(raw: str) -> str:
    return str(raw).strip().upper().replace("-", "_").translate(_ACCENT_TABLE)


def lexicon_lookup(raw: str):
    """Busca una glosa en GLOSS_LEXICON tolerando tildes y guiones."""
    return GLOSS_LEXICON.get(_lexicon_key(raw))


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

# Espejo de _deicticTimeForm en el cliente: unidad sin cantidad detrás resuelta
# con su forma deíctica, no el lexema base sin artículo ("Semana, una persona
# me robó.").
_DEICTIC_TIME_FORM = {
    "MINUTO": "este minuto", "HORA": "esta hora", "DIA": "hoy",
    "SEMANA": "esta semana", "MES": "este mes", "ANO": "este año",
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
    # Relaciones espaciales: "cerca/lejos/dentro/fuera/al lado" no significan
    # nada sin su referencia (auditoría 2026-09).
    "CERCA": "relacion", "LEJOS": "relacion", "DENTRO": "relacion",
    "FUERA": "relacion", "AL_LADO": "relacion",
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
        entry = lexicon_lookup(unidad)
        if entry and not analysis["tiempos"]:
            deictico = _DEICTIC_TIME_FORM.get(unidad, entry["es"])
            analysis["tiempos"].insert(0, {**entry, "glosa": unidad, "es": deictico})
        return

    if cantidad == "1":
        cardinal = "una" if spec["femenino"] else "un"
        medida = spec["singular"]
    else:
        # _CARDINALES solo deletrea 1-9; un modal de cantidad en el cliente
        # ahora admite cualquier cifra ("hace 15 días"), y de dos cifras en
        # adelante se escribe en dígitos, tal como se diría de todos modos —
        # el acceso directo aquí lanzaba KeyError con cualquier número así.
        cardinal = _CARDINALES.get(cantidad, cantidad)
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
    if etiqueta == "relacion":
        return f"{lexema} de {propio}"
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
        # Quien PRESENCIÓ el hecho. Bucket propio, no `descriptores`: ahí
        # `_agresor_text` lo tomaba por el autor del delito y el acta recogía
        # "Un testigo me robó", que acusa a quien solo miraba. Espejo de
        # `_Role.testigo` en el cliente.
        "testigos": [],
        "testigos_negados": False,
        "testigos_afirmados": False,
        "huida": None,
        "frecuencia": None,
        "desconocidos": [],
    }

    # Tras el marcador VICTIMA, los descriptores describen a la persona
    # agredida (no al agresor). Mantiene la coherencia del relato de testigo.
    victim_mode = False
    # Marcadores estructurales del cliente (kEvidenceMarker/kVehicleMarker):
    # cambian el papel del objeto que sigue, nunca son palabras del relato.
    # Sin reconocerlos, PRUEBA_MARCADOR caía en "desconocidos" y se filtraba
    # como texto crudo ("hago referencia a prueba_marcador"), y el objeto que
    # lo seguía se contaba como botín robado en vez de como prueba aportada
    # (auditoría 2026-09).
    evidence_mode = False
    vehicle_mode = False
    negar_siguiente_verbo = False
    afirmar_siguiente_verbo = False
    detalles = {}
    # Se normalizan tildes aquí, una sola vez, para que TODAS las
    # comparaciones internas (unidades de tiempo, cardinales, marcadores,
    # lexicón) trabajen sobre la misma forma canónica sin tilde — igual que
    # hace el cliente en `_normalize`/`_stripGlossAccents`. Antes solo el
    # lookup final al lexicón toleraba tildes; `_TIME_UNITS`, `_ADMITE_DETALLE`
    # y los marcadores de frecuencia/evidencia seguían exigiendo la forma sin
    # tilde y nunca coincidían con DÍA, SÍ, etc. (auditoría 2026-09).
    normalizadas = _extract_details(_join_spelled_digits(
        [_lexicon_key(c) for c in cards]), detalles)
    for indice, card in enumerate(normalizadas):
        key = _lexicon_key(card)

        # CAMBIO (paridad Dart): en LSB la negación es una seña aparte, no un
        # prefijo. NO delante de un verbo lo niega ("NO ENTREGAR" → "no me
        # entregaron"). Sin esto el NO quedaba suelto y el verbo se afirmaba,
        # que es decir lo contrario de lo que la persona quiso decir.
        if key in ("NO", "SI") and indice + 1 < len(normalizadas):
            siguiente = lexicon_lookup(normalizadas[indice + 1])
            # Alcanza también a TESTIGO: "¿Hay testigos?" se responde sí o no
            # y su respuesta no es un verbo, sino la persona misma.
            if siguiente and siguiente["rol"] in ("VERBO", "TESTIGO"):
                if key == "NO":
                    negar_siguiente_verbo = True
                else:
                    afirmar_siguiente_verbo = True
                continue
        if key == "VICTIMA":
            victim_mode = True
            continue
        if key == "PRUEBA_MARCADOR":
            evidence_mode = True
            continue
        if key == "VEHICULO_MARCADOR":
            vehicle_mode = True
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
            entry = lexicon_lookup(key)
            if entry:
                analysis.setdefault("evidencias", []).append({"glosa": key, **entry})
            continue

        # CAMBIO (paridad Dart): huida del agresor, no agresión contra mí.
        if key in _FLIGHT_VERBS:
            entry = lexicon_lookup(key)
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

        # CAMBIO (paridad Dart): dígito huérfano —sin unidad de tiempo
        # delante— no significa nada por sí solo. Como los dígitos SÍ tienen
        # entrada en GLOSS_LEXICON (rol VERBO, para deletrear placas y
        # NUREJ), este descarte debe ir ANTES del despacho por rol: si no,
        # `if entry:` siempre gana primero y el "2" huérfano se cuela como
        # un verbo más, saliendo como una oración propia ("...urgente. 2.").
        if key in _DIGITOS:
            continue

        entry = lexicon_lookup(key)
        if entry and entry["rol"] == "TESTIGO":
            analysis["testigos_negados"] = (
                analysis["testigos_negados"] or negar_siguiente_verbo)
            analysis["testigos_afirmados"] = (
                analysis["testigos_afirmados"] or afirmar_siguiente_verbo)
            negar_siguiente_verbo = False
            afirmar_siguiente_verbo = False
            if entry["es"] not in analysis["testigos"]:
                analysis["testigos"].append(entry["es"])
            continue
        if entry and entry["rol"] == "DESCRIPTOR" and victim_mode:
            analysis["victima_descriptores"].append({"glosa": key, **entry})
            continue
        # Un objeto tras PRUEBA_MARCADOR se aportó como prueba, no como
        # botín: sin esto, una fotografía o factura mencionada para acreditar
        # el hecho se contaba como algo robado (auditoría 2026-09).
        if entry and entry["rol"] == "OBJETO" and evidence_mode:
            registro = {"glosa": key, **entry}
            registro["es"] = _con_detalle(key, registro["es"], detalles)
            analysis.setdefault("evidencias", []).append(registro)
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
            if rol == "VERBO":
                if negar_siguiente_verbo:
                    registro["es"] = f'no {registro["es"]}'
                elif afirmar_siguiente_verbo:
                    registro["es"] = f'sí {registro["es"]}'
                negar_siguiente_verbo = False
                afirmar_siguiente_verbo = False
            analysis[dest].append(registro)
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
    verbos = [v["glosa"] for v in analysis["verbos"]]
    tramites = [t["glosa"] for t in analysis["tramites"]]
    documentos = [d["glosa"] for d in analysis["documentos"]]

    if ctx in ("accidente", "emergencia"):
        return "EMERGENCIA"
    # Fase 1 no narra un hecho: la declaración son los datos, que viajan como
    # marcadores y encabezan. Sin esta rama caía en la plantilla de solicitud
    # y salía "Necesito asistencia", que nadie pidió.
    if ctx == "identificacion":
        return "IDENTIFICACION"

    # PERDER manda sobre el contexto, incluso dentro del menú de robo: haber
    # entrado a "Denunciar robo" para llegar hasta esta pregunta no prueba
    # que haya ocurrido un robo. Antes, elegir Perder dentro de ese contexto
    # se narraba igual como un asalto (auditoría 2026-09, hallazgo PERDER).
    if any(v in ("PERDER", "FALTA") for v in verbos):
        return "PERDIDA"

    # Misma regla para el relato de un hecho: el cliente enruta por contexto
    # (`'denuncia_robo' || 'violencia' => _composeIncident`). Sin esto, una
    # denuncia sin verbo de delito —una estafa, que el diccionario no puede
    # nombrar— caía en la plantilla de ESTADO y salía "Por un problema.",
    # perdiendo el dinero, el producto y el canal.
    #
    # Pero un contexto por sí solo no es un hecho: responder solo "¿hay
    # testigos? No" dentro de este menú no debe fabricar una afirmación de
    # robo o agresión que esas dos glosas no contienen (auditoría 2026-09,
    # hallazgo NO+TESTIGO). Se exige alguna señal real del hecho —un verbo,
    # un objeto, un rasgo de la persona o un lugar— antes de forzar la
    # plantilla del contexto.
    hay_contenido_del_hecho = bool(
        verbos or analysis.get("objetos") or analysis.get("descriptores")
        or analysis.get("lugares") or documentos
    )
    if ctx == "denuncia_robo":
        return "ROBO" if hay_contenido_del_hecho else "GENERAL"
    if ctx == "violencia":
        return "AGRESION" if hay_contenido_del_hecho else "GENERAL"

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
    # PERDER/FALTA ya se resolvieron arriba, antes que cualquier ctx.
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

# ===========================================================================
# GENERACIÓN ESTRUCTURADA — espejo de `assembleStructured` en
# local_sentence_assembler.dart (auditoría 2026-09).
#
# A diferencia de `analyze_glosses`/`generate_base_sentence` (una lista plana
# de glosas que este módulo debe reclasificar y adivinar cómo relacionar),
# esta función recibe el `declaration` que ya viajó con las relaciones
# explícitas desde el cliente: qué prenda y color son de qué persona, qué
# papel cumple cada objeto, y de qué lugar es referencia una relación
# espacial. Se limita a redactarlas. Solo se usa para `denuncia_robo` cuando
# el cliente manda `contractVersion >= 2` y un `declaration`; los demás
# contextos siguen la vía determinista anterior.
_NEUTRAL_CLOTHING = {
    "POLERA": "una polera", "PANTALON": "un pantalón", "PANTALÓN": "un pantalón",
    "GORRA": "una gorra", "CHAMARRA": "una chamarra",
    "LENTES": "lentes", "MOCHILA": "una mochila", "BOLSA": "una bolsa",
    "CAJA": "una caja",
}
_FEMININE_CLOTHING = {"POLERA", "GORRA", "CHAMARRA", "BOLSA", "MOCHILA", "CAJA"}
_PLURAL_CLOTHING = {"LENTES"}


def _color_adj(concept: str, color: str) -> str:
    concept_key = _lexicon_key(concept)
    plural = concept_key in _PLURAL_CLOTHING
    fem = concept_key in _FEMININE_CLOTHING
    c = _lexicon_key(color)
    if c == "ROJO":
        return "rojos" if plural else ("roja" if fem else "rojo")
    if c == "NEGRO":
        return "negros" if plural else ("negra" if fem else "negro")
    if c == "AZUL":
        return "azules" if plural else "azul"
    if c == "BLANCO":
        return "blancos" if plural else ("blanca" if fem else "blanco")
    if c == "VERDE":
        return "verdes" if plural else "verde"
    if c in ("CAFE", "CAFÉ"):
        return "cafés" if plural else "café"
    if c == "GRIS":
        return "grises" if plural else "gris"
    if c == "PLOMO":
        return "plomos" if plural else ("ploma" if fem else "plomo")
    if c == "AMARILLO":
        return "amarillos" if plural else ("amarilla" if fem else "amarillo")
    if c == "MORADO":
        return "morados" if plural else ("morada" if fem else "morado")
    if c == "NARANJA":
        return "naranjas" if plural else "naranja"
    return str(color).lower().replace("_", " ")


def _relation_word(relation: str) -> str:
    return {
        "CERCA": "cerca", "LEJOS": "lejos", "DENTRO": "dentro",
        "FUERA": "fuera", "AL_LADO": "al lado",
    }.get(_lexicon_key(relation), str(relation).lower())



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

    # Testigos: su propia oración, después del relato. Quién presenció el
    # hecho no es parte de lo que ocurrió. Espejo de `_withWitnesses` en el
    # cliente, y en el mismo sitio: un punto único para los trece
    # generadores, en vez de la regla repetida trece veces.
    sentence = _append_witnesses(sentence, analysis)

    # Verbos de acción que la plantilla no recogió. `_compose_incident` narra
    # con el verbo de agresión y descarta el resto, así que responder "¿conoce
    # a la persona?" dentro de una denuncia perdía la respuesta entera: el
    # cliente sí la compone, y una glosa que él representa y el servidor no
    # hace que se descarte TODA la redacción por cobertura incompleta.
    sueltos = [v["es"] for v in analysis.get("verbos", [])
               if not v.get("agresor")
               and _normalizar(v["es"]) not in _normalizar(sentence)]
    for texto in sueltos:
        sentence = sentence.rstrip(".") + ". " + texto[0].upper() + texto[1:]

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


def _append_witnesses(sentence: str, analysis: dict) -> str:
    """Cierra el relato con quién lo presenció.

    "¿Hay testigos?" se responde sí o no, así que la negativa tiene forma
    propia: que no los haya es un dato del acta, no un silencio.
    """
    testigos = analysis.get("testigos") or []
    if not testigos:
        return sentence
    if analysis.get("testigos_negados"):
        clausula = "No hay testigos"
    else:
        afirmacion = "Sí, hay" if analysis.get("testigos_afirmados") else "Hay"
        clausula = (f"{afirmacion} {testigos[0]}" if len(testigos) == 1
                    else f"{afirmacion} testigos")
    base = sentence.strip()
    if not base:
        return f"{clausula}."
    return f'{base.rstrip(".")}. {clausula}.'


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

    # CAMBIO (paridad Dart): las urgencias (HERIDA, AUXILIO, VIOLENCIA…) no
    # entraban en ninguna categoría de este generador ni de su respaldo
    # "all_es", así que una respuesta que solo las contenía (sin verbo,
    # documento, trámite o servicio) caía al último respaldo —los glosas
    # crudas en mayúscula, unidas y con .capitalize()— y salía "Violencia
    # herida auxilio.": exactamente lo que la persona no quiso comunicar.
    # Se redactan como cláusula propia, igual que `r.urgencies` en el
    # cliente (`_join(r.urgencies)`), en vez de perderse o salir en crudo.
    urgencias = [u["es"] for u in analysis.get("urgencias", [])]

    if parts:
        sentence = parts[0].capitalize()
        if len(parts) > 1:
            sentence += " " + " ".join(parts[1:])
        if urgencias:
            sentence = sentence.rstrip(".") + ". " + _cap(_join_es(urgencias))
        return sentence

    if urgencias:
        return _cap(_join_es(urgencias))

    all_es = []
    for cat in ["sujetos", "verbos", "documentos", "tramites", "tiempos", "instituciones", "servicios"]:
        for item in analysis[cat]:
            all_es.append(item["es"])
    for item in analysis["desconocidos"]:
        all_es.append(item["es"])

    return " ".join(all_es).capitalize() if all_es else " ".join(ir["glosas_originales"]).capitalize()

def has_structured_declaration(body: dict) -> bool:
    """Indica si la solicitud trae una declaración estructurada.

    Se llamaba `uses_structured`, igual que la variable local del handler, así
    que quedaba ensombrecida y nunca se ejecutaba: la decisión estaba escrita
    dos veces y solo valía una. Ahora hay un único sitio donde se decide.
    """
    if not isinstance(body, dict):
        return False
    decl = body.get("declaration")
    return isinstance(decl, dict) and bool(decl)


def _cap(s: str) -> str:
    if not s:
        return ""
    return s[0].upper() + s[1:]


def _decap(s: str) -> str:
    if not s:
        return ""
    return s[0].lower() + s[1:]


def _join(items: list) -> str:
    if not items:
        return ""
    if len(items) == 1:
        return items[0]
    if len(items) == 2:
        return f"{items[0]}, {items[1]}"
    return f"{', '.join(items[:-1])}, {items[-1]}"


def _person_phrase_structured(p: dict) -> str:
    genero = (p.get("gender") or p.get("genero") or "").strip().lower()
    complexion = (p.get("build") or p.get("complexion") or "").strip().lower()
    if complexion == "alto":
        comp_text = "de contextura alta"
    elif complexion:
        comp_text = f"de contextura {complexion}"
    else:
        comp_text = ""

    desc = f"{genero} {comp_text}".strip() if genero else (f"persona {comp_text}".strip() if comp_text else "persona")

    clothes = p.get("clothing") or p.get("clothes") or p.get("ropa") or []
    prendas = []
    for c in clothes:
        prenda_concept = (c.get("concept") or c.get("prenda") or c.get("garment") or "").strip()
        # Nombre de la prenda con su tilde correcta ("pantalón", no
        # "pantalon"): se toma del lexicón/mapa neutro en vez del texto
        # crudo que mandó el cliente, que puede no llevar tilde.
        neutral_form = _NEUTRAL_CLOTHING.get(_lexicon_key(prenda_concept))
        if neutral_form:
            prenda = re.sub(r"^(un|una|el|la)\s+", "", neutral_form)
        else:
            prenda = prenda_concept.lower()
        color_state = c.get("colorState") or c.get("color_state") or "confirmed"
        color = (c.get("color") or "").strip().lower() if color_state == "confirmed" else ""
        # Concordancia de género con la prenda (auditoría 2026-09): "polera
        # roja", no "polera rojo" — cada prenda concuerda con SU color, sin
        # afectar a las demás.
        color = _color_adj(prenda_concept, color.upper()) if color else color
        if prenda and color:
            prendas.append(f"{prenda} {color}")
        elif prenda:
            prendas.append(prenda)

    if prendas:
        return f"{desc}, vestía {', '.join(prendas)}"
    return desc


def _object_self_phrase_py(o: dict) -> str:
    concept = (o.get("concept") or o.get("glosa") or "").strip().upper()
    # El monto de BILLETES es el hecho, no un detalle secundario: sin esto
    # "500 bolivianos" desaparecía de una denuncia de estafa o robo de
    # dinero (auditoría 2026-09).
    cantidad = o.get("quantity") or o.get("cantidad")
    if _lexicon_key(concept) == "BILLETES" and cantidad:
        unidad = o.get("unit") or o.get("unidad") or "bolivianos"
        return f"{cantidad} {unidad} en billetes"
    det = o.get("detail") or o.get("detalles")
    if det and str(det).strip():
        return str(det).strip()
    doc_type = o.get("doc_type") or o.get("docType")
    if doc_type and str(doc_type).strip():
        return str(doc_type).strip()
    entry = lexicon_lookup(concept)
    if entry:
        return entry["es"].lower()
    return concept.lower()


def _object_neutral_phrase_py(o: dict) -> str:
    """Frase neutra (sin posesivo) para un objeto que llevaba OTRA persona,
    no el declarante: "una mochila", no "mi mochila" (auditoría 2026-09)."""
    concept = (o.get("concept") or o.get("glosa") or "").strip().upper()
    neutral = _NEUTRAL_CLOTHING.get(_lexicon_key(concept))
    if neutral:
        return neutral
    entry = lexicon_lookup(concept)
    base = entry["es"].lower() if entry else concept.lower()
    base = re.sub(r"^(mi|mis|la|el)\s+", "", base)
    if base.startswith(("un ", "el ", "la ", "una ")):
        return base
    return f"un {base}"


# Papeles del protagonista de un hecho. Conjunto cerrado: un valor fuera de
# aquí no se interpreta a ojo, se degrada a 'unknown' y se registra. Antes era
# texto libre, así que un 'sospechozo' mal escrito pasaba sin que nada lo
# notara y la frase perdía a quién atribuía la acción.
ACTOR_ROLES = {"suspect", "victim", "thirdParty", "unknown"}

# Alias aceptados durante la migración del contrato v2 al v3. El cliente Dart
# emitía `actorRole` y este archivo solo leía `actor_role`, así que el campo
# viajaba en cada petición y nunca se leía: "El sospechoso se dio a la fuga"
# no podía aparecer jamás. Se aceptan las dos formas y las traducciones al
# castellano que ya circulaban.
_ACTOR_ROLE_ALIASES = {
    "suspect": "suspect", "sospechoso": "suspect", "agresor": "suspect",
    "ladron": "suspect", "ladrón": "suspect",
    "victim": "victim", "victima": "victim", "víctima": "victim",
    "yo": "victim", "declarante": "victim",
    "thirdparty": "thirdParty", "third_party": "thirdParty",
    "tercero": "thirdParty", "otra_persona": "thirdParty",
    "unknown": "unknown", "desconocido": "unknown", "": "unknown",
}


def normalize_actor_role(raw) -> str:
    """Papel del protagonista, siempre dentro de [ACTOR_ROLES]."""
    if raw is None:
        return "unknown"
    clave = str(raw).strip().lower().replace(" ", "_")
    rol = _ACTOR_ROLE_ALIASES.get(clave)
    if rol is None:
        logger.info("actorRole desconocido, se degrada a 'unknown'")
        return "unknown"
    return rol


def normalize_facts(d: dict) -> list:
    """Los hechos del relato, en una lista, vengan en v2 o en v3.

    v3 manda `declaration.facts`, una lista con un hecho por acción. v2 manda
    `declaration.fact`, un único objeto. Se normalizan a la misma forma para
    que el generador no tenga dos caminos y para que un borrador guardado con
    el contrato anterior siga redactándose igual.
    """
    if not isinstance(d, dict):
        return []

    crudos = d.get("facts") or d.get("hechos")
    if not isinstance(crudos, list):
        uno = d.get("fact") or d.get("hecho")
        crudos = [uno] if isinstance(uno, dict) and uno else []

    salida = []
    for i, f in enumerate(crudos):
        if not isinstance(f, dict):
            continue
        accion = (f.get("action") or f.get("accion") or "").strip().upper()
        if not accion:
            continue
        # `actorRole` (cliente Dart) y `actor_role` (contrato antiguo) son el
        # mismo dato escrito de dos maneras; el cliente enviaba el primero y
        # este archivo solo leía el segundo.
        rol = normalize_actor_role(f.get("actorRole") or f.get("actor_role"))
        salida.append({
            "id": str(f.get("id") or f"f{i + 1}"),
            "action": accion,
            "actorRole": rol,
            "actorDetail": f.get("actorDetail") or f.get("actor_detail") or "",
            "objectIds": [str(o) for o in (f.get("objectEntityIds")
                                           or f.get("object_entity_ids") or [])],
            "negated": bool(f.get("negated")),
            "certainty": (f.get("certainty") or "confirmed").strip().lower(),
            "lossType": f.get("lossType") or f.get("loss_type") or "",
        })

        # Compatibilidad v2: la huida viajaba como propiedad del hecho
        # principal (`escapar_actor`), no como hecho propio. Se convierte en
        # un segundo hecho, que es lo que siempre fue, para que un borrador
        # guardado con el contrato anterior siga redactándose igual.
        escapar = f.get("escapar_actor") or f.get("escaparActor")
        if escapar and accion != "ESCAPAR":
            salida.append({
                "id": f"{salida[-1]['id']}-escape",
                "action": "ESCAPAR",
                "actorRole": normalize_actor_role(escapar),
                "actorDetail": "",
                "objectIds": [],
                "negated": False,
                "certainty": "confirmed",
                "lossType": "",
            })
    return salida


# Acciones que sí describen una sustracción. Que el relato no sea una pérdida
# NO lo convierte en un robo: ESCAPAR sola describe una huida, y redactar
# "Denuncio el robo de mis pertenencias" a partir de ella pone en boca del
# declarante una acusación que no hizo.
ROBBERY_ACTIONS = {"ROBAR", "QUITAR", "ARREBATAR", "HURTAR"}
LOSS_ACTIONS = {"PERDER", "OLVIDAR"}


# Cómo se relata cada acción cuando no hay robo ni pérdida que encabece el
# relato. El sujeto sale del papel del protagonista, así que la misma acción
# no dice lo mismo según quién la hizo.
_FACT_PHRASES = {
    "ESCAPAR": {"victim": "Logré escapar",
                "suspect": "La persona se dio a la fuga",
                "thirdParty": "Otra persona se dio a la fuga",
                "unknown": "Hubo una huida"},
    "DAÑAR": {"victim": "Sufrí daños",
              "suspect": "La persona causó daños",
              "thirdParty": "Otra persona causó daños",
              "unknown": "Se causaron daños"},
    "ENGAÑAR": {"victim": "Fui engañado",
                "suspect": "La persona me engañó",
                "thirdParty": "Otra persona engañó",
                "unknown": "Hubo un engaño"},
    "AMENAZAR": {"victim": "Fui amenazado",
                 "suspect": "La persona me amenazó",
                 "thirdParty": "Otra persona amenazó",
                 "unknown": "Hubo amenazas"},
    "GOLPEAR": {"victim": "Fui agredido",
                "suspect": "La persona me agredió",
                "thirdParty": "Otra persona agredió",
                "unknown": "Hubo una agresión"},
}


def _describe_other_facts(facts: list) -> str:
    """Relato de hechos que no son ni robo ni pérdida.

    Devuelve cadena vacía si ninguno tiene una redacción conocida: es
    preferible no decir nada a inventar de qué se trataba.
    """
    partes = []
    for f in facts:
        plantilla = _FACT_PHRASES.get(f["action"])
        if not plantilla:
            continue
        frase = plantilla.get(f["actorRole"], plantilla["unknown"])
        if f["negated"]:
            frase = f"No es cierto que {frase[0].lower()}{frase[1:]}"
        elif f["certainty"] in ("uncertain", "incierto"):
            frase = f"No estoy seguro, pero creo que {frase[0].lower()}{frase[1:]}"
        partes.append(frase)
    if not partes:
        return ""
    return _join(partes) + "."


def _describe_escape(facts: list) -> str:
    """Quién escapó, según el protagonista del hecho ESCAPAR."""
    for f in facts:
        if f["action"] != "ESCAPAR" or f["negated"]:
            continue
        return {
            "suspect": "El sospechoso se dio a la fuga.",
            "victim": "Logré escapar.",
            "thirdParty": "Otra persona se dio a la fuga.",
        }.get(f["actorRole"], "Hubo una huida, sin precisar de quién.")
    return ""


def generate_structured_sentence(d: dict) -> str:
    """Genera la declaración determinista formal a partir de un dict estructurado para los 8 contextos."""
    if not isinstance(d, dict):
        return "Quiero comunicar lo siguiente, aunque todavía no completé los detalles."

    context_id = (d.get("context_id") or d.get("contextId") or "denuncia_robo").strip().lower()
    sentences = []

    loc_dict = d.get("location") or d.get("lugar") or {}
    espacio = loc_dict.get("espacio") or loc_dict.get("main_place_concept") or loc_dict.get("mainPlaceConcept") or ""
    zona = loc_dict.get("zona") or loc_dict.get("main_place_detail") or loc_dict.get("mainPlaceDetail") or ""
    loc_part = ""
    if espacio and zona:
        loc_part = f"en {espacio.lower()} en zona {zona}"
    elif espacio:
        loc_part = f"en {espacio.lower()}"
    elif zona:
        loc_part = f"en zona {zona}"

    # Relación espacial (CERCA/LEJOS/DENTRO/FUERA/AL_LADO) con su referencia
    # real. Sin esto, esta ruta ignoraba por completo la ubicación con
    # referencia que el wizard captura (auditoría 2026-09, hallazgo CERCA):
    # la relación llegaba en el `declaration` pero nunca se leía aquí.
    relation = loc_dict.get("relation") or loc_dict.get("relacion")
    pending_loc = bool(loc_dict.get("pending"))
    if relation and not pending_loc:
        rel_word = _relation_word(relation)
        referencia = None
        ref_type = loc_dict.get("referenceType") or loc_dict.get("reference_type")
        if ref_type == "home":
            referencia = "mi casa"
        else:
            ref_literal = (loc_dict.get("referenceLiteralText")
                           or loc_dict.get("reference_literal_text") or "").strip()
            if ref_literal:
                referencia = ref_literal
            else:
                ref_concept = (loc_dict.get("referenceConceptGloss")
                               or loc_dict.get("reference_concept_gloss"))
                if ref_concept:
                    entry = lexicon_lookup(ref_concept)
                    referencia = entry["es"] if entry else str(ref_concept).lower()
        if referencia:
            rel_part = f"{rel_word} de {referencia}"
            loc_part = f"{loc_part} {rel_part}".strip() if loc_part else rel_part

    time_val = d.get("time") or d.get("tiempo")
    time_text = ""
    if isinstance(time_val, str) and time_val.strip():
        time_text = time_val.strip()
    elif isinstance(time_val, dict):
        time_text = (time_val.get("date_or_moment") or time_val.get("dateOrMoment") or "").lower()

    objects = d.get("objects") or d.get("objetos") or []
    stolen = [o for o in objects if (o.get("role") or o.get("rol")) in ("stolen", "robado")]
    lost = [o for o in objects if (o.get("role") or o.get("rol")) in ("lost", "perdido", "documento")]
    # Un objeto que llevaba OTRA persona (no el declarante) no es botín
    # propio: mezclarlo con `stolen` le atribuía al declarante algo que solo
    # describía a un tercero (auditoría 2026-09, hallazgo mochila robada vs.
    # mochila llevada).
    carried = [o for o in objects
               if (o.get("role") or o.get("rol")) in ("carriedByOtherPerson", "carried_by_other_person")]

    persons = d.get("persons") or d.get("personas") or []
    suspects = [p for p in persons if (p.get("role") or p.get("rol")) in ("suspect", "sospechoso")]

    witnesses_dict = d.get("witnesses") or d.get("testigos") or {}
    witness_existence = witnesses_dict.get("existence") or witnesses_dict.get("existencia")

    fact = d.get("fact") or d.get("hecho") or {}
    action = (fact.get("action") or fact.get("accion") or "").strip().upper()
    tipo_hecho = (fact.get("tipo") or "").strip().lower()

    # Colección de hechos (contrato v3). Un relato puede llevar dos acciones
    # con protagonistas distintos —«me robaron y yo escapé» no es lo mismo que
    # «me robaron y el ladrón escapó»— y el campo único `fact.action` no podía
    # representarlo: la segunda selección pisaba la primera.
    facts = normalize_facts(d)

    if context_id == "violencia":
        violence = d.get("violence") or d.get("violencia") or {}
        sentences.append("Denuncio agresión física y violencia sufrida.")
        if violence.get("agresor_relacion"):
            sentences.append(f"La persona agresora es mi {violence['agresor_relacion']}.")
        if violence.get("heridas"):
            sentences.append(f"Presento lesiones: {violence['heridas']}.")
        if violence.get("atencion_medica") or violence.get("medical_care_requested"):
            sentences.append("He recibido o requiero atención médica de urgencia.")
        if violence.get("certificado_forense"):
            sentences.append("Cuento con certificado médico forense.")
        if violence.get("frecuencia"):
            sentences.append(f"Esta situación de agresión ocurre de manera {violence['frecuencia']}.")
        if violence.get("solicita_medidas_proteccion") or violence.get("protection_requested"):
            sentences.append("Solicito medidas de protección inmediata para salvaguardar mi integridad.")

    elif context_id == "amenaza_digital":
        threat = d.get("digital_threat") or d.get("digitalThreat") or d.get("amenaza_digital") or {}
        sentences.append("Denuncio la recepción de mensajes hostiles y amenazas a través de medios digitales.")
        if threat.get("medio") or threat.get("channel"):
            sentences.append(f"Canal utilizado: {threat.get('medio') or threat.get('channel')}.")
        if threat.get("remitente"):
            sentences.append(f"Remitente: {threat['remitente']}.")
        if threat.get("numero_telefono") or threat.get("phoneNumber"):
            sentences.append(f"Número de contacto / remitente: {threat.get('numero_telefono') or threat.get('phoneNumber')}.")
        if threat.get("has_saved_evidence") or threat.get("mensajes_guardados") or threat.get("capturas_pantalla"):
            sentences.append("Dispongo de capturas de pantalla y mensajes guardados como evidencia.")

    elif context_id == "engano_dinero":
        fraud = d.get("fraud") or d.get("engano_dinero") or {}
        tipo_engano = fraud.get("tipo_engano") or "engaño económico"
        sentences.append(f"Denuncio un engaño económico / {tipo_engano}.")
        if fraud.get("monto_aproximado") or fraud.get("amount"):
            sentences.append(f"Monto involucrado: {fraud.get('monto_aproximado') or fraud.get('amount')}.")
        if fraud.get("via_pago") or fraud.get("delivery_method"):
            sentences.append(f"Medio de pago / transferencia: {fraud.get('via_pago') or fraud.get('delivery_method')}.")
        if fraud.get("destinatario") or fraud.get("recipient_name"):
            sentences.append(f"Beneficiario o destinatario del dinero: {fraud.get('destinatario') or fraud.get('recipient_name')}.")
        if fraud.get("tiene_comprobante") or fraud.get("receipt_doc"):
            sentences.append("Cuento con comprobantes bancarios y respaldo de la transacción.")

    elif context_id == "seguimiento":
        proc = d.get("procedure") or d.get("procedimiento") or {}
        if proc.get("tipo_tramite"):
            sentences.append(f"Solicito información sobre el trámite: {proc['tipo_tramite']}.")
        else:
            sentences.append("El ciudadano consulta el estado de su trámite o investigación.")
        if proc.get("numero_caso") or proc.get("caseNumber"):
            sentences.append(f"Número de caso / NUREJ / referencia: {proc.get('numero_caso') or proc.get('caseNumber')}.")
        if proc.get("autoridad_destino") or proc.get("targetInstitution"):
            sentences.append(f"Autoridad o despacho: {proc.get('autoridad_destino') or proc.get('targetInstitution')}.")
        if proc.get("accion_solicitada") or proc.get("procedureType"):
            sentences.append(f"Acción o consulta: {proc.get('accion_solicitada') or proc.get('procedureType')}.")
        if proc.get("proxima_fecha"):
            sentences.append(f"Fecha programada / retorno: {proc['proxima_fecha']}.")

    elif context_id == "identificacion":
        id_nom = d.get("identificacion_nombre") or d.get("nombre")
        id_doc = d.get("identificacion_documento") or d.get("documento")
        id_con = d.get("identificacion_contacto") or d.get("contacto")
        id_aco = d.get("identificacion_acompanante") or d.get("acompanante")
        sentences.append("Datos de identificación:")
        if id_nom:
            sentences.append(f"Nombre completo: {id_nom}.")
        if id_doc:
            sentences.append(f"Documento de identidad: {id_doc}.")
        if id_con:
            sentences.append(f"Teléfono / WhatsApp de contacto: {id_con}.")
        if id_aco:
            sentences.append(f"Acompañante: {id_aco}.")
        if d.get("necesita_interprete") or d.get("needs_interpreter"):
            sentences.append("Comunico que soy una persona sorda y requiero comunicación escrita o intérprete oficial de LSB.")

    elif context_id == "preguntas":
        inq = d.get("consulta") or d.get("inquiry") or {}
        if inq.get("pregunta_principal"):
            sentences.append(f"Consulta ciudadana: {inq['pregunta_principal']}")
            if inq.get("lugar_consulta"):
                sentences.append(f"Lugar o institución de referencia: {inq['lugar_consulta']}.")
            if inq.get("autoridad_consulta"):
                sentences.append(f"Funcionario / autoridad por quien se consulta: {inq['autoridad_consulta']}.")
            if inq.get("tema_consulta"):
                sentences.append(f"Materia o tema: {inq['tema_consulta']}.")
            if inq.get("tiempo_espera"):
                sentences.append(f"Tiempo estimado o plazo informado: {inq['tiempo_espera']}.")
        else:
            sentences.append("¿Dónde debo realizar esta consulta o presentar el trámite?")

    elif context_id == "otro":
        relato = fact.get("relato_libre") or fact.get("narrative")
        if relato:
            sentences.append(f"Declaración testimonial: {relato}")
            if persons:
                sentences.append("Personas observadas:")
                for p in persons:
                    sentences.append(_person_phrase_structured(p))
        else:
            sentences.append("El declarante se presenta en calidad de testigo presencial de los hechos.")
        if d.get("necesita_interprete") or d.get("needs_interpreter"):
            sentences.append("Solicito asistencia de un intérprete en Lengua de Señas Boliviana (LSB).")

    else: # denuncia_robo / hurto / perdida
        acciones = {f["action"] for f in facts if not f["negated"]}
        es_perdida = (bool(acciones & LOSS_ACTIONS)
                      or action in LOSS_ACTIONS
                      or tipo_hecho == "perdida")
        # El robo se afirma solo si alguien lo dijo. Antes esta rama era el
        # `else` de la pérdida, así que cualquier otra acción —ESCAPAR, DAÑAR,
        # o ninguna— acababa redactando "Denuncio el robo de mis pertenencias".
        es_robo = (bool(acciones & ROBBERY_ACTIONS)
                   or action in ROBBERY_ACTIONS
                   or tipo_hecho in ("robo", "hurto"))

        if es_perdida and not es_robo:
            objs = lost if lost else stolen
            what = _join([_object_self_phrase_py(o) for o in objs])
            lugar_str = f" {loc_part}" if loc_part else ""
            sentences.append(f"He extraviado o perdido: {what}. Ocurrió{lugar_str}.".strip() if lugar_str else f"He extraviado o perdido: {what}.")
        else:
            if es_robo:
                what = _join([_object_self_phrase_py(o) for o in stolen])
                if what:
                    sentences.append(f"Denuncio el robo de {what}.")
                else:
                    sentences.append("Denuncio el robo de mis pertenencias.")
            else:
                # Hay hechos, pero ninguno es un robo ni una pérdida. Se
                # relatan por lo que son, sin ascenderlos a denuncia de robo.
                relato = _describe_other_facts(facts)
                sentences.append(relato if relato else
                                 "Quiero comunicar lo siguiente, aunque "
                                 "todavía no completé los detalles.")

            loc_time = []
            if loc_part:
                loc_time.append(loc_part)
            if time_text:
                loc_time.append(time_text)
            if loc_time:
                sentences.append(f"Ocurrió {', '.join(loc_time)}.")

            # Quién escapó sale del protagonista del propio hecho ESCAPAR,
            # no de un campo suelto del relato.
            fuga = _describe_escape(facts)
            if fuga:
                sentences.append(fuga)

            if suspects:
                sentences.append("Autor / sospechoso:")
                for p in suspects:
                    sentences.append(_person_phrase_structured(p))

            if carried:
                what_carried = _join([_object_neutral_phrase_py(o) for o in carried])
                quien = _person_phrase_structured(suspects[0]) if suspects else "la persona"
                sentences.append(f"{quien[0].upper()}{quien[1:]} llevaba {what_carried}.")

            evid = d.get("evidence") or d.get("evidencia") or []
            if evid:
                sentences.append("Cuento con elementos de prueba o respaldo:")

        # Testigos: estado propio, sin equiparar la ausencia de respuesta a
        # que no los hay (auditoría 2026-09, hallazgo NO+TESTIGO / "no sabe").
        if witness_existence in ("confirmed", "confirmado"):
            count = witnesses_dict.get("count") or witnesses_dict.get("cantidad")
            sentences.append(f"Hay {count} testigos." if count else "Hay testigos.")
        elif witness_existence in ("negated", "negado"):
            sentences.append("No hay testigos.")
        elif witness_existence in ("uncertain", "incierto"):
            sentences.append("No sé si hay testigos.")

    texto = " ".join([s.strip() for s in sentences if s.strip()])
    return texto if texto else "Quiero comunicar lo siguiente, aunque todavía no completé los detalles."


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
        entry = lexicon_lookup(key)
        if entry:
            significados.append(f'- {key}: {entry["es"]}')
    hechos = "\n".join(significados) or "- (sin glosas reconocidas)"

    registro = ("formal, legal y preciso, propio de un acta de denuncia"
                if is_formal else "claro, correcto y respetuoso")

    return f"""Eres quien redacta, en español de Bolivia, la declaración de una persona sorda en el ámbito PENAL Y JUDICIAL. Ella se comunica eligiendo señas; tú conviertes esas señas en la declaración que leerá o escuchará el funcionario que la recibe.

ÁMBITO: Ministerio Público (Fiscalía), FELCC y FELCV, juzgados de instrucción penal y tribunales, Defensa Pública (SEPDEP) y Asistencia a la Víctima (SEPDAVI). Cuando el texto nombre un lugar institucional, se refiere a una de estas dependencias, no a una oficina cualquiera. El registro es el de un acta de recepción de denuncia o de una diligencia preliminar.

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


def _es_pregunta(texto: str) -> bool:
    return "¿" in texto or texto.strip().endswith("?")


def _generation_is_safe(cards: list, generated: str, base: str) -> tuple:
    """Cobertura, no-invención y preservación del acto comunicativo.
    Espejo de `isBackendDegenerate` del cliente.

    Devuelve (es_segura, motivo). Antes solo comprobaba que cada seña elegida
    siguiera representada (una comprobación de una sola dirección): aceptaba
    agregar una fecha, un lugar o un monto que nadie declaró, y aceptaba que
    una afirmación se convirtiera en pregunta conservando las mismas palabras
    relevantes (auditoría 2026-09). Ahora también rechaza contenido nuevo que
    ninguna glosa aportó, y exige que el acto comunicativo (afirmar vs.
    preguntar) se conserve.
    """
    if not generated or not generated.strip():
        return False, "vacío"

    plano = _normalizar(generated)

    faltantes = []
    for card in cards:
        key = str(card).upper().strip()
        entry = lexicon_lookup(key)
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

    # No inventar: todo número que aparece en el texto generado debe
    # aparecer también en los hechos verificados. Un monto, una fecha o una
    # cantidad que solo está en el texto generado no salió de ninguna seña.
    #
    # NOTA: se probó además un chequeo léxico más amplio —rechazar cualquier
    # palabra de contenido ausente de los hechos verificados y del
    # significado de las señas— pero eso también rechazaba paráfrasis fieles
    # ("resulté con una herida" para HERIDA) por usar palabras que ninguna
    # glosa aporta literalmente. Se retiró: por ahora solo se verifica lo que
    # se puede comprobar sin falsos positivos. Agregar una fecha o un lugar
    # inventados que no sean números (el caso "ayer" + "una plaza" del
    # hallazgo original) queda como limitación conocida — ver informe.
    numeros_generados = set(re.findall(r"\d+", generated))
    numeros_base = set(re.findall(r"\d+", base))
    numeros_inventados = numeros_generados - numeros_base
    if numeros_inventados:
        return False, f"agrega números no declarados: {', '.join(sorted(numeros_inventados))}"

    # El acto comunicativo no puede cambiar: una afirmación no se vuelve
    # pregunta (ni al revés) conservando las mismas palabras relevantes.
    if _es_pregunta(base) != _es_pregunta(generated):
        return False, "cambia afirmación por pregunta (o al revés)"

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
        # Sin el texto descartado: puede contener el mismo contenido sensible
        # que se está rechazando (auditoría 2026-09, hallazgo de logging).
        logger.warning("Generación descartada (%s), %d caracteres", motivo, len(texto))
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

def generate_cache_key(context_type: str, cards: list, institution_type: str = "",
                        language: str = "", speech_act: str = "",
                        declaration=None) -> str:
    """Clave de caché. Todo lo que puede cambiar la salida debe estar aquí:
    antes solo entraban `context`/`cards`, así que dos peticiones con las
    mismas glosas pero distinto `institutionType`, `language`, acto
    comunicativo o relaciones estructuradas compartían una respuesta cacheada
    que no correspondía a ninguna de las dos (auditoría 2026-09). No se
    incluye `replyToId` como tal —identifica el turno, no cambia la
    redacción— pero si en el futuro el texto llega a citar la pregunta
    respondida, debe agregarse aquí también.
    """
    declaration_part = (
        json.dumps(declaration, sort_keys=True, ensure_ascii=False)
        if declaration else ""
    )
    normalized = "|".join([
        context_type.lower().strip(),
        "|".join(c.upper().strip() for c in cards),
        institution_type.lower().strip(),
        language.lower().strip(),
        speech_act.lower().strip(),
        declaration_part,
    ])
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


# Conjuntos cerrados del contrato v3. Un valor fuera de aquí es un error del
# cliente, no un campo que se ignora en silencio: la configuración de interfaz
# no sustituye la validación del backend.
USAGE_MODES = {"personal", "counter"}
NEEDS = {"denuncias", "tramites", "consultas"}
SPEECH_ACTS = {"statement", "question", "request", "reply", "instruction"}
CERTAINTIES = {"confirmed", "uncertain", "unknown"}

MAX_ID_LENGTH = 64


def _validate_enum(body: dict, campo: str, permitidos: set) -> str:
    valor = body.get(campo)
    if valor is None:
        return ""
    if not isinstance(valor, str):
        return f"El campo '{campo}' debe ser una cadena."
    if valor not in permitidos:
        return (f"Valor no reconocido en '{campo}'. "
                f"Admitidos: {', '.join(sorted(permitidos))}.")
    return ""


def validate_business_signals(body: dict) -> tuple:
    """Comprueba las señales de negocio del contrato v3.

    Se validan aunque no cambien el texto: un `need` mal escrito significa que
    el cliente y el backend han dejado de entenderse, y descubrirlo en una
    ventanilla es tarde.
    """
    for campo, permitidos in (("usageMode", USAGE_MODES),
                              ("need", NEEDS),
                              ("speechAct", SPEECH_ACTS)):
        error = _validate_enum(body, campo, permitidos)
        if error:
            return False, error

    for campo in ("institutionProfileId", "intentId", "conversationId"):
        valor = body.get(campo)
        if valor is None:
            continue
        if not isinstance(valor, str):
            return False, f"El campo '{campo}' debe ser una cadena."
        if len(valor) > MAX_ID_LENGTH:
            return False, f"El campo '{campo}' es demasiado largo."

    version = body.get("messageVersion")
    if version is not None and (not isinstance(version, int) or version < 1):
        return False, "El campo 'messageVersion' debe ser un entero positivo."

    declaration = body.get("declaration")
    if isinstance(declaration, dict):
        hechos = declaration.get("facts")
        if hechos is not None:
            if not isinstance(hechos, list):
                return False, "El campo 'facts' debe ser una lista."
            if len(hechos) > 2:
                return False, "Un relato admite como mucho dos hechos."
            for i, f in enumerate(hechos):
                if not isinstance(f, dict):
                    return False, f"El hecho en posición {i} no es válido."
                rol = f.get("actorRole") or f.get("actor_role")
                if rol is not None and str(rol) not in ACTOR_ROLES:
                    return False, (
                        f"El papel '{rol}' del hecho en posición {i} no es "
                        f"válido. Admitidos: {', '.join(sorted(ACTOR_ROLES))}.")
                certeza = f.get("certainty")
                if certeza is not None and str(certeza) not in CERTAINTIES:
                    return False, (
                        f"La certeza '{certeza}' del hecho en posición {i} no "
                        "es válida.")
    return True, None


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

    is_valid, err = validate_business_signals(body)
    if not is_valid:
        return build_response(400, {"error": "VALIDATION_ERROR", "message": err})

    cards = [c.strip().upper() for c in body["cards"]]
    context_type = body.get("context", "general").strip().lower()
    institution_type = (body.get("institutionType") or "").strip().lower()
    language = (body.get("language") or "es").strip()
    # Contrato v2 (auditoría 2026-09): representación estructurada, acto
    # comunicativo y turno al que se responde. Un cliente v1 sigue
    # funcionando: sin `declaration`, el pipeline determinista de siempre.
    speech_act = (body.get("speechAct") or "").strip().lower()
    reply_to_id = body.get("replyToId")
    raw_declaration = body.get("declaration")
    declaration = raw_declaration if isinstance(raw_declaration, dict) else None
    contract_version = body.get("contractVersion") or 1
    # Una declaración estructurada vale en cualquier contexto. La condición
    # anterior exigía `context_type == "denuncia_robo"`, así que en violencia,
    # amenaza_digital, engaño y seguimiento el cliente enviaba las relaciones
    # explícitas —persona↔prenda, objeto↔papel, lugar↔referencia— y el backend
    # las descartaba en silencio, volviendo a adivinarlas desde la lista plana
    # de glosas. Si un contexto no sabe redactarla, el generador cae a su
    # camino determinista, pero eso se decide dentro y queda registrado.
    uses_structured = (
        has_structured_declaration(body) and contract_version >= 2
    )

    cache_key = generate_cache_key(
        context_type, cards, institution_type, language, speech_act, declaration)
    # No se registran las glosas ni el `declaration` completos: son el
    # contenido de una declaración que puede llegar a un expediente y no
    # debe quedar en texto plano en los registros de la Lambda (auditoría
    # 2026-09, hallazgo de logging). Se registran solo metadatos.
    logger.info(
        "Procesando — context: %s, institutionType: %s, language: %s, "
        "speechAct: %s, cards_count: %d, structured: %s, cache_key: %s",
        context_type, institution_type, language, speech_act,
        len(cards), uses_structured, cache_key,
    )

    cached = get_cached_response(cache_key)
    if cached is not None:
        logger.info("Cache HIT — cache_key: %s", cache_key)
        return build_response(200, cached)
    logger.info("Cache MISS — procesando pipeline completo: %s", cache_key)

    analysis = analyze_glosses(cards)

    # CAMBIO (paridad Dart): cierra la cadena temporal antes de generar. Debe
    # ir aquí y no en analyze_glosses porque la dirección depende del contexto.
    _resolve_gender(analysis)
    _resolve_time(analysis, context_type, cards)

    intermediate = build_intermediate_representation(cards, analysis, context_type)

    if uses_structured:
        # El cliente ya mandó las relaciones explícitas (persona↔prenda↔color,
        # objeto↔papel, lugar↔referencia): redactarlas no requiere volver a
        # adivinarlas desde una lista plana de glosas.
        base_sentence = generate_structured_sentence(declaration)
    else:
        base_sentence = generate_base_sentence(intermediate, analysis, context_type, institution_type)
    logger.info("Oración base generada (%d caracteres, estructurada=%s)",
                len(base_sentence), uses_structured)

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

    # Se registran longitudes, no el contenido de la declaración (auditoría
    # 2026-09, hallazgo de logging).
    logger.info(
        "Completado — base: %d caracteres | final: %d caracteres | bedrock: %s",
        len(base_sentence), len(generated_text), bedrock_used,
    )

    gloss_sequence = []
    for card in cards:
        entry = lexicon_lookup(card)
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
