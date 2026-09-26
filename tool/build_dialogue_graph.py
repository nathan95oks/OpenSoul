"""Genera el grafo de diálogo y la matriz de cobertura desde el corpus.

    python tool/build_dialogue_graph.py

Escribe dos artefactos, y no toca ninguna otra cosa:

  assets/dialogue/dialogue_graph.json   datos que carga la app
  docs/Matriz_Cobertura_Corpus_209.md   estado de las 98 + 60 + 51 entradas

El grafo es declarativo y versionado: cada nodo declara de dónde sale (sección,
subsección y número de fila del corpus), en qué modos A/B/C puede activarse,
qué ranuras de respuesta admite y qué opciones son alcanzables **de verdad**
con el catálogo que carga la app. Una opción que no resuelve contra el
catálogo no se emite como tarjeta: se registra como pendiente con su razón.
"""

from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import corpus_dialogue as C  # noqa: E402

GRAPH_VERSION = 2

# El banco semántico de preguntas es la fuente de las RESPUESTAS. El corpus da
# el enunciado y su vocabulario; el banco dice qué se puede contestar a cada
# pregunta del funcionario, con qué dato y con qué frase. Mezclar las dos cosas
# —usar las glosas que formulan la pregunta como tarjetas de respuesta— es lo
# que ofrecía DÓNDE ante «¿Dónde ocurrió?» o TOTAL ante «¿Conserva toda la
# conversación?».
BANK_PATH = os.path.join(C.ROOT, "docs", "negocio", "config", "banco_preguntas.json")

GRAPH_OUT = os.path.join(C.ROOT, "assets", "dialogue", "dialogue_graph.json")
MATRIX_OUT = os.path.join(C.ROOT, "docs", "Matriz_Cobertura_Corpus_209.md")

# Subsección del corpus → contexto seleccionable de la app.
#
# Son los ocho que existen hoy en `context_catalog.dart`. Las subsecciones que
# no tienen contexto propio no se reasignan a uno ajeno: van a 'otro', que es
# el contexto general, y quedan anotadas en la matriz. Inventar aquí un
# contexto 'consulta' o 'tramite' sería reanimar los contextos legados que el
# enrutador menciona pero el catálogo no ofrece.
SCOPE_BY_SUBSECTION = {
    "ACCESO_COMUNICATIVO_E_IDENTIFICACION": "identificacion",
    "INICIO_DE_DENUNCIA_Y_RELATO_BASICO": "denuncia_robo",
    "DESCRIPCION_DE_PERSONAS": "denuncia_robo",
    "ROBO,_HURTO_Y_OBJETOS": "denuncia_robo",
    "AGRESION,_VIOLENCIA_Y_RIESGO": "violencia",
    "AMENAZAS,_MENSAJES_Y_ENTORNO_DIGITAL": "amenaza_digital",
    "ENGAÑO,_DINERO_Y_TRANSACCIONES": "engano_dinero",
    "TESTIGOS,_FOTOS,_VIDEO_Y_OTROS_ELEMENTOS": "otro",
    "SEGUIMIENTO_PRELIMINAR_Y_ORIENTACION": "seguimiento",
    "INTERACCION_CON_FISCAL/JUEZ_EN_EL_LIMITE_DEL_ALCANCE": "seguimiento",
    "ACCESO_Y_COMUNICACION": "identificacion",
    "DENUNCIA_Y_RELATO": "denuncia_robo",
    "ROBO_Y_OBJETOS": "denuncia_robo",
    "VIOLENCIA,_AMENAZAS_Y_ASISTENCIA": "violencia",
    "TESTIGOS_Y_EVIDENCIA_CONCRETA": "otro",
    "CONSULTA_Y_SEGUIMIENTO": "seguimiento",
    "FISCALIA,_ASISTENCIA_Y_DEFENSA": "seguimiento",
}

# Ranuras de respuesta, deducidas de la intención y del enunciado. Una ranura
# no aparece por defecto: solo si la intervención la pide. Es la diferencia
# entre ofrecer "¿dónde?" porque toca y ofrecerlo porque se preguntó.
SLOT_RULES = [
    ("time", r"cuándo|qué hora|hoy|ayer|antes|fecha|cuánto tiempo|desde cuándo"),
    ("place", r"dónde|lugar|dentro o fuera|dirección|calle"),
    ("person", r"quién|persona|hombre|mujer|edad|estatura|cabello|ropa|"
               r"agresor|testigo|acompañ"),
    ("object", r"objeto|celular|teléfono|dinero|documento|mochila|bolso|"
               r"qué le robaron|marca|modelo"),
    ("amount", r"cuánto|monto|cantidad|cuántas|cuántos"),
    ("institution", r"policía|fiscal|juzgado|felcc|felcv|sepdavi|sepdep|"
                    r"institución|oficina|defensoría"),
    ("evidence", r"fotos|video|captura|comprobante|factura|certificado|"
                 r"evidencia|prueba|testigo"),
    ("free_text", r"algo más|agregar|explicar|contar|narrar|qué ocurrió|"
                  r"qué pasó"),
]

# Respuestas de salida que siempre deben poder darse ante una pregunta, si la
# interfaz puede expresarlas con fidelidad. Se emiten solo si la glosa existe
# de verdad en el catálogo.
ESCAPE_GLOSSES = ["NO_SABER", "NO_RECORDAR"]

POLAR_GLOSSES = ["SÍ", "NO"]


# Palabras que abren una pregunta abierta. Si una pregunta empieza por una de
# ellas, pide un dato concreto y no un sí/no: ofrecer polaridad ahí es poner
# una respuesta que nadie pidió.
OPEN_QUESTION_WORDS = (
    "qué", "quién", "quiénes", "dónde", "cuándo", "cómo", "cuál", "cuáles",
    "cuánto", "cuántos", "cuánta", "cuántas", "por qué", "para qué",
)


def is_polar_question(entry: C.CorpusEntry) -> bool:
    """Si la pregunta se contesta con sí/no.

    Una disyuntiva («¿Era un hombre o una mujer?», «¿Vino solo o acompañado?»,
    «¿Fue hoy, ayer o antes?») no empieza por interrogativa y tampoco es de
    sí/no: se contesta eligiendo una alternativa. Tratarla como cerrada ponía
    SÍ/NO delante de HOMBRE/MUJER.
    """
    if entry.speech_act != "question":
        return False
    text = entry.spanish.strip().lstrip("¿").lower()
    if text.startswith(OPEN_QUESTION_WORDS) or text.startswith(("a qué", "en qué", "de qué", "con qué")):
        return False
    if re.search(r"(o|u)", text):
        return False
    return True


def slots_for(entry: C.CorpusEntry) -> list:
    text = entry.spanish.lower()
    slots = []
    # La polaridad va primero porque es la respuesta más directa a una
    # pregunta cerrada; las demás ranuras son el detalle que se añade después.
    if is_polar_question(entry):
        slots.append("polarity")
    for name, pattern in SLOT_RULES:
        if re.search(pattern, text):
            slots.append(name)
    return slots or ["free_text"]


# Campos del banco → ranuras que lee el cliente.
CAMPO_A_RANURA = {
    "polaridad": "polarity", "persona": "person", "rasgo": "person", "edad": "person", "prenda": "person",
    "nombre": "person", "telefono": "object", "objeto": "object", "documento": "evidence", "evidencia": "evidence",
    "lugar": "place", "tiempo": "time", "frecuencia": "time", "cantidad": "amount", "medio": "object",
    "institucion": "institution", "servicio": "institution", "hecho": "free_text", "consulta": "free_text",
    "estado": "free_text", "parte_cuerpo": "free_text", "interrogativa": "free_text", "compania": "person",
    "modificador": "free_text", "detalle": "free_text",
}


def slots_for_bank(pregunta: dict) -> list:
    ranuras = []
    for campo in pregunta.get("campos", []):
        r = CAMPO_A_RANURA.get(campo)
        if r and r not in ranuras:
            ranuras.append(r)
    return ranuras or ["free_text"]


def scope_for(entry: C.CorpusEntry) -> str:
    key = C.norm(entry.subsection)
    if key in SCOPE_BY_SUBSECTION:
        return SCOPE_BY_SUBSECTION[key]
    return "otro"


def node_id(entry: C.CorpusEntry) -> str:
    return "n-" + entry.entry_id.lower().replace(",", "").replace("/", "-")


STOPWORDS = {
    "de", "la", "el", "los", "las", "un", "una", "unos", "unas", "y", "o",
    "que", "qué", "en", "a", "al", "del", "se", "su", "sus", "le", "lo",
    "me", "mi", "es", "está", "con", "por", "para", "usted", "puede",
    "puedo", "si", "no", "más", "este", "esta", "ese", "esa",
}


def keywords(text: str) -> list:
    words = re.findall(r"[a-záéíóúñü]+", text.lower())
    return sorted({w for w in words if w not in STOPWORDS and len(w) > 3})


def build_options(resolver: C.ConceptResolver, entry: C.CorpusEntry) -> tuple:
    """Opciones alcanzables y pendientes de esta intervención.

    Alcanzable = el concepto resuelve contra el catálogo que carga la app, o
    contra un mecanismo real (dactilología, número). Todo lo demás se anota
    como pendiente con su razón; ninguna se emite como tarjeta.
    """
    reachable, pending = [], []
    for res in resolver.resolve_cell(entry.concepts_raw):
        item = {
            "concept": res.concept,
            "coverage": res.status,
            "avatar": res.avatar,
            "reason": res.reason,
        }
        if res.alternatives:
            item["alternatives"] = res.alternatives
        if res.status == C.DIRECT_SIGN and res.app_gloss:
            item["kind"] = "card"
            item["gloss"] = res.app_gloss
            if res.corpus_source:
                item["corpusSource"] = res.corpus_source
            reachable.append(item)
        elif res.status == C.DIRECT_SIGN and res.mechanism == C.MECHANISM_NUMBER:
            item["kind"] = "number"
            reachable.append(item)
        elif res.status == C.DACTYLOLOGY:
            item["kind"] = "spelling"
            reachable.append(item)
        else:
            pending.append(item)
    return reachable, pending


def build_graph():
    resolver = C.ConceptResolver()
    entries = C.load_corpus_entries()
    app = resolver.app

    def gloss_if_present(name):
        e = app.get(C.norm(name))
        return e["gloss"] if e else None

    escapes = [g for g in (gloss_if_present(n) for n in ESCAPE_GLOSSES) if g]
    polars = [g for g in (gloss_if_present(n) for n in POLAR_GLOSSES) if g]

    nodes, matrix = [], []
    by_intent = {}

    with open(BANK_PATH, encoding="utf-8") as f:
        banco = json.load(f)
    bank_by_node = {}
    for q in banco["preguntas"]:
        for n in q.get("nodos", []):
            if n in bank_by_node:
                raise SystemExit(f"nodo {n} asignado a dos preguntas del banco")
            bank_by_node[n] = q

    for entry in entries:
        resolutions = resolver.resolve_cell(entry.concepts_raw)
        status = C.entry_status(resolutions)
        reachable, pending = build_options(resolver, entry)
        scope = scope_for(entry)
        slots = slots_for(entry)
        markers = resolver.markers_in(entry.concepts_raw)

        # En qué modos puede activarse este nodo.
        #   S6: lo dice el oyente  -> la persona sorda le RESPONDE (modo C).
        #   S7: lo pregunta ella   -> formulación propia (A, B).
        #   S8: declara ella       -> formulación propia (A, B).
        # Solo los enunciados del oyente se emparejan con un turno oyente: una
        # declaración de la persona sorda no es algo a lo que ella responda.
        modes = ["C"] if entry.section == 6 else ["A", "B"]

        nid = node_id(entry)
        pregunta = bank_by_node.get(nid)

        # Vocabulario del ENUNCIADO: las glosas con que se formula la
        # intervención. Sirven para reconocerla y para el avatar; nunca son
        # tarjetas de respuesta.
        formulacion = []
        for o in reachable:
            if o.get("kind") == "card":
                formulacion.append(o["gloss"])
                continue
            # Dactilología institucional explícita del corpus, d(FISCALÍA):
            # si la sigla existe en el catálogo v4 (FISCALIA, SEPDAVI,
            # SEPDEP…), forma parte del enunciado en la posición que le da el
            # corpus. Antes se descartaba y «¿Dónde está la Fiscalía?» quedaba
            # como un DÓNDE suelto. Solo en las preguntas del banco, que es lo
            # auditado (docs/negocio/13_Auditoria_Gramatica_LSB.md); no valida
            # el orden, solo deja de perder una pieza.
            m = re.match(r"^d\((.+)\)$", o.get("concept", "").strip(), re.IGNORECASE)
            if pregunta is not None and o.get("kind") == "spelling" and m:
                sigla = gloss_if_present(m.group(1))
                if sigla:
                    formulacion.append(sigla)
        # Valores literales y mecanismos: números, deletreos y conceptos
        # pendientes. No son señas nuevas.
        literales = [
            {"concept": o["concept"], "kind": o["kind"], "coverage": o["coverage"]}
            for o in reachable if o.get("kind") in ("number", "spelling")
        ]

        respuestas, controles = [], []
        if pregunta is not None:
            for op in pregunta.get("opciones", []):
                item = {
                    "id": op["id"],
                    "label": op.get("etiqueta", op["id"]),
                    "glosses": op.get("glosas", []),
                    "state": op.get("estado", "afirmado"),
                }
                if op.get("editor"):
                    item["editor"] = op["editor"]
                if op.get("salida"):
                    controles.append({**item, "kind": "exit"})
                else:
                    respuestas.append(item)
            controles.append({"id": "omitir", "label": "Omitir", "glosses": [],
                              "state": "omitido", "kind": "skip"})

        # `options` conserva el formato que lee el cliente: SOLO respuestas
        # válidas del banco (y sus salidas), nunca el vocabulario del enunciado.
        options = []
        for item in respuestas + [c for c in controles if c["kind"] == "exit"]:
            for g in item["glosses"][:1]:
                options.append({
                    "concept": g, "gloss": g, "kind": "card",
                    "coverage": C.DIRECT_SIGN,
                    "avatar": "baked" if C.norm(g) in resolver.baked else "placeholder",
                    "reason": ("respuesta del banco " + pregunta["id"] + " / " + item["id"]),
                    "answerId": item["id"],
                })

        if pregunta is not None:
            slots = slots_for_bank(pregunta)
        node = {
            "id": nid,
            "version": GRAPH_VERSION,
            "provenance": {
                "section": entry.section,
                "subsection": entry.subsection,
                "row": entry.number,
                "spanish": entry.spanish,
                "conceptsRaw": entry.concepts_raw,
                "note": entry.note,
            },
            "scope": scope,
            "intent": entry.intent,
            "speaker": entry.speaker,
            "speechAct": entry.speech_act,
            "modes": modes,
            "entry": {
                "phrase": entry.spanish,
                "keywords": keywords(entry.spanish),
            },
            "guideText": entry.spanish if entry.section == 6 else "",
            "slots": slots,
            "markers": markers,
            "bankQuestion": pregunta["id"] if pregunta else None,
            "formulationGlosses": formulacion,
            "answerOptions": respuestas,
            "answerParts": [p["pregunta"] for p in (pregunta or {}).get("pasosRespuesta", [])],
            "controls": controles,
            "literals": literales,
            "options": options,
            "pendingOptions": pending,
            "coverage": status,
        }
        nodes.append(node)
        by_intent.setdefault(entry.intent, []).append(node["id"])

        matrix.append({
            "entryId": entry.entry_id,
            "section": entry.section,
            "subsection": entry.subsection,
            "row": entry.number,
            "spanish": entry.spanish,
            "intent": entry.intent,
            "modes": modes,
            "scope": scope,
            "coverage": status,
            "nodeId": node["id"],
            "glosses": [o.get("gloss", o["concept"]) for o in reachable],
            "pending": pending,
        })

    # Transiciones: dentro de un mismo ámbito, una respuesta lleva a los
    # nodos que comparten alguna ranura sin repetir el nodo actual. No es un
    # orden fijo de preguntas: es un conjunto de continuaciones posibles que
    # el motor pondera con el estado del diálogo.
    by_scope = {}
    for n in nodes:
        by_scope.setdefault(n["scope"], []).append(n)

    for n in nodes:
        mine = set(n["slots"])
        nxt = []
        for other in by_scope[n["scope"]]:
            if other["id"] == n["id"]:
                continue
            nuevas = set(other["slots"]) - mine
            if not nuevas:
                # No aporta ninguna ranura nueva: es una variante de lo mismo,
                # no un paso siguiente.
                continue
            nxt.append({
                "to": other["id"],
                "adds": sorted(nuevas),
                "priority": len(nuevas),
            })
        # Primero lo que más añade, y a igualdad, el orden del corpus. Es una
        # preferencia, no un orden fijo: el motor la reordena con el estado
        # del diálogo, y nada impide llegar a los demás.
        nxt.sort(key=lambda t: (-t["priority"], t["to"]))
        n["transitions"] = nxt[:12]

    graph = {
        "version": GRAPH_VERSION,
        "generatedFrom": os.path.basename(C.corpus_path()),
        "counts": {
            "nodes": len(nodes),
            "section6": sum(1 for e in entries if e.section == 6),
            "section7": sum(1 for e in entries if e.section == 7),
            "section8": sum(1 for e in entries if e.section == 8),
        },
        "intents": {k: v for k, v in sorted(by_intent.items())},
        "nodes": nodes,
    }
    return graph, matrix


def write_matrix(matrix):
    total = len(matrix)
    by_status = {}
    for m in matrix:
        by_status.setdefault(m["coverage"], []).append(m)

    labels = {
        C.DIRECT_SIGN: "cubierta",
        C.DACTYLOLOGY: "cubierta con dactilología",
        C.VALIDATED_COMPOSITION: "cubierta por composición validada",
        C.NEEDS_VALIDATION: "requiere validación",
        C.UNSUPPORTED: "no soportada",
    }

    lines = [
        "# Matriz de cobertura del corpus conversacional (209 intervenciones)",
        "",
        "Generado por `tool/build_dialogue_graph.py` desde "
        f"`{os.path.basename(C.corpus_path())}`. No editar a mano.",
        "",
        "Cada fila es una intervención de ejemplo de los bancos 6, 7 y 8 del "
        "corpus, con los modos A/B/C en que su nodo puede activarse y el "
        "estado de cobertura con los recursos que la app tiene hoy.",
        "",
        "**Qué significa cada estado**",
        "",
        "| Estado | Significado |",
        "|---|---|",
        "| cubierta | Todos sus conceptos resuelven contra el catálogo que "
        "carga la app. |",
        "| cubierta con dactilología | Algún concepto se representa "
        "deletreando, porque no hay seña directa documentada. |",
        "| requiere validación | Algún concepto está documentado en el corpus "
        "pero no es elegible en la app, o el corpus lo marca como pendiente. |",
        "| no soportada | Algún concepto no está ni en el catálogo, ni en el "
        "apéndice 12, ni es deletreable. |",
        "",
        "**Resumen**",
        "",
        "| Estado | Intervenciones | % |",
        "|---|---:|---:|",
    ]
    for status in (C.DIRECT_SIGN, C.DACTYLOLOGY, C.VALIDATED_COMPOSITION,
                   C.NEEDS_VALIDATION, C.UNSUPPORTED):
        rows = by_status.get(status, [])
        lines.append(
            f"| {labels[status]} | {len(rows)} | {100 * len(rows) / total:.1f}% |")
    lines += [f"| **Total** | **{total}** | **100%** |", ""]

    lines += [
        "## Pendientes, una por una",
        "",
        "Las intervenciones que no quedan cubiertas del todo, con el motivo "
        "exacto. Ninguna se presenta como terminada.",
        "",
        "| Entrada | Frase | Concepto | Motivo |",
        "|---|---|---|---|",
    ]
    pendientes = [m for m in matrix
                  if m["coverage"] in (C.NEEDS_VALIDATION, C.UNSUPPORTED)]
    for m in pendientes:
        for p in m["pending"]:
            lines.append(
                f"| `{m['entryId']}` | {m['spanish']} | `{p['concept']}` | "
                f"{p['reason']} |")
    if not pendientes:
        lines.append("| — | — | — | Ninguna |")
    lines.append("")

    for section, title in ((6, "Sección 6 — preguntas del funcionario (98)"),
                           (7, "Sección 7 — preguntas del ciudadano sordo (60)"),
                           (8, "Sección 8 — declaraciones y respuestas (51)")):
        rows = [m for m in matrix if m["section"] == section]
        lines += [
            f"## {title}",
            "",
            "| # | Frase en español | Intención | Modos | Ámbito | Estado | Nodo |",
            "|---|---|---|---|---|---|---|",
        ]
        for m in rows:
            lines.append(
                f"| {m['row']} | {m['spanish']} | `{m['intent']}` | "
                f"{'/'.join(m['modes'])} | `{m['scope']}` | "
                f"{labels[m['coverage']]} | `{m['nodeId']}` |")
        lines.append("")

    os.makedirs(os.path.dirname(MATRIX_OUT), exist_ok=True)
    with open(MATRIX_OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def render_graph(graph) -> str:
    return json.dumps(graph, ensure_ascii=False, indent=1) + "\n"


def check() -> int:
    """Comprueba que lo empaquetado sea lo que el corpus produce hoy.

    Sirve para que el corpus y el asset no se separen en silencio: si alguien
    edita el Markdown y no regenera, esto lo dice en vez de dejar la app
    sirviendo un grafo viejo.
    """
    graph, _ = build_graph()
    esperado = render_graph(graph)
    if not os.path.exists(GRAPH_OUT):
        print("FALTA assets/dialogue/dialogue_graph.json — ejecuta la "
              "herramienta sin --check.")
        return 1
    actual = open(GRAPH_OUT, encoding="utf-8").read()
    if actual != esperado:
        print("El grafo empaquetado no coincide con el corpus actual. "
              "Ejecuta: python tool/build_dialogue_graph.py")
        return 1
    print("El grafo empaquetado está al día con el corpus.")
    return 0


def main():
    if "--check" in sys.argv:
        raise SystemExit(check())

    graph, matrix = build_graph()
    os.makedirs(os.path.dirname(GRAPH_OUT), exist_ok=True)
    with open(GRAPH_OUT, "w", encoding="utf-8") as f:
        f.write(render_graph(graph))
    write_matrix(matrix)

    counts = {}
    for m in matrix:
        counts[m["coverage"]] = counts.get(m["coverage"], 0) + 1
    print(f"nodos: {len(graph['nodes'])}")
    print(f"intenciones distintas: {len(graph['intents'])}")
    for k, v in sorted(counts.items()):
        print(f"  {k}: {v}")
    print(f"escrito: {os.path.relpath(GRAPH_OUT, C.ROOT)}")
    print(f"escrito: {os.path.relpath(MATRIX_OUT, C.ROOT)}")


if __name__ == "__main__":
    main()
