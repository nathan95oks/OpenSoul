"""Clasifica todas las entradas del catálogo contra las fuentes del repositorio.

    python tool/build_vocabulary_matrix.py

Produce tres artefactos en `docs/negocio/`:

    vocabulario.json            procesable, una entrada por glosa
    vocabulario.csv             procesable en hoja de cálculo
    01_Matriz_Vocabulario.md    revisable, con resúmenes y brechas

No inventa nada. Cada campo declara de qué archivo del repositorio sale:

  catálogo      assets/dictionary/official_dictionary.json
  corpus §12    docs/Corpus_Maestro_Unificado_LSB_v4_Auditado (2).md
  corpus §4     el mismo, conceptos sin correspondencia directa segura
  función       lib/core/domain/services/local_sentence_assembler.dart (_Role)
  avatar        lib/core/domain/services/animation_url_resolver.dart
  uso real      assets/dialogue/dialogue_graph.json (nodos, intenciones, campos)

Una glosa sin uso documentado en ningún recorrido se marca como tal, con su
motivo. No se le inventa una necesidad para que aparezca en pantalla.
"""

from __future__ import annotations

import csv
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import corpus_dialogue as C  # noqa: E402

OUT_DIR = os.path.join(C.ROOT, "docs", "negocio")
ASSEMBLER = os.path.join(
    C.ROOT, "lib", "core", "domain", "services", "local_sentence_assembler.dart")
GRAPH = os.path.join(C.ROOT, "assets", "dialogue", "dialogue_graph.json")

# --------------------------------------------------------------------------
# Clase léxica: separa el conteo de señas del de mecanismos
# --------------------------------------------------------------------------
CLASE_SENA = "sena_lexica"
CLASE_LETRA = "letra_dactilologica"
CLASE_DIGITO = "digito"
CLASE_INSTITUCION = "institucion_dactilologica"


def clase_lexica(entry: dict, en_corpus: bool) -> str:
    g = C.norm(entry["gloss"])
    if len(g) == 1 and g.isdigit():
        return CLASE_DIGITO
    if len(g) == 1:
        return CLASE_LETRA
    if (entry.get("canonicalGloss") or "").lower().startswith("d("):
        return CLASE_INSTITUCION
    return CLASE_SENA if en_corpus else CLASE_INSTITUCION


# --------------------------------------------------------------------------
# Función semántica: se lee del rol que el ensamblador ya le asigna
# --------------------------------------------------------------------------
# El ensamblador es la única fuente del repositorio que declara qué papel
# gramatical juega cada glosa al redactar. Se traduce a las funciones que pide
# el encargo sin perder el rol original, que queda registrado aparte.
FUNCION_POR_ROL = {
    "sujeto": "participante",
    "personaDesc": "participante",
    "testigo": "participante",
    "rasgo": "descriptor",
    "descriptor": "descriptor",
    "verboAccion": "accion",
    "verboAgresion": "accion",
    "objeto": "objeto",
    "documento": "evidencia",
    "lugar": "lugar",
    "institucion": "institucion",
    "servicio": "interaccion",
    "tramite": "interaccion",
    "emocion": "estado",
    "urgencia": "estado",
    "motivo": "motivo",
    "tiempo": "tiempo",
    "marcador": "marcador",
    "interrogativa": "interaccion",
}


def load_assembler_roles() -> dict:
    """{clave normalizada: (rol, lema español)} desde el ensamblador Dart."""
    src = open(ASSEMBLER, encoding="utf-8").read()
    out = {}
    for gloss, rol, es in re.findall(
            r"'([^']+)':\s*_Lex\(_Role\.(\w+),\s*'((?:[^'\\]|\\')*)'", src):
        out[C.norm(gloss)] = (rol, es.replace("\\'", "'"))
    return out


# --------------------------------------------------------------------------
# Necesidad: las tres entradas visuales del modo personal
# --------------------------------------------------------------------------
# Los ámbitos del grafo y los contextos del catálogo se agrupan en las tres
# necesidades. `identificacion`, `preguntas` y `otro` son transversales: no
# pertenecen a una necesidad, sirven a las tres. Transversal no significa
# "mostrar siempre": significa que la pertinencia la decide el campo que se
# está respondiendo, no la necesidad elegida.
NECESIDAD_POR_AMBITO = {
    "denuncia_robo": ["denuncias"],
    "violencia": ["denuncias"],
    "amenaza_digital": ["denuncias"],
    "engano_dinero": ["denuncias"],
    "seguimiento": ["tramites", "consultas"],
    "identificacion": ["denuncias", "tramites", "consultas"],
    "preguntas": ["denuncias", "tramites", "consultas"],
    "otro": ["denuncias", "tramites", "consultas"],
}

TRANSVERSALES = {"identificacion", "preguntas", "otro"}


def load_graph_usage() -> dict:
    """Uso real de cada glosa en el grafo: nodos, intenciones y campos."""
    graph = json.load(open(GRAPH, encoding="utf-8"))
    uso = {}
    for node in graph["nodes"]:
        for o in node.get("options", []):
            gloss = o.get("gloss")
            if not gloss:
                continue
            k = C.norm(gloss)
            reg = uso.setdefault(k, {
                "nodos": set(), "intenciones": set(),
                "campos": set(), "ambitos": set(), "actos": set(),
            })
            reg["nodos"].add(node["id"])
            reg["intenciones"].add(node["intent"])
            reg["campos"].update(node.get("slots", []))
            reg["ambitos"].add(node["scope"])
            reg["actos"].add(node["speechAct"])
    return uso


# --------------------------------------------------------------------------
# Restricciones de sentido conocidas y documentadas
# --------------------------------------------------------------------------
# Solo las que tienen respaldo en el corpus o en el código; no se inventan.
RESTRICCIONES = {
    "CELULAR": "Polisémica por papel, no por seña: objeto sustraído o medio "
               "de contacto. Lo decide el campo que se responde, no la "
               "necesidad activa.",
    "PERDER": "No equivale a ROBAR. El backend no puede derivar una "
              "afirmación de robo de una pérdida (auditoría 2026-09).",
    "ESCAPAR": "Es un hecho propio, no un calificador de robo. Seleccionarla "
               "sola no autoriza a redactar una denuncia de robo.",
    "TESTIGO": "NO + TESTIGO no fabrica testigos ni afirma que los haya. "
               "Ausencia de respuesta, negación e incertidumbre son estados "
               "distintos.",
    "CERTIFICADO": "Fuente léxica en sección escolar (M4 · Escuela II · "
                   "p.129). Su presencia NO valida los sentidos registrales "
                   "(certificado de propiedad, de no propiedad).",
    "FISCAL": "La entrada FISCAL de M3 significa «fiscal» como escuela "
              "pública. No reutilizar para el funcionario del Ministerio "
              "Público (corpus §4).",
    "PAPEL": "No es un documento genérico. No sustituye FOLIO REAL, "
             "ESCRITURA ni CÉDULA (corpus §4: preferir el objeto concreto).",
    "BILLETES": "No sustituye BILLETERA. Son cosas distintas.",
    "QUEJAR": "No es una seña directa de DENUNCIA. La composición "
              "QUEJAR + AUTORIDAD es provisional y está sin validar "
              "(corpus §4).",
    "TRÁMITE": "Entrada del Diccionario 2024 (p.216). Nombra la gestión, no "
               "un trámite institucional concreto ni su procedimiento.",
    "NO_SABER": "Expresa desconocimiento. No equivale a negar ni a omitir "
                "la respuesta: son tres estados distintos.",
}

# Conceptos que el encargo pide tratar explícitamente y que NO tienen entrada.
# Se registran como brecha, no se incorporan como señas nuevas.
BRECHAS_DECLARADAS = {
    "FOLIO": "consultas",
    "PAGAR": "tramites",
    "DOCUMENTO": "tramites",
    "PROPIEDAD": "tramites",
    "ESCRITURA": "tramites",
    "CEDULA": "identificacion",
    "ENTREGAR": "tramites",
    "REGISTRAR": "tramites",
    "CORREGIR": "tramites",
    "RENOVAR": "tramites",
    "JUICIO": "consultas",
    "BILLETERA": "denuncias",
    "ARMA": "denuncias",
    "NOCHE": "denuncias",
}


def build():
    resolver = C.ConceptResolver()
    doc = json.load(open(C.DICTIONARY_PATH, encoding="utf-8"))
    corpus12 = C.load_corpus_glosses()
    pendientes4 = C.load_pending_concepts()
    roles = load_assembler_roles()
    uso = load_graph_usage()

    filas = []
    for entry in doc["entries"]:
        k = C.norm(entry["gloss"])
        en_corpus = k in corpus12
        clase = clase_lexica(entry, en_corpus)
        rol, lema = roles.get(k, ("", ""))
        u = uso.get(k)

        # Necesidades: primero el uso real en el grafo; si no aparece en
        # ningún recorrido, se cae a los contextos declarados en el catálogo,
        # y eso se marca como evidencia más débil.
        if u:
            ambitos = sorted(u["ambitos"])
            fuente_necesidad = "uso en el grafo"
        else:
            ambitos = sorted(set(entry.get("contexts", [])))
            fuente_necesidad = "campo contexts del catálogo"

        necesidades, solo_transversal = set(), bool(ambitos)
        for a in ambitos:
            necesidades.update(NECESIDAD_POR_AMBITO.get(a, []))
            if a not in TRANSVERSALES:
                solo_transversal = False

        # Representación: mecanismo real, no el campo animationFile.
        if clase == CLASE_INSTITUCION:
            representacion = "dactilologia"
        elif clase == CLASE_LETRA:
            representacion = "letra_dactilologica"
        elif clase == CLASE_DIGITO:
            representacion = "digito"
        elif k in pendientes4:
            representacion = "concepto_pendiente"
        elif en_corpus:
            representacion = "sena_documentada"
        else:
            representacion = "cobertura_pendiente"

        avatar = ("baked" if k in resolver.baked
                  else "spelled" if k in resolver.spelled
                  else "placeholder")

        motivo_sin_uso = ""
        if not u:
            if clase in (CLASE_LETRA, CLASE_DIGITO):
                motivo_sin_uso = (
                    "Mecanismo de deletreo o numeración: se usa dentro de una "
                    "respuesta tipada, no como tarjeta de un nodo.")
            elif clase == CLASE_INSTITUCION:
                motivo_sin_uso = (
                    "Nombre institucional por dactilología: se ofrece en el "
                    "campo institución, no en los nodos del banco 6/7/8.")
            else:
                motivo_sin_uso = (
                    "Documentada en el corpus §12 pero ningún ejemplo de los "
                    "bancos 6/7/8 la utiliza. Se conserva en el catálogo y "
                    "queda disponible por categoría y buscador; no se le "
                    "asigna una necesidad sin uso que lo respalde.")

        filas.append({
            "id": entry["id"],
            "glosa": entry["gloss"],
            "glosaCanonica": entry.get("canonicalGloss", ""),
            "textoVisible": entry.get("displayText", ""),
            "claseLexica": clase,
            "significadoDocumentado": corpus12.get(k, {}).get("spanish", ""),
            "lemaEnsamblador": lema,
            "idCorpus": corpus12.get(k, {}).get("sourceId", ""),
            "referenciaCorpus": corpus12.get(k, {}).get("reference", ""),
            "auditoriaCorpus": corpus12.get(k, {}).get("audit", ""),
            "estadoValidacion": (
                "trazada en corpus §12" if en_corpus
                else "mecanismo de interfaz, sin entrada léxica"),
            "rolEnsamblador": rol,
            "funcionSemantica": FUNCION_POR_ROL.get(rol, "sin_rol_asignado"),
            "necesidades": sorted(necesidades),
            "fuenteNecesidad": fuente_necesidad,
            "soloTransversal": solo_transversal,
            "ambitos": ambitos,
            "intenciones": sorted(u["intenciones"]) if u else [],
            "camposRespuesta": sorted(u["campos"]) if u else [],
            "actosComunicativos": sorted(u["actos"]) if u else [],
            "nodosQueLaUsan": len(u["nodos"]) if u else 0,
            "representacion": representacion,
            "avatar": avatar,
            "prioridadCatalogo": entry.get("priority"),
            "frecuente": entry.get("isFrequent", False),
            "emergencia": entry.get("isEmergency", False),
            "categoria": entry.get("categoryId", ""),
            "subcategoria": entry.get("subcategoryId", ""),
            "restriccion": RESTRICCIONES.get(entry["gloss"], ""),
            "motivoSinUso": motivo_sin_uso,
        })

    brechas = []
    app = resolver.app
    for concepto, necesidad in BRECHAS_DECLARADAS.items():
        k = C.norm(concepto)
        brechas.append({
            "concepto": concepto,
            "necesidadAfectada": necesidad,
            "enCatalogo": k in app,
            "enCorpus12": k in corpus12,
            "deletreable": k in resolver.spelled,
            "tratamiento": (
                "Entrada existente: revisar sentido antes de usar."
                if k in app else
                "Sin entrada. No incorporar como seña nueva. Comunicar la "
                "parte cubierta y declarar la brecha; usar dactilología solo "
                "si el término literal es imprescindible y el mecanismo lo "
                "admite."),
        })

    return filas, brechas


def write_json(filas, brechas):
    payload = {
        "version": 1,
        "fuentes": {
            "catalogo": "assets/dictionary/official_dictionary.json",
            "corpus": os.path.basename(C.corpus_path()),
            "grafo": "assets/dialogue/dialogue_graph.json",
            "ensamblador": "lib/core/domain/services/local_sentence_assembler.dart",
            "avatar": "lib/core/domain/services/animation_url_resolver.dart",
        },
        "conteos": _conteos(filas),
        "entradas": filas,
        "brechasDeclaradas": brechas,
    }
    with open(os.path.join(OUT_DIR, "vocabulario.json"), "w",
              encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
        f.write("\n")


CSV_COLS = [
    "id", "glosa", "claseLexica", "significadoDocumentado", "idCorpus",
    "referenciaCorpus", "estadoValidacion", "rolEnsamblador",
    "funcionSemantica", "necesidades", "fuenteNecesidad", "soloTransversal",
    "camposRespuesta", "actosComunicativos", "nodosQueLaUsan",
    "representacion", "avatar", "restriccion", "motivoSinUso",
]


def write_csv(filas):
    path = os.path.join(OUT_DIR, "vocabulario.csv")
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(CSV_COLS)
        for r in filas:
            w.writerow([
                "|".join(r[c]) if isinstance(r[c], list) else r[c]
                for c in CSV_COLS
            ])


def _conteos(filas):
    def n(clase):
        return sum(1 for r in filas if r["claseLexica"] == clase)

    usadas = sum(1 for r in filas if r["nodosQueLaUsan"] > 0)
    return {
        "entradasCatalogo": len(filas),
        "senasLexicas": n(CLASE_SENA),
        "letrasDactilologicas": n(CLASE_LETRA),
        "digitos": n(CLASE_DIGITO),
        "institucionesDactilologicas": n(CLASE_INSTITUCION),
        "conUsoEnGrafo": usadas,
        "sinUsoEnGrafo": len(filas) - usadas,
        "sinRolEnEnsamblador": sum(
            1 for r in filas if r["funcionSemantica"] == "sin_rol_asignado"),
        "avatarHorneado": sum(1 for r in filas if r["avatar"] == "baked"),
    }


def write_markdown(filas, brechas):
    c = _conteos(filas)
    L = [
        "# Matriz de vocabulario — clasificación completa del catálogo",
        "",
        "Generado por `tool/build_vocabulary_matrix.py`. No editar a mano.",
        "Formato procesable: `vocabulario.json` y `vocabulario.csv`.",
        "",
        "Cada entrada se clasifica contra las fuentes del repositorio, sin",
        "añadir sentidos que ninguna de ellas respalde.",
        "",
        "## 1. Composición del catálogo",
        "",
        "El conteo léxico y el de mecanismos van separados, como pide el",
        "encargo: las letras, los dígitos y los nombres institucionales no",
        "son señas del corpus.",
        "",
        "| Clase | Entradas | Qué es |",
        "|---|---:|---|",
        f"| Seña léxica | {c['senasLexicas']} | Documentada en el corpus §12 |",
        f"| Letra dactilológica | {c['letrasDactilologicas']} | Alfabeto, "
        "mecanismo de deletreo |",
        f"| Dígito | {c['digitos']} | Mecanismo de numeración |",
        f"| Institución por dactilología | "
        f"{c['institucionesDactilologicas']} | `canonicalGloss: d(...)` |",
        f"| **Total del catálogo** | **{c['entradasCatalogo']}** | |",
        "",
        "**Conteo léxico real: "
        f"{c['senasLexicas']} señas.** Las otras "
        f"{c['entradasCatalogo'] - c['senasLexicas']} entradas son mecanismos "
        "de representación.",
        "",
        "## 2. Cobertura de uso y de avatar",
        "",
        "| Indicador | Valor | Lectura |",
        "|---|---:|---|",
        f"| Con uso en algún recorrido del grafo | {c['conUsoEnGrafo']} | "
        "Tienen al menos un nodo que las ofrece |",
        f"| Sin uso en el grafo | {c['sinUsoEnGrafo']} | Accesibles por "
        "categoría y buscador; no se les asigna necesidad sin respaldo |",
        f"| Sin rol en el ensamblador | {c['sinRolEnEnsamblador']} | No "
        "pueden integrarse en una oración: brecha de redacción |",
        f"| Ejecutables por el avatar | {c['avatarHorneado']} | El resto se "
        "deletrea o se muestra como marcador |",
        "",
        "## 3. Funciones semánticas presentes",
        "",
        "| Función | Entradas |",
        "|---|---:|",
    ]
    from collections import Counter
    for fn, n in Counter(r["funcionSemantica"] for r in filas).most_common():
        L.append(f"| `{fn}` | {n} |")

    L += [
        "",
        "## 4. Restricciones de sentido y combinación",
        "",
        "Solo las que tienen respaldo en el corpus o en el código.",
        "",
        "| Glosa | Restricción |",
        "|---|---|",
    ]
    for r in filas:
        if r["restriccion"]:
            L.append(f"| `{r['glosa']}` | {r['restriccion']} |")

    L += [
        "",
        "## 5. Brechas declaradas",
        "",
        "Conceptos que los recorridos propuestos necesitan y que el catálogo",
        "no tiene. Ninguno se incorpora como seña nueva.",
        "",
        "| Concepto | Necesidad afectada | ¿En catálogo? | ¿En corpus §12? | Tratamiento |",
        "|---|---|:-:|:-:|---|",
    ]
    for b in brechas:
        L.append(
            f"| `{b['concepto']}` | {b['necesidadAfectada']} | "
            f"{'sí' if b['enCatalogo'] else 'no'} | "
            f"{'sí' if b['enCorpus12'] else 'no'} | {b['tratamiento']} |")

    L += [
        "",
        "## 6. Entradas sin uso documentado en los recorridos",
        "",
        "Se conservan en el catálogo. No se les fuerza una necesidad para que",
        "aparezcan en pantalla.",
        "",
        "| Glosa | Clase | Motivo |",
        "|---|---|---|",
    ]
    sin_uso = [r for r in filas
               if r["nodosQueLaUsan"] == 0 and r["claseLexica"] == CLASE_SENA]
    for r in sin_uso:
        L.append(f"| `{r['glosa']}` | {r['claseLexica']} | {r['motivoSinUso']} |")
    L.append("")
    L.append(f"Total sin uso en recorridos, entre las señas léxicas: "
             f"**{len(sin_uso)}**.")

    L += [
        "",
        "## 7. Clasificación completa",
        "",
        "| ID | Glosa | Clase | Función | Necesidades | Campos | Representación | Avatar |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for r in filas:
        L.append(
            f"| `{r['id']}` | `{r['glosa']}` | {r['claseLexica']} | "
            f"{r['funcionSemantica']} | {', '.join(r['necesidades']) or '—'} | "
            f"{', '.join(r['camposRespuesta']) or '—'} | "
            f"{r['representacion']} | {r['avatar']} |")
    L.append("")

    with open(os.path.join(OUT_DIR, "01_Matriz_Vocabulario.md"), "w",
              encoding="utf-8") as f:
        f.write("\n".join(L))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    filas, brechas = build()
    write_json(filas, brechas)
    write_csv(filas)
    write_markdown(filas, brechas)
    c = _conteos(filas)
    for k, v in c.items():
        print(f"  {k}: {v}")
    print("escrito: docs/negocio/vocabulario.json, vocabulario.csv, "
          "01_Matriz_Vocabulario.md")


if __name__ == "__main__":
    main()
