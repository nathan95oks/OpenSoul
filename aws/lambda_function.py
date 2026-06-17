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
    "YO":         {"rol": "SUJETO", "es": "yo", "perspectiva": "1P"},
    "NOSOTROS":   {"rol": "SUJETO", "es": "nosotros", "perspectiva": "1P_PLURAL"},
    "HIJO":       {"rol": "SUJETO", "es": "mi hijo", "perspectiva": "3P"},
    "HIJA":       {"rol": "SUJETO", "es": "mi hija", "perspectiva": "3P"},
    "MAMA":       {"rol": "SUJETO", "es": "mi madre", "perspectiva": "3P"},
    "PAPA":       {"rol": "SUJETO", "es": "mi padre", "perspectiva": "3P"},
    "HERMANO":    {"rol": "SUJETO", "es": "mi hermano", "perspectiva": "3P"},
    "HERMANA":    {"rol": "SUJETO", "es": "mi hermana", "perspectiva": "3P"},
    "ESPOSO":     {"rol": "SUJETO", "es": "mi esposo", "perspectiva": "3P"},
    "ESPOSA":     {"rol": "SUJETO", "es": "mi esposa", "perspectiva": "3P"},
    "FAMILIA":    {"rol": "SUJETO", "es": "mi familia", "perspectiva": "3P"},
    "PERSONA":    {"rol": "SUJETO", "es": "una persona", "perspectiva": "3P"},
    "NIÑO":       {"rol": "SUJETO", "es": "un niño", "perspectiva": "3P"},
    "NIÑA":       {"rol": "SUJETO", "es": "una niña", "perspectiva": "3P"},
    "BEBE":       {"rol": "SUJETO", "es": "un bebé", "perspectiva": "3P"},
    "AMIGO":      {"rol": "SUJETO", "es": "mi amigo", "perspectiva": "3P"},
    "VECINO":     {"rol": "SUJETO", "es": "mi vecino", "perspectiva": "3P"},

    "NECESITAR":  {"rol": "VERBO", "es": "necesitar", "1p": "necesito", "3p": "necesita", "formal": "requiero"},
    "PEDIR":      {"rol": "VERBO", "es": "pedir", "1p": "solicito", "3p": "solicita", "formal": "solicitar"},
    "TRAMITAR":   {"rol": "VERBO", "es": "tramitar", "1p": "necesito tramitar", "3p": "necesita tramitar", "formal": "deseo realizar el trámite de"},
    "SOLICITAR":  {"rol": "VERBO", "es": "solicitar", "1p": "solicito", "3p": "solicita", "formal": "deseo solicitar"},
    "REGISTRAR":  {"rol": "VERBO", "es": "registrar", "1p": "necesito registrar", "3p": "necesita registrar", "formal": "deseo registrar"},
    "CONSULTAR":  {"rol": "VERBO", "es": "consultar", "1p": "deseo consultar", "3p": "consulta", "formal": "deseo realizar una consulta sobre"},
    "PAGAR":      {"rol": "VERBO", "es": "pagar", "1p": "necesito pagar", "3p": "necesita pagar", "formal": "deseo realizar el pago de"},
    "RENOVAR":    {"rol": "VERBO", "es": "renovar", "1p": "necesito renovar", "3p": "necesita renovar", "formal": "deseo renovar"},
    "INSCRIBIR":  {"rol": "VERBO", "es": "inscribir", "1p": "necesito inscribir", "3p": "necesita inscribir", "formal": "deseo realizar la inscripción de"},
    "RECOGER":    {"rol": "VERBO", "es": "recoger", "1p": "necesito recoger", "3p": "necesita recoger", "formal": "deseo retirar"},
    "ENTREGAR":   {"rol": "VERBO", "es": "entregar", "1p": "necesito entregar", "3p": "necesita entregar", "formal": "deseo presentar"},
    "PREGUNTAR":  {"rol": "VERBO", "es": "preguntar", "1p": "deseo preguntar", "3p": "pregunta", "formal": "deseo realizar una consulta"},
    "AYUDAR":     {"rol": "VERBO", "es": "ayudar", "1p": "necesito ayuda", "3p": "necesita ayuda"},
    "AYUDA":      {"rol": "VERBO", "es": "ayudar", "1p": "necesito ayuda", "3p": "necesita ayuda"},
    "TENER":      {"rol": "VERBO", "es": "tener", "1p": "tengo", "3p": "tiene"},
    "QUERER":     {"rol": "VERBO", "es": "querer", "1p": "quiero", "3p": "quiere", "formal": "deseo"},
    "PODER":      {"rol": "VERBO", "es": "poder", "1p": "puedo", "3p": "puede"},
    "SABER":      {"rol": "VERBO", "es": "saber", "1p": "sé", "3p": "sabe"},
    "ESPERAR":    {"rol": "VERBO", "es": "esperar", "1p": "estoy esperando", "3p": "está esperando"},
    "PERDER":     {"rol": "VERBO", "es": "perder", "1p": "perdí", "3p": "perdió", "formal": "he extraviado"},
    "DENUNCIAR":  {"rol": "VERBO", "es": "denunciar", "1p": "deseo presentar un reclamo", "3p": "presenta un reclamo", "formal": "deseo presentar un reclamo formal por"},
    "VER":        {"rol": "VERBO", "es": "ver", "1p": "vi", "3p": "vio"},
    "SENTIR":     {"rol": "VERBO", "es": "sentir", "1p": "sentí", "3p": "sintió"},
    "FIRMAR":     {"rol": "VERBO", "es": "firmar", "1p": "necesito firmar", "3p": "necesita firmar", "formal": "deseo proceder con la firma de"},
    "CORREGIR":   {"rol": "VERBO", "es": "corregir", "1p": "necesito corregir", "3p": "necesita corregir", "formal": "deseo solicitar la corrección de"},
    "VERIFICAR":  {"rol": "VERBO", "es": "verificar", "1p": "necesito verificar", "3p": "necesita verificar", "formal": "deseo verificar"},

    "ROBAR":      {"rol": "VERBO", "es": "robar", "agresor": "robó", "1p": "me robaron"},
    "ASALTAR":    {"rol": "VERBO", "es": "asaltar", "agresor": "asaltó", "1p": "me asaltaron"},
    "QUITAR":     {"rol": "VERBO", "es": "quitar", "agresor": "quitó", "1p": "me quitaron"},
    "GOLPEAR":    {"rol": "VERBO", "es": "golpear", "agresor": "golpeó", "1p": "me golpearon"},
    "AMENAZAR":   {"rol": "VERBO", "es": "amenazar", "agresor": "amenazó", "1p": "me amenazaron"},
    "EMPUJAR":    {"rol": "VERBO", "es": "empujar", "agresor": "empujó", "1p": "me empujaron"},
    "GRITAR":     {"rol": "VERBO", "es": "gritar", "agresor": "gritó", "1p": "me gritaron"},
    "PERSEGUIR":  {"rol": "VERBO", "es": "perseguir", "agresor": "persiguió", "1p": "me persiguieron"},
    "ACOSAR":     {"rol": "VERBO", "es": "acosar", "agresor": "acosó", "1p": "me acosaron"},
    "SECUESTRAR": {"rol": "VERBO", "es": "secuestrar", "agresor": "secuestró", "1p": "me secuestraron"},
    "ABUSO":      {"rol": "VERBO", "es": "abuso sexual", "agresor": "agredió sexualmente", "1p": "fui agredido sexualmente"},

    "HOMBRE":      {"rol": "DESCRIPTOR", "es": "un hombre", "persona": True},
    "MUJER":       {"rol": "DESCRIPTOR", "es": "una mujer", "persona": True},
    "JOVEN":       {"rol": "DESCRIPTOR", "es": "un joven", "persona": True},
    "DESCONOCIDO": {"rol": "DESCRIPTOR", "es": "un desconocido", "persona": True},
    "VECINO":      {"rol": "DESCRIPTOR", "es": "un vecino", "persona": True},
    "GRUPO":       {"rol": "DESCRIPTOR", "es": "un grupo de personas", "persona": True},
    "ADULTO":      {"rol": "DESCRIPTOR", "es": "un adulto", "persona": True},
    "ANCIANO":     {"rol": "DESCRIPTOR", "es": "un anciano", "persona": True},
    "CONOCIDO":    {"rol": "DESCRIPTOR", "es": "un conocido", "persona": True},
    "ALTO":        {"rol": "DESCRIPTOR", "es": "alto"},
    "BAJO":        {"rol": "DESCRIPTOR", "es": "bajo"},
    "DELGADO":     {"rol": "DESCRIPTOR", "es": "delgado"},
    "GORDO":       {"rol": "DESCRIPTOR", "es": "robusto"},
    "MORENO":      {"rol": "DESCRIPTOR", "es": "moreno"},
    "BARBA":       {"rol": "DESCRIPTOR", "es": "con barba"},
    "LENTES":      {"rol": "DESCRIPTOR", "es": "con lentes"},

    "CELULAR":   {"rol": "OBJETO", "es": "mi celular"},
    "DINERO":    {"rol": "OBJETO", "es": "mi dinero"},
    "MOCHILA":   {"rol": "OBJETO", "es": "mi mochila"},
    "BOLSA":     {"rol": "OBJETO", "es": "mi bolsa"},
    "LLAVE":     {"rol": "OBJETO", "es": "mis llaves"},
    "BILLETERA": {"rol": "OBJETO", "es": "mi billetera"},
    "TARJETA":   {"rol": "OBJETO", "es": "mi tarjeta bancaria"},
    "RELOJ":     {"rol": "OBJETO", "es": "mi reloj"},
    "CADENA":    {"rol": "OBJETO", "es": "mi cadena"},
    "ANILLO":    {"rol": "OBJETO", "es": "mi anillo"},
    "COLLAR":    {"rol": "OBJETO", "es": "mi collar"},
    "ARETES":    {"rol": "OBJETO", "es": "mis aretes"},
    "LAPTOP":    {"rol": "OBJETO", "es": "mi laptop"},
    "AUDIFONOS": {"rol": "OBJETO", "es": "mis audífonos"},
    "BICICLETA": {"rol": "OBJETO", "es": "mi bicicleta"},
    "AUTO":      {"rol": "OBJETO", "es": "mi auto"},
    "MOTO":      {"rol": "OBJETO", "es": "mi moto"},
    "CUCHILLO":  {"rol": "OBJETO", "es": "un cuchillo", "arma": True},

    "CALLE":   {"rol": "LUGAR", "es": "en la calle"},
    "CASA":    {"rol": "LUGAR", "es": "en mi casa"},
    "MERCADO": {"rol": "LUGAR", "es": "en el mercado"},
    "PARADA":  {"rol": "LUGAR", "es": "en la parada"},
    "MICRO":   {"rol": "LUGAR", "es": "en el micro"},
    "PARQUE":  {"rol": "LUGAR", "es": "en el parque"},
    "TRABAJO": {"rol": "LUGAR", "es": "en mi trabajo"},
    "CAJERO":  {"rol": "LUGAR", "es": "en el cajero automático"},
    "TAXI":    {"rol": "LUGAR", "es": "en un taxi"},
    "PLAZA":   {"rol": "LUGAR", "es": "en la plaza"},
    "ESQUINA": {"rol": "LUGAR", "es": "en la esquina"},
    "PUENTE":  {"rol": "LUGAR", "es": "en el puente"},

    "ENOJO":    {"rol": "ESTADO", "es": "estoy enojado", "formal": "manifiesto enojo"},
    "TRISTE":   {"rol": "ESTADO", "es": "estoy triste", "formal": "me encuentro afectado"},
    "NERVIOSO": {"rol": "ESTADO", "es": "estoy nervioso", "formal": "me encuentro nervioso"},

    "DOCUMENTO":  {"rol": "DOCUMENTO", "es": "documento", "art": "el"},
    "DOCUMENTOS": {"rol": "DOCUMENTO", "es": "documentos", "art": "los"},
    "CARNET":     {"rol": "DOCUMENTO", "es": "carnet de identidad", "art": "el"},
    "CERTIFICADO":{"rol": "DOCUMENTO", "es": "certificado", "art": "el"},
    "FORMULARIO": {"rol": "DOCUMENTO", "es": "formulario", "art": "el"},
    "PARTIDA_NACIMIENTO": {"rol": "DOCUMENTO", "es": "partida de nacimiento", "art": "la"},
    "CERTIFICADO_NACIMIENTO": {"rol": "DOCUMENTO", "es": "certificado de nacimiento", "art": "el"},
    "CERTIFICADO_MATRIMONIO": {"rol": "DOCUMENTO", "es": "certificado de matrimonio", "art": "el"},
    "CERTIFICADO_DEFUNCION": {"rol": "DOCUMENTO", "es": "certificado de defunción", "art": "el"},
    "LICENCIA":   {"rol": "DOCUMENTO", "es": "licencia de conducir", "art": "la"},
    "FACTURA":    {"rol": "DOCUMENTO", "es": "factura", "art": "la"},
    "RECIBO":     {"rol": "DOCUMENTO", "es": "recibo", "art": "el"},
    "TITULO":     {"rol": "DOCUMENTO", "es": "título de propiedad", "art": "el"},
    "PODER":      {"rol": "DOCUMENTO", "es": "poder notarial", "art": "el"},
    "FOTOCOPIA":  {"rol": "DOCUMENTO", "es": "fotocopia", "art": "la"},
    "FOTO":       {"rol": "DOCUMENTO", "es": "fotografía", "art": "la"},
    "CREDENCIAL": {"rol": "DOCUMENTO", "es": "credencial", "art": "la"},
    "PASAPORTE":  {"rol": "DOCUMENTO", "es": "pasaporte", "art": "el"},
    "ANTECEDENTES":{"rol": "DOCUMENTO", "es": "certificado de antecedentes", "art": "el"},

    "RENOVACION": {"rol": "TRAMITE", "es": "renovación", "art": "la", "formal": "trámite de renovación"},
    "INSCRIPCION":{"rol": "TRAMITE", "es": "inscripción", "art": "la", "formal": "trámite de inscripción"},
    "REGISTRO":   {"rol": "TRAMITE", "es": "registro", "art": "el", "formal": "trámite de registro"},
    "PAGO":       {"rol": "TRAMITE", "es": "pago", "art": "el", "formal": "trámite de pago"},
    "CONSULTA":   {"rol": "TRAMITE", "es": "consulta", "art": "la", "formal": "consulta ciudadana"},
    "RECLAMO":    {"rol": "TRAMITE", "es": "reclamo", "art": "el", "formal": "reclamo formal"},
    "QUEJA":      {"rol": "TRAMITE", "es": "queja", "art": "la", "formal": "queja formal"},
    "CITA":       {"rol": "TRAMITE", "es": "cita", "art": "la", "formal": "cita programada"},
    "TURNO":      {"rol": "TRAMITE", "es": "turno", "art": "el", "formal": "turno de atención"},
    "DUPLICADO":  {"rol": "TRAMITE", "es": "duplicado", "art": "el", "formal": "trámite de duplicado"},

    "NOCHE":      {"rol": "TIEMPO", "es": "en la noche", "formal": "durante el horario nocturno"},
    "DIA":        {"rol": "TIEMPO", "es": "durante el día", "formal": "en horas del día"},
    "MAÑANA":     {"rol": "TIEMPO", "es": "en la mañana", "formal": "durante la mañana"},
    "TARDE":      {"rol": "TIEMPO", "es": "en la tarde", "formal": "durante la tarde"},
    "AYER":       {"rol": "TIEMPO", "es": "ayer", "formal": "el día de ayer"},
    "HOY":        {"rol": "TIEMPO", "es": "hoy", "formal": "el día de hoy"},
    "AHORA":      {"rol": "TIEMPO", "es": "ahora", "formal": "en este momento"},
    "ANTES":      {"rol": "TIEMPO", "es": "antes", "formal": "con anterioridad"},
    "SEMANA":     {"rol": "TIEMPO", "es": "esta semana", "formal": "durante la presente semana"},

    "ALCALDIA":   {"rol": "INSTITUCION", "es": "alcaldía", "prep": "en la"},
    "GOBERNACION":{"rol": "INSTITUCION", "es": "gobernación", "prep": "en la"},
    "REGISTRO_CIVIL": {"rol": "INSTITUCION", "es": "registro civil", "prep": "en el"},
    "SEGIP":      {"rol": "INSTITUCION", "es": "SEGIP", "prep": "en el"},
    "IMPUESTOS":  {"rol": "INSTITUCION", "es": "oficina de impuestos", "prep": "en la"},
    "BANCO":      {"rol": "INSTITUCION", "es": "banco", "prep": "en el"},
    "MUNICIPIO":  {"rol": "INSTITUCION", "es": "municipio", "prep": "en el"},
    "HOSPITAL":   {"rol": "INSTITUCION", "es": "hospital", "prep": "en el"},
    "ESCUELA":    {"rol": "INSTITUCION", "es": "unidad educativa", "prep": "en la"},
    "UNIVERSIDAD":{"rol": "INSTITUCION", "es": "universidad", "prep": "en la"},
    "NOTARIA":    {"rol": "INSTITUCION", "es": "notaría", "prep": "en la"},
    "JUZGADO":    {"rol": "INSTITUCION", "es": "juzgado", "prep": "en el"},
    "POLICIA":    {"rol": "INSTITUCION", "es": "estación de policía", "prep": "en la"},
    "OFICINA":    {"rol": "INSTITUCION", "es": "oficina pública", "prep": "en la"},
    "DEFENSORIA": {"rol": "INSTITUCION", "es": "defensoría", "prep": "en la"},

    "ABOGADO":    {"rol": "SERVICIO", "es": "abogado", "formal": "asistencia legal"},
    "DOCTOR":     {"rol": "SERVICIO", "es": "médico", "formal": "atención médica"},
    "INTERPRETE": {"rol": "SERVICIO", "es": "intérprete", "formal": "intérprete de lengua de señas"},
    "INFORMACION":{"rol": "SERVICIO", "es": "información", "formal": "servicio de información"},
    "ATENCION":   {"rol": "SERVICIO", "es": "atención al ciudadano", "formal": "servicio de atención ciudadana"},
    "ORIENTACION":{"rol": "SERVICIO", "es": "orientación", "formal": "servicio de orientación"},
    "AMBULANCIA": {"rol": "SERVICIO", "es": "ambulancia", "formal": "servicio de ambulancia"},
    "BOMBERO":    {"rol": "SERVICIO", "es": "bomberos", "formal": "servicio de bomberos"},

    "NUEVO":      {"rol": "DESCRIPTOR", "es": "nuevo"},
    "VIEJO":      {"rol": "DESCRIPTOR", "es": "antiguo"},
    "GRANDE":     {"rol": "DESCRIPTOR", "es": "grande"},
    "PEQUEÑO":    {"rol": "DESCRIPTOR", "es": "pequeño"},
    "PRIMERO":    {"rol": "DESCRIPTOR", "es": "por primera vez"},
    "OTRA_VEZ":   {"rol": "DESCRIPTOR", "es": "otra vez"},
    "GRATIS":     {"rol": "DESCRIPTOR", "es": "gratuito"},
    "RAPIDO":     {"rol": "DESCRIPTOR", "es": "rápido"},
    "CORRECTO":   {"rol": "DESCRIPTOR", "es": "correcto"},
    "INCORRECTO": {"rol": "DESCRIPTOR", "es": "incorrecto"},

    "URGENTE":    {"rol": "URGENCIA", "es": "urgente", "formal": "de manera urgente"},
    "EMERGENCIA": {"rol": "URGENCIA", "es": "es una emergencia", "formal": "se trata de una emergencia"},
    "PELIGRO":    {"rol": "URGENCIA", "es": "hay peligro", "formal": "existe una situación de peligro"},
    "IMPORTANTE": {"rol": "URGENCIA", "es": "es importante", "formal": "reviste importancia"},

    "ENFERMO":    {"rol": "ESTADO", "es": "enfermo/a", "formal": "con problemas de salud"},
    "HERIDO":     {"rol": "ESTADO", "es": "herido/a", "formal": "con lesiones físicas"},
    "ASUSTADO":   {"rol": "ESTADO", "es": "asustado/a", "formal": "en estado de temor"},
    "MIEDO":      {"rol": "ESTADO", "es": "tengo miedo", "formal": "siento temor"},
    "DOLOR":      {"rol": "ESTADO", "es": "siento dolor", "formal": "presento dolor"},
    "HAMBRE":     {"rol": "ESTADO", "es": "tengo hambre", "formal": "necesito alimentación"},
    "SOLO":       {"rol": "ESTADO", "es": "estoy solo/a", "formal": "me encuentro sin acompañante"},
    "PERDIDO":    {"rol": "ESTADO", "es": "estoy perdido/a", "formal": "me encuentro extraviado/a"},
    "CONFUNDIDO": {"rol": "ESTADO", "es": "estoy confundido/a", "formal": "no comprendo el procedimiento"},
    "PREOCUPADO": {"rol": "ESTADO", "es": "estoy preocupado/a", "formal": "me encuentro preocupado/a"},
}

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
        "desconocidos": [],
    }

    for card in cards:
        key = card.upper().strip()
        entry = GLOSS_LEXICON.get(key)
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
        else:
            analysis["desconocidos"].append({"glosa": key, "rol": "DESCONOCIDO", "es": key.lower()})

    analysis["tipo_evento"] = _detect_event_type(analysis)
    analysis["perspectiva"] = _detect_perspective(analysis)

    return analysis

def _detect_event_type(analysis: dict) -> str:
    verbos = [v["glosa"] for v in analysis["verbos"]]
    tramites = [t["glosa"] for t in analysis["tramites"]]
    documentos = [d["glosa"] for d in analysis["documentos"]]

    if any(v in ["ROBAR", "ASALTAR", "QUITAR"] for v in verbos):
        return "ROBO"
    if any(v in ["GOLPEAR", "AMENAZAR", "EMPUJAR", "GRITAR",
                 "PERSEGUIR", "ACOSAR", "SECUESTRAR", "ABUSO"] for v in verbos):
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
    if any(v in ["DENUNCIAR"] for v in verbos) or any(t in ["RECLAMO", "QUEJA"] for t in tramites):
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

    sentence = re.sub(r'\s+', ' ', sentence).strip()
    if sentence and not sentence.endswith('.'):
        sentence += '.'

    return sentence

def _get_time_institution(analysis, is_formal):
    parts = []
    for t in analysis["tiempos"]:
        parts.append(t.get("formal", t["es"]) if is_formal else t["es"])
    instituciones = analysis["instituciones"]
    if instituciones:
        inst_parts = []
        for i in instituciones:
            inst_parts.append(f"{i.get('prep', 'en')} {i['es']}")
        parts.append(" ".join(inst_parts))
    return " ".join(parts)

def _get_urgency(analysis, is_formal):
    if analysis["urgencias"]:
        u = analysis["urgencias"][0]
        return u.get("formal", u["es"]) if is_formal else u["es"]
    return ""

def _get_documents_text(analysis, is_formal):
    if not analysis["documentos"]:
        return ""
    docs = analysis["documentos"]
    if len(docs) == 1:
        d = docs[0]
        return f'{d.get("art", "el")} {d["es"]}'
    texts = [f'{d.get("art", "el")} {d["es"]}' for d in docs]
    return ", ".join(texts[:-1]) + " y " + texts[-1]

def _get_tramite_text(analysis, is_formal):
    if not analysis["tramites"]:
        return ""
    t = analysis["tramites"][0]
    return t.get("formal", t["es"]) if is_formal else f'{t.get("art", "el")} {t["es"]}'



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

def _lugar_text(analysis):
    return analysis["lugares"][0]["es"] if analysis["lugares"] else ""

def _agresor_text(analysis):
    personas = [d for d in analysis["descriptores"] if d.get("persona")]
    rasgos = [d for d in analysis["descriptores"] if not d.get("persona")]
    base = personas[0]["es"] if personas else "una persona"
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
    core = f"{subj} me {verb}"

    objs = _objetos_text(analysis)
    if objs:
        core += f" {objs}"
    arma = _arma_text(analysis)
    if arma:
        core += f" {arma}"
    lugar = _lugar_text(analysis)
    if lugar:
        core += f" {lugar}"

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
    if analysis["urgencias"]:
        u = analysis["urgencias"][0]
        ut = u.get("formal", u["es"]) if is_formal else u["es"]
        parts.append(f"{ut[0].upper()}{ut[1:]}.")
    if analysis["servicios"]:
        svc = _join_es([s.get("formal", s["es"]) if is_formal else s["es"]
                        for s in analysis["servicios"]])
        parts.append(f"Necesito {svc}.")
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
        parts.append(f"y necesita {svc_text} de forma urgente" if subj else f"Necesito {svc_text} de forma urgente")
    else:
        parts.append("Se requiere atención inmediata" if is_formal else "Es urgente")

    return " ".join(parts) if parts else "Se presenta una situación de emergencia"

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

def _build_bedrock_request_body(prompt_text: str) -> dict:
    model_id_lower = BEDROCK_MODEL_ID.lower()
    if "nova" in model_id_lower:
        return {"messages": [{"role": "user", "content": [{"text": prompt_text}]}],
                "inferenceConfig": {"maxTokens": 256, "temperature": 0.2, "topP": 0.9}}
    elif "anthropic" in model_id_lower or "claude" in model_id_lower:
        return {"anthropic_version": "bedrock-2023-05-31", "max_tokens": 256,
                "temperature": 0.2, "top_p": 0.9,
                "messages": [{"role": "user", "content": prompt_text}]}
    elif "titan" in model_id_lower:
        return {"inputText": prompt_text,
                "textGenerationConfig": {"maxTokenCount": 256, "temperature": 0.2, "topP": 0.9, "stopSequences": []}}
    elif "llama" in model_id_lower or "meta" in model_id_lower:
        return {"prompt": prompt_text, "max_gen_len": 256, "temperature": 0.2, "top_p": 0.9}
    else:
        return {"anthropic_version": "bedrock-2023-05-31", "max_tokens": 256,
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
    for i, card in enumerate(cards):
        if not isinstance(card, str) or not card.strip():
            return False, f"La glosa en posición {i} no es válida."
    return True, None

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
