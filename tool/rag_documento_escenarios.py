"""Convierte un documento de escenarios ya redactado (PDF) en un borrador
`.md` con el formato que procesa `tool/build_rag_corpus.py`.

Lo usa `tool/rag_ingestar_documentos.py` cuando el documento no es una
fuente oficial sino una propuesta de escenarios (una página por escenario,
«ESC-DDRR-05 / CERTIFICADOS Y CONSULTAS», su diálogo numerado, sus variantes
y respuestas y, al final, sus fuentes). Solo reordena lo que el documento
dice: no añade hechos, requisitos, precios ni condiciones.

* Las respuestas «Sí / No / No sé» quedan como respuestas documentadas.
* «Escenarios posibles» es una descripción narrativa: se copia como nota y
  **no** crea ramificaciones. Una dependencia entre preguntas se declara a
  mano en `### Ramificaciones` (ver `docs/negocio/rag/README.md`).
* Cada escenario cita la página del PDF de donde sale
  (`- **Documento:** documentos/<archivo>#p=N`).

El borrador va a `docs/negocio/rag/pendientes/` y se revisa antes de
moverlo a `escenarios/`.
"""

from __future__ import annotations

import re

_CABECERA = re.compile(r"^(ESC-[A-Z]+-\d+)\s*/\s*(.+)$")
_ROLES = {"funcionario": "Funcionario", "persona usuaria": "Usuario Sordo",
          "usuario sordo": "Usuario Sordo", "persona sorda": "Usuario Sordo",
          "usuaria sorda": "Usuario Sordo"}
_TURNOS = "PREGUNTAS EN UNA SECUENCIA POSIBLE"
_VARIANTES = "VARIANTES Y RESPUESTAS POSIBLES"
_POSIBLES = "ESCENARIOS POSIBLES"


def es_documento_de_escenarios(paginas: list) -> bool:
    """Si alguna página empieza con la cabecera de un escenario."""
    return any(ls and _CABECERA.match(ls[0]) for _, ls in _sin_pie(paginas))


def _lineas(texto: str) -> list:
    return [l.strip() for l in texto.split("\n") if l.strip()]


def _sin_pie(paginas: list) -> list:
    """Quita el número de página («3 / 35») y el encabezado o pie: la primera
    o última línea que se repite en la mayoría de las páginas. Solo en los
    bordes: los títulos de sección también se repiten en cada página."""
    limpias = [(n, [l for l in _lineas(t)
                    if not re.fullmatch(r"\d+\s*/\s*\d+", l)])
               for n, t in paginas]
    bordes = {}
    for _, ls in limpias:
        for l in ({ls[0], ls[-1]} if ls else ()):
            bordes[l] = bordes.get(l, 0) + 1
    repetidas = {l for l, c in bordes.items()
                 if len(limpias) > 2 and c > len(limpias) / 2}
    out = []
    for n, ls in limpias:
        while ls and ls[-1] in repetidas:
            ls = ls[:-1]
        while ls and ls[0] in repetidas:
            ls = ls[1:]
        out.append((n, ls))
    return out


def _unir(lineas: list) -> str:
    return re.sub(r"\s+", " ", " ".join(lineas)).strip()


def _partes(texto: str) -> list:
    return [p.strip() for p in texto.split(" / ") if p.strip()]


def _celda(texto: str) -> str:
    return texto.replace("|", "/")


def _escenario(n_pagina: int, lineas: list, errores: list) -> dict | None:
    m = _CABECERA.match(lineas[0])
    eid = m.group(1)
    donde = f"página {n_pagina} ({eid})"
    try:
        i_sit = next(i for i, l in enumerate(lineas) if l.startswith("Situación:"))
        i_tur = lineas.index(_TURNOS)
        i_var = lineas.index(_VARIANTES)
    except (StopIteration, ValueError):
        errores.append(f"{donde}: falta «Situación:», «{_TURNOS}» o «{_VARIANTES}»")
        return None
    i_pos = lineas.index(_POSIBLES) if _POSIBLES in lineas else len(lineas)
    titulo = _unir(lineas[1:i_sit])
    situacion = _unir([lineas[i_sit][len("Situación:"):]] + lineas[i_sit + 1:i_tur])

    turnos, actual = [], None
    for l in lineas[i_tur + 1:i_var]:
        if re.fullmatch(r"\d{1,2}", l):
            actual = {"n": int(l), "rol": [], "texto": []}
            turnos.append(actual)
        elif actual is None:
            errores.append(f"{donde}: texto antes del primer turno «{l}»")
        elif not actual["texto"] and _norm_rol(actual["rol"]) not in _ROLES:
            actual["rol"].append(l)
        else:
            actual["texto"].append(l)
    for k, t in enumerate(turnos, 1):
        rol = _ROLES.get(_norm_rol(t["rol"]))
        if t["n"] != k or rol is None or not t["texto"]:
            errores.append(f"{donde}: turno {t['n']} ilegible (rol "
                           f"«{' '.join(t['rol'])}»)")
            return None
        t["rol"] = rol
        t["texto"] = _unir(t["texto"])

    bloques, actual = [], None
    for l in lineas[i_var + 1:i_pos]:
        mp = re.match(r"P(\d+)\.\s*(.*)", l)
        if mp:
            actual = {"pregunta": [mp.group(2)], "variantes": [],
                      "respuestas": [], "en": "pregunta"}
            bloques.append(actual)
        elif actual is None:
            errores.append(f"{donde}: texto antes de la primera pregunta «{l}»")
        elif l.startswith("Variantes:"):
            actual["en"] = "variantes"
            actual["variantes"].append(l[len("Variantes:"):])
        elif l.startswith("Respuestas:"):
            actual["en"] = "respuestas"
            actual["respuestas"].append(l[len("Respuestas:"):])
        else:
            actual[actual["en"]].append(l)
    variantes = []
    for b in bloques:
        pregunta = _unir(b["pregunta"])
        turno = next((t for t in turnos if t["rol"] == "Funcionario"
                      and t["texto"] == pregunta), None)
        if turno is None:
            errores.append(f"{donde}: la pregunta «{pregunta}» de las variantes "
                           "no está en el diálogo")
            continue
        variantes.append((turno["n"], _partes(_unir(b["variantes"])),
                          _partes(_unir(b["respuestas"]))))

    narrativa, referencia, tipo = [], "", ""
    for l in lineas[i_pos + 1:]:
        if l.startswith("Referencia temática:"):
            resto = _unir([l] + lineas[lineas.index(l) + 1:])
            mr = re.search(r"Referencia temática:\s*([^·]+)", resto)
            mt = re.search(r"Tipo:\s*([a-z_]+)", resto)
            referencia = mr.group(1).strip() if mr else ""
            tipo = mt.group(1) if mt else ""
            break
        narrativa.append(l)
    return {"id": eid, "categoria": m.group(2).strip(), "titulo": titulo,
            "situacion": situacion, "turnos": turnos, "variantes": variantes,
            "narrativa": _unir(narrativa), "referencia": referencia,
            "tipo": tipo, "pagina": n_pagina}


def _norm_rol(partes: list) -> str:
    return " ".join(partes).strip().lower()


def _fuentes(lineas: list) -> tuple:
    """(fecha de consulta, [(id, título, url)]) de la página de fuentes."""
    texto = "\n".join(lineas)
    m = re.search(r"Consultad[oa]s? el (\d{4}-\d{2}-\d{2})", texto)
    fecha = m.group(1) if m else ""
    out = []
    for i, l in enumerate(lineas):
        mf = re.match(r"(F-[A-Z]+-\d+)\s*·\s*(.+)", l)
        if not mf:
            continue
        url = ""
        for siguiente in lineas[i + 1:]:
            if re.match(r"F-[A-Z]+-\d+", siguiente) or " " in siguiente:
                break
            url += siguiente
        out.append((mf.group(1), mf.group(2).strip(), url))
    return fecha, out


def convertir(nombre: str, paginas: list, huella: str,
              instituciones: dict) -> tuple:
    """(markdown, errores) del borrador de escenarios de [paginas].

    [instituciones] da el nombre de la institución de cada área
    (`{"DDRR": ("Derechos Reales – Cochabamba", "Derechos Reales")}`, el del
    escenario y el de la fuente) tomado del corpus activo; un área nueva
    queda `[VERIFICAR]`.
    """
    errores, escenarios = [], []
    fecha, fuentes = "", []
    for n, lineas in _sin_pie(paginas):
        if not lineas:
            continue
        if _CABECERA.match(lineas[0]):
            e = _escenario(n, lineas, errores)
            if e:
                escenarios.append(e)
        elif any(re.match(r"F-[A-Z]+-\d+\s*·", l) for l in lineas):
            fecha, fuentes = _fuentes(lineas)
    if not escenarios:
        errores.append("no se reconoció ningún escenario")
    if not fuentes:
        errores.append("no se encontró la lista de fuentes (F-…-NN · título y URL)")
    if fuentes and not fecha:
        errores.append("las fuentes no dicen su fecha de consulta")

    def institucion(area: str, de_fuente: bool = False) -> str:
        par = instituciones.get(area)
        return (par[1] if de_fuente else par[0]) if par else "[VERIFICAR]"

    md = [
        # Lo que entra desde un documento solo admite señas del léxico LSB
        # (tool/build_rag_corpus.py, MARCA_ESTRICTA).
        "<!-- lexico: estricto -->",
        f"<!-- Borrador generado por tool/rag_ingestar_documentos.py desde "
        f"documentos/{nombre} (huella: {huella}). Revísalo y muévelo a "
        "escenarios/ para incorporarlo; después ejecuta "
        "tool/rag_actualizar.py. «Escenarios posibles» es una nota narrativa: "
        "no crea ramificaciones; decláralas en «### Ramificaciones». -->",
        f"# Escenarios desde {nombre}",
        "",
        "## Fuentes",
        "| ID | Institución | Título | URL | Consultado |",
        "|---|---|---|---|---|",
    ]
    for fid, titulo, url in fuentes:
        area = fid.split("-")[1]
        md.append(f"| {fid} | {_celda(institucion(area, True))} | "
                  f"{_celda(titulo)} | {url} | {fecha} |")
    md += ["", "## Hechos verificados",
           "| ID | Institución | Hecho | Tipo | Fuente | Vigencia |",
           "|---|---|---|---|---|---|", ""]
    for e in escenarios:
        area = e["id"].split("-")[1]
        md += [
            f"## {e['id']} — {e['titulo']}",
            "",
            f"- **Institución:** {institucion(area)}",
            f"- **Trámite:** {e['titulo']}",
            f"- **Tipo:** {e['tipo'] or '[VERIFICAR]'}",
            f"- **Inicia:** {e['turnos'][0]['rol'] if e['turnos'] else ''}",
            f"- **Situación:** {e['situacion']}",
        ]
        if e["referencia"]:
            md.append(f"- **Referencia:** {e['referencia']}")
        md += [f"- **Documento:** documentos/{nombre}#p={e['pagina']}", "",
               "| # | Rol | Mensaje | Propósito | Hechos |",
               "|---|---|---|---|---|"]
        for t in e["turnos"]:
            md.append(f"| {t['n']} | {t['rol']} | {_celda(t['texto'])} | — | — |")
        if e["variantes"]:
            md += ["", "### Variantes", ""]
            for n, preguntas, respuestas in e["variantes"]:
                md.append(f"- **Turno {n} (Funcionario):** "
                          + " · ".join(f"«{p}»" for p in preguntas))
                md.append("- **Respuestas:** "
                          + " · ".join(f"«{r}»" for r in respuestas))
        if e["narrativa"]:
            md += ["", "### Escenarios posibles", "",
                   "Nota narrativa del documento (no crea ramificaciones): "
                   + e["narrativa"]]
        md.append("")
    return "\n".join(md), errores
