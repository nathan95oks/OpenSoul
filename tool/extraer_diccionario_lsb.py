"""Convierte un diccionario LSB en PDF a CSV, una sola vez por versión.

    python tool/extraer_diccionario_lsb.py            # los PDF sin CSV al día
    python tool/extraer_diccionario_lsb.py --todo     # vuelve a extraerlos

Para cada `docs/lsb_fuentes/diccionarios/<NOMBRE>.pdf` escribe, junto a él:

    <NOMBRE>.csv     palabra, pagina, entrada, categoria, definicion, glosa
    <NOMBRE>.huella  SHA-256 del PDF del que sale el CSV

Leer un diccionario de cientos de páginas con imágenes tarda minutos; el
CSV se versiona y `tool/build_lexico_lsb.py` lo lee en un instante. La
huella le permite saber si el PDF cambió sin volver a extraerlo.

Hoy lee el formato del **II Diccionario Bilingüe LSB–Castellano** (Ministerio
de Educación, 2024): entradas numeradas «499.Robar: v. Quitar algo…», en
orden alfabético, con el número de página impreso arriba. Otro diccionario
con otra maquetación no se adivina: si no se reconocen entradas, se detiene.

No escribe nada si:

* el texto trae caracteres dañados (los controles de la ingesta);
* la numeración de las entradas salta, se repite o retrocede de una página
  a la siguiente (se perdió una entrada al extraer). Dentro de una página el
  orden no cuenta: pypdf lee sus dos columnas en otro orden. Una errata del
  propio diccionario solo se acepta si está en `ERRATAS`, palabra por
  palabra;
* una seña que el catálogo de la app cita de este diccionario («D2024-499»)
  no es la palabra que el PDF tiene en esa entrada.
"""

from __future__ import annotations

import csv
import glob
import hashlib
import io
import json
import logging
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import build_lexico_lsb as L  # noqa: E402
import rag_texto as T  # noqa: E402

DICCIONARIO_APP = os.path.join(L.ROOT, "assets", "dictionary",
                               "official_dictionary.json")
COLUMNAS = ["palabra", "pagina", "entrada", "categoria", "definicion", "glosa"]

# «499.Robar: v. Quitar algo a alguien.» al empezar una línea.
_ENTRADA = re.compile(
    r"^(?P<n>\d{1,4})\s*\.\s*(?P<palabra>[^\W\d_][^:\n]{0,60}?)\s*:\s*(?P<resto>.*)$")
# «sin. Anta.» (sinónimo) y la categoría gramatical, al empezar la definición.
_SINONIMO = re.compile(r"^sin\.\s*(?P<sin>[^.]{1,40})\.\s*")
_CATEGORIAS = (r"(?:f|m|v|adj|adv|leng|prep|pron|conj|interj|loc|sust|n|rel|comp|"
               r"m\.\s*f|m\s*y\s*f|f\s*y\s*m|v\.\s*prnl|prnl)\.")
_CATEGORIA = re.compile(rf"^(?P<cat>{_CATEGORIAS})\s*")
# Errata del diccionario: «87.Buque de guerra. m. Barco militar.», con
# punto en lugar de dos puntos. Solo vale si sigue una categoría.
_ENTRADA_CON_PUNTO = re.compile(
    r"^(?P<n>\d{1,4})\s*\.\s*(?P<palabra>[^\W\d_][^:.\n]{0,60}?)\.\s+"
    rf"(?P<resto>{_CATEGORIAS}.*)$")

# Erratas comprobadas en el PDF, por diccionario: números de entrada que el
# propio diccionario repite, con las palabras exactas que llevan. Otra
# repetición sigue deteniendo la extracción.
ERRATAS = {
    "D2024": {"repetidas": {73: ["Autor/ra", "Auxilio"]}},
}
MAX_DEFINICION = 120


class ErrorExtraccion(Exception):
    pass


def huella(ruta: str) -> str:
    with open(ruta, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def paginas(ruta: str) -> list:
    """(número de página del PDF, texto) de cada página."""
    try:
        from pypdf import PdfReader
    except ImportError as e:
        raise ErrorExtraccion(
            "falta pypdf. Instálalo en el Python con que ejecutas esto: "
            f"{sys.executable} -m pip install -r tool/requirements.txt") from e
    logging.getLogger("pypdf").setLevel(logging.ERROR)
    lector = PdfReader(ruta)
    out = []
    for i, p in enumerate(lector.pages, 1):
        out.append((i, p.extract_text() or ""))
        if i % 25 == 0:
            print(f"  {i}/{len(lector.pages)} páginas", flush=True)
    return out


def pagina_impresa(texto: str) -> str | None:
    """El número impreso en la página («3», o «208 209» en una doble)."""
    for linea in texto.split("\n")[:3]:
        m = re.fullmatch(r"\s*(\d{1,3})(?:\s+\d{1,3})?\s*", linea)
        if m:
            return m.group(1)
    return None


def definicion(resto: str) -> tuple:
    """(sinónimos, categoría, definición corta) del texto tras «palabra:»."""
    resto = resto.strip()
    sinonimos = []
    m = _SINONIMO.match(resto)
    if m:
        sinonimos.append(m.group("sin").strip())
        resto = resto[m.end():]
    categorias = []
    # «rel. m. Esposo de María…»: puede haber varias seguidas.
    while (m := _CATEGORIA.match(resto)):
        categorias.append(m.group("cat"))
        resto = resto[m.end():]
    categoria = " ".join(categorias)
    # Solo la primera oración: en la misma línea suele seguir el ejemplo.
    corta = re.split(r"(?<=[.!?])\s", resto, maxsplit=1)[0].strip()
    return sinonimos, categoria, corta[:MAX_DEFINICION]


def entradas(paginas_pdf: list, nombre: str = "") -> tuple:
    """(entradas, errores). Cada entrada: {n, palabra, formas, pagina,
    pagina_pdf, categoria, definicion}."""
    salida, errores = [], []
    for n_pdf, texto in paginas_pdf:
        texto, _ = T.normalizar(texto)
        errores += T.resumir(T.problemas(texto), f"página {n_pdf} del PDF, ")
        impresa = pagina_impresa(texto)
        for linea in texto.split("\n"):
            m = (_ENTRADA.match(linea.strip())
                 or _ENTRADA_CON_PUNTO.match(linea.strip()))
            if not m:
                continue
            sinonimos, categoria, corta = definicion(m.group("resto"))
            palabra = re.sub(r"\s+", " ", m.group("palabra")).strip()
            salida.append({
                "n": int(m.group("n")), "palabra": palabra,
                "formas": [palabra] + sinonimos,
                "pagina": impresa or f"pdf {n_pdf}", "pagina_pdf": n_pdf,
                "categoria": categoria, "definicion": corta,
            })
    numeros = [e["n"] for e in salida]
    if not numeros:
        errores.append("no se reconoció ninguna entrada «N.Palabra: …»: la "
                       "maquetación no es la del II Diccionario 2024")
        return salida, errores
    repetidas = (ERRATAS.get(nombre) or {}).get("repetidas") or {}
    por_numero = {}
    for e in salida:
        por_numero.setdefault(e["n"], []).append(e["palabra"])
    for n, palabras in sorted(por_numero.items()):
        if len(palabras) > 1 and sorted(palabras) != sorted(repetidas.get(n, [])):
            errores.append(f"entrada {n} repetida ({', '.join(palabras)}): no "
                           "está entre las erratas comprobadas del diccionario")
    # El orden se exige entre páginas: todo lo de una página va antes que lo
    # de la siguiente.
    por_pagina = {}
    for e in salida:
        por_pagina.setdefault(e["pagina_pdf"], []).append(e["n"])
    previa = None
    for pag in sorted(por_pagina):
        if previa is not None and min(por_pagina[pag]) < max(por_pagina[previa]):
            errores.append(f"la página {pag} del PDF empieza en la entrada "
                           f"{min(por_pagina[pag])} y la anterior llega a la "
                           f"{max(por_pagina[previa])}: el orden se perdió")
        previa = pag
    vistos = set(por_numero)
    faltan = sorted(set(range(1, max(numeros) + 1)) - vistos)
    if faltan:
        errores.append(f"faltan {len(faltan)} entradas: {faltan[:30]}"
                       + (" …" if len(faltan) > 30 else "")
                       + ": no se pudieron leer del PDF")
    return salida, errores


def citas_del_catalogo(nombre: str) -> dict:
    """{número de entrada: glosa} de las señas del catálogo de la app que
    citan este diccionario por número («D2024-499»)."""
    if not os.path.exists(DICCIONARIO_APP):
        return {}
    with open(DICCIONARIO_APP, encoding="utf-8") as f:
        datos = json.load(f)
    out = {}
    for e in datos.get("entries") or []:
        m = re.match(rf"{re.escape(nombre)}-(\d+)\b", e.get("source") or "")
        if m:
            out[int(m.group(1))] = e["gloss"]
    return out


def contrastar(nombre: str, lista: list) -> list:
    """Errores donde la entrada citada por el catálogo no es esa palabra."""
    por_numero = {}
    for e in lista:
        por_numero.setdefault(e["n"], []).append(e)
    errores = []
    for n, glosa in sorted(citas_del_catalogo(nombre).items()):
        candidatas = por_numero.get(n) or []
        if not candidatas:
            errores.append(f"el catálogo cita {nombre}-{n} ({glosa}) y esa "
                           "entrada no se leyó")
            continue
        clave = L._norm(glosa.replace("_", " "))

        def coincide(e: dict) -> bool:
            # «LADRÓN/A» → «Ladrón»; la glosa puede llevar el género.
            formas = {L._norm(f) for f in L.formas_de(e["palabra"])[0] + e["formas"]}
            return clave in formas or any(
                clave.startswith(f) or f.startswith(clave) for f in formas)

        if not any(coincide(e) for e in candidatas):
            errores.append(f"el catálogo cita {nombre}-{n} como {glosa} pero el "
                           "PDF tiene «"
                           + "», «".join(e["palabra"] for e in candidatas)
                           + "» en esa entrada")
    return errores


def a_csv(lista: list) -> str:
    salida = io.StringIO()
    w = csv.DictWriter(salida, fieldnames=COLUMNAS, lineterminator="\n")
    w.writeheader()
    for e in lista:
        w.writerow({"palabra": " / ".join(e["formas"]), "pagina": e["pagina"],
                    "entrada": e["n"], "categoria": e["categoria"],
                    "definicion": e["definicion"], "glosa": ""})
    return salida.getvalue()


def procesar(ruta: str, todo: bool = False) -> list:
    nombre = os.path.splitext(os.path.basename(ruta))[0]
    destino = os.path.splitext(ruta)[0] + ".csv"
    marca = os.path.splitext(ruta)[0] + ".huella"
    actual = huella(ruta)
    if (not todo and os.path.exists(destino) and os.path.exists(marca)
            and open(marca, encoding="utf-8").read().strip() == actual):
        return [f"al día: {nombre}"]
    print(f"extrayendo {os.path.basename(ruta)} (puede tardar minutos)…",
          flush=True)
    try:
        lista, errores = entradas(paginas(ruta), nombre)
    except ErrorExtraccion as e:
        return [f"ERROR {nombre}: {e}"]
    errores += contrastar(nombre, lista)
    if errores:
        return ([f"ERROR {nombre}: {e}" for e in errores]
                + [f"ERROR {nombre}: no se escribe el CSV."])
    with open(destino, "w", encoding="utf-8", newline="") as f:
        f.write(a_csv(lista))
    with open(marca, "w", encoding="utf-8", newline="") as f:
        f.write(actual + "\n")
    citas = len(citas_del_catalogo(nombre))
    return [f"escrito: {os.path.relpath(destino, L.ROOT)} · {len(lista)} "
            f"entradas (1..{max(e['n'] for e in lista)}) · {citas} citas del catálogo "
            "comprobadas"]


def main() -> int:
    pdfs = sorted(glob.glob(os.path.join(L.DICCIONARIOS, "*.pdf")))
    if not pdfs:
        print(f"No hay diccionarios en PDF en {os.path.relpath(L.DICCIONARIOS, L.ROOT)}.")
        return 0
    fallos = 0
    for ruta in pdfs:
        lineas = procesar(ruta, "--todo" in sys.argv)
        for l in lineas:
            print(l)
        fallos += any(l.startswith("ERROR") for l in lineas)
    return 1 if fallos else 0


if __name__ == "__main__":
    raise SystemExit(main())
