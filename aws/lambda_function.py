"""
Lambda: translate-lsb-dev — Arquitectura Híbrida
Motor Inteligente Propio + Bedrock como Refinador Complementario

Flujos:
  guided: grafo → SemanticFrame → Bedrock → validador → Polly/S3
          (GuidedComposer es el fallback seguro)
  free/legacy: glosas → análisis local → base → Bedrock → Polly/S3

Dominio: Trámites y consultas ciudadanas en entidades públicas bolivianas
Autor: Nathanael Alba — Proyecto de Grado OpenSoul
"""

import json
import os
import hashlib
import logging
import re
import time

from guided_composer import compose as compose_guided
from guided_composer import Composer as GuidedComposer
from guided_composer import EDITOR_KEYS as GUIDED_EDITOR_KEYS
from guided_composer import load_bank as load_guided_bank
import rag_consulta as RAG
import rag_equivalencias as EQUIV
import rag_revision as REVISION
import rag_zonas as ZONAS
from gloss_lexicon import GLOSS_LEXICON
from sentence_composer import (  # noqa: F401  (se reexportan)
    LOSS_ACTIONS,
    ROBBERY_ACTIONS,
    _ACCENT_TABLE,
    _ACTOR_ROLE_ALIASES,
    _ADMITE_DETALLE,
    _CARDINALES,
    _DIGITOS,
    _FACT_PHRASES,
    _FEMININE_CLOTHING,
    _FLIGHT_VERBS,
    _FORMAL_CONTEXTS,
    _FORMAL_INSTITUTIONS,
    _FREQUENCY_GLOSSES,
    _INHERENT_EVIDENCE,
    _MARKER_GLOSSES,
    _NEUTRAL_CLOTHING,
    _PLURAL_CLOTHING,
    _PREPOSICIONES,
    _TIME_UNITS,
    _a_destino,
    _agresor_text,
    _agresor_verb,
    _append_unused_states,
    _append_witnesses,
    _cap,
    _color_adj,
    _compose_action_report,
    _compose_incident,
    _con_detalle,
    _describe_escape,
    _describe_other_facts,
    _detect_event_type,
    _detect_perspective,
    _es_letra,
    _extract_details,
    _gen_agresion,
    _gen_consulta,
    _gen_emergencia,
    _gen_entrega,
    _gen_estado,
    _gen_general,
    _gen_gestion,
    _gen_identificacion,
    _gen_pago,
    _gen_perdida,
    _gen_reclamo,
    _gen_robo,
    _gen_solicitud,
    _gen_tramite,
    _get_documents_text,
    _get_time_institution,
    _get_tramite_text,
    _get_urgency,
    _is_formal,
    _join,
    _join_es,
    _join_spelled_digits,
    _lexicon_key,
    _lugar_text,
    _normalizar,
    _object_neutral_phrase_py,
    _object_self_phrase_py,
    _objetos_text,
    _person_phrase_structured,
    _relation_word,
    analyze_glosses,
    generate_base_sentence,
    generate_structured_sentence,
    lexicon_lookup,
    normalize_actor_role,
    normalize_facts,
)

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
# Embeddings del RAG por significado (acciones «consulta» y «rag_indexar»).
RAG_EMBEDDING_MODEL = os.environ.get(
    "RAG_EMBEDDING_MODEL", "amazon.titan-embed-text-v2:0").strip()
RAG_EMBEDDING_DIM = int(os.environ.get("RAG_EMBEDDING_DIM", "256"))

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


# Espejo de _deicticTimeForm en el cliente: unidad sin cantidad detrás resuelta
# con su forma deíctica, no el lexema base sin artículo ("Semana, una persona
# me robó.").
_DEICTIC_TIME_FORM = {
    "MINUTO": "este minuto", "HORA": "esta hora", "DIA": "hoy",
    "SEMANA": "esta semana", "MES": "este mes", "ANO": "este año",
}


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


_VOICE_BY_LANG = {
    "es-bo": ("Lupe", "es-US"),
    "es-mx": ("Mia", "es-MX"),
    "es-us": ("Lupe", "es-US"),
    "es":    ("Lupe", "es-US"),
}


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


def _decap(s: str) -> str:
    if not s:
        return ""
    return s[0].lower() + s[1:]


# Papeles del protagonista de un hecho. Conjunto cerrado: un valor fuera de
# aquí no se interpreta a ojo, se degrada a 'unknown' y se registra. Antes era
# texto libre, así que un 'sospechozo' mal escrito pasaba sin que nada lo
# notara y la frase perdía a quién atribuía la acción.
ACTOR_ROLES = {"suspect", "victim", "thirdParty", "unknown"}


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


# Marcas de quién huyó, por papel. Si el relato dice que escapó el
# sospechoso, el texto refinado no puede decir que escapó el declarante: son
# dos relatos distintos con las mismas palabras.
_ESCAPE_MARKERS = {
    "suspect": ("sospechoso se dio a la fuga", "persona se dio a la fuga",
                "se dio a la fuga", "el ladron escapo", "el escapo"),
    "victim": ("logre escapar", "pude escapar", "el declarante logro escapar",
               "yo escape"),
    "thirdParty": ("otra persona se dio a la fuga",
                   "una tercera persona escapo", "un tercero escapo"),
}

# Cómo se reconoce que el texto AFIRMA cada acción.
_ACTION_ASSERTIONS = {
    "ROBAR": ("robo", "robaron", "me robo", "sustrajo", "sustrajeron",
              "sustraido", "sustraccion"),
    "PERDER": ("perdi", "extravie", "he extraviado", "perdido"),
    "GOLPEAR": ("agredio", "me agredio", "golpeo", "agresion"),
    "AMENAZAR": ("amenazo", "amenaza"),
    "ENGAÑAR": ("engano", "me engano", "estafa"),
    "DAÑAR": ("dano", "danos"),
    "ESCAPAR": ("escapo", "escape", "fuga", "huida"),
}

# Marcas de duda. Si el relato declaraba incertidumbre, el texto tiene que
# conservarla: "creo que" no es lo mismo que afirmarlo.
_UNCERTAINTY_MARKERS = ("no estoy seguro", "creo que", "no recuerdo",
                        "no se si", "posiblemente", "quiza")

_NEGATION_MARKERS = ("no es cierto", "no ", "ningun", "nadie", "nada")


def _asserts_action(plano: str, accion: str) -> bool:
    """Si [plano] afirma la acción [accion]."""
    for marca in _ACTION_ASSERTIONS.get(accion.upper(), ()):
        if marca in plano:
            return True
    return False


def relations_are_preserved(facts: list, generated: str) -> tuple:
    """Comprueba que el refinamiento conserve las RELACIONES, no las palabras.

    Encontrar las mismas palabras no demuestra nada: «me robaron y yo escapé»
    y «me robaron y el ladrón escapó» comparten todas, y no dicen lo mismo.
    Aquí se comprueba quién hizo qué, qué se negó y qué quedó en duda.

    Devuelve (conserva, motivo).
    """
    if not facts:
        return True, ""

    plano = _normalizar(generated)

    # 1. Ningún hecho negado puede aparecer afirmado.
    for f in facts:
        if not f.get("negated"):
            continue
        if _asserts_action(plano, f["action"]):
            hay_negacion = any(m in plano for m in _NEGATION_MARKERS)
            if not hay_negacion:
                return False, (
                    f"afirma {f['action']}, que se habia declarado negado")

    # 2. La incertidumbre no se convierte en afirmación.
    for f in facts:
        if f.get("certainty") not in ("uncertain", "unknown"):
            continue
        if _asserts_action(plano, f["action"]) and not any(
                m in plano for m in _UNCERTAINTY_MARKERS):
            return False, (
                f"afirma {f['action']}, que se habia declarado con duda")

    # 3. Quién escapó se conserva.
    for f in facts:
        if f["action"] != "ESCAPAR" or f.get("negated"):
            continue
        rol = f.get("actorRole", "unknown")
        if rol == "unknown":
            continue
        propias = _ESCAPE_MARKERS.get(rol, ())
        ajenas = [m for otro, marcas in _ESCAPE_MARKERS.items()
                  if otro != rol for m in marcas]
        dice_lo_suyo = any(m in plano for m in propias)
        dice_lo_ajeno = any(m in plano for m in ajenas)
        if dice_lo_ajeno and not dice_lo_suyo:
            return False, "cambia quien escapo"

    # 4. No se afirma una sustraccion que nadie declaro.
    acciones = {f["action"] for f in facts if not f.get("negated")}
    if not (acciones & ROBBERY_ACTIONS) and _asserts_action(plano, "ROBAR"):
        return False, "introduce un robo que nadie declaro"

    return True, ""


def _generation_is_safe(cards: list, generated: str, base: str,
                        facts: list = ()) -> tuple:
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

    # Y lo que las palabras no dicen: quién hizo qué, qué se negó y qué quedó
    # en duda. Un texto puede contener todas las señas y haber cambiado de
    # protagonista.
    conserva, motivo = relations_are_preserved(list(facts), generated)
    if not conserva:
        return False, motivo

    return True, ""


def _semantic_frame_relation_facts(frame: dict) -> list:
    """Adapta el frame guiado al validador de relaciones ya existente."""
    roles = {r.get("factId"): r for r in frame.get("roles") or []}
    out = []
    for fact in frame.get("facts") or []:
        effect = fact.get("effect") or {}
        action = effect.get("action")
        if not action:
            action = next((g for g in fact.get("concepts") or []
                           if str(g).upper() in _ACTION_ASSERTIONS), None)
        if not action:
            continue
        role = roles.get(fact.get("id"), {})
        state = fact.get("state")
        out.append({
            "id": fact.get("id"),
            "action": str(action).upper(),
            "actorRole": (effect.get("actorRole")
                          or role.get("actorRole") or "unknown"),
            "negated": state == "negado",
            "certainty": ("unknown" if state == "desconocido"
                          else effect.get("certainty") or "confirmed"),
            "objectIds": [],
            "actorDetail": "",
            "lossType": effect.get("lossType") or "",
        })
    return out


def _semantic_validation_cards(frame: dict) -> list:
    """Conceptos cuya presencia léxica sí se puede comprobar sin ambigüedad.

    Acciones, polaridad e incertidumbre se validan por estado/relaciones. El
    dinero con monto se valida por sus literales: exigir además la palabra
    «billetes» rechazaría una salida fiel como «Bs 500».
    """
    action_ids = set(_ACTION_ASSERTIONS)
    skip = action_ids | {"SÍ", "SI", "NO", "NO_SABER"}
    money_facts = {
        literal.get("factId")
        for literal in frame.get("literals") or []
        if literal.get("key") in ("monto", "moneda")
    }
    cards = []
    for fact in frame.get("facts") or []:
        for concept in fact.get("concepts") or []:
            key = str(concept).upper().strip()
            if key in skip:
                continue
            if fact.get("id") in money_facts and key in ("BILLETES", "DINERO"):
                continue
            cards.append(key)
    return cards


def _literal_is_present(literal: dict, generated: str) -> bool:
    """Los datos escritos se conservan exactamente en valor y tipo."""
    key = str(literal.get("key") or "").split(".")[-1].lower()
    value = literal.get("value")
    if value is None or isinstance(value, bool) or key == "aprox":
        return True
    raw = str(value).strip()
    if not raw:
        return True
    plano = _normalizar(generated)
    esperado = _normalizar(raw)

    if key in ("telefono", "numero"):
        digits = re.sub(r"\D", "", raw)
        return bool(digits) and digits in re.sub(r"\D", "", generated)
    if key in ("monto", "n") or re.fullmatch(r"\d+(?:[.,]\d+)?", raw):
        return re.search(rf"(?<!\d){re.escape(raw)}(?!\d)", generated) is not None
    if key == "moneda":
        aliases = {
            "bs": ("bs", "bob", "boliviano", "bolivianos"),
            "bob": ("bs", "bob", "boliviano", "bolivianos"),
            "usd": ("usd", "dolar", "dolares"),
        }
        return any(re.search(rf"\b{re.escape(a)}\b", plano)
                   for a in aliases.get(esperado, (esperado,)))
    return esperado in plano


def _unexpected_catalog_fact(frame: dict, generated: str) -> str:
    """Detecta entidades concretas del catálogo que el frame no confirmó."""
    expected = {
        _normalizar(str(g).replace("_", " "))
        for fact in frame.get("facts") or []
        for g in fact.get("concepts") or []
    }
    if frame.get("institutionContext"):
        expected.add(_normalizar(str(frame["institutionContext"])
                                 .replace("_", " ")))
    plano = _normalizar(generated)
    checked_roles = {"LUGAR", "INSTITUCION", "OBJETO", "DOCUMENTO", "TIEMPO"}
    stop = {"a", "al", "de", "del", "el", "en", "la", "las", "lo", "los",
            "mi", "mis", "un", "una", "unos", "unas"}
    for concept, entry in GLOSS_LEXICON.items():
        if entry.get("rol") not in checked_roles:
            continue
        canonical = _normalizar(str(concept).replace("_", " "))
        if canonical in expected:
            continue
        words = [w for w in re.findall(r"[a-z0-9]+", _normalizar(entry.get("es", "")))
                 if w not in stop]
        if not words:
            continue
        marker = " ".join(words)
        if len(marker) < 4:
            continue
        if re.search(rf"\b{re.escape(marker)}\b", plano):
            return str(concept)
    return ""


def semantic_frame_is_preserved(frame: dict, generated: str,
                                deterministic_fallback: str) -> tuple:
    """Valida que la salida exprese exactamente el frame guiado.

    Es deliberadamente conservador: ante una equivalencia que el código no
    puede demostrar, devuelve falso y gana el compositor determinista.
    """
    relation_facts = _semantic_frame_relation_facts(frame)
    safe, reason = _generation_is_safe(
        _semantic_validation_cards(frame), generated,
        deterministic_fallback, relation_facts)
    if not safe:
        return False, reason

    plano = _normalizar(generated)
    expected_actions = {f["action"] for f in relation_facts
                        if not f.get("negated")}
    for action in expected_actions:
        if not _asserts_action(plano, action):
            return False, f"omite acción confirmada {action}"
    for action in _ACTION_ASSERTIONS:
        if action not in expected_actions and _asserts_action(plano, action):
            return False, f"agrega acción no confirmada {action}"

    has_negation = bool(frame.get("negations"))
    has_unknown = bool(frame.get("unknowns"))
    output_has_negation = any(marker in f" {plano} "
                              for marker in _NEGATION_MARKERS)
    output_has_uncertainty = any(marker in plano
                                 for marker in _UNCERTAINTY_MARKERS)
    if has_negation and not output_has_negation:
        return False, "elimina una negación confirmada"
    if has_unknown and not output_has_uncertainty:
        return False, "convierte desconocimiento en afirmación"
    if not has_negation and not has_unknown and output_has_negation:
        return False, "agrega una negación no confirmada"

    for literal in frame.get("literals") or []:
        if not _literal_is_present(literal, generated):
            return False, f"cambia u omite literal {literal.get('key', '')}"

    unexpected = _unexpected_catalog_fact(frame, generated)
    if unexpected:
        return False, f"agrega entidad no confirmada {unexpected}"
    return True, ""


def build_guided_realization_prompt(frame: dict) -> str:
    """Prompt de guided: semántica+LSB, nunca la frase española fallback."""
    payload = {
        key: frame[key]
        for key in ("lsbSequence", "intent", "facts", "roles", "slots",
                    "negations", "unknowns", "literals", "context",
                    "institutionContext")
        if key in frame
    }
    return """Actúas únicamente como REALIZADOR LINGÜÍSTICO. Convierte el SemanticFrame de una persona sorda a español natural, formal y claro de Bolivia.

REGLAS INNEGOCIABLES:
1. El SemanticFrame y lsbSequence son la única fuente de verdad. No infieras hechos por contexto.
2. Expresa todos y solo los facts confirmados. No omitas, agregues ni reinterpretes ninguno.
3. Conserva exactamente roles (actor, paciente, receptor), negations, estados desconocidos y el intent.
4. Conserva literalmente cantidades, monedas, fechas, horas, nombres, teléfonos, códigos y documentos incluidos en literals.
5. No agregues institución, lugar, medio, culpable, víctima, relación, objeto ni trámite si no aparecen confirmados.
6. No generes opciones ni glosas nuevas. No expliques tu trabajo.
7. Devuelve SOLO el texto final en español, sin JSON, etiquetas, comillas, markdown ni comentarios.

SEMANTIC_FRAME:
""" + json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def generate_spanish_from_semantic_frame(frame: dict,
                                         deterministic_fallback: str) -> tuple:
    """Realiza guided con Bedrock; retorna (texto, usado, mismatch)."""
    if not ENABLE_BEDROCK:
        return deterministic_fallback, False, False

    prompt = build_guided_realization_prompt(frame)
    try:
        request_body = _build_bedrock_request_body(prompt, max_tokens=400)
        response = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL_ID, contentType="application/json",
            accept="application/json", body=json.dumps(request_body),
        )
        texto = _parse_bedrock_response(json.loads(response["body"].read()))
    except Exception as e:  # noqa: BLE001 — todo fallo cae al compositor seguro
        logger.warning("Realización guided con Bedrock falló: %s", e)
        return deterministic_fallback, False, False

    texto = (texto or "").strip().strip('"').strip()
    safe, reason = semantic_frame_is_preserved(
        frame, texto, deterministic_fallback)
    if not safe:
        logger.warning(
            "Realización guided descartada por mismatch semántico (%s), "
            "%d caracteres", reason, len(texto))
        return deterministic_fallback, False, True
    return texto, True, False


def generate_with_bedrock(cards: list, analysis: dict, base_sentence: str,
                          context_type: str, institution_type: str = "",
                          facts: list = ()) -> tuple:
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
    seguro, motivo = _generation_is_safe(cards, texto, base_sentence, facts)
    if not seguro:
        # Sin el texto descartado: puede contener el mismo contenido sensible
        # que se está rechazando (auditoría 2026-09, hallazgo de logging).
        logger.warning("Generación descartada (%s), %d caracteres", motivo, len(texto))
        return base_sentence, False

    return texto, True


def refine_with_bedrock(base_sentence: str, context_type: str,
                        institution_type: str = "") -> str:
    """Compatibilidad del refinador legacy; guided no llama esta función.

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
                "Refinamiento legacy descartado por divergencia: "
                "base_chars=%d final_chars=%d",
                len(base_sentence), len(refined),
            )
            return base_sentence
        logger.info("Refinamiento legacy aceptado: base_chars=%d final_chars=%d",
                    len(base_sentence), len(refined))
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

def _bedrock_raw_text(response_body: dict) -> str:
    """El texto completo que devolvió el modelo, según la familia."""
    if "output" in response_body and isinstance(response_body.get("output"), dict):
        return (response_body["output"].get("message", {})
                .get("content", [{}])[0].get("text", "").strip())
    if "content" in response_body and isinstance(response_body["content"], list):
        return response_body["content"][0].get("text", "").strip()
    if "results" in response_body and isinstance(response_body["results"], list):
        return response_body["results"][0].get("outputText", "").strip()
    if "generation" in response_body:
        return response_body["generation"].strip()
    raise ValueError("Respuesta Bedrock no reconocida")


def _parse_bedrock_response(response_body: dict) -> str:
    """La oración que devolvió el modelo: la primera línea con contenido,
    sin rótulos («Oración refinada:») ni comillas. Solo para respuestas de
    una frase; un JSON se lee con `invoke_bedrock_json`."""
    raw = _bedrock_raw_text(response_body)

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

def read_cache_json(cache_key: str):
    """Lee una entrada JSON de la caché S3, o None si no hay acierto."""
    try:
        obj = s3_client.get_object(Bucket=S3_BUCKET, Key=_cache_s3_key(cache_key))
        return json.loads(obj["Body"].read())
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code", "")
        if code not in ("NoSuchKey", "404", "NotFound"):
            logger.warning("No se pudo leer la caché %s: %s", cache_key, e)
        return None
    except Exception as e:
        logger.warning("Caché ilegible %s: %s", cache_key, e)
        return None


def write_cache_json(cache_key: str, body: dict) -> None:
    """Escribe una entrada JSON en la caché S3; un fallo no corta la respuesta."""
    try:
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=_cache_s3_key(cache_key),
            Body=json.dumps(body, ensure_ascii=False).encode("utf-8"),
            ContentType="application/json",
        )
    except Exception as e:
        logger.warning("No se pudo escribir la caché %s: %s", cache_key, e)


def get_cached_response(cache_key: str):
    """Devuelve la respuesta cacheada (con audioUrl prefirmado fresco) o None."""
    data = read_cache_json(cache_key)
    if data is None:
        return None

    audio_key = data.pop("audioKey", None)
    data["audioUrl"] = _presign_audio(audio_key) if audio_key else None
    data["cacheHit"] = True
    data["cachedGenerationSource"] = data.get("generationSource", "")
    data["generationSource"] = "cache"
    return data

def put_cached_response(cache_key: str, payload: dict, audio_key: str) -> None:
    """Guarda la respuesta (sin la URL firmada efímera) para futuros aciertos."""
    body = {k: v for k, v in payload.items() if k not in ("audioUrl", "cacheHit")}
    body["audioKey"] = audio_key
    write_cache_json(cache_key, body)

def build_response(status_code: int, body: dict) -> dict:
    return {"statusCode": status_code, "headers": CORS_HEADERS,
            "body": json.dumps(body, ensure_ascii=False)}

# Versión del contrato que habla este backend.
#
# Viaja en cada respuesta para que el cliente sepa si puede enviar una
# colección de hechos. Sin este anuncio, un cliente v3 contra una Lambda
# anterior recibe 200 y pierde el segundo hecho sin que nada lo diga: la
# petición se acepta y el significado se va por el camino.
BACKEND_CONTRACT_VERSION = 4


# Versión del generador determinista.
#
# Entra en la clave de caché porque una respuesta guardada con un generador
# anterior puede estar MAL. La versión 2 corrige que ESCAPAR se redactara como
# un robo, que `actorRole` no se leyera y que el `declaration` se descartara
# fuera de `denuncia_robo`: todo lo cacheado con la 1 puede contener esos
# errores, y servirlo tras desplegar la corrección es dejar el fallo vivo en
# los casos más frecuentes, que son justo los que están en caché.
#
# Subir este número al cambiar el generador invalida lo anterior sin tener que
# vaciar el bucket a mano.
#
# La versión 5 incorpora SemanticFrame y realización Bedrock validada en la
# ruta guiada. Una respuesta v4 podía ser la frase determinista; reutilizarla
# impediría activar el nuevo pipeline y mezclaría métricas de origen.
GENERATOR_VERSION = 5


def generate_cache_key(context_type: str, cards: list, institution_type: str = "",
                        language: str = "", speech_act: str = "",
                        declaration=None, contract_version=None, guided=None,
                        semantic_frame=None) -> str:
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
        f"g{GENERATOR_VERSION}",
        f"c{contract_version or 1}",
        context_type.lower().strip(),
        "|".join(c.upper().strip() for c in cards),
        institution_type.lower().strip(),
        language.lower().strip(),
        speech_act.lower().strip(),
        declaration_part,
        json.dumps(guided, sort_keys=True, ensure_ascii=False) if guided else "",
        (json.dumps(semantic_frame, sort_keys=True, ensure_ascii=False)
         if semantic_frame else ""),
    ])
    # SHA-256 (NIST FIPS 180-4), no MD5. La clave sale de lo que manda
    # cualquiera a un endpoint público, y MD5 tiene colisiones prácticas desde
    # 2004 (la RFC 6151 lo descarta para seguridad desde 2011): alguien podría
    # fabricar dos pedidos con la misma clave y que la caché le sirviera a una
    # persona la traducción o el audio de otra. SHA-256 no tiene colisiones
    # conocidas, viene en la biblioteca estándar y es el hash que ya usa AWS
    # (firma SigV4, checksums de S3); su costo aquí es de microsegundos.
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()

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
    # Una intervención guiada hecha solo de valores escritos (un nombre, un
    # teléfono) no tiene glosas: las glosas no se inventan para rellenar.
    if len(cards) == 0 and not isinstance(body.get("guided"), dict):
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

# ---------------------------------------------------------------------------
# Contrato v4: intervención guiada
# ---------------------------------------------------------------------------
# Las mismas reglas que aplica el dominio del cliente (GuidedFlow): la
# configuración de la interfaz no sustituye la validación del backend. Una
# respuesta con Sí y No a la vez, una quinta opción donde caben cuatro o un
# valor escrito sin tope se rechazan aquí, no se redactan.

MAX_GUIDED_ANSWERS = 64
MAX_GUIDED_STEPS = 128
MAX_VALUE_LENGTH = 120
MAX_HEARING_TEXT = 1000
GUIDED_STATES = ("afirmado", "negado", "desconocido", "omitido")
GUIDED_PURPOSES = ("standalone", "initiative", "reply")

_GUIDED_BANK = None


def _guided_bank() -> dict:
    global _GUIDED_BANK
    if _GUIDED_BANK is None:
        _GUIDED_BANK = load_guided_bank()
    return _GUIDED_BANK


def _max_picks(q: dict) -> int:
    if q.get("control") == "seleccion_multiple":
        return int(q.get("maximo") or len(q.get("opciones") or []) or 1)
    return 1


def _is_exclusive(o: dict) -> bool:
    return bool(o.get("salida")) or (o.get("estado") or "afirmado") != "afirmado"


def validate_guided(body: dict) -> tuple:
    """Comprueba la intervención guiada (contrato v4) contra el banco."""
    guided = body.get("guided")
    if guided is None:
        return True, None
    if not isinstance(guided, dict):
        return False, "El campo 'guided' debe ser un objeto."
    bank = _guided_bank()
    questions = {q["id"]: q for q in bank["preguntas"]}

    journey = guided.get("recorrido", "")
    if not isinstance(journey, str) or len(journey) > MAX_ID_LENGTH:
        return False, "El recorrido guiado no es válido."
    if journey and journey not in bank.get("recorridos", {}):
        return False, f"Recorrido guiado desconocido: {journey}."
    if guided.get("proposito") not in GUIDED_PURPOSES:
        return False, "El propósito de la intervención guiada no es válido."
    for campo, tope in (("conversationId", MAX_ID_LENGTH),
                        ("hearingTurnId", MAX_ID_LENGTH),
                        ("hearingTurnText", MAX_HEARING_TEXT)):
        valor = guided.get(campo)
        if valor is not None and (not isinstance(valor, str) or len(valor) > tope):
            return False, f"El campo '{campo}' de la intervención no es válido."
    pasos = guided.get("pasos", [])
    if (not isinstance(pasos, list) or len(pasos) > MAX_GUIDED_STEPS
            or not all(isinstance(p, str) and p in questions for p in pasos)):
        return False, "Los pasos de la intervención guiada no son válidos."

    respuestas = guided.get("respuestas")
    if not isinstance(respuestas, list) or len(respuestas) > MAX_GUIDED_ANSWERS:
        return False, "Las respuestas de la intervención guiada no son válidas."
    vistas = set()
    for i, a in enumerate(respuestas):
        donde = f"La respuesta {i}"
        if not isinstance(a, dict):
            return False, f"{donde} no es un objeto."
        qid = a.get("pregunta")
        q = questions.get(qid) if isinstance(qid, str) else None
        if q is None:
            return False, f"{donde} cita una pregunta inexistente."
        if qid in vistas:
            return False, f"{donde} repite la pregunta {qid}."
        vistas.add(qid)
        estado = a.get("estado")
        if estado not in GUIDED_STATES:
            return False, f"{donde} tiene un estado no válido."
        opciones = a.get("opciones", [])
        if not isinstance(opciones, list) or not all(isinstance(o, str) for o in opciones):
            return False, f"{donde} tiene opciones no válidas."
        por_id = {o["id"]: o for o in q.get("opciones", [])}
        if len(set(opciones)) != len(opciones) or any(o not in por_id for o in opciones):
            return False, f"{donde} elige una opción que {qid} no tiene."
        if estado == "omitido":
            if opciones:
                return False, f"{donde} está omitida y a la vez elige opciones."
        else:
            if not opciones:
                return False, f"{donde} no elige ninguna opción."
            if len(opciones) > _max_picks(q):
                return False, f"{donde} supera el máximo de opciones de {qid}."
            elegidas = [por_id[o] for o in opciones]
            if len(elegidas) > 1 and any(_is_exclusive(o) for o in elegidas):
                return False, f"{donde} mezcla una respuesta excluyente con otras."
            esperado = (elegidas[0].get("estado") or "afirmado") if len(elegidas) == 1 else "afirmado"
            if estado != esperado:
                return False, f"{donde} declara un estado que no corresponde a su opción."
        valores = a.get("valores", {})
        if not isinstance(valores, dict):
            return False, f"{donde} tiene valores no válidos."
        for oid, vals in valores.items():
            if oid not in opciones or not isinstance(vals, dict):
                return False, f"{donde} trae valores de una opción no elegida."
            permitidas = set(GUIDED_EDITOR_KEYS.get(por_id[oid].get("editor") or "", ())) | {"aprox"}
            for clave, valor in vals.items():
                if clave not in permitidas:
                    return False, f"{donde} trae un valor desconocido ({clave})."
                if not isinstance(valor, (str, int)) or isinstance(valor, bool):
                    return False, f"{donde} trae un valor que no es texto."
                if len(str(valor)) > MAX_VALUE_LENGTH:
                    return False, f"{donde} trae un valor demasiado largo."
        mencion = a.get("mencion")
        if mencion is not None:
            if (not isinstance(mencion, dict)
                    or not isinstance(mencion.get("frase", ""), str)
                    or len(mencion.get("frase", "")) > MAX_VALUE_LENGTH):
                return False, f"{donde} trae una mención no válida."
        padre = a.get("padre")
        if padre is not None and padre not in questions:
            return False, f"{donde} cita un padre inexistente."
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
    # El texto completo, no solo su primera línea: el modelo suele escribir
    # el JSON en varias líneas («{» sola, o un bloque ```json). Leerlo con
    # `_parse_bedrock_response` (una frase, la primera línea) dejaba sin
    # objeto JSON toda respuesta así, y el desempate de Conversación y las
    # sugerencias caían siempre en «model_error».
    crudo = _bedrock_raw_text(json.loads(respuesta["body"].read()))
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


# ===================================================================
# RUTEO DE CONVERSACIÓN SOBRE EL GRAFO (action: "route")
# ===================================================================
# Conversation no tiene traductor propio. El turno del oyente ya llega
# entendido por Audio/Texto→LSB (su SemanticTurn); aquí el modelo solo decide
# QUÉ parte del grafo de LSB→Texto/Audio permite a la persona sorda
# responder, y solo entre rutas candidatas que el cliente armó con el banco.
#
# El modelo elige por id. La respuesta copia los campos de la candidata ya
# validada contra el banco, nunca los del modelo: un contexto, una pregunta o
# una opción inventados no tienen por dónde salir. No se traduce el turno otra
# vez ni se responde por nadie.

ROUTE_TYPES = (
    "CONTEXT_SELECTOR",
    "DIRECT_CONTEXT",
    "DIRECT_QUESTION",
    "MINIMAL_GRAPH_PATH",
    "NO_SAFE_ROUTE",
)
ROUTER_PROMPT_VERSION = 1
MAX_ROUTE_CANDIDATES = 12
MAX_ROUTE_QUESTIONS = 8
MAX_ROUTE_LABEL = 200
ROUTE_MIN_CONFIDENCE = 0.6
_ROUTE_ID_RE = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
# Ranuras que puede pedir un turno: el vocabulario del grafo de diálogo, el
# mismo que emite la lectura semántica de Audio/Texto→LSB.
ROUTE_SLOTS = {"time", "place", "person", "object", "amount", "evidence",
               "polarity", "free_text"}
# Una elección del modelo vale mientras no cambien el router, el banco ni el
# modelo (todos van en la clave). "Sin ruta" se guarda poco tiempo: un banco
# ampliado puede tener mañana la ruta que hoy falta.
ROUTE_NO_ROUTE_TTL_SECONDS = int(os.environ.get("ROUTE_NO_ROUTE_TTL_SECONDS", "900"))
_BANK_FINGERPRINT = None
_PROMPT_CONTROL = re.compile(r"[\x00-\x1f\x7f]")


def _texto_para_prompt(texto, tope):
    """Texto del cliente listo para ir entre comillas en el prompt."""
    limpio = _PROMPT_CONTROL.sub(" ", str(texto or ""))
    limpio = limpio.replace("«", "\"").replace("»", "\"")
    return re.sub(r"\s+", " ", limpio).strip()[:tope]


def _bank_fingerprint(bank):
    """Huella del banco guiado: si cambia una pregunta o un recorrido, las
    rutas guardadas con el banco anterior dejan de encontrarse."""
    global _BANK_FINGERPRINT
    if _BANK_FINGERPRINT is None:
        material = json.dumps(bank, sort_keys=True, ensure_ascii=False)
        _BANK_FINGERPRINT = hashlib.sha256(material.encode("utf-8")).hexdigest()[:16]
    return _BANK_FINGERPRINT


def _sin_tildes(texto):
    for con, sin in (("Á", "A"), ("É", "E"), ("Í", "I"), ("Ó", "O"), ("Ú", "U"), ("Ü", "U")):
        texto = texto.replace(con, sin)
    return texto


def _turn_signature(turn):
    """Lo que el turno significa, normalizado: no el texto tal como se dijo.

    Dos frases con el mismo significado («¿Dónde fue?», «¿Dónde pasó?»)
    comparten ruta; la misma frase con otra negación o contexto, no."""
    def lista(valor, tope):
        return [_sin_tildes(str(v).upper().strip())
                for v in (valor or [])[:tope] if isinstance(v, str)]

    menciones = turn.get("mentionedContexts") or []
    return {
        "intent": str(turn.get("intent") or ""),
        "speechAct": str(turn.get("speechAct") or ""),
        "slots": sorted(set(lista(turn.get("requestedSlots"), 16))),
        "entities": sorted(set(lista(turn.get("entities"), MAX_CARDS))),
        "mentions": sorted({str(m.get("id")) for m in menciones[:16]
                            if isinstance(m, dict) and m.get("id")}),
        "negations": sorted(set(lista(turn.get("negations"), 8))),
    }


def route_cache_key(turn, candidates, active_context):
    """Clave de la caché de rutas: versión del router, huella del banco,
    modelo, significado normalizado del turno, contexto activo y candidatas."""
    material = {
        "router": ROUTER_PROMPT_VERSION,
        "bank": _bank_fingerprint(_guided_bank()),
        "model": BEDROCK_MODEL_ID,
        "turn": _turn_signature(turn),
        "active": active_context,
        "candidates": sorted(c["id"] for c in candidates),
    }
    digest = hashlib.sha256(
        json.dumps(material, sort_keys=True, ensure_ascii=False).encode("utf-8")
    ).hexdigest()
    return f"route-v{ROUTER_PROMPT_VERSION}-{digest}"


def _route_payload(ruta, confianza, razon, fuente):
    return {
        "generated": True,
        "routerVersion": ROUTER_PROMPT_VERSION,
        "routeSource": fuente,
        "candidateId": ruta["id"],
        "routeType": ruta["routeType"],
        "targetContextId": ruta["targetContextId"],
        "targetFamilyId": ruta["targetFamilyId"],
        "targetQuestionIds": ruta["targetQuestionIds"],
        "requestedSlots": ruta["requestedSlots"],
        "confidence": confianza,
        "reason": razon,
    }


def _no_route(razon="", cache_hit=False):
    return {"generated": False, "routerVersion": ROUTER_PROMPT_VERSION,
            "routeSource": "noSafeRoute", "reason": razon, "cacheHit": cache_hit}


def serve_cached_route(cached, candidates):
    """Una ruta guardada se vuelve a validar contra las candidatas actuales
    (ya comprobadas contra el banco). Si no encaja, es un fallo de caché."""
    if not isinstance(cached, dict) or cached.get("kind") != "route":
        return None
    if cached.get("routerVersion") != ROUTER_PROMPT_VERSION:
        return None
    if not cached.get("generated"):
        try:
            edad = time.time() - float(cached.get("cachedAt") or 0)
        except (TypeError, ValueError):
            return None
        if edad > ROUTE_NO_ROUTE_TTL_SECONDS:
            return None
        return _no_route(str(cached.get("reason") or ""), cache_hit=True)
    ruta = {c["id"]: c for c in candidates}.get(cached.get("candidateId"))
    try:
        confianza = float(cached.get("confidence", 0))
    except (TypeError, ValueError):
        return None
    if ruta is None or confianza < ROUTE_MIN_CONFIDENCE:
        return None
    return {**_route_payload(ruta, confianza, str(cached.get("reason") or ""), "cache"),
            "cacheHit": True}


def validate_route_candidate(raw, bank):
    """Una candidata solo con identificadores reales del banco."""
    if not isinstance(raw, dict):
        return None, "La candidata no es un objeto."
    questions = {q["id"]: q for q in bank["preguntas"]}
    recorridos = bank.get("recorridos", {})
    route_type = raw.get("routeType")
    if route_type not in ROUTE_TYPES:
        return None, "Tipo de ruta desconocido."
    cid = raw.get("id")
    if not isinstance(cid, str) or not cid or len(cid) > 256:
        return None, "La candidata no tiene id."
    context = raw.get("targetContextId")
    if context is not None and (not isinstance(context, str) or context not in recorridos):
        return None, f"Contexto desconocido: {str(context)[:40]}."
    family = raw.get("targetFamilyId")
    if family is not None and (not isinstance(family, str) or not _ROUTE_ID_RE.match(family)):
        return None, "Familia no válida."
    qids = raw.get("targetQuestionIds", [])
    if (not isinstance(qids, list) or len(qids) > MAX_ROUTE_QUESTIONS
            or not all(isinstance(q, str) and q in questions
                       and questions[q].get("control") != "derivacion" for q in qids)):
        return None, "La candidata cita una pregunta inexistente."
    slots = raw.get("requestedSlots", [])
    if not isinstance(slots, list) or not all(
            isinstance(s, str) and s in ROUTE_SLOTS for s in slots):
        return None, "La candidata cita una ranura inexistente."
    if route_type in ("DIRECT_QUESTION", "MINIMAL_GRAPH_PATH"):
        if context is None or not qids:
            return None, "Una ruta de preguntas necesita contexto y preguntas."
        if route_type == "DIRECT_QUESTION" and len(qids) != 1:
            return None, "DIRECT_QUESTION abre una sola pregunta."
    elif qids:
        return None, "Esta ruta no abre preguntas."
    if route_type == "DIRECT_CONTEXT" and context is None and family is None:
        return None, "DIRECT_CONTEXT sin contexto ni familia."
    if route_type in ("CONTEXT_SELECTOR", "NO_SAFE_ROUTE") and context is not None:
        return None, "Esta ruta no fija contexto."
    return {
        "id": cid,
        "routeType": route_type,
        "targetContextId": context,
        "targetFamilyId": family,
        "targetQuestionIds": list(qids),
        "requestedSlots": list(slots),
        "label": _texto_para_prompt(raw.get("label"), MAX_ROUTE_LABEL),
    }, None


def build_route_prompt(turn, candidates, active_context):
    """Prompt para elegir una ruta del grafo; nunca para traducir."""
    texto = _texto_para_prompt(turn.get("text"), MAX_HEARING_TEXT)
    glosas = [_texto_para_prompt(g, MAX_CARD_LENGTH)
              for g in (turn.get("entities") or [])[:MAX_CARDS] if isinstance(g, str)]
    acto = _texto_para_prompt(turn.get("speechAct"), 32)
    activo = _texto_para_prompt(active_context, MAX_CONTEXT_LENGTH) or "ninguno"
    rutas = "\n".join(f"- id: {c['id']} | {c['routeType']} | {c['label']}" for c in candidates)
    return f"""Eres el enrutador de conversación de una aplicación para personas sordas en instituciones públicas de Bolivia.

Una persona oyente acaba de decir: «{texto}»
Su traducción a LSB (ya hecha, no la repitas): {' '.join(glosas) or '(sin glosas)'}
Acto comunicativo: {acto or 'desconocido'}. Contexto activo de la conversación: {activo}.

La persona sorda va a RESPONDER eligiendo tarjetas LSB en UNA de estas rutas del grafo existente:
{rutas}

REGLAS:
1. Elige la ruta que permite responder exactamente a lo que preguntó el oyente.
2. Solo puedes devolver un id de la lista, copiado tal cual. No inventes rutas, preguntas ni contextos.
3. No respondas por la persona sorda ni propongas respuestas, opciones ni glosas.
4. Si ninguna ruta sirve con seguridad, devuelve "candidateId": null.

FORMATO (JSON estricto, sin texto alrededor):
{{"candidateId": "<id o null>", "confidence": 0.0, "reason": "motivo breve"}}"""


def route_conversation_turn(body):
    """Elige, con el modelo, una ruta real del grafo para responder al oyente."""
    turn = body.get("semanticTurn")
    if not isinstance(turn, dict) or not isinstance(turn.get("text"), str):
        return build_response(400, {
            "error": "VALIDATION_ERROR",
            "message": "semanticTurn con su texto es obligatorio.",
        })
    if len(turn["text"]) > MAX_HEARING_TEXT:
        return build_response(400, {
            "error": "VALIDATION_ERROR",
            "message": "El turno del oyente es demasiado largo.",
        })
    raw_candidates = body.get("candidates")
    if (not isinstance(raw_candidates, list) or not raw_candidates
            or len(raw_candidates) > MAX_ROUTE_CANDIDATES):
        return build_response(400, {
            "error": "VALIDATION_ERROR",
            "message": "candidates es obligatorio: el modelo solo elige dentro de él.",
        })
    bank = _guided_bank()
    candidates = []
    for raw in raw_candidates:
        clean, err = validate_route_candidate(raw, bank)
        if clean is None:
            return build_response(400, {"error": "VALIDATION_ERROR", "message": err})
        candidates.append(clean)
    active = body.get("activeContextId")
    if active is not None and active not in bank.get("recorridos", {}):
        active = None

    # 1. Caché: una ruta ya elegida para el mismo significado no vuelve a
    #    pasar por el modelo. Se revalida antes de servirla.
    cache_key = route_cache_key(turn, candidates, active)
    servida = serve_cached_route(read_cache_json(cache_key), candidates)
    if servida is not None:
        logger.info("Ruta de conversación desde caché (%s)", servida["routeSource"])
        return build_response(200, servida)

    # 2. Modelo: elige por id entre las candidatas validadas.
    try:
        crudo = invoke_bedrock_json(build_route_prompt(turn, candidates, active))
    except Exception as e:  # noqa: BLE001 — sin modelo queda la ruta determinista
        logger.warning("Ruteo de conversación no generado (%s)", e)
        return build_response(200, _no_route("model_error"))
    if not isinstance(crudo, dict):
        crudo = {}

    elegido = crudo.get("candidateId")
    por_id = {c["id"]: c for c in candidates}
    try:
        confianza = float(crudo.get("confidence", 0))
    except (TypeError, ValueError):
        confianza = 0.0
    confianza = max(0.0, min(1.0, confianza))
    razon = _texto_para_prompt(crudo.get("reason"), MAX_ROUTE_LABEL)

    if not isinstance(elegido, str) or elegido not in por_id:
        if elegido is not None:
            logger.info("Ruta descartada por no estar entre las candidatas: %.60r", elegido)
        motivo = "outside_candidates" if elegido is not None else "no_route"
    elif confianza < ROUTE_MIN_CONFIDENCE:
        motivo = "low_confidence"
    else:
        motivo = None

    # 3. Guardar lo decidido. "Sin ruta" caduca pronto (ver TTL).
    if motivo is not None:
        write_cache_json(cache_key, {"kind": "route", "routerVersion": ROUTER_PROMPT_VERSION,
                                     "generated": False, "reason": motivo,
                                     "cachedAt": time.time()})
        return build_response(200, _no_route(motivo))
    write_cache_json(cache_key, {"kind": "route", "routerVersion": ROUTER_PROMPT_VERSION,
                                 "generated": True, "candidateId": elegido,
                                 "confidence": confianza, "reason": razon,
                                 "cachedAt": time.time()})
    return build_response(200, {**_route_payload(por_id[elegido], confianza, razon, "bedrock"),
                                "cacheHit": False})


# ══════════════════════════════════════════════════════════════════════════════
# RAG POR SIGNIFICADO (action: "consulta" / "rag_indexar")
# ══════════════════════════════════════════════════════════════════════════════
#
# La app busca primero por palabras, sin red; solo si no encuentra nada
# pregunta aquí. Ver `rag_consulta.py`. Un fallo nunca es un error para la
# app: responde `generated: false` y ella sigue sin sugerencias.

_RAG_STATE = None


def _rag_state():
    """(entradas, clave S3 del índice), o None sin corpus empaquetado."""
    global _RAG_STATE
    if _RAG_STATE is None:
        corpus = RAG.cargar_corpus()
        if corpus is None:
            _RAG_STATE = ()
        else:
            lista = RAG.entradas(corpus)
            _RAG_STATE = (lista, RAG.clave_indice(RAG_EMBEDDING_MODEL, lista))
    return _RAG_STATE or None


def _titan_embed(texto: str, dimensiones: int | None = None) -> list:
    respuesta = bedrock_runtime.invoke_model(
        modelId=RAG_EMBEDDING_MODEL,
        contentType="application/json",
        accept="application/json",
        body=json.dumps({"inputText": texto[:MAX_HEARING_TEXT],
                         "dimensions": dimensiones or RAG_EMBEDDING_DIM,
                         "normalize": True}),
    )
    return json.loads(respuesta["body"].read())["embedding"]


def _rag_no(razon: str) -> dict:
    return build_response(200, {"generated": False, "reason": razon,
                                "suggestions": []})


def rag_consult(body):
    """Respuestas documentadas de las situaciones más parecidas en significado."""
    texto = body.get("text")
    if not isinstance(texto, str) or not texto.strip():
        return build_response(400, {"error": "VALIDATION_ERROR",
                                    "message": "text es obligatorio."})
    if len(texto) > MAX_HEARING_TEXT:
        return build_response(400, {"error": "VALIDATION_ERROR",
                                    "message": "El texto es demasiado largo."})
    area = body.get("preferArea")
    if area is not None and not (isinstance(area, str)
                                 and re.fullmatch(r"[A-Z]{2,10}", area)):
        area = None
    limite = body.get("limit", 4)
    if not isinstance(limite, int) or not 1 <= limite <= RAG.MAX_LIMIT:
        limite = 4
    # Umbral por petición, solo para calibrar (la app no lo envía): acotado
    # para que no sirva para vaciar el corpus.
    minimo = body.get("minSimilarity")
    if not (isinstance(minimo, (int, float)) and not isinstance(minimo, bool)
            and 0.3 <= minimo <= 0.9):
        minimo = RAG.MIN_SIMILARITY
    if not ENABLE_BEDROCK:
        return _rag_no("bedrock_desactivado")
    estado = _rag_state()
    if estado is None:
        return _rag_no("sin_corpus")
    lista, clave = estado
    indice = read_cache_json(clave)
    if not indice or len(indice.get("vectores") or {}) < len(lista):
        return _rag_no("sin_indice")
    mejor = {}
    try:
        sugerencias = RAG.consultar(texto, lista, indice, _titan_embed,
                                    prefer_area=area, limite=limite,
                                    minimo=minimo, diagnostico=mejor)
    except Exception as e:  # noqa: BLE001 — Bedrock o datos: nunca un 500
        logger.warning("Consulta RAG fallida: %s", e)
        return _rag_no("error_modelo")
    # La pregunta más parecida y su similitud, aunque no supere el umbral:
    # permite calibrarlo y vigilarlo en los registros.
    logger.info("RAG consulta: mejor %.3f %s (umbral %.2f, %d sugerencias)",
                mejor.get("score", 0), mejor.get("scenarioId", "-"), minimo,
                len(sugerencias))
    return build_response(200, {"generated": True, "suggestions": sugerencias,
                                "best": mejor, "minSimilarity": minimo,
                                "index": clave})


def rag_index_batch():
    """Calcula la siguiente tanda de vectores del corpus empaquetado."""
    if not ENABLE_BEDROCK:
        return _rag_no("bedrock_desactivado")
    estado = _rag_state()
    if estado is None:
        return _rag_no("sin_corpus")
    lista, clave = estado
    indice = read_cache_json(clave) or {}
    try:
        indice = RAG.indexar(lista, indice, _titan_embed)
    except Exception as e:  # noqa: BLE001
        logger.warning("Indexación RAG fallida: %s", e)
        return build_response(502, {"error": "BEDROCK_ERROR",
                                    "message": "No se pudo calcular la tanda."})
    write_cache_json(clave, indice)
    hechas = len(indice["vectores"])
    return build_response(200, {"indexed": hechas, "total": len(lista),
                                "pending": len(lista) - hechas, "index": clave})


# ══════════════════════════════════════════════════════════════════════════════
# EQUIVALENCIAS CON SEÑAS DEL CATÁLOGO (action: "equivalencias")
# ══════════════════════════════════════════════════════════════════════════════
#
# Para el vocabulario del corpus RAG: Bedrock propone una seña oficial
# equivalente para cada palabra sin seña, o ninguna. Ver `rag_equivalencias.py`.
# Solo lo usa `tool/rag_buscar_equivalencias.py`; la app no lo llama.

_CATALOGO_LSB = None
_LEXICO_LSB = None


def rag_equivalences(body):
    global _LEXICO_LSB
    palabras, error = EQUIV.validar_pedido(body)
    if error:
        return build_response(400, {"error": "VALIDATION_ERROR", "message": error})
    if not ENABLE_BEDROCK:
        return build_response(200, {"generated": False,
                                    "reason": "bedrock_desactivado"})
    if _LEXICO_LSB is None:
        # M1–M4, los diccionarios y el catálogo (lexico_lsb.json); sin él,
        # solo el catálogo.
        _LEXICO_LSB = EQUIV.cargar_lexico()
    if not _LEXICO_LSB:
        return build_response(200, {"generated": False, "reason": "sin_catalogo"})

    def invocar(texto: str) -> str:
        respuesta = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL_ID, contentType="application/json",
            accept="application/json",
            body=json.dumps(_build_bedrock_request_body(
                texto, max_tokens=EQUIV.MAX_TOKENS)))
        return EQUIV.texto_de_respuesta(json.loads(respuesta["body"].read()))

    try:
        propuestas = EQUIV.proponer(palabras, _LEXICO_LSB, invocar)
    except Exception as e:  # noqa: BLE001 — Bedrock: nunca un 500
        logger.warning("Equivalencias fallidas: %s", e)
        return build_response(200, {"generated": False, "reason": "error_modelo"})
    return build_response(200, {"generated": True, "model": BEDROCK_MODEL_ID,
                                "propuestas": propuestas})


# ══════════════════════════════════════════════════════════════════════════════
# CONTROL DE GLOSAS DEL CORPUS (action: "retrotraducir")
# ══════════════════════════════════════════════════════════════════════════════
#
# Bedrock traduce las glosas de vuelta al español y Titan compara su
# significado con la frase original. Ver `rag_revision.py`. Solo lo usa
# `tool/rag_revisar_glosas.py`; la app no lo llama.

def rag_back_translate(body):
    items, error = REVISION.validar_pedido(body)
    if error:
        return build_response(400, {"error": "VALIDATION_ERROR", "message": error})
    if not ENABLE_BEDROCK:
        return build_response(200, {"generated": False,
                                    "reason": "bedrock_desactivado"})

    def invocar(texto: str) -> str:
        respuesta = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL_ID, contentType="application/json",
            accept="application/json",
            body=json.dumps(_build_bedrock_request_body(
                texto, max_tokens=REVISION.MAX_TOKENS)))
        return EQUIV.texto_de_respuesta(json.loads(respuesta["body"].read()))

    try:
        revisadas = REVISION.revisar(items, invocar, _titan_embed)
    except Exception as e:  # noqa: BLE001 — Bedrock: nunca un 500
        logger.warning("Retrotraducción fallida: %s", e)
        return build_response(200, {"generated": False, "reason": "error_modelo"})
    return build_response(200, {"generated": True, "model": BEDROCK_MODEL_ID,
                                "embeddings": RAG_EMBEDDING_MODEL,
                                "items": revisadas})


def rag_correct_glosses(body):
    global _CATALOGO_LSB
    items, error = REVISION.validar_pedido_correccion(body)
    if error:
        return build_response(400, {"error": "VALIDATION_ERROR", "message": error})
    if not ENABLE_BEDROCK:
        return build_response(200, {"generated": False,
                                    "reason": "bedrock_desactivado"})
    if _CATALOGO_LSB is None:
        _CATALOGO_LSB = EQUIV.cargar_catalogo()
    if not _CATALOGO_LSB:
        return build_response(200, {"generated": False, "reason": "sin_catalogo"})

    def invocar(texto: str) -> str:
        respuesta = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL_ID, contentType="application/json",
            accept="application/json",
            body=json.dumps(_build_bedrock_request_body(
                texto, max_tokens=REVISION.MAX_TOKENS)))
        return EQUIV.texto_de_respuesta(json.loads(respuesta["body"].read()))

    try:
        corregidas = REVISION.corregir(items, _CATALOGO_LSB, invocar)
    except Exception as e:  # noqa: BLE001 — Bedrock: nunca un 500
        logger.warning("Corrección de glosas fallida: %s", e)
        return build_response(200, {"generated": False, "reason": "error_modelo"})
    return build_response(200, {"generated": True, "model": BEDROCK_MODEL_ID,
                                "items": corregidas})


# ══════════════════════════════════════════════════════════════════════════════
# ZONA DE CADA PALABRA SIN SEÑA (action: "zonas")
# ══════════════════════════════════════════════════════════════════════════════
#
# Titan y Bedrock eligen por separado la zona de tarjetas de cada palabra;
# si coinciden, entra a esa zona. Ver `rag_zonas.py`.

_ZONAS_LSB = None
_VECTORES_DEFINICION = {}


def _embed_zonas(texto: str) -> list:
    return _titan_embed(texto, ZONAS.DIMENSIONES)


def rag_zones(body):
    global _ZONAS_LSB
    palabras, error = ZONAS.validar_pedido(body)
    if error:
        return build_response(400, {"error": "VALIDATION_ERROR", "message": error})
    if not ENABLE_BEDROCK:
        return build_response(200, {"generated": False,
                                    "reason": "bedrock_desactivado"})
    if _ZONAS_LSB is None:
        _ZONAS_LSB = ZONAS.zonas_con_senas(ZONAS.cargar_zonas(),
                                           EQUIV.cargar_formas())
    if not _ZONAS_LSB:
        return build_response(200, {"generated": False, "reason": "sin_zonas"})

    def invocar(texto: str) -> str:
        respuesta = bedrock_runtime.invoke_model(
            modelId=BEDROCK_MODEL_ID, contentType="application/json",
            accept="application/json",
            body=json.dumps(_build_bedrock_request_body(
                texto, max_tokens=ZONAS.MAX_TOKENS)))
        return EQUIV.texto_de_respuesta(json.loads(respuesta["body"].read()))

    try:
        clasificadas = ZONAS.clasificar(palabras, _ZONAS_LSB, _embed_zonas,
                                        invocar, _VECTORES_DEFINICION)
    except Exception as e:  # noqa: BLE001 — Bedrock: nunca un 500
        logger.warning("Zonas fallidas: %s", e)
        return build_response(200, {"generated": False, "reason": "error_modelo"})
    return build_response(200, {"generated": True, "model": BEDROCK_MODEL_ID,
                                "embeddings": RAG_EMBEDDING_MODEL,
                                "palabras": clasificadas})


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
    if (body.get("action") or "").strip().lower() == "route":
        return route_conversation_turn(body)
    if (body.get("action") or "").strip().lower() == "consulta":
        return rag_consult(body)
    if (body.get("action") or "").strip().lower() == "rag_indexar":
        return rag_index_batch()
    if (body.get("action") or "").strip().lower() == "equivalencias":
        return rag_equivalences(body)
    if (body.get("action") or "").strip().lower() == "retrotraducir":
        return rag_back_translate(body)
    if (body.get("action") or "").strip().lower() == "corregir":
        return rag_correct_glosses(body)
    if (body.get("action") or "").strip().lower() == "zonas":
        return rag_zones(body)

    is_valid, err = validate_request(body)
    if not is_valid:
        return build_response(400, {"error": "VALIDATION_ERROR", "message": err})

    is_valid, err = validate_business_signals(body)
    if not is_valid:
        return build_response(400, {"error": "VALIDATION_ERROR", "message": err})

    is_valid, err = validate_guided(body)
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
    raw_guided = body.get("guided")
    guided = raw_guided if isinstance(raw_guided, dict) else None
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

    # Guided ya llega resuelto por el grafo. Su representación primaria no es
    # ninguna plantilla española: es este frame tipado, construido antes de
    # la caché para que hechos, roles, negaciones y literales formen parte de
    # la identidad de la salida.
    guided_composer = GuidedComposer(_guided_bank()) if guided else None
    semantic_frame = (
        guided_composer.semantic_frame(
            guided, context=context_type,
            institution_context=institution_type, speech_act=speech_act)
        if guided_composer else None
    )

    cache_key = generate_cache_key(
        context_type, cards, institution_type, language, speech_act,
        declaration, contract_version, guided, semantic_frame)
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
        logger.info(
            "Cache HIT — cache_key: %s | generation_source=cache | "
            "semantic_mismatch=%s", cache_key,
            bool(cached.get("semanticMismatch")))
        return build_response(200, cached)
    logger.info("Cache MISS — procesando pipeline completo: %s", cache_key)

    guided_covered = False
    if guided:
        # El compositor español queda como fallback verificable. Bedrock no
        # recibe esta frase: recibe exclusivamente semantic_frame.
        base_sentence, representadas = guided_composer.compose_traced(guided)
        guided_covered = (
            guided_composer.confirmed_facts(guided) <= representadas)
        intermediate = semantic_frame
    elif uses_structured:
        analysis = analyze_glosses(cards)
        _resolve_gender(analysis)
        _resolve_time(analysis, context_type, cards)
        intermediate = build_intermediate_representation(
            cards, analysis, context_type)
        # El cliente ya mandó las relaciones explícitas (persona↔prenda↔color,
        # objeto↔papel, lugar↔referencia): redactarlas no requiere volver a
        # adivinarlas desde una lista plana de glosas.
        base_sentence = generate_structured_sentence(declaration)
    else:
        # Free/legacy conserva su analizador local. Guided no pasa por aquí:
        # el grafo ya resolvió esos hechos y volver a inferirlos sería perder
        # precisión y gastar trabajo de forma redundante.
        analysis = analyze_glosses(cards)
        _resolve_gender(analysis)
        _resolve_time(analysis, context_type, cards)
        intermediate = build_intermediate_representation(
            cards, analysis, context_type)
        base_sentence = generate_base_sentence(intermediate, analysis, context_type, institution_type)
    logger.info("Oración base generada (%d caracteres, estructurada=%s)",
                len(base_sentence), uses_structured)

    # CAMBIO: el modelo REDACTA a partir de las glosas y de los hechos
    # verificados, en vez de pulir una frase ya hecha. La fluidez la pone el
    # modelo; la fidelidad, el ensamblador determinista, que sigue siendo
    # quien garantiza que ninguna seña se pierda.
    # Los hechos normalizados viajan al validador: sin ellos solo se puede
    # comprobar que estén las mismas palabras, y eso no distingue "me robaron
    # y yo escapé" de "me robaron y el ladrón escapó".
    hechos = normalize_facts(declaration) if declaration else []
    if guided:
        if guided_covered:
            generated_text, bedrock_used, semantic_mismatch = (
                generate_spanish_from_semantic_frame(
                    semantic_frame, base_sentence))
        else:
            generated_text = base_sentence
            bedrock_used = False
            semantic_mismatch = True
        generation_validated = guided_covered
        generation_source = (
            "bedrock" if bedrock_used else "deterministic_fallback")
    else:
        generated_text, generation_validated = generate_with_bedrock(
            cards, analysis, base_sentence, context_type, institution_type,
            facts=hechos)
        bedrock_used = generated_text != base_sentence
        semantic_mismatch = False
        generation_source = (
            "bedrock" if bedrock_used else "deterministic_fallback")

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
        "Completado — base: %d caracteres | final: %d caracteres | "
        "generation_source=%s | semantic_mismatch=%s",
        len(base_sentence), len(generated_text), generation_source,
        semantic_mismatch,
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
        # El cliente lo lee para saber si puede enviar una colección de
        # hechos o si debe avisar de que se perderían.
        "contractVersion": BACKEND_CONTRACT_VERSION,
        "generatorVersion": GENERATOR_VERSION,
        "baseSentence": base_sentence,
        "generatedText": generated_text,
        "intermediateRepresentation": intermediate,
        "glossSequence": gloss_sequence,
        "audioUrl": audio_url,
        "cacheHit": False,
        "bedrockUsed": bedrock_used,
        "generationSource": generation_source,
        "semanticMismatch": semantic_mismatch,
        # El servidor ya comprobó, con las mismas reglas que el cliente, que
        # el texto generado representa TODAS las glosas. El cliente lo usa
        # para no volver a exigir una coincidencia literal que una redacción
        # libre —"me sustrajo el celular" por ROBAR + TELEFONO— nunca cumple.
        # Es una promesa de nuestro propio código sobre la salida del modelo,
        # no una promesa del modelo.
        "coverageValidated": generation_validated,
    }

    # El frame se devuelve para auditoría del contrato y pruebas de cobertura;
    # nunca se escribe en logs. La asignación separada evita incluir una clave
    # nula en el camino libre/legacy.
    if semantic_frame is not None:
        response_payload["semanticFrame"] = semantic_frame

    put_cached_response(cache_key, response_payload, _audio_s3_key(cache_key))

    return build_response(200, response_payload)
