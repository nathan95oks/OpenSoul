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

Autor: Nathanael Alba — Proyecto de Grado OpenSoul
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
logger = logging.getLogger("lsb-to-text-audio")
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------------------
# Variables de entorno
# ---------------------------------------------------------------------------
S3_BUCKET = os.environ.get("S3_BUCKET", "opensoul-lsb-audio-dev")
APP_PREFIX = os.environ.get("APP_PREFIX", "lsb-to-text-audio")
VOICE_ID = os.environ.get("VOICE_ID", "Lupe")
BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "amazon.titan-text-express-v1")
APP_REGION = os.environ.get("APP_REGION", os.environ.get("AWS_REGION", "us-east-1"))
ENABLE_BEDROCK = os.environ.get("ENABLE_BEDROCK", "true").lower() == "true"

# ---------------------------------------------------------------------------
# Clientes AWS
# ---------------------------------------------------------------------------
bedrock_runtime = boto3.client("bedrock-runtime", region_name=APP_REGION)
polly_client = boto3.client("polly", region_name=APP_REGION)
s3_client = boto3.client("s3", region_name=APP_REGION)

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Amz-Date,X-Api-Key",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Content-Type": "application/json",
}


# ===================================================================
# MÓDULO 1: LEXICÓN DE GLOSAS LSB — DOMINIO JURÍDICO
# ===================================================================

GLOSS_LEXICON = {
    # --- SUJETOS ---
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

    # --- AGENTES (personas externas que actúan) ---
    "HOMBRE":     {"rol": "AGENTE", "es": "un hombre", "perspectiva": "3P"},
    "MUJER":      {"rol": "AGENTE", "es": "una mujer", "perspectiva": "3P"},
    "LADRON":     {"rol": "AGENTE", "es": "un ladrón", "perspectiva": "3P"},
    "AGRESOR":    {"rol": "AGENTE", "es": "el agresor", "perspectiva": "3P"},
    "DESCONOCIDO":{"rol": "AGENTE", "es": "una persona desconocida", "perspectiva": "3P"},
    "GRUPO":      {"rol": "AGENTE", "es": "un grupo de personas", "perspectiva": "3P_PLURAL"},

    # --- VERBOS ---
    "DENUNCIAR":  {"rol": "VERBO", "es": "denunciar", "1p": "deseo denunciar", "3p": "denunció", "formal": "presentar denuncia por"},
    "ROBAR":      {"rol": "VERBO", "es": "robar", "1p": "me robaron", "3p": "robó", "formal": "sustraer"},
    "QUITAR":     {"rol": "VERBO", "es": "quitar", "1p": "me quitaron", "3p": "quitó", "formal": "arrebatar"},
    "NECESITAR":  {"rol": "VERBO", "es": "necesitar", "1p": "necesito", "3p": "necesita", "formal": "requiero"},
    "PERDER":     {"rol": "VERBO", "es": "perder", "1p": "perdí", "3p": "perdió", "formal": "he extraviado"},
    "AYUDAR":     {"rol": "VERBO", "es": "ayudar", "1p": "necesito ayuda", "3p": "necesita ayuda"},
    "AYUDA":      {"rol": "VERBO", "es": "ayudar", "1p": "necesito ayuda", "3p": "necesita ayuda"},
    "PEGAR":      {"rol": "VERBO", "es": "golpear", "1p": "me golpearon", "3p": "golpeó", "formal": "agredir físicamente"},
    "GOLPEAR":    {"rol": "VERBO", "es": "golpear", "1p": "me golpearon", "3p": "golpeó", "formal": "agredir"},
    "AMENAZAR":   {"rol": "VERBO", "es": "amenazar", "1p": "me amenazaron", "3p": "amenazó"},
    "SEGUIR":     {"rol": "VERBO", "es": "seguir", "1p": "me siguieron", "3p": "siguió", "formal": "acechar"},
    "ROBO":       {"rol": "VERBO", "es": "robar", "1p": "fui víctima de un robo", "3p": "robó", "tipo_evento": "ROBO"},
    "TRAMITE":    {"rol": "VERBO", "es": "tramitar", "1p": "necesito realizar un trámite", "3p": "tramitó"},
    "DESCRIBIR":  {"rol": "VERBO", "es": "describir", "1p": "deseo describir", "3p": "describió"},
    "VER":        {"rol": "VERBO", "es": "ver", "1p": "vi", "3p": "vio", "formal": "presencié"},
    "ESCUCHAR":   {"rol": "VERBO", "es": "escuchar", "1p": "escuché", "3p": "escuchó"},
    "SENTIR":     {"rol": "VERBO", "es": "sentir", "1p": "sentí", "3p": "sintió"},
    "TENER":      {"rol": "VERBO", "es": "tener", "1p": "tengo", "3p": "tiene"},
    "QUERER":     {"rol": "VERBO", "es": "querer", "1p": "quiero", "3p": "quiere", "formal": "deseo"},
    "PODER":      {"rol": "VERBO", "es": "poder", "1p": "puedo", "3p": "puede"},
    "SABER":      {"rol": "VERBO", "es": "saber", "1p": "sé", "3p": "sabe"},
    "PEDIR":      {"rol": "VERBO", "es": "pedir", "1p": "solicito", "3p": "solicita", "formal": "solicitar"},
    "ESPERAR":    {"rol": "VERBO", "es": "esperar", "1p": "estoy esperando", "3p": "está esperando"},
    "CORRER":     {"rol": "ACCION_SEQ", "es": "corriendo", "pasado": "huyó corriendo"},
    "HUIR":       {"rol": "ACCION_SEQ", "es": "huyendo", "pasado": "huyó"},
    "ESCAPAR":    {"rol": "ACCION_SEQ", "es": "escapando", "pasado": "escapó"},
    "GRITAR":     {"rol": "ACCION_SEQ", "es": "gritando", "pasado": "gritó"},
    "CAER":       {"rol": "ACCION_SEQ", "es": "cayendo", "pasado": "cayó al suelo"},

    # --- OBJETOS ---
    "MOCHILA":    {"rol": "OBJETO", "es": "mochila", "art": "la"},
    "DOCUMENTO":  {"rol": "OBJETO", "es": "documento", "art": "el"},
    "DOCUMENTOS": {"rol": "OBJETO", "es": "documentos", "art": "los"},
    "CELULAR":    {"rol": "OBJETO", "es": "teléfono celular", "art": "el"},
    "TELEFONO":   {"rol": "OBJETO", "es": "teléfono", "art": "el"},
    "DINERO":     {"rol": "OBJETO", "es": "dinero", "art": "el"},
    "BILLETERA":  {"rol": "OBJETO", "es": "billetera", "art": "la"},
    "CARTERA":    {"rol": "OBJETO", "es": "cartera", "art": "la"},
    "BOLSA":      {"rol": "OBJETO", "es": "bolsa", "art": "la"},
    "LLAVES":     {"rol": "OBJETO", "es": "llaves", "art": "las"},
    "AUTO":       {"rol": "OBJETO", "es": "automóvil", "art": "el"},
    "MOTO":       {"rol": "OBJETO", "es": "motocicleta", "art": "la"},
    "BICICLETA":  {"rol": "OBJETO", "es": "bicicleta", "art": "la"},
    "ROPA":       {"rol": "OBJETO", "es": "ropa", "art": "la"},
    "CREDENCIAL": {"rol": "OBJETO", "es": "credencial", "art": "la"},
    "CARNET":     {"rol": "OBJETO", "es": "carnet de identidad", "art": "el"},

    # --- TIEMPO ---
    "NOCHE":      {"rol": "TIEMPO", "es": "en la noche", "formal": "durante el horario nocturno"},
    "DIA":        {"rol": "TIEMPO", "es": "durante el día", "formal": "en horas del día"},
    "MAÑANA":     {"rol": "TIEMPO", "es": "en la mañana", "formal": "durante la mañana"},
    "TARDE":      {"rol": "TIEMPO", "es": "en la tarde", "formal": "durante la tarde"},
    "AYER":       {"rol": "TIEMPO", "es": "ayer", "formal": "el día de ayer"},
    "HOY":        {"rol": "TIEMPO", "es": "hoy", "formal": "el día de hoy"},
    "AHORA":      {"rol": "TIEMPO", "es": "ahora", "formal": "en este momento"},
    "ANTES":      {"rol": "TIEMPO", "es": "antes", "formal": "con anterioridad"},
    "SEMANA":     {"rol": "TIEMPO", "es": "esta semana", "formal": "durante la presente semana"},

    # --- LUGARES ---
    "PARADA":     {"rol": "LUGAR", "es": "parada", "prep": "en una"},
    "MICRO":      {"rol": "LUGAR", "es": "micro", "prep": "de"},
    "CASA":       {"rol": "LUGAR", "es": "casa", "prep": "en mi"},
    "CALLE":      {"rol": "LUGAR", "es": "calle", "prep": "en la"},
    "PLAZA":      {"rol": "LUGAR", "es": "plaza", "prep": "en la"},
    "MERCADO":    {"rol": "LUGAR", "es": "mercado", "prep": "en el"},
    "TIENDA":     {"rol": "LUGAR", "es": "tienda", "prep": "en una"},
    "ESQUINA":    {"rol": "LUGAR", "es": "esquina", "prep": "en la"},
    "PARQUE":     {"rol": "LUGAR", "es": "parque", "prep": "en el"},
    "TRABAJO":    {"rol": "LUGAR", "es": "lugar de trabajo", "prep": "en mi"},
    "ESCUELA":    {"rol": "LUGAR", "es": "escuela", "prep": "en la"},
    "HOSPITAL":   {"rol": "LUGAR", "es": "hospital", "prep": "en el"},

    # --- DESCRIPTORES ---
    "ALTO":       {"rol": "DESCRIPTOR", "es": "alto"},
    "BAJO":       {"rol": "DESCRIPTOR", "es": "bajo"},
    "JOVEN":      {"rol": "DESCRIPTOR", "es": "joven"},
    "VIEJO":      {"rol": "DESCRIPTOR", "es": "mayor de edad"},
    "GRANDE":     {"rol": "DESCRIPTOR", "es": "grande"},
    "PEQUEÑO":    {"rol": "DESCRIPTOR", "es": "pequeño"},
    "GORDO":      {"rol": "DESCRIPTOR", "es": "de contextura gruesa"},
    "FLACO":      {"rol": "DESCRIPTOR", "es": "de contextura delgada"},
    "MORENO":     {"rol": "DESCRIPTOR", "es": "de tez morena"},
    "BLANCO":     {"rol": "DESCRIPTOR", "es": "de tez clara"},
    "ROJO":       {"rol": "DESCRIPTOR", "es": "de color rojo"},
    "NEGRO":      {"rol": "DESCRIPTOR", "es": "de color negro"},
    "PELO_LARGO": {"rol": "DESCRIPTOR", "es": "de cabello largo"},
    "PELO_CORTO": {"rol": "DESCRIPTOR", "es": "de cabello corto"},

    # --- URGENCIA ---
    "URGENTE":    {"rol": "URGENCIA", "es": "urgente", "formal": "de manera urgente"},
    "RAPIDO":     {"rol": "URGENCIA", "es": "rápidamente", "formal": "con carácter de urgencia"},
    "EMERGENCIA": {"rol": "URGENCIA", "es": "es una emergencia", "formal": "se trata de una emergencia"},
    "PELIGRO":    {"rol": "URGENCIA", "es": "hay peligro", "formal": "existe una situación de peligro"},
    "IMPORTANTE": {"rol": "URGENCIA", "es": "es importante", "formal": "reviste importancia"},

    # --- SERVICIOS ---
    "POLICIA":    {"rol": "SERVICIO", "es": "policía", "formal": "asistencia policial"},
    "ABOGADO":    {"rol": "SERVICIO", "es": "abogado", "formal": "asistencia legal"},
    "DOCTOR":     {"rol": "SERVICIO", "es": "médico", "formal": "atención médica"},
    "BOMBERO":    {"rol": "SERVICIO", "es": "bomberos", "formal": "servicio de bomberos"},
    "AMBULANCIA": {"rol": "SERVICIO", "es": "ambulancia", "formal": "servicio de ambulancia"},
    "JUEZ":       {"rol": "SERVICIO", "es": "juez", "formal": "autoridad judicial"},
    "FISCAL":     {"rol": "SERVICIO", "es": "fiscal", "formal": "representante del Ministerio Público"},
    "INTERPRETE": {"rol": "SERVICIO", "es": "intérprete", "formal": "intérprete de lengua de señas"},

    # --- ESTADOS ---
    "ENFERMO":    {"rol": "ESTADO", "es": "enfermo/a", "formal": "con problemas de salud"},
    "HERIDO":     {"rol": "ESTADO", "es": "herido/a", "formal": "con lesiones físicas"},
    "ASUSTADO":   {"rol": "ESTADO", "es": "asustado/a", "formal": "en estado de temor"},
    "MIEDO":      {"rol": "ESTADO", "es": "tengo miedo", "formal": "siento temor"},
    "DOLOR":      {"rol": "ESTADO", "es": "siento dolor", "formal": "presento dolor"},
    "HAMBRE":     {"rol": "ESTADO", "es": "tengo hambre", "formal": "necesito alimentación"},
    "SOLO":       {"rol": "ESTADO", "es": "estoy solo/a", "formal": "me encuentro sin acompañante"},
    "PERDIDO":    {"rol": "ESTADO", "es": "estoy perdido/a", "formal": "me encuentro extraviado/a"},
}


# ===================================================================
# MÓDULO 2: ANÁLISIS SEMÁNTICO
# ===================================================================

def analyze_glosses(cards: list) -> dict:
    """
    Clasifica cada glosa por su rol semántico usando el lexicón.
    Detecta el tipo de evento basado en la combinación de verbos y objetos.
    """
    analysis = {
        "sujetos": [], "agentes": [], "verbos": [], "objetos": [],
        "tiempos": [], "lugares": [], "descriptores": [], "urgencias": [],
        "servicios": [], "estados": [], "acciones_seq": [], "desconocidos": [],
    }

    for card in cards:
        key = card.upper().strip()
        entry = GLOSS_LEXICON.get(key)
        if entry:
            rol = entry["rol"]
            mapping = {
                "SUJETO": "sujetos", "AGENTE": "agentes", "VERBO": "verbos",
                "OBJETO": "objetos", "TIEMPO": "tiempos", "LUGAR": "lugares",
                "DESCRIPTOR": "descriptores", "URGENCIA": "urgencias",
                "SERVICIO": "servicios", "ESTADO": "estados", "ACCION_SEQ": "acciones_seq",
            }
            dest = mapping.get(rol, "desconocidos")
            analysis[dest].append({"glosa": key, **entry})
        else:
            analysis["desconocidos"].append({"glosa": key, "rol": "DESCONOCIDO", "es": key.lower()})

    # Detectar tipo de evento
    analysis["tipo_evento"] = _detect_event_type(analysis)
    # Detectar perspectiva
    analysis["perspectiva"] = _detect_perspective(analysis)

    return analysis


def _detect_event_type(analysis: dict) -> str:
    verbos = [v["glosa"] for v in analysis["verbos"]]
    objetos = [o["glosa"] for o in analysis["objetos"]]
    servicios = [s["glosa"] for s in analysis["servicios"]]

    if any(v in ["ROBO", "ROBAR", "QUITAR"] for v in verbos):
        return "ROBO"
    if any(v in ["DENUNCIAR"] for v in verbos):
        return "DENUNCIA"
    if any(v in ["PEGAR", "GOLPEAR", "AMENAZAR"] for v in verbos):
        return "AGRESION"
    if any(v in ["PERDER"] for v in verbos):
        return "PERDIDA"
    if any(v in ["DESCRIBIR"] for v in verbos):
        return "DESCRIPCION"
    if any(v in ["NECESITAR", "AYUDA", "AYUDAR", "PEDIR"] for v in verbos):
        return "SOLICITUD"
    if analysis["urgencias"] or any(v in ["EMERGENCIA"] for v in verbos):
        return "EMERGENCIA"
    if servicios:
        return "SOLICITUD"
    if analysis["estados"]:
        return "ESTADO"
    return "GENERAL"


def _detect_perspective(analysis: dict) -> str:
    for s in analysis["sujetos"]:
        if s.get("perspectiva") == "1P":
            return "PRIMERA_PERSONA"
    return "PRIMERA_PERSONA"  # Default para LSB jurídico


# ===================================================================
# MÓDULO 3: REPRESENTACIÓN INTERMEDIA
# ===================================================================

def build_intermediate_representation(cards: list, analysis: dict, context_type: str) -> dict:
    return {
        "roles": {
            "sujeto": analysis["sujetos"][0]["glosa"] if analysis["sujetos"] else None,
            "verbo_principal": analysis["verbos"][0]["glosa"] if analysis["verbos"] else None,
            "objeto": analysis["objetos"][0]["glosa"] if analysis["objetos"] else None,
            "agente": analysis["agentes"][0]["glosa"] if analysis["agentes"] else None,
            "tiempo": analysis["tiempos"][0]["glosa"] if analysis["tiempos"] else None,
            "lugar": [l["glosa"] for l in analysis["lugares"]] if analysis["lugares"] else None,
            "descriptores": [d["glosa"] for d in analysis["descriptores"]] if analysis["descriptores"] else None,
            "servicios": [s["glosa"] for s in analysis["servicios"]] if analysis["servicios"] else None,
            "urgencia": analysis["urgencias"][0]["glosa"] if analysis["urgencias"] else None,
            "estados": [e["glosa"] for e in analysis["estados"]] if analysis["estados"] else None,
            "acciones_secundarias": [a["glosa"] for a in analysis["acciones_seq"]] if analysis["acciones_seq"] else None,
        },
        "tipo_evento": analysis["tipo_evento"],
        "perspectiva": analysis["perspectiva"],
        "contexto": context_type,
        "total_glosas": len(cards),
        "glosas_originales": cards,
        "glosas_reconocidas": len(cards) - len(analysis["desconocidos"]),
    }


# ===================================================================
# MÓDULO 4: GENERADOR DE ORACIÓN BASE (REGLAS PROPIAS)
# ===================================================================

def generate_base_sentence(ir: dict, analysis: dict, context_type: str) -> str:
    """
    Genera una oración base en español usando reglas gramaticales propias
    y plantillas por tipo de evento. Este es el NÚCLEO del sistema.
    """
    tipo = ir["tipo_evento"]
    is_legal = context_type.lower() == "legal"

    generators = {
        "DENUNCIA": _gen_denuncia,
        "ROBO": _gen_robo,
        "AGRESION": _gen_agresion,
        "SOLICITUD": _gen_solicitud,
        "PERDIDA": _gen_perdida,
        "DESCRIPCION": _gen_descripcion,
        "EMERGENCIA": _gen_emergencia,
        "ESTADO": _gen_estado,
    }

    gen_func = generators.get(tipo, _gen_general)
    sentence = gen_func(ir, analysis, is_legal)

    # Limpiar espacios y asegurar punto final
    sentence = re.sub(r'\s+', ' ', sentence).strip()
    if sentence and not sentence.endswith('.'):
        sentence += '.'

    return sentence


def _get_time_place(analysis, is_legal):
    parts = []
    for t in analysis["tiempos"]:
        parts.append(t.get("formal", t["es"]) if is_legal else t["es"])
    lugares = analysis["lugares"]
    if lugares:
        loc_parts = []
        for l in lugares:
            loc_parts.append(f"{l.get('prep', 'en')} {l['es']}")
        parts.append(" ".join(loc_parts))
    return " ".join(parts)


def _get_urgency(analysis, is_legal):
    if analysis["urgencias"]:
        u = analysis["urgencias"][0]
        return u.get("formal", u["es"]) if is_legal else u["es"]
    return ""


def _get_descriptors(analysis):
    if not analysis["descriptores"]:
        return ""
    descs = [d["es"] for d in analysis["descriptores"]]
    if len(descs) == 1:
        return descs[0]
    return ", ".join(descs[:-1]) + " y " + descs[-1]


def _gen_denuncia(ir, analysis, is_legal):
    verbo = analysis["verbos"][0] if analysis["verbos"] else None
    objeto = analysis["objetos"][0] if analysis["objetos"] else None
    tp = _get_time_place(analysis, is_legal)

    if verbo and verbo["glosa"] == "DENUNCIAR" and objeto:
        obj_text = f'{objeto.get("art", "el")} {objeto["es"]}'
        base = f"Deseo denunciar {obj_text}"
    elif verbo:
        verb_text = verbo.get("formal", verbo.get("1p", verbo["es"])) if is_legal else verbo.get("1p", verbo["es"])
        base = f"Deseo presentar una denuncia: {verb_text}" if is_legal else f"{verb_text}"
    else:
        base = "Deseo presentar una denuncia" if is_legal else "Quiero hacer una denuncia"

    if "ROBO" in [v["glosa"] for v in analysis["verbos"]]:
        base = "Deseo denunciar un robo" if is_legal else "Quiero denunciar un robo"

    if tp:
        base += f" {tp}"
    return base


def _gen_robo(ir, analysis, is_legal):
    agente = analysis["agentes"][0] if analysis["agentes"] else None
    objeto = analysis["objetos"][0] if analysis["objetos"] else None
    tp = _get_time_place(analysis, is_legal)

    if agente and objeto:
        obj_text = f'{objeto.get("art", "el")} {objeto["es"]}'
        ag_text = agente["es"]
        base = f"{ag_text.capitalize()} me {analysis['verbos'][0].get('3p', 'quitó') if analysis['verbos'] else 'quitó'} {obj_text}"
    elif objeto:
        obj_text = f'{objeto.get("art", "el")} {objeto["es"]}'
        base = f"Me robaron {obj_text}" if not is_legal else f"Fui víctima del robo de {obj_text}"
    else:
        base = "Fui víctima de un robo" if is_legal else "Me robaron"

    seq = analysis["acciones_seq"]
    if seq:
        base += f" y {seq[0].get('pasado', seq[0]['es'])}"

    if tp:
        base += f" {tp}"
    return base


def _gen_agresion(ir, analysis, is_legal):
    agente = analysis["agentes"][0] if analysis["agentes"] else None
    verbo = analysis["verbos"][0] if analysis["verbos"] else None
    tp = _get_time_place(analysis, is_legal)

    if agente and verbo:
        v_text = verbo.get("formal", verbo.get("3p", verbo["es"])) if is_legal else verbo.get("3p", verbo["es"])
        base = f"{agente['es'].capitalize()} me {v_text}"
    elif verbo:
        v_text = verbo.get("1p", verbo["es"])
        base = f"Fui víctima de agresión: {v_text}" if is_legal else v_text.capitalize()
    else:
        base = "Fui víctima de una agresión" if is_legal else "Me agredieron"

    if tp:
        base += f" {tp}"
    return base


def _gen_solicitud(ir, analysis, is_legal):
    servicios = analysis["servicios"]
    verbo = analysis["verbos"][0] if analysis["verbos"] else None
    urg = _get_urgency(analysis, is_legal)

    parts = []
    if verbo:
        v_text = verbo.get("formal", verbo.get("1p", verbo["es"])) if is_legal else verbo.get("1p", verbo["es"])
        parts.append(v_text.capitalize())

    if servicios:
        svc_texts = [s.get("formal", s["es"]) if is_legal else s["es"] for s in servicios]
        if verbo and verbo["glosa"] in ("NECESITAR", "AYUDA", "AYUDAR", "PEDIR"):
            parts.append("y requiero " + ", ".join(svc_texts) if len(parts) > 0 else "Requiero " + ", ".join(svc_texts))
        else:
            parts.append("Solicito " + ", ".join(svc_texts))

    if urg:
        parts.append(urg)

    base = " ".join(parts) if parts else "Necesito asistencia"
    tp = _get_time_place(analysis, is_legal)
    if tp:
        base += f" {tp}"
    return base


def _gen_perdida(ir, analysis, is_legal):
    objeto = analysis["objetos"][0] if analysis["objetos"] else None
    servicios = analysis["servicios"]

    if objeto:
        obj_text = f'{objeto.get("art", "el")} {objeto["es"]}'
        base = f"He extraviado {obj_text}" if is_legal else f"Perdí {obj_text}"
    else:
        base = "He extraviado un objeto personal" if is_legal else "Perdí algo"

    if any(v["glosa"] == "TRAMITE" for v in analysis["verbos"]):
        base += " y necesito realizar un trámite"
    elif servicios:
        svc = servicios[0]
        base += f" y requiero {svc.get('formal', svc['es'])}" if is_legal else f" y necesito {svc['es']}"

    return base


def _gen_descripcion(ir, analysis, is_legal):
    agente = analysis["agentes"][0] if analysis["agentes"] else None
    descs = _get_descriptors(analysis)

    target = agente["es"] if agente else "la persona"
    base = f"Deseo describir a {target}"
    if descs:
        base += f": es {descs}"
    return base


def _gen_emergencia(ir, analysis, is_legal):
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
        parts.append(f"{subj} se encuentra {est.get('formal', est['es'])}" if is_legal else f"{subj} está {est['es']}")
    elif estados:
        est = estados[0]
        parts.append(est.get("formal", est["es"]).capitalize() if is_legal else est["es"].capitalize())

    if servicios:
        svc = servicios[0]
        svc_text = svc.get("formal", svc["es"]) if is_legal else svc["es"]
        parts.append(f"y necesita {svc_text} de forma urgente" if subj else f"Necesito {svc_text} de forma urgente")
    else:
        parts.append("Se requiere atención inmediata" if is_legal else "Es urgente")

    return " ".join(parts) if parts else "Se presenta una situación de emergencia"


def _gen_estado(ir, analysis, is_legal):
    estados = analysis["estados"]
    if estados:
        est = estados[0]
        return est.get("formal", est["es"]).capitalize() if is_legal else est["es"].capitalize()
    return "Me encuentro en una situación que requiere asistencia"


def _gen_general(ir, analysis, is_legal):
    """Fallback: construye oración uniendo los componentes detectados."""
    parts = []

    for v in analysis["verbos"]:
        parts.append(v.get("1p", v["es"]))
    for o in analysis["objetos"]:
        parts.append(f'{o.get("art", "")} {o["es"]}'.strip())
    for s in analysis["servicios"]:
        svc_text = s.get("formal", s["es"]) if is_legal else s["es"]
        parts.append(svc_text)

    tp = _get_time_place(analysis, is_legal)
    if tp:
        parts.append(tp)

    if parts:
        sentence = parts[0].capitalize()
        if len(parts) > 1:
            sentence += " " + " ".join(parts[1:])
        return sentence

    # Último recurso: unir todas las glosas reconocidas
    all_es = []
    for cat in ["sujetos", "verbos", "objetos", "agentes", "tiempos", "lugares", "servicios"]:
        for item in analysis[cat]:
            all_es.append(item["es"])
    for item in analysis["desconocidos"]:
        all_es.append(item["es"])

    return " ".join(all_es).capitalize() if all_es else " ".join(ir["glosas_originales"]).capitalize()


# ===================================================================
# MÓDULO 5: REFINAMIENTO CON BEDROCK (COMPLEMENTARIO)
# ===================================================================

def refine_with_bedrock(base_sentence: str, context_type: str) -> str:
    """
    Envía la oración BASE (ya generada por el motor propio) a Bedrock
    para refinamiento de redacción. NO traduce glosas — solo pule.
    Si falla, retorna la oración base sin modificar (fallback elegante).
    """
    if not ENABLE_BEDROCK:
        logger.info("Bedrock deshabilitado, usando oración base directamente.")
        return base_sentence

    ctx_instruction = ("Contexto jurídico/administrativo: usa vocabulario formal y preciso."
                       if context_type.lower() == "legal"
                       else "Contexto general: usa español claro y correcto.")

    prompt = f"""Recibes una oración base generada por un sistema de interpretación de Lengua de Señas Boliviana (LSB).
Tu ÚNICA tarea es refinar la redacción para que sea más fluida, natural y apropiada.
{ctx_instruction}

REGLAS:
1. NO cambies el significado de la oración.
2. NO agregues hechos, personas ni circunstancias nuevas.
3. NO agregues explicaciones ni comentarios.
4. Devuelve SOLO la oración refinada.
5. Si la oración ya es correcta, devuélvela sin cambios.

Oración base: {base_sentence}
Oración refinada:"""

    try:
        request_body = _build_bedrock_request_body(prompt)
        response = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL_ID, contentType="application/json",
            accept="application/json", body=json.dumps(request_body),
        )
        response_body = json.loads(response["body"].read())
        refined = _parse_bedrock_response(response_body)
        logger.info("Bedrock refinó: '%s' → '%s'", base_sentence, refined)
        return refined
    except Exception as e:
        logger.warning("Bedrock falló, usando oración base como fallback: %s", str(e))
        return base_sentence


def _build_bedrock_request_body(prompt_text: str) -> dict:
    model_id_lower = BEDROCK_MODEL_ID.lower()
    if "anthropic" in model_id_lower or "claude" in model_id_lower:
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


def _parse_bedrock_response(response_body: dict) -> str:
    if "content" in response_body and isinstance(response_body["content"], list):
        raw = response_body["content"][0].get("text", "").strip()
    elif "results" in response_body and isinstance(response_body["results"], list):
        raw = response_body["results"][0].get("outputText", "").strip()
    elif "generation" in response_body:
        raw = response_body["generation"].strip()
    else:
        raise ValueError("Respuesta Bedrock no reconocida")

    lines = [l.strip() for l in raw.split("\n") if l.strip()]
    result = lines[0] if lines else raw
    for prefix in ["Oración refinada:", "Salida:", "Respuesta:"]:
        if result.lower().startswith(prefix.lower()):
            result = result[len(prefix):].strip()
    if (result.startswith('"') and result.endswith('"')):
        result = result[1:-1].strip()
    return result


# ===================================================================
# MÓDULO 6: SALIDA MULTIMODAL (Polly + S3)
# ===================================================================

def synthesize_audio(text: str) -> bytes:
    logger.info("Sintetizando audio con Polly — Voz: %s", VOICE_ID)
    response = polly_client.synthesize_speech(
        Text=text, OutputFormat="mp3", VoiceId=VOICE_ID,
        Engine="neural", LanguageCode="es-US",
    )
    audio_bytes = response["AudioStream"].read()
    logger.info("Audio sintetizado: %d bytes", len(audio_bytes))
    return audio_bytes


def upload_audio_to_s3(audio_bytes: bytes, cache_key: str) -> str:
    s3_key = f"{APP_PREFIX}/{cache_key}.mp3"
    logger.info("Subiendo audio a S3 — Bucket: %s, Key: %s", S3_BUCKET, s3_key)
    s3_client.put_object(Bucket=S3_BUCKET, Key=s3_key, Body=audio_bytes, ContentType="audio/mpeg")
    audio_url = f"https://{S3_BUCKET}.s3.{APP_REGION}.amazonaws.com/{s3_key}"
    logger.info("Audio disponible en: %s", audio_url)
    return audio_url


# ===================================================================
# UTILIDADES
# ===================================================================

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


# ===================================================================
# HANDLER PRINCIPAL
# ===================================================================

def lambda_handler(event, context):
    http_method = event.get("httpMethod", event.get("requestContext", {}).get("http", {}).get("method", "POST"))
    if http_method == "OPTIONS":
        return build_response(200, {"message": "CORS preflight OK"})

    request_id = context.aws_request_id if context and hasattr(context, "aws_request_id") else ""
    logger.info("Solicitud recibida — request_id: %s", request_id)

    # 1. Parsear y validar
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
    cache_key = generate_cache_key(context_type, cards)
    logger.info("Procesando — cards: %s, context: %s, cache_key: %s", cards, context_type, cache_key)

    # 2. MOTOR INTELIGENTE PROPIO — Análisis semántico
    analysis = analyze_glosses(cards)
    logger.info("Análisis semántico: tipo_evento=%s", analysis["tipo_evento"])

    # 3. MOTOR INTELIGENTE PROPIO — Representación intermedia
    intermediate = build_intermediate_representation(cards, analysis, context_type)

    # 4. MOTOR INTELIGENTE PROPIO — Generación de oración base
    base_sentence = generate_base_sentence(intermediate, analysis, context_type)
    logger.info("Oración base generada: %s", base_sentence)

    # 5. CAPA COMPLEMENTARIA — Refinamiento con Bedrock
    try:
        generated_text = refine_with_bedrock(base_sentence, context_type)
    except Exception as e:
        logger.warning("Refinamiento con Bedrock falló, usando oración base: %s", str(e))
        generated_text = base_sentence

    bedrock_used = generated_text != base_sentence

    # 6. SALIDA MULTIMODAL — Polly + S3
    try:
        audio_bytes = synthesize_audio(generated_text)
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

    # 7. Respuesta exitosa
    logger.info("Completado — base: '%s' | final: '%s' | bedrock: %s", base_sentence, generated_text, bedrock_used)

    return build_response(200, {
        "baseSentence": base_sentence,
        "generatedText": generated_text,
        "intermediateRepresentation": intermediate,
        "audioUrl": audio_url,
        "cacheHit": False,
        "bedrockUsed": bedrock_used,
    })
