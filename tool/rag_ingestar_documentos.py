"""Prepara documentos (PDF, .md, .txt) para ampliar el corpus RAG.

    python tool/rag_ingestar_documentos.py

Para cada archivo de `docs/negocio/rag/documentos/`:

1. **Detecta el formato por su firma**, no por la extensión
   (`tool/rag_texto.py`): un PDF guardado como `.md` se lee como PDF; la
   copia como texto de un PDF (`%PDF-1.4 … /BaseFont … endobj`, con «�»
   donde iban los datos comprimidos) se rechaza: lo perdido no se recupera
   y hace falta el PDF original.
2. **Extrae el texto por página** y lo normaliza sin cambiar lo que dice
   (Unicode NFC, espacios raros, guiones blandos; conserva tildes, ñ, ¿ ¡,
   cifras y nombres).
3. **Revisa** cada página: caracteres de reemplazo, de control, de uso
   privado, mojibake o sintaxis de PDF detienen el documento con su página,
   línea y columna; una página sin texto pide OCR.
4. Solo si pasa la revisión, guarda el texto en
   `documentos/extraido/<nombre>.md` (texto extraído para leer y citar
   como `documentos/<archivo>#p=N`; **no** es un archivo de escenarios) y:
   * si es un **documento oficial**, escribe en
     `docs/negocio/rag/pendientes/<nombre>_prompt.md` un prompt que pide
     escenarios **solo** con lo que dice el documento, con los siguientes
     identificadores libres de cada área y las reglas y el formato de
     `prompt_investigacion_chatgpt.md`;
   * si ya es un **documento de escenarios** (una página por escenario,
     «ESC-DDRR-05 / …»), escribe el borrador
     `pendientes/<nombre>_escenarios.md` (`tool/rag_documento_escenarios.py`)
     y lo valida junto al corpus activo sin escribir nada más.

Lo que sale de aquí se revisa y se mueve a `docs/negocio/rag/escenarios/`.
Después:

    python tool/rag_actualizar.py

No llama a ningún modelo ni toca el corpus activo. Un documento que no
cambió (misma huella SHA-256) no se vuelve a procesar. Devuelve 1 si algún
documento no se pudo usar.
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
import rag_documento_escenarios as D  # noqa: E402
import rag_texto as T  # noqa: E402

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


class DocumentoInutilizable(Exception):
    """El documento no se puede usar tal como está; el mensaje dice por qué
    y qué hace falta."""


def paginas(ruta: str, formato: dict | None = None) -> list:
    """Texto crudo de cada página, según el formato real del archivo. Un
    texto es una sola página."""
    formato = formato or T.detectar_formato(ruta)
    nombre = os.path.basename(ruta)
    tipo = formato["formato"]
    if tipo == "pdf":
        from pypdf import PdfReader
        from pypdf.errors import PdfReadError
        try:
            lector = PdfReader(ruta)
            if lector.is_encrypted and not lector.decrypt(""):
                raise DocumentoInutilizable(
                    f"{nombre} es un PDF protegido con contraseña: hace falta "
                    "una copia sin protección.")
            return [p.extract_text() or "" for p in lector.pages]
        except (PdfReadError, ValueError, KeyError) as e:
            raise DocumentoInutilizable(
                f"{nombre} empieza como PDF pero está dañado ({e}): hace falta "
                "volver a descargar o exportar el PDF original.") from e
    if tipo == "copia_pdf":
        raise DocumentoInutilizable(
            f"{nombre} es una copia como texto de un PDF (contiene "
            f"{formato['detalle']}): el contenido comprimido se perdió al "
            "copiarlo y no se puede recuperar. Hace falta el PDF original "
            "(.pdf), sin abrirlo ni guardarlo como texto.")
    if tipo == "binario":
        raise DocumentoInutilizable(
            f"{nombre} no es PDF ni texto ({formato['detalle']}): expórtalo "
            "como PDF o como texto UTF-8.")
    if tipo == "no_utf8":
        raise DocumentoInutilizable(
            f"{nombre} no está en UTF-8 ({formato['detalle']}): guárdalo en "
            "UTF-8; no se adivina la codificación para no cambiar letras.")
    if tipo == "vacio":
        raise DocumentoInutilizable(f"{nombre} está vacío.")
    with open(ruta, encoding="utf-8") as f:
        return [f.read()]


def revisar(nombre: str, crudas: list) -> tuple:
    """(páginas normalizadas, errores, avisos) del texto extraído."""
    textos, errores, avisos = [], [], []
    cambios = set()
    for n, cruda in enumerate(crudas, 1):
        texto, hechos = T.normalizar(cruda)
        cambios.update(hechos)
        textos.append((n, texto))
        donde = f"{nombre} página {n}, " if len(crudas) > 1 else f"{nombre}, "
        errores += T.resumir(T.problemas(texto), donde)
    vacias = [n for n, t in textos if not t]
    if vacias and len(vacias) == len(textos):
        errores.append(f"{nombre}: no tiene texto extraíble (¿PDF escaneado? "
                       "hace falta OCR antes de usarlo)")
    elif vacias:
        avisos.append(f"aviso {nombre}: páginas sin texto {vacias}: hace falta "
                      "OCR para ellas; su contenido no llega al corpus")
    if cambios:
        avisos.append(f"normalizado {nombre}: {', '.join(sorted(cambios))}")
    return textos, errores, avisos


def instituciones_activas() -> dict:
    """{área: (institución de sus escenarios, institución de sus fuentes)}
    del corpus activo."""
    fuentes, _, escenarios, *_ = B.leer_todos(B.ESCENARIOS)
    out = {}
    for e in escenarios:
        area = e["id"].split("-")[1]
        de_fuente = next((f["institucion"] for fid, f in fuentes.items()
                          if fid.split("-")[1] == area), None)
        nombre = e["meta"].get("institucion")
        if nombre and area not in out:
            out[area] = (nombre, de_fuente or nombre)
    return out


def validar_borrador(ruta: str) -> tuple:
    """(errores, avisos, frases sin glosas) del borrador junto al corpus
    activo, sin escribir nada."""
    leido = B.leer_todos(B.ESCENARIOS, extras=[ruta])
    fuentes, hechos, escenarios, errores, avisos, archivos = leido
    corpus = B.construir(fuentes, hechos, escenarios, errores, avisos,
                         archivos=archivos)
    propio = B._rel(ruta)
    cache = B._leer(B.GLOSAS)
    faltan = set()
    for e in corpus["escenarios"]:
        if e["archivo"] != propio:
            continue
        for t in B.frases_a_traducir(e):
            if t["texto"] not in cache:
                faltan.add(t["texto"])
    return errores, avisos, len(faltan)


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

    formato = T.detectar_formato(ruta)
    avisos = []
    if formato["formato"] in ("pdf", "texto") and not formato["coincide"]:
        leido = "PDF" if formato["formato"] == "pdf" else "texto"
        avisos.append(f"aviso {nombre}: la extensión «{formato['extension']}» "
                      f"no corresponde al contenido; se lee como {leido}")
    try:
        crudas = paginas(ruta, formato)
    except DocumentoInutilizable as e:
        return [f"ERROR {e}"]
    textos, errores, mas = revisar(nombre, crudas)
    avisos += mas
    if errores:
        # Nada se escribe: un texto dañado no se resume, no se cita ni se
        # convierte en escenarios.
        return ([f"ERROR {e}" for e in errores]
                + [f"ERROR {nombre}: no se usa. Revisa esas páginas en el "
                   "documento original; lo que falta no se reconstruye."]
                + avisos)

    os.makedirs(EXTRAIDO, exist_ok=True)
    with open(extraido, "w", encoding="utf-8", newline="") as f:
        f.write(f"<!-- origen: documentos/{nombre} · huella: {marca} · "
                f"formato: {formato['formato']} · texto extraído para leer y "
                "citar; no es un archivo de escenarios -->\n")
        f.write(f"# {nombre}\n\n")
        for n, t in textos:
            f.write(f"## Página {n}\n\n{t}\n\n")
    avisos.append(f"texto: {B._rel(extraido)}")

    if D.es_documento_de_escenarios(textos):
        return [f"procesado: {nombre} ({len(textos)} páginas, documento de "
                "escenarios)"] + avisos + borrador(nombre, s, textos, marca)

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


def borrador(nombre: str, s: str, textos: list, marca: str) -> list:
    """Escribe y valida el borrador de un documento de escenarios."""
    md, errores = D.convertir(nombre, textos, marca, instituciones_activas())
    os.makedirs(PENDIENTES, exist_ok=True)
    destino = os.path.join(PENDIENTES, f"{s}_escenarios.md")
    if errores:
        if os.path.exists(destino):
            os.remove(destino)
        return [f"ERROR {nombre}: {e}" for e in errores] + [
            f"ERROR {nombre}: no se escribe el borrador."]
    with open(destino, "w", encoding="utf-8", newline="") as f:
        f.write(md)
    errores, avisos, faltan = validar_borrador(destino)
    salida = [f"borrador: {B._rel(destino)}"]
    salida += [f"aviso borrador: {a}" for a in avisos]
    salida += [f"ERROR borrador: {e}" for e in errores]
    if errores:
        salida.append(f"ERROR {nombre}: el borrador no pasa la validación; "
                      "corrígelo antes de moverlo a escenarios/.")
    else:
        salida.append(
            f"validado junto al corpus activo: sin errores · {faltan} frases "
            "por traducir. Revísalo, muévelo a docs/negocio/rag/escenarios/ y "
            "ejecuta python tool/rag_actualizar.py")
    return salida


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
    fallos = 0
    for ruta in archivos:
        lineas = procesar(ruta, ids)
        for linea in lineas:
            print(linea)
        fallos += any(l.startswith("ERROR") for l in lineas)
    if fallos:
        print(f"{fallos} documentos no se pudieron usar: el corpus activo no "
              "cambió.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
