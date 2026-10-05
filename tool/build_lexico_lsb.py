"""Léxico LSB válido: el vocabulario de los módulos M1–M4 y los diccionarios.

    python tool/build_lexico_lsb.py            # valida y escribe
    python tool/build_lexico_lsb.py --check    # valida y comprueba que el
                                               # léxico versionado está al día

Fuentes (versionadas, en `docs/lsb_fuentes/`):

    modulos/M1.pdf … M4.pdf   «Curso de enseñanza de la LSB», Ministerio de
                              Educación. Se lee su «Índice de palabras y
                              señas»: cada tema con su página y sus palabras
                              numeradas.
    diccionarios/*.csv|json   un diccionario por archivo (formato en
                              `docs/lsb_fuentes/README.md`).
    diccionarios/*.pdf        un diccionario en PDF vale por su CSV, que
                              escribe tool/extraer_diccionario_lsb.py con la
                              huella del PDF: si el PDF cambió, se detiene.

Además entra el catálogo de la app (`aws/catalogo_senas.json`): sus señas ya
están auditadas contra M1–M4 y el II Diccionario 2024.

Genera `aws/lexico_lsb.json`, que la Lambda empaqueta y que el corpus RAG usa
para filtrar: solo valen glosas que estén aquí. Cada glosa dice de dónde sale
(módulo y página), sus formas en español y si el avatar tiene animación.

Lo que se lee de un PDF se trata como dato, no como verdad. Se detiene sin
escribir nada si un módulo falta o no se puede leer, si su índice trae texto
dañado, si un tema salta números (se perdió una palabra al extraer) o si un
diccionario no tiene el formato esperado.
"""

from __future__ import annotations

import csv
import glob
import hashlib
import json
import logging
import os
import re
import sys
import unicodedata

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import rag_texto as T  # noqa: E402

ROOT = os.path.dirname(AQUI)
FUENTES = os.path.join(ROOT, "docs", "lsb_fuentes")
MODULOS = os.path.join(FUENTES, "modulos")
DICCIONARIOS = os.path.join(FUENTES, "diccionarios")
CATALOGO = os.path.join(ROOT, "aws", "catalogo_senas.json")
ANIMACIONES = os.path.join(ROOT, "lib", "core", "domain", "services",
                           "animation_url_resolver.dart")
SALIDA = os.path.join(ROOT, "aws", "lexico_lsb.json")

NUM_MODULOS = 4
# Un índice con menos temas o palabras no se leyó entero: se detiene.
MIN_TEMAS = 10
MIN_PALABRAS = 150
# Los temas de números se signan con cifras (dactilología numérica), que ya
# valen como glosa: sus nombres en letras no entran como señas.
_TEMA_NUMEROS = re.compile(r"^n[uú]meros\b", re.IGNORECASE)

_CABECERA = re.compile(r"^(?P<titulo>.*?)\s*\.{3,}[\s.]*P[áa]g\.?\s*(?P<pag>\d+)")
_ITEM = re.compile(r"^(?P<n>\d+)\s*\.\s*(?P<texto>\S.*)$")
_PIE = "índice de palabras y señas"
# pypdf separa la «Y» inicial de su palabra por el interletrado de la fuente:
# «Y o», «Y erno», «Y ogur».
_Y_PARTIDA = re.compile(r"\bY (?=[a-záéíóúñ])")
_PALABRAS_FUNCION = {"el", "la", "los", "las", "al", "un", "una", "de", "y"}


class ErrorLexico(Exception):
    """Una fuente no se puede usar tal como está; el mensaje dice por qué."""


def _norm(texto: str) -> str:
    sin = unicodedata.normalize("NFD", texto.lower())
    sin = "".join(c for c in sin if unicodedata.category(c) != "Mn")
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s]", " ", sin)).strip()


def glosa_de(forma: str) -> str:
    """La glosa de una forma en español: mayúsculas, con tildes, «_» entre
    palabras («Buenos días» → BUENOS_DÍAS)."""
    palabras = re.findall(r"[\wÁÉÍÓÚÜÑáéíóúüñ]+", forma)
    return "_".join(p.upper() for p in palabras)


def _rel(ruta: str) -> str:
    """Ruta relativa al repositorio con «/», igual en Windows y en Linux: el
    léxico generado no puede depender del sistema donde se construye."""
    return os.path.relpath(ruta, ROOT).replace(os.sep, "/")


def huella(ruta: str) -> str:
    """SHA-256 del archivo. En un texto (CSV, .md) no cuentan los finales de
    línea: Git en Windows los cambia a CRLF y la huella no debe cambiar."""
    with open(ruta, "rb") as f:
        datos = f.read()
    if not ruta.lower().endswith(".pdf"):
        datos = datos.replace(b"\r\n", b"\n")
    return hashlib.sha256(datos).hexdigest()


# ── Índice de los módulos ────────────────────────────────────────────────────


def _es_pagina_de_indice(texto: str) -> bool:
    lineas = texto.split("\n")
    return (any(_CABECERA.match(l.strip()) for l in lineas)
            and any(_ITEM.match(l.strip()) for l in lineas))


def paginas_de_indice(paginas: list) -> list:
    """(número, texto) de las páginas del «Índice de palabras y señas»: el
    primer bloque seguido de páginas con temas y palabras numeradas."""
    marcadas = [n for n, t in paginas if _es_pagina_de_indice(t)]
    if not marcadas:
        return []
    bloque = [marcadas[0]]
    for n in marcadas[1:]:
        if n - bloque[-1] > 2:
            break
        bloque.append(n)
    return [(n, t) for n, t in paginas if bloque[0] <= n <= bloque[-1]]


def leer_indice(modulo: str, paginas: list) -> tuple:
    """(temas, errores, avisos). Cada tema: {titulo, pagina, palabras:
    [(n, texto, página del índice)]}."""
    temas, errores, avisos = [], [], []
    titulo_pendiente, actual = [], None
    for n_pag, texto in paginas:
        donde = f"{modulo} página {n_pag}"
        errores += T.resumir(T.problemas(texto), f"{donde}, ")
        lineas = [l.strip() for l in texto.split("\n")]
        for i, linea in enumerate(lineas):
            if not linea or (i == 0 and linea.isdigit()):
                continue
            if _norm(linea) == _norm(_PIE):
                continue
            cab = _CABECERA.match(linea)
            if cab:
                titulo = " ".join(titulo_pendiente + [cab.group("titulo")])
                titulo = re.sub(r"\s+", " ", titulo).strip()
                titulo_pendiente = []
                if not titulo:
                    errores.append(f"{donde}: tema sin título «{linea}»")
                    continue
                actual = {"titulo": titulo, "pagina": int(cab.group("pag")),
                          "palabras": []}
                temas.append(actual)
                continue
            item = _ITEM.match(linea)
            if item and actual is not None:
                actual["palabras"].append(
                    (int(item.group("n")), item.group("texto"), n_pag))
                continue
            if (actual is not None and actual["palabras"]
                    and actual["palabras"][-1][1].count("(")
                    > actual["palabras"][-1][1].count(")")):
                # «7. Inicial (educación en familia» + «comunitaria)».
                n, t, p = actual["palabras"][-1]
                actual["palabras"][-1] = (n, f"{t} {linea}", p)
                continue
            # Un título en varias líneas («Salud sexual y» / «reproductiva»).
            titulo_pendiente.append(linea)
    for tema in temas:
        numeros = [n for n, _, _ in tema["palabras"]]
        if not numeros:
            errores.append(f"{modulo} «{tema['titulo']}»: tema sin palabras")
        elif numeros != list(range(1, len(numeros) + 1)):
            esperados = set(range(1, max(numeros) + 1))
            faltan = sorted(esperados - set(numeros))
            errores.append(
                f"{modulo} «{tema['titulo']}» (índice p.{tema['palabras'][0][2]}): "
                f"la numeración no es 1..{len(numeros)} ({numeros}); "
                + (f"faltan {faltan}: " if faltan else "")
                + "se perdió o desordenó una palabra al extraer el PDF")
    if titulo_pendiente:
        avisos.append(f"{modulo}: texto sin tema al final del índice "
                      f"«{' '.join(titulo_pendiente)[:80]}»")
    return temas, errores, avisos


def formas_de(texto: str) -> tuple:
    """(formas en español, nota) de una palabra del índice.

    «Bonito/a» → bonito, bonita · «Salario / Sueldo» → salario, sueldo ·
    «Conocido - Conocer» → conocido, conocer · «Prestar (opción 1 y 2)» →
    prestar, con la nota «opción 1 y 2».
    """
    texto = _Y_PARTIDA.sub("Y", texto.strip())
    notas = re.findall(r"\(([^)]*)\)", texto)
    base = re.sub(r"\([^)]*\)", " ", texto)
    base = re.sub(r"\s+", " ", base).strip(" .,;")
    formas = []
    partes = re.split(r"\s+-\s+|\s*/\s*", base)
    for parte in partes:
        parte = parte.strip(" .,;")
        if not parte:
            continue
        if re.fullmatch(r"[aoAO]", parte) and formas:
            # Género: «Bonito/a», «Secretaria/o», «Coordinador/a».
            anterior = formas[-1]
            if anterior[-1:].lower() in "ao":
                formas.append(anterior[:-1] + parte.lower())
            else:
                formas.append(anterior + parte.lower())
            continue
        if re.fullmatch(r"[a-zñ]{2,3}", parte) and formas:
            # Género con más letras, como en el II Diccionario 2024:
            # «Delgado/da» → delgada, «Autor/ra» → autora, «Castellano/na» →
            # castellana. El final empieza en la última aparición de su
            # primera letra dentro de las últimas letras de la palabra.
            anterior = formas[-1]
            i = anterior.lower().rfind(parte[0], max(0, len(anterior) - 3))
            if i > 0:
                formas.append(anterior[:i] + parte)
                continue
        if len(partes) > 1 and _norm(parte) in _PALABRAS_FUNCION:
            # «El / al lado»: un artículo suelto no es una seña.
            continue
        formas.append(parte)
    return formas, "; ".join(n.strip() for n in notas if n.strip())


def leer_modulo(ruta: str) -> list:
    """(número, texto) de cada página del PDF."""
    try:
        from pypdf import PdfReader
        from pypdf.errors import PdfReadError
    except ImportError as e:
        raise ErrorLexico(
            "falta pypdf para leer los módulos. Instálalo en el Python con que "
            f"ejecutas esto: {sys.executable} -m pip install -r "
            "tool/requirements.txt") from e
    # pypdf avisa por cada fuente sin fontTools; los daños de verdad los
    # detecta la revisión del texto (T.problemas), no estos avisos.
    logging.getLogger("pypdf").setLevel(logging.ERROR)
    try:
        lector = PdfReader(ruta)
        return [(i, p.extract_text() or "")
                for i, p in enumerate(lector.pages, 1)]
    except (PdfReadError, ValueError, KeyError, OSError) as e:
        raise ErrorLexico(f"{os.path.basename(ruta)} no se puede leer ({e}): "
                          "hace falta el PDF original") from e


def entradas_de_modulo(modulo: str, ruta: str) -> tuple:
    """(entradas, errores, avisos) de un módulo. Cada entrada:
    {formas, nota, fuente}."""
    formato = T.detectar_formato(ruta)
    if formato["formato"] != "pdf":
        raise ErrorLexico(f"{modulo}: {os.path.basename(ruta)} no es un PDF "
                          f"({formato['formato']} {formato['detalle']})")
    paginas = leer_modulo(ruta)
    indice = paginas_de_indice(paginas)
    if not indice:
        raise ErrorLexico(f"{modulo}: no se encontró el «Índice de palabras y "
                          "señas» (¿PDF escaneado o de otra edición?)")
    temas, errores, avisos = leer_indice(modulo, indice)
    entradas = []
    for tema in temas:
        if _TEMA_NUMEROS.match(tema["titulo"]):
            continue
        for n, texto, _ in tema["palabras"]:
            formas, nota = formas_de(texto)
            if not formas:
                errores.append(f"{modulo} «{tema['titulo']}» {n}: «{texto}» "
                               "no deja ninguna palabra")
                continue
            for f in formas:
                if re.search(r"\b[A-ZÁÉÍÓÚÑ] [a-záéíóúñ]", f):
                    avisos.append(f"{modulo} «{tema['titulo']}» {n}: «{f}» "
                                  "parece una palabra partida por el PDF")
            entradas.append({
                "formas": formas, "nota": nota,
                "fuente": {"fuente": modulo, "pagina": tema["pagina"],
                           "tema": tema["titulo"], "n": n},
            })
    palabras = sum(len(t["palabras"]) for t in temas)
    if len(temas) < MIN_TEMAS or palabras < MIN_PALABRAS:
        errores.append(f"{modulo}: el índice dio solo {len(temas)} temas y "
                       f"{palabras} palabras (mínimo {MIN_TEMAS} y "
                       f"{MIN_PALABRAS}): no se leyó entero")
    return entradas, errores, avisos


# ── Diccionarios ─────────────────────────────────────────────────────────────


def entradas_de_diccionario(ruta: str) -> tuple:
    """(entradas, errores) de un diccionario en CSV o JSON.

    Columnas: `palabra` (obligatoria; varias formas con «/»), `pagina`
    (obligatoria), `glosa` (opcional) y `nota` (opcional). El nombre del
    archivo, sin extensión, es el nombre de la fuente.
    """
    nombre = os.path.splitext(os.path.basename(ruta))[0]
    ext = os.path.splitext(ruta)[1].lower()
    errores = []
    if ext == ".csv":
        with open(ruta, encoding="utf-8-sig", newline="") as f:
            filas = list(csv.DictReader(f))
    elif ext == ".json":
        with open(ruta, encoding="utf-8") as f:
            filas = json.load(f)
        if not isinstance(filas, list):
            return [], [f"{nombre}: el JSON debe ser una lista de entradas"]
    else:
        return [], [
            f"{os.path.basename(ruta)}: formato {ext or 'sin extensión'} sin "
            "extractor. Un diccionario en PDF se convierte primero a CSV "
            "(columnas palabra, pagina) o se le escribe su extractor: ver "
            "docs/lsb_fuentes/README.md"]
    entradas = []
    for i, fila in enumerate(filas, 2):
        fila = {str(k).strip().lower(): (str(v).strip() if v is not None else "")
                for k, v in (fila.items() if isinstance(fila, dict) else [])}
        palabra, pagina = fila.get("palabra", ""), fila.get("pagina", "")
        if not palabra or not pagina:
            errores.append(f"{nombre} fila {i}: faltan «palabra» o «pagina»")
            continue
        problemas = T.problemas(palabra)
        if problemas:
            errores += T.resumir(problemas, f"{nombre} fila {i}, ")
            continue
        formas, nota = formas_de(palabra)
        glosa = fila.get("glosa", "")
        if glosa and not re.fullmatch(r"[A-ZÁÉÍÓÚÜÑ0-9]+(?:_[A-ZÁÉÍÓÚÜÑ0-9]+)*",
                                      glosa):
            errores.append(f"{nombre} fila {i}: glosa «{glosa}» inválida "
                           "(MAYÚSCULAS con «_» entre palabras)")
            continue
        fuente = {"fuente": nombre, "pagina": pagina}
        if fila.get("entrada"):
            fuente["entrada"] = int(fila["entrada"]) if fila["entrada"].isdigit() \
                else fila["entrada"]
        if fila.get("definicion"):
            # El sentido de la seña: con él Bedrock distingue homónimos.
            fuente["definicion"] = fila["definicion"]
        entradas.append({
            "formas": formas, "nota": "; ".join(
                x for x in (nota, fila.get("nota", "")) if x),
            "glosa": glosa or None,
            "fuente": fuente,
        })
    if not entradas and not errores:
        errores.append(f"{nombre}: no tiene entradas")
    return entradas, errores


def pdf_al_dia(ruta: str) -> list:
    """Errores si el CSV de un diccionario en PDF falta o salió de otro PDF."""
    base = os.path.splitext(ruta)[0]
    nombre = os.path.basename(ruta)
    pedir = ("ejecuta python tool/extraer_diccionario_lsb.py y revisa el CSV "
             "antes de reconstruir el léxico")
    if not (os.path.exists(base + ".csv") and os.path.exists(base + ".huella")):
        return [f"{nombre} no tiene su CSV extraído: {pedir}"]
    with open(base + ".huella", encoding="utf-8") as f:
        if f.read().strip() != huella(ruta):
            return [f"{nombre} cambió desde que se extrajo su CSV: {pedir}"]
    return []


# ── Unión ────────────────────────────────────────────────────────────────────


def glosas_animadas() -> set:
    """Glosas con clip en el .glb del avatar, sin tildes."""
    if not os.path.exists(ANIMACIONES):
        return set()
    with open(ANIMACIONES, encoding="utf-8") as f:
        fuente = f.read()
    m = re.search(r"available3DGlosses = \{(.*?)\};", fuente, re.DOTALL)
    return {_norm(g) for g in re.findall(r"'([^']+)'", m.group(1))} if m else set()


def unir(catalogo: dict, entradas: list, animadas: set) -> tuple:
    """(léxico, avisos). Una palabra cuya forma ya es una seña del catálogo
    se suma a esa seña; si no, es una seña nueva con la glosa de su forma."""
    lexico, avisos = {}, []
    por_forma = {}
    for g, formas in catalogo.items():
        lexico[g] = {"formas": list(dict.fromkeys(formas)),
                     "fuentes": [{"fuente": "catalogo"}], "catalogo": True}
        for f in formas + [g.replace("_", " ")]:
            por_forma.setdefault(_norm(f), set()).add(g)
    for e in entradas:
        glosa = e.get("glosa")
        if not glosa:
            claves = {g for f in e["formas"] for g in por_forma.get(_norm(f), ())}
            # «Ver / mirar» nombra VER y MIRAR: manda la seña que se llama
            # como la primera forma.
            propia = [g for g in claves
                      if _norm(g.replace("_", " ")) == _norm(e["formas"][0])]
            if len(claves) == 1:
                glosa = next(iter(claves))
            elif len(propia) == 1:
                glosa = propia[0]
            else:
                glosa = glosa_de(e["formas"][0])
            if len(claves) > 1 and len(propia) != 1:
                avisos.append(f"«{' / '.join(e['formas'])}» coincide con "
                              f"varias señas del catálogo {sorted(claves)}: "
                              f"queda como {glosa}")
        dato = lexico.setdefault(glosa, {"formas": [], "fuentes": [],
                                         "catalogo": False})
        for f in e["formas"]:
            if f not in dato["formas"]:
                dato["formas"].append(f)
            por_forma.setdefault(_norm(f), set()).add(glosa)
        fuente = dict(e["fuente"])
        if e.get("nota"):
            fuente["nota"] = e["nota"]
        dato["fuentes"].append(fuente)
    for g, dato in lexico.items():
        dato["animacion"] = _norm(g.replace("_", " ")).replace(" ", "_") in {
            a.replace(" ", "_") for a in animadas}
    ambiguas = {f: sorted(gs) for f, gs in por_forma.items() if len(gs) > 1}
    return lexico, ambiguas, avisos


def construir() -> tuple:
    """(datos del léxico, errores, avisos)."""
    errores, avisos, entradas, fuentes = [], [], [], {}
    for i in range(1, NUM_MODULOS + 1):
        modulo = f"M{i}"
        ruta = os.path.join(MODULOS, f"{modulo}.pdf")
        if not os.path.exists(ruta):
            errores.append(f"falta {_rel(ruta)}")
            continue
        try:
            e, err, av = entradas_de_modulo(modulo, ruta)
        except ErrorLexico as ex:
            errores.append(str(ex))
            continue
        entradas += e
        errores += err
        avisos += av
        fuentes[modulo] = {"archivo": _rel(ruta),
                           "sha256": huella(ruta), "palabras": len(e)}
    for ruta in sorted(glob.glob(os.path.join(DICCIONARIOS, "*"))):
        base, ext = os.path.splitext(ruta)
        if (os.path.basename(ruta).lower() in ("readme.md", ".gitkeep")
                or ext == ".huella"):
            continue
        if ext.lower() == ".pdf":
            errores += pdf_al_dia(ruta)
            continue
        e, err = entradas_de_diccionario(ruta)
        errores += err
        entradas += e
        nombre = os.path.splitext(os.path.basename(ruta))[0]
        fuentes[nombre] = {"archivo": _rel(ruta),
                           "sha256": huella(ruta), "palabras": len(e)}
        if os.path.exists(base + ".pdf"):
            fuentes[nombre]["pdf"] = _rel(base + ".pdf")
    with open(CATALOGO, encoding="utf-8") as f:
        catalogo = json.load(f)
    lexico, ambiguas, mas = unir(catalogo, entradas, glosas_animadas())
    avisos += mas
    datos = {
        "nota": "GENERADO por tool/build_lexico_lsb.py desde docs/lsb_fuentes "
                "y aws/catalogo_senas.json. No editar a mano.",
        "fuentes": fuentes,
        "glosas": {g: lexico[g] for g in sorted(lexico)},
        # Formas que nombran más de una seña: una palabra así no se cambia
        # sola por una glosa; pasa por las equivalencias.
        "ambiguas": ambiguas,
    }
    return datos, errores, avisos


def cargar(ruta: str = SALIDA) -> dict:
    """El léxico generado, o {} si no existe."""
    if not os.path.exists(ruta):
        return {}
    with open(ruta, encoding="utf-8") as f:
        return json.load(f)


def main() -> int:
    datos, errores, avisos = construir()
    for a in avisos:
        print(f"aviso: {a}")
    if errores:
        for e in errores:
            print(f"ERROR: {e}")
        print(f"{len(errores)} errores: no se escribe nada; el léxico activo "
              "no cambió.")
        return 1
    glosas = datos["glosas"]
    por_fuente = {}
    for d in glosas.values():
        for f in {x["fuente"] for x in d["fuentes"]}:
            por_fuente[f] = por_fuente.get(f, 0) + 1
    print(f"léxico: {len(glosas)} glosas · "
          f"{sum(d['catalogo'] for d in glosas.values())} del catálogo · "
          f"{sum(d['animacion'] for d in glosas.values())} con animación · "
          f"{len(datos['ambiguas'])} formas ambiguas")
    print("por fuente: " + ", ".join(f"{k} {v}" for k, v in sorted(por_fuente.items())))
    texto = json.dumps(datos, ensure_ascii=False, indent=1) + "\n"
    if "--check" in sys.argv:
        if not os.path.exists(SALIDA) or open(SALIDA, encoding="utf-8").read() != texto:
            print(f"desactualizado: {os.path.relpath(SALIDA, ROOT)}\n"
                  "Ejecuta: python tool/build_lexico_lsb.py")
            return 1
        print("Léxico LSB al día con sus fuentes.")
        return 0
    with open(SALIDA, "w", encoding="utf-8", newline="") as f:
        f.write(texto)
    print(f"escrito: {os.path.relpath(SALIDA, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
