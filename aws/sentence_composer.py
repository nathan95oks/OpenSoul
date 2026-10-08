"""Composición de la oración base a partir de las glosas.

Clasifica cada glosa por su rol (GLOSS_LEXICON) y redacta la oración en
español formal, sin Bedrock: la versión plana (`generate_base_sentence`)
y la estructurada desde el borrador de la declaración
(`generate_structured_sentence`). Es la contraparte del ensamblador del
cliente (lib/core/domain/services/local_sentence_assembler*.dart). La
usa lambda_function.py, que la reexporta con los mismos nombres.
"""

from gloss_lexicon import GLOSS_LEXICON
import re
import logging

logger = logging.getLogger("lsb-to-text-audio")


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


_FORMAL_INSTITUTIONS = {"entidad_publica", "formal", "legal", "ciudadano", "judicial"}


_FORMAL_CONTEXTS = {
    "ciudadano", "formal", "legal",
    "denuncia_robo", "violencia", "accidente", "emergencia",
    "otro", "orientacion", "tramite_id", "perdida",
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


def _cap(s: str) -> str:
    if not s:
        return ""
    return s[0].upper() + s[1:]


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
        # «Hace 15 días» también es un dato de tiempo: antes se descartaba y
        # solo sobrevivía una glosa de momento.
        unidad = str(time_val.get("elapsedUnit") or time_val.get("elapsed_unit") or "").upper()
        cantidad = str(time_val.get("elapsedCount") or time_val.get("elapsed_count") or "").strip()
        plural = {"MINUTO": "minutos", "HORA": "horas", "DÍA": "días", "DIA": "días",
                  "SEMANA": "semanas", "MES": "meses"}.get(unidad)
        if plural and cantidad and not time_text:
            time_text = f"hace {cantidad} {plural}"

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
        # «Física» solo si lo que se declaró lo es: una amenaza o un grito no
        # se convierten en agresión física.
        fisicas = {"PEGAR", "GOLPEAR", "MALTRATAR", "ABUSAR", "VIOLENCIA", "PELEAR"}
        acciones_v = {f["action"] for f in facts if not f["negated"]} | ({action} if action else set())
        tipo_v = violence.get("aggressionType") or violence.get("tipo_agresion")
        if acciones_v & fisicas or violence.get("physicalInjury") or tipo_hecho == "violencia_fisica":
            sentences.append("Denuncio agresión física y violencia sufrida.")
        elif tipo_v:
            sentences.append(f"Denuncio haber sufrido: {str(tipo_v).lower().replace('_', ' ')}.")
        else:
            sentences.append("Denuncio una situación de violencia.")
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
        # Guardar los mensajes y tener capturas son dos hechos distintos: uno
        # no implica el otro.
        if threat.get("has_saved_evidence") or threat.get("hasSavedEvidence") or threat.get("mensajes_guardados"):
            sentences.append("Guardé los mensajes.")
        if threat.get("capturas_pantalla"):
            sentences.append("Tengo capturas de pantalla de los mensajes.")

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
        # El tipo de comprobante no se supone: «bancario» solo si se dijo.
        recibo = fraud.get("receipt_doc") or fraud.get("receiptDoc")
        if recibo:
            sentences.append(f"Cuento con este comprobante: {recibo}.")
        elif fraud.get("tiene_comprobante"):
            sentences.append("Cuento con un comprobante de la transacción.")

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
            sentences.append(f"Teléfono de contacto: {id_con}.")
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
            # Sin pregunta declarada no se inventa una («¿Dónde…?»).
            sentences.append("Quiero hacer una consulta.")

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
                    # Sin objetos declarados no se supone qué se llevaron.
                    sentences.append("Denuncio un robo.")
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
                # Se nombra cada elemento: antes quedaba «Cuento con…:» sin
                # decir con qué.
                nombres = []
                for e in evid:
                    if isinstance(e, dict):
                        if (e.get("availability") or "confirmed") == "negated":
                            continue
                        concepto = str(e.get("concept") or e.get("concepto") or "")
                    else:
                        concepto = str(e)
                    if not concepto:
                        continue
                    entry = lexicon_lookup(concepto)
                    nombres.append(entry["es"] if entry else concepto.lower().replace("_", " "))
                if nombres:
                    sentences.append(f"Cuento con elementos de prueba o respaldo: {_join(nombres)}.")

        # Lo que el cliente ya mandaba y esta ruta descartaba: herida,
        # atención médica, voluntad de denunciar, apoyo y autoridad elegida.
        if d.get("injured"):
            sentences.append("Estoy herido y necesito atención médica."
                             if d.get("medicalHelpRequested") else "Estoy herido.")
        elif d.get("medicalHelpRequested"):
            sentences.append("Necesito atención médica.")
        voluntad = d.get("willFileComplaint")
        if voluntad == "confirmed":
            sentences.append("Quiero presentar una denuncia formal.")
        elif voluntad == "negated":
            sentences.append("Por ahora no quiero presentar una denuncia formal.")
        elif voluntad == "uncertain":
            sentences.append("Todavía no sé si quiero presentar una denuncia formal.")
        if d.get("needsLegalSupport"):
            sentences.append("Necesito apoyo legal.")
        destino = d.get("receivingInstitution")
        if isinstance(destino, str) and destino.strip():
            entry = lexicon_lookup(destino)
            nombre = entry["es"] if entry else destino.strip().lower()
            if nombre.startswith("en "):
                nombre = nombre[3:]
            sentences.append(f"Deseo presentar esto ante {nombre}.")

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
