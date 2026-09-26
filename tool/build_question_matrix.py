"""Banco semántico de preguntas: validación contra el repositorio y generación.

    python tool/build_question_matrix.py            # valida y escribe
    python tool/build_question_matrix.py --check    # valida y comprueba que
                                                    # lo generado está al día

Fuentes editables (escritas a mano):

    docs/negocio/config/banco_preguntas.json   preguntas, opciones, recorridos
    docs/negocio/config/acepciones.json        clase semántica por acepción

Se contrastan con (solo lectura):

    assets/dictionary/official_dictionary.json     catálogo de tarjetas
    assets/dialogue/dialogue_graph.json            209 nodos (generado antes)
    lib/core/domain/services/context_catalog.dart  contextos de la app
    lib/core/domain/services/animation_url_resolver.dart

Genera (no editar a mano):

    lib/core/domain/guided/question_bank_data.g.dart  banco que usa la app
    aws/question_bank.json                             banco que usa la Lambda
    docs/negocio/matriz_preguntas.json · .csv          matriz procesable
    docs/negocio/matriz_nodos_grafo.csv                nodos con su pregunta
    docs/negocio/matriz_modos.csv                      personal / ventanilla
    docs/negocio/11_Matriz_Preguntas.md                resumen revisable
    docs/negocio/12_Brechas_Lexicas_Animacion.md
    docs/negocio/13_Auditoria_Gramatica_LSB.md · matriz_gramatica_lsb.csv

Devuelve 1 y no escribe nada si el banco contradice al repositorio: glosa de
respuesta inexistente o sin acepción para el campo que se pregunta, pregunta de
sí/no respondida con otra cosa, plantilla con un hueco que ninguna respuesta
llena, recorrido con una condición imposible, nodo del funcionario sin
pregunta, o pregunta inalcanzable.
"""

from __future__ import annotations

import csv
import io
import json
import os
import re
import sys
import unicodedata
from collections import Counter, OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "aws"))

import guided_composer as GC  # noqa: E402
import corpus_dialogue as CD  # noqa: E402

NEG = os.path.join(ROOT, "docs", "negocio")
P_BANCO = os.path.join(NEG, "config", "banco_preguntas.json")
P_ACEP = os.path.join(NEG, "config", "acepciones.json")
P_CATALOGO = os.path.join(ROOT, "assets", "dictionary", "official_dictionary.json")
P_GRAFO = os.path.join(ROOT, "assets", "dialogue", "dialogue_graph.json")
P_CONTEXTOS = os.path.join(ROOT, "lib", "core", "domain", "services", "context_catalog.dart")
P_RESOLVER = os.path.join(ROOT, "lib", "core", "domain", "services", "animation_url_resolver.dart")

OUT_DART = os.path.join(ROOT, "lib", "core", "domain", "guided", "question_bank_data.g.dart")
OUT_AWS = os.path.join(ROOT, "aws", "question_bank.json")
OUT_JSON = os.path.join(NEG, "matriz_preguntas.json")
OUT_CSV = os.path.join(NEG, "matriz_preguntas.csv")
OUT_NODOS = os.path.join(NEG, "matriz_nodos_grafo.csv")
OUT_MODOS = os.path.join(NEG, "matriz_modos.csv")
OUT_MD = os.path.join(NEG, "11_Matriz_Preguntas.md")
OUT_BRECHAS = os.path.join(NEG, "12_Brechas_Lexicas_Animacion.md")
OUT_GRAMATICA_MD = os.path.join(NEG, "13_Auditoria_Gramatica_LSB.md")
OUT_GRAMATICA_CSV = os.path.join(NEG, "matriz_gramatica_lsb.csv")

CONTROLES = {"polar2", "polar3", "alternativa", "seleccion_unica", "seleccion_multiple",
             "persona_identidad", "texto_nombre", "telefono", "entero", "monto", "tiempo", "hora",
             "lugar", "documento_numero", "texto_detalle", "intervencion", "derivacion"}
ESTADOS = {"afirmado", "negado", "desconocido"}
EDITORES = set(GC.EDITOR_KEYS)
CLAVES_PLANTILLA = {"nombre", "apellido", "telefono", "n", "monto", "moneda", "texto", "hora",
                    "numero", "referencia", "mencionado", "aprox", "frag"}
POLARES = {"SÍ", "NO", "NO_SABER"}

# Campos de la opción y de la pregunta que viajan al banco de ejecución.
CAMPOS_OPCION = ("id", "etiqueta", "glosas", "estado", "salida", "polar", "editor", "editorOpcional",
                 "frase", "fraseSinValor", "fraseSingular", "fraseExtra", "rango", "grupo", "cuando",
                 "literal", "glosasPropias", "sinSena", "sinAproximado", "autor", "accion", "actor",
                 "tipoPerdida", "certeza", "soloControl")
CAMPOS_PREGUNTA = ("id", "dominio", "formulacion", "acto", "entidad", "campo", "control", "modo",
                   "campos", "maximo", "plantilla", "unir", "fraseSuelta", "requiereMencion",
                   "pasosRespuesta", "variantes", "nodos", "reglas")


def leer(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def cargar():
    banco = json.loads(leer(P_BANCO))
    acep = json.loads(leer(P_ACEP))
    catalogo = {e["gloss"]: e for e in json.loads(leer(P_CATALOGO))["entries"]}
    grafo = json.loads(leer(P_GRAFO))
    contextos = re.findall(r"SemanticContext\(\s*id:\s*'(\w+)'", leer(P_CONTEXTOS))
    resolver = leer(P_RESOLVER).split("available3DGlosses = {")[1].split("};")[0]
    horneadas = set(re.findall(r"'([^']+)'", resolver))
    return banco, acep, catalogo, grafo, contextos, horneadas


def tokens(plantilla):
    return re.findall(r"\{([^{}]+)\}", plantilla or "")


# --------------------------------------------------------------------------
# Validación
# --------------------------------------------------------------------------

def validar(banco, acep, catalogo, grafo, contextos):
    errores, avisos = [], []
    Q = {}
    for q in banco["preguntas"]:
        if q["id"] in Q:
            errores.append(f"pregunta duplicada: {q['id']}")
        Q[q["id"]] = q
    glosas_acep = acep["glosas"]
    campos_validos = set(acep["campos"])

    def acepciones(g):
        return {a["campo"] for a in glosas_acep.get(g, [])}

    def ref_ok(qid_ref, origen):
        partes = qid_ref.split(".")
        for n in range(len(partes), 1, -1):
            qid = ".".join(partes[:n])
            if qid in Q:
                attr = ".".join(partes[n:])
                if attr and not any(attr in o for o in Q[qid]["opciones"]):
                    errores.append(f"{origen}: atributo '{attr}' inexistente en {qid}")
                return qid
        errores.append(f"{origen}: referencia a pregunta inexistente {qid_ref}")
        return None

    referenciadas = set()
    for q in banco["preguntas"]:
        qid = q["id"]
        if q.get("control") not in CONTROLES:
            errores.append(f"{qid}: control desconocido {q.get('control')}")
        for c in q.get("campos", []):
            if c not in campos_validos:
                errores.append(f"{qid}: campo desconocido {c}")
        if not q.get("campos") and q.get("opciones"):
            errores.append(f"{qid}: sin campos declarados")
        if not q.get("opciones") and not q.get("pasosRespuesta"):
            errores.append(f"{qid}: sin opciones ni pasos de respuesta")
        ids = [o["id"] for o in q.get("opciones", [])]
        for i, c in Counter(ids).items():
            if c > 1:
                errores.append(f"{qid}: opción duplicada {i}")
        polar = q["control"] in ("polar2", "polar3")
        for o in q.get("opciones", []):
            donde = f"{qid}/{o['id']}"
            if o.get("estado", "afirmado") not in ESTADOS:
                errores.append(f"{donde}: estado inválido {o.get('estado')}")
            if o.get("editor") and o["editor"] not in EDITORES:
                errores.append(f"{donde}: editor desconocido {o['editor']}")
            if o.get("literal") and o.get("glosas"):
                errores.append(f"{donde}: una opción literal no lleva glosas")
            for g in o.get("glosas", []):
                if g not in catalogo:
                    errores.append(f"{donde}: glosa {g} no está en el catálogo")
                if g not in glosas_acep:
                    errores.append(f"{donde}: glosa {g} sin acepción declarada")
            if o.get("glosas"):
                nucleo = o["glosas"][0]
                admitidos = set(q.get("campos", []))
                if o.get("salida") or o.get("polar"):
                    admitidos |= {"polaridad"}
                if o.get("glosasPropias"):
                    admitidos |= {"interrogativa"}
                if not (acepciones(nucleo) & admitidos):
                    errores.append(
                        f"{donde}: {nucleo} ({', '.join(sorted(acepciones(nucleo))) or 'sin acepción'}) "
                        f"no responde el campo {sorted(q.get('campos', []))}")
                if polar and not o.get("salida") and nucleo not in POLARES:
                    errores.append(f"{donde}: pregunta de sí/no respondida con {nucleo}")
            for campo_frase in ("frase", "fraseSinValor", "fraseSingular", "fraseExtra"):
                texto = o.get(campo_frase)
                if texto is None:
                    continue
                for t in tokens(texto):
                    if t.startswith(("Q.", "I.")):
                        ref = ref_ok(t.split("|")[0], f"{donde}.{campo_frase}")
                        if ref:
                            referenciadas.add(ref)
                        continue
                    clave = t.lstrip("?")
                    if clave not in CLAVES_PLANTILLA:
                        errores.append(f"{donde}.{campo_frase}: hueco desconocido {{{t}}}")
                        continue
                    if clave == "mencionado":
                        if not q.get("requiereMencion"):
                            errores.append(f"{donde}: usa {{mencionado}} sin requiereMencion")
                        continue
                    if clave == "aprox":
                        if o.get("editor") != "edad":
                            errores.append(f"{donde}: {{aprox}} solo con el editor de edad")
                        continue
                    if campo_frase == "fraseSinValor":
                        errores.append(f"{donde}.fraseSinValor no puede usar {{{t}}}")
                    elif clave not in GC.EDITOR_KEYS.get(o.get("editor") or "", ()):
                        errores.append(f"{donde}.{campo_frase}: {{{t}}} sin editor que lo llene")
            if o.get("editorOpcional") and o.get("fraseSinValor") is None:
                errores.append(f"{donde}: editor opcional sin fraseSinValor")
            for cond in o.get("cuando", []):
                validar_condicion(cond, Q, f"{donde}.cuando", errores)
        for t in tokens(q.get("plantilla")):
            if t != "items":
                errores.append(f"{qid}.plantilla: hueco desconocido {{{t}}}")
        for p in q.get("pasosRespuesta", []):
            if p["pregunta"] not in Q:
                errores.append(f"{qid}.pasosRespuesta: {p['pregunta']} inexistente")
            for cond in p.get("cuando", []):
                validar_condicion(cond, Q, f"{qid}.pasosRespuesta", errores)
        for g in (q.get("noOfrecer") or {}):
            # Una glosa que formula la pregunta también se muestra en LSB:
            # tiene que existir en el corpus v4 igual que una respuesta.
            if g not in catalogo:
                errores.append(f"{qid}: noOfrecer cita {g}, que no está en el catálogo (corpus v4)")
            if any(g in o.get("glosas", [])[:1] for o in q.get("opciones", []) if not o.get("salida")):
                errores.append(f"{qid}: {g} está en noOfrecer y a la vez es respuesta")

    for qid, q in Q.items():
        if q.get("modo") == "fragmento" and qid not in referenciadas:
            errores.append(f"{qid}: fragmento que ninguna plantilla usa")
        # Sin frase suelta, la respuesta a un fragmento que nadie cita (el
        # oyente pregunta directamente «¿Qué le robaron?») se perdería.
        if q.get("modo") == "fragmento" and "{frag}" not in (q.get("fraseSuelta") or ""):
            errores.append(f"{qid}: fragmento sin fraseSuelta con {{frag}}")

    # Recorridos
    recorridos = banco["recorridos"]
    for c in contextos:
        if c not in recorridos:
            errores.append(f"el contexto {c} de context_catalog.dart no tiene recorrido")
    for cid, r in recorridos.items():
        if cid not in contextos:
            errores.append(f"recorrido {cid} sin contexto en context_catalog.dart")
        vistos = set()
        for paso in r["pasos"]:
            p = paso["pregunta"]
            if p not in Q:
                errores.append(f"{cid}: pregunta inexistente {p}")
                continue
            for cond in paso.get("cuando", []):
                if cond.get("pregunta") and cond["pregunta"] not in vistos:
                    errores.append(f"{cid}/{p}: la condición mira {cond['pregunta']}, que no va antes")
                validar_condicion(cond, Q, f"{cid}/{p}", errores)
            for oid in paso.get("ocultar", []):
                if oid not in {o["id"] for o in Q[p]["opciones"]}:
                    errores.append(f"{cid}/{p}: ocultar {oid} inexistente")
            vistos.add(p)
        orden = r.get("ordenRedaccion")
        if orden:
            faltan = vistos - set(orden)
            if faltan:
                errores.append(f"{cid}: ordenRedaccion no incluye {sorted(faltan)}")
        if not r["pasos"][0].get("obligatoria") and cid != "identificacion":
            avisos.append(f"{cid}: la primera pregunta no es obligatoria")
        # Una opción que no redacta nada solo es válida si abre, en este
        # recorrido, una pregunta obligatoria que sí lo hace (PERDER →
        # «¿Lo perdió o se lo quitaron?»), o si el banco la declara de control.
        for paso in r["pasos"]:
            p = paso["pregunta"]
            for o in Q.get(p, {}).get("opciones", []):
                if GC._writes_something(o) or o.get("soloControl"):
                    continue
                abre = any(
                    otro.get("obligatoria") and any(
                        c.get("pregunta") == p and o["id"] in c.get("opciones", [])
                        for c in otro.get("cuando", []))
                    for otro in r["pasos"])
                if not abre:
                    errores.append(
                        f"{cid}/{p}/{o['id']}: no redacta nada ni abre una pregunta obligatoria")

    # Nodos del funcionario
    nodos = {n["id"]: n for n in grafo["nodes"]}
    asignados = {}
    for q in banco["preguntas"]:
        for n in q.get("nodos", []):
            if n not in nodos:
                errores.append(f"{q['id']}: nodo inexistente {n}")
            asignados[n] = q["id"]
    for nid, n in nodos.items():
        if n["provenance"]["section"] != 6:
            continue
        if nid not in asignados:
            errores.append(f"nodo del funcionario sin pregunta del banco: {nid}")
        if n.get("bankQuestion") != asignados.get(nid):
            errores.append(f"{nid}: el grafo está desactualizado (ejecuta build_dialogue_graph.py)")
        for o in n["options"]:
            if not o.get("answerId"):
                errores.append(f"{nid}: la opción {o['gloss']} no sale del banco")

    # Alcanzabilidad
    alcanzables = set(asignados.values())
    for r in recorridos.values():
        alcanzables |= {p["pregunta"] for p in r["pasos"]}
    for q in banco["preguntas"]:
        alcanzables |= {p["pregunta"] for p in q.get("pasosRespuesta", [])}
    alcanzables |= referenciadas
    for qid in Q:
        if qid not in alcanzables:
            errores.append(f"{qid}: pregunta inalcanzable (ni recorrido, ni nodo, ni referencia)")

    validar_gramatica(banco, grafo, errores)

    # Autoprueba de redacción: cada opción, con valores de ejemplo, en los dos propósitos
    comp = GC.Composer(banco_ejecucion(banco, acep))
    ejemplo = {"nombre": "María Quispe", "apellido": "Quispe", "telefono": "71234567", "n": "3",
               "monto": "150", "moneda": "Bs", "texto": "un recibo", "hora": "18:30",
               "numero": "4567890 CB", "referencia": "el mercado"}
    for q in banco["preguntas"]:
        for o in q.get("opciones", []):
            for proposito in ("standalone", "reply"):
                valores = {o["id"]: {k: ejemplo[k] for k in GC.EDITOR_KEYS.get(o.get("editor") or "", ())}}
                respuesta = {"pregunta": q["id"], "estado": o.get("estado", "afirmado"),
                             "opciones": [o["id"]], "valores": valores,
                             "mencion": {"frase": "el celular"}}
                texto, representadas = comp.compose_traced(
                    {"proposito": proposito, "pasos": [q["id"]], "respuestas": [respuesta]})
                if "{" in texto or "}" in texto:
                    errores.append(f"{q['id']}/{o['id']}: hueco sin llenar en «{texto}»")
                # Cobertura: una respuesta que redacta algo tiene que aparecer
                # en la frase aunque sea la única respondida.
                if GC._writes_something(o) and f"{q['id']}#{o['id']}" not in representadas:
                    errores.append(f"{q['id']}/{o['id']}: respuesta confirmada que no aparece en la frase")
                # Los valores escritos se conservan literalmente.
                for k, v in valores[o["id"]].items():
                    if texto and v not in texto and k != "moneda" and not o.get("fraseSingular"):
                        errores.append(f"{q['id']}/{o['id']}: el valor {k}={v} no aparece en «{texto}»")
    return errores, avisos


# --------------------------------------------------------------------------
# Gramática LSB de las formulaciones
# --------------------------------------------------------------------------
#
# `glosa válida ≠ oración LSB validada`. La formulación LSB de cada pregunta
# vive en `gramaticaLsb.secuencia` del banco canónico y llega a la app, a la
# Lambda y al grafo. Se construye desde la fila del corpus (§6) enlazada a la
# pregunta, o desde patrones consistentes del propio corpus cuando no hay fila;
# cada cambio lleva su regla y su evidencia. El corpus advierte (§6) que su
# columna de conceptos no fija la sintaxis definitiva y (§10) que no se asuma
# un orden OSV fijo: ninguna secuencia pasa sola a validada.
#
#   GRAMMAR_VALIDATED    validada por una persona competente; exige
#                        `validacion` con la secuencia exacta.
#   GRAMMAR_PROVISIONAL  secuencia completa con glosas v4, sin validar.
#   GRAMMAR_PENDING      sin secuencia sustentable; `motivo` dice por qué.
#   LEXICAL_GAP          falta un concepto en v4 (`huecos`).
#
# Tokens admitidos en una secuencia: glosa del catálogo v4, dactilología
# `d(SIGLA)` (letras del alfabeto v4, mecanismo permitido por el corpus) y el
# mecanismo numérico `NÚM(...)` del propio corpus.

ESTADOS_GRAMATICA = ("GRAMMAR_VALIDATED", "GRAMMAR_PROVISIONAL", "GRAMMAR_PENDING", "LEXICAL_GAP")
TIPOS_PREGUNTA = ("polar", "qu", "disyuntiva", "compuesta")
INTERROGATIVOS = ("QUÉ", "QUIÉN", "DÓNDE", "CUÁNDO", "CUÁL", "CÓMO", "CUÁNTOS")
POLARES_RESPUESTA = {"SÍ", "NO", "NO_SABER"}
NUMERO = "NÚM(...)"
_PRONOMBRES = {"TÚ", "YO", "ÉL", "ELLA", "TUYO", "MÍO", "SUYO", "NOSOTROS"}
_POSESIVOS = {"TUYO", "MÍO", "SUYO"}
_TIEMPO = {"AYER", "HOY", "MAÑANA", "AHORA", "ANTES", "DESPUÉS", "PASADO", "PRÓXIMO", "SIEMPRE", "TARDE",
           "TEMPRANO", "ANTEAYER", "AÚN", "PRIMERA_VEZ", "CADA_DÍA", "DÍA", "SEMANA", "MES", "HORA", "FECHA"}
# Interrogativo español → interrogativos LSB admitidos (evidencia del corpus:
# «¿Qué ropa…?» → ¿CUÁL?, «¿A qué hora…?» → ¿CUÁNTOS?).
_WH_ES = [
    (r"\bqui[eé]n(es)?\b", {"QUIÉN"}),
    (r"\bd[oó]nde\b", {"DÓNDE", "CUÁL"}),
    (r"\bcu[aá]ndo\b", {"CUÁNDO"}),
    (r"\bcu[aá]l\b", {"CUÁL"}),
    (r"\bc[oó]mo\b", {"CÓMO"}),
    (r"\bcu[aá]nt[oa]s?\b", {"CUÁNTOS"}),
    (r"\bqu[eé]\b", {"QUÉ", "CUÁL", "CUÁNTOS"}),
]


def _tokens_corpus(celda):
    celda = celda.replace("→", "·")
    for marca in CD.MARKERS:
        celda = celda.replace(marca, " ")
    return [t.strip() for t in re.split(r"[·+]", celda) if t.strip()]


def secuencia_del_corpus(celda, app):
    """Fila del corpus en tokens de la app: (secuencia, alternativas, huecos)."""
    sec, alternativas, huecos = [], {}, []
    for t in _tokens_corpus(celda):
        limpio = t.replace("¿", "").replace("?", "").strip()
        if re.match(r"^d\(.+\)$", limpio, re.IGNORECASE):
            sec.append(limpio)
            continue
        m = re.match(r"^NÚM\((.*)\)$", limpio)
        if m:
            sec.append(m.group(1) if m.group(1).isdigit() else NUMERO)
            continue
        if limpio.startswith("["):
            huecos.append(limpio.strip("[]"))
            continue
        partes = [p.strip() for p in limpio.split("/") if p.strip()]
        glosas = [app[CD.norm(p)]["gloss"] for p in partes if CD.norm(p) in app]
        if not glosas:
            huecos.append(limpio)
            continue
        if len(glosas) > 1:
            alternativas[str(len(sec))] = glosas
        sec.append(glosas[0])
    return sec, alternativas, huecos


def token_valido(t, catalogo, letras):
    if t in catalogo or t == NUMERO:
        return True
    m = re.match(r"^d\((.+)\)$", t)
    if not m:
        return False
    palabra = CD.strip_accents(m.group(1).upper().replace("Ñ", "\u0001")).replace("\u0001", "Ñ")
    return bool(palabra) and all(c in letras for c in palabra)


def analizar_gramatica(banco, grafo, resolver=None):
    """Evidencia y puntos a validar de cada formulación. Nunca valida sola."""
    resolver = resolver or CD.ConceptResolver()
    nodos = {n["id"]: n for n in grafo["nodes"]}
    catalogo = {e["gloss"] for e in resolver.app.values()}
    letras = {g for g in catalogo if len(CD.norm(g)) == 1 and not g.isdigit()}
    out = {}
    for q in banco["preguntas"]:
        g = q.get("gramaticaLsb") or {}
        sec = list(g.get("secuencia") or [])
        filas = []
        for nid in q.get("nodos", []):
            n = nodos.get(nid)
            if n is None:
                continue
            p = n["provenance"]
            base, alt, huecos = secuencia_del_corpus(p["conceptsRaw"], resolver.app)
            filas.append({"nodo": nid, "frase": p["spanish"], "corpus": p["conceptsRaw"], "nota": p["note"],
                          "base": base, "alternativas": alt, "huecos": huecos})
        # Lo que la fila del corpus traía y la secuencia ya no lleva.
        justificacion = CD.norm(" ".join([
            g.get("regla", ""), g.get("referente", ""), g.get("motivo", ""),
            " ".join(h.get("concepto", "") for h in g.get("huecos", [])),
            " ".join(x for alts in (g.get("alternativas") or {}).values() for x in alts),
        ]))
        omitidos = []
        if filas:
            for t in filas[0]["base"]:
                if t not in sec and CD.norm(t.replace("(", "").replace(")", "")) not in justificacion:
                    omitidos.append(t)
        invalidos = [t for t in sec if not token_valido(t, catalogo, letras)]

        validar = []
        tipo = g.get("tipo")
        if sec:
            validar.append(f"confirmar el orden {' · '.join(sec)} como formulación natural "
                           "(el corpus no fija la sintaxis, §6/§10)")
            interrogativos = [t for t in sec if t in INTERROGATIVOS]
            for w in interrogativos:
                i = sec.index(w)
                pos = "final" if i == len(sec) - 1 else ("inicial" if i == 0 else "intermedia")
                validar.append(f"confirmar la posición {pos} de ¿{w}?")
            if tipo == "polar":
                validar.append("confirmar la marca no manual de pregunta sí/no (la secuencia no la lleva)")
            elif tipo == "disyuntiva":
                validar.append("confirmar cómo se marca la elección entre alternativas")
            pron = [t for t in sec if t in _PRONOMBRES]
            if pron:
                validar.append(f"confirmar si {', '.join(pron)} es necesario o lo expresa la dirección/mirada")
            if any(t in _POSESIVOS for t in sec):
                validar.append("confirmar la construcción posesiva (poseedor delante)")
            tiempo = [t for t in sec if t in _TIEMPO]
            if tiempo:
                validar.append(f"confirmar la posición de la expresión temporal {', '.join(tiempo)}")
            for c in g.get("compuestos", []):
                validar.append(f"confirmar la composición {'+'.join(c)} como unidad")
            for t in sec:
                if t.startswith("d("):
                    validar.append(f"confirmar la integración de {t} en la secuencia")
            if NUMERO in sec:
                validar.append("confirmar el uso del mecanismo numérico NÚM(...) en la pregunta")
            for i, alts in (g.get("alternativas") or {}).items():
                validar.append(f"elegir {'/'.join(alts)} según el referente")
            if g.get("referente"):
                validar.append(f"confirmar el referente: {g['referente']}")
            if g.get("regla", "").startswith("secuencia de la fila") is False:
                validar.append(f"confirmar la corrección aplicada: {g.get('regla', '')}")
        for h in g.get("huecos", []):
            validar.append(f"confirmar cómo expresar {h.get('concepto')} sin una seña fuera del corpus v4"
                           + (f" (hoy: {h['tratamiento']})" if h.get("tratamiento") else ""))
        if not sec and not g.get("huecos"):
            validar.append("proponer la secuencia con una persona señante: " + g.get("motivo", ""))

        if g.get("huecos"):
            maximo = "LEXICAL_GAP"
        elif sec:
            maximo = "GRAMMAR_PROVISIONAL"
        else:
            maximo = "GRAMMAR_PENDING"
        out[q["id"]] = {"secuencia": sec, "filas": filas, "omitidos": omitidos, "invalidos": invalidos,
                        "validar": validar, "estadoMaximo": maximo, "todasEnV4": not invalidos}
    return out


def validar_gramatica(banco, grafo, errores, resolver=None):
    """Consistencia técnica de las formulaciones (no demuestra gramática)."""
    resolver = resolver or CD.ConceptResolver()
    analisis = analizar_gramatica(banco, grafo, resolver)
    catalogo = {e["gloss"] for e in resolver.app.values()}
    for q in banco["preguntas"]:
        qid = q["id"]
        a = analisis[qid]
        g = q.get("gramaticaLsb")
        if not isinstance(g, dict) or g.get("estado") not in ESTADOS_GRAMATICA:
            errores.append(f"{qid}: falta gramaticaLsb.estado ({', '.join(ESTADOS_GRAMATICA)})")
            continue
        estado, sec = g["estado"], a["secuencia"]
        if a["invalidos"]:
            errores.append(f"{qid}: la formulación usa {a['invalidos']}, fuera del corpus v4")
        if g.get("huecos") and estado != "LEXICAL_GAP":
            errores.append(f"{qid}: declara huecos {[h.get('concepto') for h in g['huecos']]}; "
                           "el estado debe ser LEXICAL_GAP")
        if estado == "LEXICAL_GAP" and not g.get("huecos"):
            errores.append(f"{qid}: LEXICAL_GAP sin huecos declarados")
        if estado in ("GRAMMAR_PROVISIONAL", "GRAMMAR_VALIDATED") and not sec:
            errores.append(f"{qid}: {estado} sin secuencia LSB")
        if estado == "GRAMMAR_PENDING":
            if sec:
                errores.append(f"{qid}: GRAMMAR_PENDING con secuencia; debería ser PROVISIONAL")
            if not str(g.get("motivo") or "").strip():
                errores.append(f"{qid}: GRAMMAR_PENDING sin motivo concreto")
        if sec and not (str(g.get("regla") or "").strip() and str(g.get("evidencia") or "").strip()):
            errores.append(f"{qid}: secuencia sin regla ni evidencia")
        if a["omitidos"]:
            errores.append(f"{qid}: la secuencia pierde {a['omitidos']} de la fila del corpus sin justificarlo")
        tipo = g.get("tipo")
        if sec:
            if tipo not in TIPOS_PREGUNTA:
                errores.append(f"{qid}: tipo de pregunta desconocido {tipo}")
            if tipo == "polar" and POLARES_RESPUESTA & set(sec):
                errores.append(f"{qid}: una pregunta sí/no no lleva {sorted(POLARES_RESPUESTA & set(sec))} "
                               "en su formulación (son respuestas)")
            if tipo in ("qu", "disyuntiva"):
                w = g.get("interrogativo")
                if w not in INTERROGATIVOS or w not in sec:
                    errores.append(f"{qid}: pregunta {tipo} sin su interrogativo en la secuencia")
                else:
                    for patron, admitidos in _WH_ES:
                        if re.search(patron, q["formulacion"].lower()):
                            if w not in admitidos:
                                errores.append(f"{qid}: «{q['formulacion']}» no se pregunta con ¿{w}?")
                            break
            for c in g.get("compuestos", []):
                if not any(sec[i:i + len(c)] == c for i in range(len(sec))):
                    errores.append(f"{qid}: el compuesto {'+'.join(c)} no es contiguo en la secuencia")
            for i, alts in (g.get("alternativas") or {}).items():
                if not i.isdigit() or int(i) >= len(sec) or sec[int(i)] != alts[0]:
                    errores.append(f"{qid}: alternativas {alts} no corresponden a la posición {i}")
                elif any(x not in catalogo for x in alts):
                    errores.append(f"{qid}: alternativas {alts} fuera del corpus v4")
        if "validacion" in g and estado != "GRAMMAR_VALIDATED":
            errores.append(f"{qid}: hay un registro de validación pero el estado es {estado}")
        if estado == "GRAMMAR_VALIDATED":
            v = g.get("validacion")
            if not isinstance(v, dict) or not all(str(v.get(k) or "").strip()
                                                  for k in ("validador", "fecha", "evidencia")):
                errores.append(f"{qid}: GRAMMAR_VALIDATED exige validacion.validador, .fecha y .evidencia "
                               "(nunca se promueve automáticamente)")
            elif not re.match(r"^\d{4}-\d{2}-\d{2}$", str(v["fecha"])):
                errores.append(f"{qid}: validacion.fecha debe ser AAAA-MM-DD")
            elif v.get("secuencia") != sec:
                errores.append(f"{qid}: la validación es de otra secuencia ({v.get('secuencia')}); "
                               f"la actual es {sec}")
    return analisis


def formulacion_ejecucion(q):
    """Lo que la app y la Lambda reciben de la formulación LSB."""
    g = q.get("gramaticaLsb") or {}
    return {k: v for k, v in {
        "glosas": list(g.get("secuencia") or []),
        "estado": g.get("estado"),
        "tipo": g.get("tipo"),
        "interrogativo": g.get("interrogativo"),
        "noManuales": g.get("noManuales"),
        "compuestos": g.get("compuestos"),
        "alternativas": g.get("alternativas"),
        "referente": g.get("referente"),
        "huecos": [h.get("concepto") for h in g.get("huecos", [])] or None,
    }.items() if v not in (None, [], {})}


def validar_condicion(cond, Q, donde, errores):
    if "perfil" in cond:
        return
    p = cond.get("pregunta")
    if p not in Q:
        errores.append(f"{donde}: condición sobre pregunta inexistente {p}")
        return
    for oid in cond.get("opciones", []):
        if oid not in {o["id"] for o in Q[p]["opciones"]}:
            errores.append(f"{donde}: condición sobre opción inexistente {p}/{oid}")
    for e in cond.get("estados", []):
        if e not in ESTADOS:
            errores.append(f"{donde}: estado de condición inválido {e}")


# --------------------------------------------------------------------------
# Banco de ejecución (lo que cargan la app y la Lambda)
# --------------------------------------------------------------------------

def banco_ejecucion(banco, acep):
    preguntas = []
    for q in sorted(banco["preguntas"], key=lambda x: x["id"]):
        pq = {k: q[k] for k in CAMPOS_PREGUNTA if k in q}
        pq["noOfrecer"] = sorted((q.get("noOfrecer") or {}).keys())
        pq["opciones"] = [{k: o[k] for k in CAMPOS_OPCION if k in o} for o in q.get("opciones", [])]
        # La formulación LSB de la pregunta llega a la app (tarjeta de la
        # pregunta) y a la Lambda desde la misma fuente.
        if q.get("gramaticaLsb"):
            pq["formulacionLsb"] = formulacion_ejecucion(q)
        preguntas.append(pq)
    return {
        "version": banco["version"],
        "preguntas": preguntas,
        "recorridos": banco["recorridos"],
        "mencionables": banco.get("mencionables", []),
        "acepciones": {g: sorted({a["campo"] for a in v}) for g, v in sorted(acep["glosas"].items())},
    }


def render_dart(ejecucion):
    datos = json.dumps(ejecucion, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    if "'''" in datos:
        raise SystemExit("el banco contiene ''' y no cabe en una cadena Dart cruda")
    return (
        "// GENERADO por tool/build_question_matrix.py desde\n"
        "// docs/negocio/config/banco_preguntas.json y acepciones.json. No editar a mano.\n\n"
        "/// Banco semántico de preguntas, recorridos y acepciones, en JSON.\n"
        f"const String kQuestionBankJson = r'''{datos}''';\n"
    )


# --------------------------------------------------------------------------
# Matrices y documentos
# --------------------------------------------------------------------------

def csv_texto(filas, columnas):
    buf = io.StringIO()
    buf.write("\ufeff")
    w = csv.writer(buf, delimiter=";", lineterminator="\n")
    w.writerow(columnas)
    for f in filas:
        w.writerow(["|".join(map(str, f.get(c, []))) if isinstance(f.get(c), list) else f.get(c, "")
                    for c in columnas])
    return buf.getvalue()


def md(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def render_gramatica(banco, grafo):
    """Matriz de auditoría: una fila por pregunta, con la formulación vigente."""
    analisis = analizar_gramatica(banco, grafo)
    filas = []
    for q in banco["preguntas"]:
        a = analisis[q["id"]]
        g = q["gramaticaLsb"]
        meta = []
        if g.get("compuestos"):
            meta.append("compuestos: " + ", ".join("+".join(c) for c in g["compuestos"]))
        if g.get("alternativas"):
            meta.append("alternativas: " + ", ".join("/".join(v) for v in g["alternativas"].values()))
        if g.get("referente"):
            meta.append("referente: " + g["referente"])
        if g.get("tiempo"):
            meta.append("tiempo: " + g["tiempo"])
        if g.get("huecos"):
            meta.append("huecos: " + ", ".join(
                h["concepto"] + (f" ({h['tratamiento']})" if h.get("tratamiento") else "")
                for h in g["huecos"]))
        filas.append({
            "questionId": q["id"],
            "espanol": q["formulacion"],
            "secuenciaCorpus": " || ".join(f["corpus"] for f in a["filas"]) or "—",
            "formulationGlosses": a["secuencia"],
            "tipo": g.get("tipo", ""),
            "interrogativo": g.get("interrogativo", ""),
            "estadoGramatica": g["estado"],
            "regla": g.get("regla") or g.get("motivo", ""),
            "evidencia": g.get("evidencia", "—"),
            "noManuales": g.get("noManuales", ""),
            "metadata": meta,
            "requiereValidacionHumana": a["validar"],
            "validadoPor": (g.get("validacion") or {}).get("validador", ""),
        })
    columnas = ["questionId", "espanol", "secuenciaCorpus", "formulationGlosses", "tipo", "interrogativo",
                "estadoGramatica", "regla", "evidencia", "noManuales", "metadata",
                "requiereValidacionHumana", "validadoPor"]
    csv_out = csv_texto(filas, columnas)

    cuenta = Counter(f["estadoGramatica"] for f in filas)
    L = ["# Auditoría gramatical LSB de las formulaciones del banco", "",
         "> Generado por `tool/build_question_matrix.py` desde `docs/negocio/config/banco_preguntas.json`,",
         "> `assets/dialogue/dialogue_graph.json` y el Corpus Maestro Unificado LSB v4. No editar a mano.", "",
         "**Glosa válida ≠ oración LSB validada.** La formulación de cada pregunta sale de la fila del corpus "
         "enlazada o, si no la hay, de patrones consistentes del propio corpus; cada cambio lleva regla y "
         "evidencia. El corpus advierte (§6) que su columna de conceptos no fija la sintaxis definitiva y (§10) "
         "que no se asuma un orden OSV fijo: ninguna secuencia está validada hasta que la revise una persona "
         "sorda señante o un intérprete (§3.1, nivel D).", "",
         "| Estado | Preguntas |", "|---|---|"]
    for e in ESTADOS_GRAMATICA:
        L.append(f"| `{e}` | {cuenta.get(e, 0)} |")
    L += ["", f"Total: **{len(filas)}** preguntas.", "",
          "Tokens: glosa del catálogo v4, `d(SIGLA)` = dactilología (mecanismo permitido por el corpus), "
          "`NÚM(...)` = mecanismo numérico del corpus. `noManuales`: el modelo es una secuencia lineal; "
          "expresión facial, cejas, mirada y dirección se registran como metadata, sin inventar glosas.", "",
          "| questionId | español | secuencia corpus | formulación LSB | tipo | estado | regla | evidencia | "
          "metadata | no manuales | requiere validación humana |",
          "|---|---|---|---|---|---|---|---|---|---|---|"]
    for f in filas:
        L.append("| " + " | ".join(md(x) for x in [
            f["questionId"], f["espanol"], f["secuenciaCorpus"],
            " · ".join(("¿" + t + "?") if t in INTERROGATIVOS else t for t in f["formulationGlosses"]) or "—",
            f["tipo"] + (f" ({f['interrogativo']})" if f["interrogativo"] else ""),
            f["estadoGramatica"], f["regla"], f["evidencia"], "; ".join(f["metadata"]) or "—",
            f["noManuales"] or "—", "; ".join(f["requiereValidacionHumana"]) or "—",
        ]) + " |")
    return "\n".join(L) + "\n", csv_out


def generar(banco, acep, catalogo, grafo, horneadas):
    ejecucion = banco_ejecucion(banco, acep)
    en_rec = {}
    for cid, r in banco["recorridos"].items():
        for i, p in enumerate(r["pasos"], 1):
            en_rec.setdefault(p["pregunta"], []).append(f"{cid}#{i}")
    nodos = {n["id"]: n for n in grafo["nodes"]}
    Q = {q["id"]: q for q in banco["preguntas"]}

    salida = OrderedDict()
    salida[OUT_DART] = render_dart(ejecucion)
    salida[OUT_AWS] = json.dumps(ejecucion, ensure_ascii=False, indent=1, sort_keys=True) + "\n"
    salida[OUT_GRAMATICA_MD], salida[OUT_GRAMATICA_CSV] = render_gramatica(banco, grafo)

    preguntas_json, filas = [], []
    for q in banco["preguntas"]:
        sin_sena = [o["id"] for o in q.get("opciones", []) if o.get("literal") or o.get("sinSena")]
        rutas = []
        if q["id"] in en_rec:
            rutas.append("recorrido")
        if q.get("nodos"):
            rutas.append("respuesta al funcionario")
        if not rutas:
            rutas.append("parte de otra respuesta")
        preguntas_json.append({
            "id": q["id"], "dominio": q.get("dominio"), "formulacion": q.get("formulacion"),
            "acto": q.get("acto"), "entidad": q.get("entidad"), "campo": q.get("campo"),
            "control": q["control"], "modo": q.get("modo"), "campos": q.get("campos"),
            "recorridos": en_rec.get(q["id"], []), "nodos": q.get("nodos", []),
            "enunciadosFuncionario": [nodos[n]["provenance"]["spanish"] for n in q.get("nodos", []) if n in nodos],
            "opciones": q.get("opciones", []), "pasosRespuesta": q.get("pasosRespuesta", []),
            "noOfrecer": q.get("noOfrecer", {}), "reglas": q.get("reglas", []),
            "rutas": rutas, "opcionesSinSena": sin_sena,
        })
        for o in q.get("opciones", []):
            nucleo = (o.get("glosas") or [""])[0]
            filas.append({
                "pregunta": q["id"], "dominio": q.get("dominio", ""), "formulacion": q.get("formulacion", ""),
                "control": q["control"], "campos": q.get("campos", []), "modo": q.get("modo", ""),
                "recorridos": en_rec.get(q["id"], []), "nodos": q.get("nodos", []),
                "opcion": o["id"], "etiqueta": o.get("etiqueta", ""), "glosas": o.get("glosas", []),
                "acepcionNucleo": sorted({a["campo"] for a in acep["glosas"].get(nucleo, [])}),
                "estado": o.get("estado", "afirmado"), "salida": bool(o.get("salida")),
                "editor": o.get("editor", ""), "frase": o.get("frase", ""),
                "fraseSinValor": o.get("fraseSinValor", ""),
                "sinSena": bool(o.get("literal") or o.get("sinSena")), "rutas": rutas,
            })
    salida[OUT_JSON] = json.dumps({
        "generadoPor": "tool/build_question_matrix.py",
        "fuentes": ["docs/negocio/config/banco_preguntas.json", "docs/negocio/config/acepciones.json"],
        "fecha": banco["fecha"],
        "totales": {"preguntas": len(banco["preguntas"]), "recorridos": len(banco["recorridos"]),
                    "opciones": len(filas)},
        "preguntas": preguntas_json,
    }, ensure_ascii=False, indent=1) + "\n"
    salida[OUT_CSV] = csv_texto(filas, ["pregunta", "dominio", "formulacion", "control", "campos", "modo",
                                        "recorridos", "nodos", "opcion", "etiqueta", "glosas",
                                        "acepcionNucleo", "estado", "salida", "editor", "frase",
                                        "fraseSinValor", "sinSena", "rutas"])
    filas_nodo = []
    for n in grafo["nodes"]:
        p = n["provenance"]
        filas_nodo.append({
            "nodo": n["id"], "seccion": p["section"], "fila": p["row"], "frase": p["spanish"],
            "intencion": n["intent"], "ambito": n["scope"], "hablante": n["speaker"],
            "acto": n["speechAct"], "modos": n["modes"], "preguntaBanco": n.get("bankQuestion") or "",
            "glosasDelEnunciado": n.get("formulationGlosses", []),
            "respuestas": [a["id"] for a in n.get("answerOptions", [])],
            "glosasDeRespuesta": [g for a in n.get("answerOptions", []) for g in a["glosses"][:1]],
            "controles": [c["id"] for c in n.get("controls", [])],
            "literales": [l["concept"] for l in n.get("literals", [])],
            "pendientes": [o["concept"] for o in n.get("pendingOptions", [])],
        })
    salida[OUT_NODOS] = csv_texto(filas_nodo, ["nodo", "seccion", "fila", "frase", "intencion", "ambito",
                                               "hablante", "acto", "modos", "preguntaBanco",
                                               "glosasDelEnunciado", "respuestas", "glosasDeRespuesta",
                                               "controles", "literales", "pendientes"])
    salida[OUT_MODOS] = csv_texto(banco["comparativaModos"],
                                  ["aspecto", "antes", "ahora", "evidencia", "justificacion"])
    salida[OUT_MD] = render_md(banco, Q, nodos)
    salida[OUT_BRECHAS] = render_brechas(banco, horneadas)
    return salida


def frase_opcion(o):
    f = o.get("frase", "")
    if o.get("fraseSinValor") is not None and o.get("editor"):
        f += f" / sin valor: «{o['fraseSinValor']}»"
    return f


def render_opciones(opciones, ocultar=()):
    return "<br>".join(
        f"{md(o.get('etiqueta', o['id']))}"
        + (f" [{' · '.join(o['glosas'])}]" if o.get("glosas") else "")
        + (f" ⟨{o['editor']}⟩" if o.get("editor") else "")
        + (" *(sin seña)*" if o.get("literal") or o.get("sinSena") else "")
        + (" *salida*" if o.get("salida") else "")
        + (f" → «{md(frase_opcion(o))}»" if o.get("frase") else " → (sin frase)")
        for o in opciones if o["id"] not in ocultar)


def render_md(banco, Q, nodos):
    L = [
        "# Matriz maestra de preguntas",
        "",
        "Generado por `tool/build_question_matrix.py` desde `config/banco_preguntas.json` y "
        "`config/acepciones.json`. **No editar a mano.**",
        "",
        "Es el contrato que implementan la app (`lib/core/domain/guided/`) y la Lambda "
        "(`aws/guided_composer.py`). `test/guided/banco_aceptacion_test.dart` recorre todas las "
        "preguntas y todas sus opciones sobre el código real.",
        "",
        "## Totales",
        "",
        "| Qué | Cantidad |",
        "|---|---:|",
        f"| Preguntas del banco | {len(Q)} |",
        f"| Recorridos (uno por contexto) | {len(banco['recorridos'])} |",
        f"| Opciones de respuesta | {sum(len(q.get('opciones', [])) for q in Q.values())} |",
        f"| Enunciados del funcionario con pregunta asignada | {sum(len(q.get('nodos', [])) for q in Q.values())} |",
        "",
        "Leyenda: `[GLOSAS]` tarjetas del catálogo; `⟨editor⟩` valor escrito que se conserva literal; "
        "*(sin seña)* opción de texto sin glosa; *salida* = No sé / No recuerdo / Ninguno.",
        "",
    ]
    for cid, r in banco["recorridos"].items():
        L += [f"## Recorrido `{cid}` — {r['nombre']}", "",
              "| # | Pregunta | Se muestra si | Obligatoria | Respuestas → frase |", "|---|---|---|---|---|"]
        for i, p in enumerate(r["pasos"], 1):
            q = Q[p["pregunta"]]
            cond = "; ".join(
                ("sin perfil institucional" if "perfil" in c else
                 f"{c['pregunta']} ∈ {{{', '.join(c.get('opciones', c.get('estados', [])))}}}")
                for c in p.get("cuando", [])) or "siempre"
            titulo = p.get("formulacion") or q.get("formulacion", "")
            L.append(f"| {i} | `{q['id']}` {md(titulo)} | {md(cond)} | "
                     f"{'sí' if p.get('obligatoria') else 'no'} | {render_opciones(q.get('opciones', []), p.get('ocultar', ()))} |")
        if r.get("ordenRedaccion"):
            L += ["", f"Orden de redacción: {' → '.join(f'`{x}`' for x in r['ordenRedaccion'])}."]
        L.append("")
    L += ["## Respuestas a preguntas del funcionario (modo respuesta)", "",
          "| Enunciado del corpus §6 | Nodo | Pregunta del banco | Respuestas |", "|---|---|---|---|"]
    for q in sorted(Q.values(), key=lambda x: x["id"]):
        for nid in q.get("nodos", []):
            n = nodos.get(nid)
            partes = [p["pregunta"] for p in q.get("pasosRespuesta", [])]
            if partes and not q.get("opciones"):
                resp = " + ".join(f"`{x}`" for x in partes)
            else:
                resp = ", ".join(md(o.get("etiqueta", o["id"])) for o in q.get("opciones", []))
            L.append(f"| {md(n['provenance']['spanish'] if n else nid)} | `{nid}` | `{q['id']}` | {resp} |")
    L.append("")
    return "\n".join(L)


def render_brechas(banco, horneadas):
    L = [
        "# Brechas lexicográficas y de animación",
        "",
        "Generado por `tool/build_question_matrix.py`. **No editar a mano.**",
        "",
        "Cinco cosas distintas: (1) que la glosa exista en el catálogo; (2) su acepción en el "
        "contexto (`config/acepciones.json`); (3) que responda el campo preguntado; (4) si la opción "
        "es texto escrito por la persona; (5) si el avatar tiene una animación declarada.",
        "",
        "## Conceptos que el banco necesita y el catálogo no documenta",
        "",
        "| Concepto | Lo necesita | Estado | Tratamiento en la app |",
        "|---|---|---|---|",
    ]
    for b in banco["brechas"]:
        L.append(f"| {md(b['concepto'])} | {md(', '.join(b['necesario']))} | {md(b['estado'])} | "
                 f"{md(b['tratamiento'])} |")
    L += ["", "## Opciones sin seña (la interfaz las rotula como texto)", "",
          "| Pregunta | Opción | Frase |", "|---|---|---|"]
    for q in banco["preguntas"]:
        for o in q.get("opciones", []):
            if o.get("literal") or o.get("sinSena"):
                L.append(f"| `{q['id']}` | {md(o.get('etiqueta'))} | {md(o.get('frase', ''))} |")
    editores = Counter(o["editor"] for q in banco["preguntas"] for o in q.get("opciones", []) if o.get("editor"))
    L += ["", "## Editores de valor literal", "",
          "El valor escrito se guarda y se redacta tal cual; no se convierte en glosas.", "",
          "| Editor | Opciones que lo usan |", "|---|---:|"]
    for k, v in sorted(editores.items()):
        L.append(f"| `{k}` | {v} |")
    usadas = OrderedDict()
    for q in banco["preguntas"]:
        for o in q.get("opciones", []):
            for g in o.get("glosas", []):
                usadas[g] = True
    dig = {"0": "CERO", "1": "UNO", "2": "DOS", "3": "TRES", "4": "CUATRO", "5": "CINCO",
           "6": "SEIS", "7": "SIETE", "8": "OCHO", "9": "NUEVE"}

    def canon(g):
        s = "".join(c if c == "Ñ" else "".join(x for x in unicodedata.normalize("NFD", c)
                                               if unicodedata.category(x) != "Mn") for c in g)
        return dig.get(s, s)

    con_clip = [g for g in usadas if canon(g) in horneadas]
    L += ["", "## Animación de las glosas del banco", "",
          "Solo cuenta para mostrar una frase en el avatar (texto/voz → LSB). La salida de las tarjetas "
          "es texto y audio en español.", "",
          f"- Glosas distintas en respuestas del banco: **{len(usadas)}**.",
          f"- Con clip declarado en `available3DGlosses` (árbol de trabajo al generar): **{len(con_clip)}** — "
          f"{', '.join(con_clip) or 'ninguna'}.",
          "- El resto se deletrea o queda como marcador en el avatar. La lista real de clips vive en el "
          "`.glb` de S3, que no está en el repositorio: **no se ha verificado en dispositivo**.", ""]
    return "\n".join(L)


def main():
    banco, acep, catalogo, grafo, contextos, horneadas = cargar()
    errores, avisos = validar(banco, acep, catalogo, grafo, contextos)
    for a in avisos:
        print(f"aviso: {a}")
    if errores:
        for e in errores:
            print(f"ERROR: {e}")
        print(f"{len(errores)} errores: no se escribe nada.")
        return 1
    salidas = generar(banco, acep, catalogo, grafo, horneadas)
    if "--check" in sys.argv:
        viejos = [p for p, t in salidas.items() if not os.path.exists(p) or leer(p) != t]
        if viejos:
            for p in viejos:
                print(f"desactualizado: {os.path.relpath(p, ROOT)}")
            print("Ejecuta: python tool/build_question_matrix.py")
            return 1
        print("Banco de preguntas al día y coherente con el repositorio.")
        return 0
    for p, t in salidas.items():
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(t)
        print(f"escrito: {os.path.relpath(p, ROOT)}")
    print(f"preguntas: {len(banco['preguntas'])} · recorridos: {len(banco['recorridos'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
