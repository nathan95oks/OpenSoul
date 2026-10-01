"""Formato y calidad del texto que entra al corpus RAG.

Lo usan `tool/rag_ingestar_documentos.py` (documentos oficiales) y
`tool/build_rag_corpus.py` (archivos de escenarios):

* `detectar_formato` mira la firma del archivo, no su extensión: un PDF
  guardado como `.md` se lee como PDF, y la copia como texto de un PDF
  (`%PDF-1.4 … /BaseFont /Helvetica … endobj`) se rechaza: sus flujos
  comprimidos se perdieron al copiarla y el texto no se puede recuperar.
* `normalizar` solo unifica lo invisible (Unicode NFC, espacios raros,
  guiones blandos, saltos de línea). Nunca quita tildes, ñ, ¿ ¡, cifras ni
  nada que cambie lo que dice el documento.
* `problemas` encuentra lo que indica texto dañado (caracteres de reemplazo,
  de control, de uso privado, mojibake, sintaxis de PDF) con su línea y
  columna, para revisarlo en el original en vez de adivinarlo.
"""

from __future__ import annotations

import os
import re
import unicodedata

# Firmas de formatos binarios que no son texto. Un PDF puede llevar basura
# antes de su cabecera: se busca en el primer kilobyte, como los lectores.
_FIRMA_PDF = b"%PDF-"
_FIRMAS_BINARIAS = {
    b"PK\x03\x04": "un ZIP (¿.docx, .odt o .xlsx?)",
    b"\xd0\xcf\x11\xe0": "un documento de Office antiguo (.doc)",
    b"{\\rtf": "un RTF",
    b"\x89PNG": "una imagen PNG",
    b"\xff\xd8\xff": "una imagen JPEG",
}

# Lo que delata la sintaxis interna de un PDF copiada como texto.
_MARCAS_PDF = [
    re.compile(r"%PDF-\d"),
    re.compile(r"\b\d+\s+0\s+obj\b"),
    re.compile(r"\bendobj\b"),
    re.compile(r"\bendstream\b"),
    re.compile(r"/Type\s*/(?:Page|Pages|Font|Catalog|XObject)\b"),
    re.compile(r"/(?:BaseFont|Contents|MediaBox|Filter|FlateDecode)\b"),
    re.compile(r"\bxref\b|\btrailer\b|\bstartxref\b"),
]

# Espacios que se ven como uno normal (no separable, fino, de cifra…).
_ESPACIOS = re.compile(r"[   -   　]")
# Invisibles que solo cortan palabras: guion blando, ancho cero, BOM.
_INVISIBLES = re.compile(r"[­​‌‍⁠﻿]")
# Ligaduras tipográficas de las fuentes de PDF («ﬁ» de «certiﬁcado»).
_LIGADURAS = {"ﬀ": "ff", "ﬁ": "fi", "ﬂ": "fl",
              "ﬃ": "ffi", "ﬄ": "ffl"}
# UTF-8 leído como Latin-1/Windows-1252: «trÃ¡mite», «Â¿», «â€œ».
_MOJIBAKE = re.compile(r"Ã[\u0080-¿]|Â[ -¿]|â€")


def detectar_formato(ruta: str) -> dict:
    """Qué es el archivo según su contenido.

    `formato` es `pdf`, `texto`, `copia_pdf` (sintaxis de PDF guardada como
    texto), `binario`, `no_utf8` o `vacio`. `coincide` dice si la extensión
    corresponde a lo que hay dentro.
    """
    ext = os.path.splitext(ruta)[1].lower()
    with open(ruta, "rb") as f:
        datos = f.read()
    cabeza = datos[:1024]

    def salida(formato: str, detalle: str = "") -> dict:
        esperada = {"pdf": ".pdf", "texto": (".md", ".txt")}.get(formato)
        coincide = (ext == esperada if isinstance(esperada, str)
                    else ext in (esperada or ()))
        return {"formato": formato, "extension": ext, "coincide": coincide,
                "detalle": detalle}

    if _FIRMA_PDF in cabeza:
        # Un PDF de verdad tiene bytes binarios (su comentario inicial, sus
        # flujos comprimidos). Si todo se lee como UTF-8 y aparece «�», es
        # el PDF abierto como texto y guardado: los bytes ya se perdieron.
        try:
            texto = datos.decode("utf-8")
        except UnicodeDecodeError:
            return salida("pdf")
        if "�" in texto:
            return salida("copia_pdf", ", ".join(
                ["«�» en lugar de datos binarios"] + marcas_pdf(texto)[:3]))
        return salida("pdf")
    for firma, nombre in _FIRMAS_BINARIAS.items():
        if datos.startswith(firma):
            return salida("binario", f"es {nombre}")
    if b"\x00" in cabeza:
        return salida("binario", "tiene bytes nulos")
    try:
        texto = datos.decode("utf-8")
    except UnicodeDecodeError as e:
        return salida("no_utf8", f"byte {e.start}: no es UTF-8")
    if not texto.strip():
        return salida("vacio")
    marcas = marcas_pdf(texto)
    if len(marcas) >= 2:
        return salida("copia_pdf", ", ".join(marcas[:4]))
    return salida("texto")


def marcas_pdf(texto: str) -> list:
    """Fragmentos de sintaxis de PDF presentes en [texto], sin repetir."""
    vistas = []
    for patron in _MARCAS_PDF:
        m = patron.search(texto)
        if m and m.group(0) not in vistas:
            vistas.append(m.group(0))
    return vistas


def normalizar(texto: str) -> tuple:
    """(texto, cambios) con la forma Unicode y los espacios unificados.

    Conserva tildes, ñ, ¿ ¡, comillas, cifras, mayúsculas y la separación en
    líneas: solo cambia caracteres que se ven igual o no se ven.
    """
    cambios = {}

    def contar(nombre: str, antes: str, despues: str) -> str:
        if antes != despues:
            cambios[nombre] = cambios.get(nombre, 0) + 1
        return despues

    t = contar("saltos de línea", texto,
               texto.replace("\r\n", "\n").replace("\r", "\n"))
    t = contar("forma Unicode (NFC)", t, unicodedata.normalize("NFC", t))
    t = contar("espacios especiales", t, _ESPACIOS.sub(" ", t))
    t = contar("caracteres invisibles", t, _INVISIBLES.sub("", t))
    t = contar("ligaduras", t,
               re.sub("[ﬀ-ﬄ]", lambda m: _LIGADURAS[m.group()], t))
    lineas = [re.sub(r"[ \t]+", " ", linea).strip() for linea in t.split("\n")]
    t2 = re.sub(r"\n{3,}", "\n\n", "\n".join(lineas)).strip()
    contar("espacios repetidos", t, t2)
    return t2, sorted(cambios)


def problemas(texto: str) -> list:
    """Señales de texto dañado, con su línea y columna (desde 1).

    Cada una es `{tipo, linea, columna, caracter, contexto}`. Todas impiden
    usar el texto: lo que se perdió no se adivina.
    """
    out = []
    for n, linea in enumerate(texto.split("\n"), 1):
        for col, c in enumerate(linea, 1):
            cat = unicodedata.category(c)
            if c == "�":
                tipo = "carácter de reemplazo (U+FFFD): se perdió el original"
            elif cat == "Cc" and c != "\t":
                tipo = f"carácter de control U+{ord(c):04X}"
            elif cat == "Co":
                tipo = (f"carácter de uso privado U+{ord(c):04X} "
                        "(glifo de fuente sin traducir)")
            elif cat == "Cn":
                tipo = f"carácter sin asignar U+{ord(c):04X}"
            else:
                continue
            out.append(_problema(tipo, n, col, linea))
        for m in _MOJIBAKE.finditer(linea):
            out.append(_problema(
                f"mojibake «{m.group()}» (UTF-8 leído con otra codificación)",
                n, m.start() + 1, linea))
    # Una palabra suelta («trailer») no basta: hacen falta dos marcas.
    marcas = marcas_pdf(texto)
    for marca in marcas if len(marcas) >= 2 else []:
        i = texto.index(marca)
        n = texto.count("\n", 0, i) + 1
        col = i - (texto.rfind("\n", 0, i) + 1) + 1
        out.append(_problema(f"sintaxis de PDF «{marca}»", n, col,
                             texto.split("\n")[n - 1]))
    return out


def _problema(tipo: str, linea: int, columna: int, texto_linea: str) -> dict:
    inicio = max(0, columna - 21)
    contexto = texto_linea[inicio:columna + 20]
    visible = "".join(c if unicodedata.category(c)[0] != "C" or c == "\t"
                      else f"<U+{ord(c):04X}>" for c in contexto)
    return {"tipo": tipo, "linea": linea, "columna": columna,
            "contexto": visible}


def resumir(lista: list, donde: str = "", maximo: int = 5) -> list:
    """Líneas legibles de [lista] de problemas: los primeros de cada tipo."""
    por_tipo = {}
    for p in lista:
        por_tipo.setdefault(p["tipo"], []).append(p)
    lineas = []
    for tipo, casos in por_tipo.items():
        lugares = "; ".join(f"línea {p['linea']}, columna {p['columna']} "
                            f"«{p['contexto']}»" for p in casos[:maximo])
        mas = f" (y {len(casos) - maximo} más)" if len(casos) > maximo else ""
        lineas.append(f"{donde}{tipo}: {len(casos)} — {lugares}{mas}")
    return lineas
