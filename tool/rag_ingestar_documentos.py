"""Prepara documentos oficiales (PDF, .md, .txt) para ampliar el corpus RAG.

    python tool/rag_ingestar_documentos.py

Para cada archivo de `docs/negocio/rag/documentos/`:

1. Extrae su texto por página en `documentos/extraido/<nombre>.md`, para
   poder revisarlo y citarlo (`documentos/<archivo>#p=N`).
2. Escribe en `docs/negocio/rag/pendientes/<nombre>_prompt.md` un prompt
   listo para ChatGPT (u otro modelo) que pide escenarios **solo** con lo que
   dice ese documento, citando su página. El prompt lleva los siguientes
   identificadores libres de cada área, para que lo nuevo no choque con lo
   existente, y las reglas y el formato del prompt de investigación
   (`prompt_investigacion_chatgpt.md`), que siguen siendo la única fuente.

La respuesta del modelo se guarda como un `.md` más en
`docs/negocio/rag/escenarios/` y se revisa. Después:

    python tool/rag_actualizar.py

No llama a ningún modelo: preparar el prompt no cuesta nada y la revisión
humana sigue antes de que algo llegue a la app. Un documento que no cambió
(misma huella SHA-256) no se vuelve a procesar.
"""

from __future__ import annotations

import glob
import hashlib
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

import build_rag_corpus as B  # noqa: E402

EXTRAIDO = os.path.join(B.DOCUMENTOS, "extraido")
PENDIENTES = os.path.join(B.RAG, "pendientes")
PROMPT_BASE = os.path.join(B.RAG, "prompt_investigacion_chatgpt.md")
EXTENSIONES = (".pdf", ".md", ".txt")

# Un prompt más largo se divide en partes: los modelos recortan el texto
# pegado demasiado largo sin avisar.
MAX_CARACTERES = 45000


def slug(nombre: str) -> str:
    base = os.path.splitext(os.path.basename(nombre))[0]
    return re.sub(r"[^a-z0-9]+", "_", B._norm(base)).strip("_")


def huella(ruta: str) -> str:
    with open(ruta, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def paginas(ruta: str) -> list:
    """Texto de cada página. Un .md o .txt es una sola página."""
    if ruta.lower().endswith(".pdf"):
        from pypdf import PdfReader
        return [(p.extract_text() or "").strip() for p in PdfReader(ruta).pages]
    with open(ruta, encoding="utf-8") as f:
        return [f.read().strip()]


def siguientes_ids() -> dict:
    """Siguiente número libre por área y tipo (ESC, F, H) en todo el corpus."""
    fuentes, hechos, escenarios, *_ = B.leer_todos(B.ESCENARIOS)
    maximo = {}
    ids = list(fuentes) + list(hechos) + [e["id"] for e in escenarios]
    for i in ids:
        m = re.fullmatch(r"(ESC|F|H)-([A-Z]+)-(\d+)", i)
        if m:
            clave = (m.group(2), m.group(1))
            maximo[clave] = max(maximo.get(clave, 0), int(m.group(3)))
    return maximo


def seccion(texto: str, titulo: str) -> str:
    """Una sección `## titulo` del prompt base, hasta la siguiente."""
    m = re.search(rf"^## {re.escape(titulo)}\n(.*?)(?=^## |\Z)", texto,
                  re.MULTILINE | re.DOTALL)
    return m.group(1).strip() if m else ""


def prompt(nombre: str, textos: list, parte: int, total: int, ids: dict) -> str:
    with open(PROMPT_BASE, encoding="utf-8") as f:
        base = f.read()
    areas = sorted({a for a, _ in ids})
    tabla = "\n".join(
        f"| {a} | ESC-{a}-{ids.get((a, 'ESC'), 0) + 1:02d} | "
        f"F-{a}-{ids.get((a, 'F'), 0) + 1:02d} | H-{a}-{ids.get((a, 'H'), 0) + 1:02d} |"
        for a in areas
    )
    paginas_md = "\n\n".join(f"### Página {n}\n\n{t}" for n, t in textos)
    return f"""# Escenarios a partir de un documento oficial — {nombre} (parte {parte} de {total})

## Tarea

Eres un investigador de trámites públicos de Bolivia. Con **únicamente** el
documento de abajo, escribe escenarios de diálogo entre un **Usuario Sordo** y
un **Funcionario** de ventanilla en Cochabamba. No uses conocimiento propio ni
otras fuentes: si el documento no dice un dato, escribe `[VERIFICAR]`.

- Cita el documento como fuente con la URL exacta
  `documentos/{nombre}#p=<página>` (la página de donde sale el dato) y fecha
  de consulta de hoy.
- Usa el código de área que corresponda. Si el documento es de una
  institución nueva, crea un código nuevo en mayúsculas (3 a 6 letras).
- **No reutilices identificadores.** Empieza en los siguientes libres:

| Área | Escenario | Fuente | Hecho |
|---|---|---|---|
{tabla}

Para un área nueva, empieza en 01.

## Reglas de veracidad (obligatorias)

{seccion(base, "Reglas de veracidad (obligatorias)")}

## Estilo de los diálogos

{seccion(base, "Estilo de los diálogos")}

## Formato de salida (respétalo exactamente; se procesa con un programa)

{seccion(base, "Formato de salida (respétalo exactamente; se procesa con un programa)")}

## Documento: {nombre}

{paginas_md}
"""


def procesar(ruta: str, ids: dict) -> list:
    nombre = os.path.basename(ruta)
    s = slug(nombre)
    marca = huella(ruta)
    extraido = os.path.join(EXTRAIDO, f"{s}.md")
    if os.path.exists(extraido):
        with open(extraido, encoding="utf-8") as f:
            if f"huella: {marca}" in f.read(2000):
                return [f"sin cambios: {nombre}"]

    textos = [(n, t) for n, t in enumerate(paginas(ruta), 1)]
    avisos = []
    vacias = [n for n, t in textos if not t]
    if len(vacias) == len(textos):
        return [f"AVISO {nombre}: no tiene texto extraíble (¿PDF escaneado? "
                "hace falta OCR antes de usarlo)"]
    if vacias:
        avisos.append(f"aviso {nombre}: páginas sin texto {vacias}")

    os.makedirs(EXTRAIDO, exist_ok=True)
    with open(extraido, "w", encoding="utf-8", newline="") as f:
        f.write(f"<!-- origen: documentos/{nombre} · huella: {marca} -->\n")
        f.write(f"# {nombre}\n\n")
        for n, t in textos:
            f.write(f"## Página {n}\n\n{t}\n\n")

    # Partes que no superan el límite, sin cortar una página.
    partes, actual, largo = [], [], 0
    for n, t in textos:
        if actual and largo + len(t) > MAX_CARACTERES:
            partes.append(actual)
            actual, largo = [], 0
        actual.append((n, t))
        largo += len(t)
    if actual:
        partes.append(actual)

    os.makedirs(PENDIENTES, exist_ok=True)
    for viejo in glob.glob(os.path.join(PENDIENTES, f"{s}_prompt*.md")):
        os.remove(viejo)
    for i, parte in enumerate(partes, 1):
        sufijo = "" if len(partes) == 1 else f"_parte{i}"
        destino = os.path.join(PENDIENTES, f"{s}_prompt{sufijo}.md")
        with open(destino, "w", encoding="utf-8", newline="") as f:
            f.write(prompt(nombre, parte, i, len(partes), ids))
        avisos.append(f"prompt: {B._rel(destino)}")
    return [f"procesado: {nombre} ({len(textos)} páginas)"] + avisos


def main() -> int:
    archivos = sorted(
        r for r in glob.glob(os.path.join(B.DOCUMENTOS, "*"))
        if os.path.isfile(r) and r.lower().endswith(EXTENSIONES)
        and os.path.basename(r).lower() != "readme.md"
    )
    if not archivos:
        print(f"No hay documentos en {B._rel(B.DOCUMENTOS)} (PDF, .md o .txt).")
        return 0
    ids = siguientes_ids()
    for ruta in archivos:
        for linea in procesar(ruta, ids):
            print(linea)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
