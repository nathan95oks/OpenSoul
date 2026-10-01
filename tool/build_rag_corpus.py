"""Corpus RAG de trámites de Cochabamba: validación y generación.

    python tool/build_rag_corpus.py            # valida y escribe
    python tool/build_rag_corpus.py --check    # valida y comprueba que lo
                                               # generado está al día

Fuentes editables (crecen añadiendo archivos, sin tocar este programa):

    docs/negocio/rag/escenarios/*.md    escenarios con el formato del prompt
                                        (docs/negocio/rag/prompt_*.md)
    docs/negocio/rag/documentos/        PDFs y .md oficiales que las fuentes
                                        pueden citar como «documentos/x.pdf#p=3»
    docs/negocio/rag/glosas_cache.json  glosas LSB ya traducidas
                                        (tool/rag_precalcular_glosas.py)

Genera (no editar a mano):

    assets/rag/escenarios_cbba.json   corpus que usa la app

Los escenarios vienen de fuera del repositorio: se tratan como datos, no como
verdad. Devuelve 1 y no escribe nada si contradicen su formato (identificador
repetido, también entre archivos; hecho, fuente o documento inexistente;
página fuera del PDF; turno sin rol válido). Además marca, sin fallar, lo que
nunca debe mostrarse a la persona sorda:

  * turnos que dependen de un dato `[VERIFICAR]` o de un dato vencido
    («hasta el 2026-10-05» ya pasado), o que hablan de la fuente en vez de
    atender («la página señala…», «para este corpus…»);
  * respuestas del usuario sordo con datos concretos de ejemplo (placas,
    edades, años, montos): ofrecerlas como tarjeta pondría un dato ficticio
    en boca de la persona.
"""

from __future__ import annotations

import datetime
import glob
import json
import os
import re
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rag_texto as T  # noqa: E402

ROOT =os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAG = os.path.join(ROOT, "docs", "negocio", "rag")
ESCENARIOS = os.path.join(RAG, "escenarios")
DOCUMENTOS = os.path.join(RAG, "documentos")
SALIDA = os.path.join(ROOT, "assets", "rag", "escenarios_cbba.json")
# Los trámites como recorridos del banco de preguntas (familia «Trámites» del
# módulo de tarjetas LSB): cada pregunta del funcionario es un paso y las
# respuestas documentadas de la persona sorda son sus opciones.
SALIDA_TRAMITES = os.path.join(ROOT, "lib", "core", "domain", "rag",
                               "tramites_data.g.dart")
# Glosas de las frases del usuario sordo, traducidas una vez por la Lambda
# Texto→LSB (tool/rag_precalcular_glosas.py). Se leen sin red.
GLOSAS = os.path.join(RAG, "glosas_cache.json")
# Señas del catálogo equivalentes a palabras sin seña (tool/rag_equivalencias.py).
# Solo se usan las aprobadas.
EQUIVALENCIAS = os.path.join(RAG, "senas_equivalentes.json")
# Glosas corregidas de frases que marcó la revisión (tool/rag_corregir_glosas.py):
# mandan sobre las de la caché de traducción.
CORRECCIONES = os.path.join(RAG, "glosas_correcciones.json")
# Zonas de tarjetas: la de cada seña oficial (aws/zonas_senas.json), la de
# cada seña a incorporar que Titan y Bedrock ubicaron de acuerdo
# (tool/rag_zonas.py) y las formas en español de las señas.
ZONAS_SENAS = os.path.join(ROOT, "aws", "zonas_senas.json")
FORMAS_SENAS = os.path.join(ROOT, "aws", "catalogo_senas.json")
ZONAS_PALABRAS = os.path.join(RAG, "zonas_palabras.json")
# Zonas con las que se contesta un trámite juntando tarjetas: cosas y datos
# («la boleta y el folio»). Los verbos (Acciones, donde el catálogo también
# pone ¿Dónde? o ¿Cuál?), los adjetivos y las partículas no se juntan en una
# lista: esas respuestas ya van en las frases documentadas.
ZONAS_DE_RESPUESTA = {
    "Documentos", "Objetos", "Lugares", "Tiempo", "Identificación",
    "Instituciones", "Conceptos jurídicos", "Números",
}
MAX_TARJETAS = 8
# Partículas de respuesta: ya van en las frases documentadas, no abren zona
# ni son tarjeta (el diccionario pone SÍ en «Hechos y urgencia»).
_PARTICULAS = {"si", "no", "no_saber", "tal_vez", "puedo", "no_puedo",
               "verdad", "mentira", "estar_de_acuerdo", "no_estar_de_acuerdo",
               # Adverbios de lugar: en una lista quedan «Casa y aquí».
               "aqui", "alli", "alla", "cerca", "lejos", "dentro", "fuera",
               "atras", "enfrente", "al_lado"}
# La lista de vocabulario por crecer, para leer y compartir.
SALIDA_VOCABULARIO = os.path.join(RAG, "senas_a_incorporar.md")

# Un hecho con plazo («hasta el 2026-10-05») deja de valer al pasar la fecha.
_HASTA = re.compile(r"hasta\s+(?:el\s+)?(\d{4}-\d{2}-\d{2})", re.IGNORECASE)

ROLES = {"Usuario Sordo": "sordo", "Funcionario": "funcionario"}
TIPOS = {"conocimiento_fijo", "dato_en_vivo", "mixto"}

# Límites del prompt de investigación: frases cortas para traducir a LSB.
MAX_PALABRAS_SORDO = 12
MAX_PALABRAS_FUNCIONARIO = 25

# Lenguaje de quien documenta, no de quien atiende una ventanilla.
_META = re.compile(
    r"\b(la página|el portal|la publicación|la ficha|la tabla|el observatorio|"
    r"para este corpus|consultad[oa]|verificado en)\b"
    r"|\bpublica(n)?\b|\bgob\.bo\b",
    re.IGNORECASE,
)
# Un dato concreto en una respuesta de la persona sorda: cifras o números
# escritos, años de gestión, placas o códigos.
_NUMERO_ESCRITO = re.compile(
    r"\b(uno|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|"
    r"trece|catorce|quince|dieciséis|diecisiete|dieciocho|diecinueve|veinte|"
    r"treinta|cuarenta|cincuenta|cien|mil)\b",
    re.IGNORECASE,
)
_CIFRA = re.compile(r"\d")
# «un/una» también es artículo; solo cuentan como número junto a una unidad.
_UNIDADES = re.compile(
    r"\b(años?|meses?|semanas?|días?|horas?|bolivianos|bs)\b", re.IGNORECASE)


class ErrorCorpus(Exception):
    pass


def _norm(texto: str) -> str:
    sin_tildes = unicodedata.normalize("NFD", texto.lower())
    return "".join(c for c in sin_tildes if unicodedata.category(c) != "Mn")


def _celdas(linea: str) -> list:
    return [c.strip() for c in linea.strip().strip("|").split("|")]


def _es_separador(linea: str) -> bool:
    return bool(re.fullmatch(r"\|[\s|:-]+\|?", linea.strip()))


def _comillas(texto: str) -> list:
    return [t.strip() for t in re.findall(r"«([^»]+)»", texto)]


def _ids(texto: str, prefijo: str) -> list:
    return re.findall(rf"\b{prefijo}-[A-Z]+-\d+\b", texto)


def _palabras(texto: str) -> int:
    return len(re.findall(r"[\wÁÉÍÓÚÜÑáéíóúüñ]+", texto))


def _dato_concreto(texto: str) -> bool:
    if _CIFRA.search(texto):
        return True
    escritos = [m for m in _NUMERO_ESCRITO.findall(texto)
                if m.lower() not in ("uno", "una")]
    if escritos:
        return True
    # «un año», «una semana»: el artículo acompaña a una unidad de medida.
    return bool(re.search(r"\b(un|una)\s+" + _UNIDADES.pattern[2:-2],
                          texto, re.IGNORECASE))


def _valores_ficticios(lineas: list) -> list:
    """Valores concretos de «Datos ficticios» («Placa: 4821ABC (ficticia)»)."""
    out = []
    for linea in lineas:
        m = re.match(r"-\s*[^:]+:\s*(.+)", linea)
        if not m:
            continue
        valor = re.sub(r"\s*\(fictici[oa]s?\)\s*$", "", m.group(1)).strip()
        if re.search(r"dato_en_vivo|\[VERIFICAR\]|fictici|verificad|omitid|oficial",
                     valor, re.IGNORECASE):
            continue
        if valor:
            out.append(valor)
    return out


def _rel(ruta: str) -> str:
    return os.path.relpath(ruta, ROOT).replace(os.sep, "/")


def leer(ruta: str) -> tuple:
    """(fuentes, hechos, escenarios, errores, avisos) de un archivo."""
    with open(ruta, encoding="utf-8") as f:
        texto = f.read()
    # Los comentarios HTML son notas para quien revisa, no datos. Se
    # conservan sus saltos para que los números de línea sigan valiendo.
    texto = re.sub(r"<!--.*?-->", lambda m: "\n" * m.group().count("\n"),
                   texto, flags=re.DOTALL)
    lineas = texto.splitlines()
    archivo = _rel(ruta)

    fuentes, hechos, escenarios = {}, {}, []
    errores, avisos = [], []
    seccion = None
    esc = None
    sub = None

    def cerrar():
        if esc is not None:
            escenarios.append(esc)

    for n, linea in enumerate(lineas, 1):
        if linea.startswith("## "):
            titulo = linea[3:].strip()
            m = re.match(r"(ESC-[A-Z]+-\d+)\s+—\s+(.+)", titulo)
            cerrar()
            esc = None
            sub = None
            if titulo == "Fuentes":
                seccion = "fuentes"
            elif titulo == "Hechos verificados":
                seccion = "hechos"
            elif m:
                seccion = "escenario"
                esc = {"id": m.group(1), "titulo": m.group(2).strip(),
                       "meta": {}, "turnos": [], "variantes": [],
                       "ficticios": [], "ramificaciones": [],
                       "composicion": [], "_linea": n, "archivo": archivo}
            else:
                seccion = None
            continue
        if linea.startswith("### "):
            sub = _norm(linea[4:].strip())
            continue
        if linea.startswith("# "):
            cerrar()
            esc, seccion, sub = None, None, None
            continue
        if not linea.strip() or _es_separador(linea):
            continue

        if seccion == "fuentes" and linea.startswith("|"):
            c = _celdas(linea)
            if c[0] == "ID" or len(c) < 5:
                continue
            fid = c[0]
            if fid in fuentes and fuentes[fid]["url"] != c[3]:
                errores.append(f"{archivo}:{n}: fuente {fid} repetida con otra URL")
            fuentes[fid] = {"institucion": c[1], "titulo": c[2],
                            "url": c[3], "consultado": c[4], "archivo": archivo}
        elif seccion == "hechos" and linea.startswith("|"):
            c = _celdas(linea)
            if c[0] == "ID" or len(c) < 6:
                continue
            hid = c[0]
            if hid in hechos:
                errores.append(f"{archivo}:{n}: hecho {hid} repetido")
            hechos[hid] = {"institucion": c[1], "hecho": c[2], "tipo": c[3],
                           "fuentes": _ids(c[4], "F"), "vigencia": c[5],
                           # El dato mismo no está confirmado: nunca se muestra.
                           "verificar": "[VERIFICAR]" in c[2],
                           # El dato está en la fuente, pero no se pudo probar
                           # que siga vigente: se muestra como «a confirmar».
                           "vigenciaSinConfirmar": "[VERIFICAR]" in c[5],
                           "archivo": archivo}
        elif seccion == "escenario" and esc is not None:
            if sub is None and linea.startswith("- **"):
                m = re.match(r"- \*\*([^:*]+):\*\*\s*(.*)", linea)
                if m:
                    esc["meta"][_norm(m.group(1)).strip()] = m.group(2).strip()
            elif sub is None and linea.startswith("|"):
                c = _celdas(linea)
                if c[0] == "#" or len(c) < 5:
                    continue
                esc["turnos"].append({"n": c[0], "rol": c[1], "texto": c[2],
                                      "proposito": c[3], "hechos": c[4],
                                      "_linea": n})
            elif sub == "variantes" and linea.startswith("- **"):
                m = re.match(r"- \*\*(.+?):\*\*\s*(.*)", linea)
                if m:
                    esc["variantes"].append((m.group(1), m.group(2), n))
            elif sub == "datos ficticios" and linea.startswith("-"):
                esc["ficticios"].append(linea)
            elif sub in ("ramificaciones", "composicion"):
                m = re.match(r"- \*\*(.+?):\*\*\s*(.*)", linea)
                if m:
                    esc[sub].append((m.group(1), m.group(2), n))
                else:
                    errores.append(f"{archivo}:{n}: línea de «{sub}» sin el "
                                   "formato «- **Turno N:** …»")
    cerrar()
    return fuentes, hechos, escenarios, errores, avisos


def revisar_archivo(ruta: str) -> list:
    """Errores que impiden leer [ruta] como archivo de escenarios: que no sea
    texto (un PDF, aunque se llame `.md`), que sea la copia como texto de un
    PDF, que tenga caracteres dañados o que sea texto extraído de un
    documento."""
    archivo = _rel(ruta)
    formato = T.detectar_formato(ruta)
    tipo = formato["formato"]
    if tipo == "pdf" or tipo == "copia_pdf":
        que = ("es un PDF" if tipo == "pdf"
               else f"es la copia como texto de un PDF ({formato['detalle']})")
        return [f"{archivo} {que}, no un archivo de escenarios. El PDF "
                f"original va en {_rel(DOCUMENTOS)}/ y se prepara con "
                "python tool/rag_ingestar_documentos.py"]
    if tipo in ("binario", "no_utf8"):
        return [f"{archivo} no es texto UTF-8 ({formato['detalle']})"]
    if tipo == "vacio":
        return [f"{archivo} está vacío"]
    with open(ruta, encoding="utf-8") as f:
        texto = f.read()
    errores = T.resumir(T.problemas(texto), f"{archivo}: ")
    if re.search(r"<!-- origen: documentos/[^>]*texto extraído", texto[:600]):
        errores.append(f"{archivo} es texto extraído de un documento, no "
                       "escenarios: va en documentos/extraido/")
    return errores


def leer_todos(carpeta: str = ESCENARIOS, extras: list = ()) -> tuple:
    """Une todos los `.md` de [carpeta] (y los [extras], para validar un
    borrador junto al corpus). Un identificador solo puede definirse una vez
    en todo el corpus; una fuente puede repetirse si es la misma.

    Cualquier otro archivo de la carpeta es un error: un PDF puesto aquí se
    ignoraría sin avisar."""
    fuentes, hechos, escenarios, errores, avisos = {}, {}, [], [], []
    archivos = sorted(glob.glob(os.path.join(carpeta, "*.md"))) + list(extras)
    for otro in sorted(glob.glob(os.path.join(carpeta, "*"))):
        nombre = os.path.basename(otro)
        if (os.path.isfile(otro) and not nombre.endswith(".md")
                and not nombre.startswith(".")):
            errores.append(
                f"{_rel(otro)}: en {_rel(carpeta)}/ solo van escenarios .md. "
                f"Un documento (PDF, .txt) va en {_rel(DOCUMENTOS)}/ y se "
                "prepara con python tool/rag_ingestar_documentos.py")
    if not archivos:
        errores.append(f"no hay escenarios en {_rel(carpeta)}")
    donde = {}
    for ruta in archivos:
        problemas_archivo = revisar_archivo(ruta)
        if problemas_archivo:
            errores += problemas_archivo
            continue
        f, h, e, err, av = leer(ruta)
        errores += err
        avisos += av
        if not (f or h or e):
            errores.append(f"{_rel(ruta)} no tiene escenarios, fuentes ni "
                           "hechos con el formato del prompt")
        for fid, fuente in f.items():
            previa = fuentes.get(fid)
            if previa and previa["url"] != fuente["url"]:
                errores.append(f"{fid} definida en {previa['archivo']} y en "
                               f"{fuente['archivo']} con otra URL")
            fuentes.setdefault(fid, fuente)
        for hid, hecho in h.items():
            if hid in hechos:
                errores.append(f"{hid} definido en {hechos[hid]['archivo']} y en "
                               f"{hecho['archivo']}")
            hechos.setdefault(hid, hecho)
        for esc in e:
            if esc["id"] in donde:
                errores.append(f"{esc['id']} definido en {donde[esc['id']]} y en "
                               f"{esc['archivo']}")
                continue
            donde[esc["id"]] = esc["archivo"]
            escenarios.append(esc)
    return fuentes, hechos, escenarios, errores, avisos, [_rel(a) for a in archivos]


def _documento_local(url: str):
    """(ruta, página) si la fuente es un documento del repositorio."""
    if url.startswith(("http://", "https://")):
        return None
    ruta, _, fragmento = url.partition("#")
    m = re.fullmatch(r"p=(\d+)", fragmento)
    return os.path.join(RAG, ruta), int(m.group(1)) if m else None


def _paginas_pdf(ruta: str):
    try:
        from pypdf import PdfReader
    except ImportError:
        return None
    return len(PdfReader(ruta).pages)


ESTADOS = ("afirmado", "negado", "desconocido")
_RAMA = re.compile(r"si\s+Turno\s+(\d+)\s+(es|=)\s+(.+)", re.IGNORECASE)


def leer_relaciones(eid: str, esc: dict, turnos: list, pares: list,
                    errores: list) -> tuple:
    """(ramificaciones, composición) que declara el escenario.

    Solo lo escrito en `### Ramificaciones` y `### Composición` crea
    relaciones; una nota narrativa («Escenarios posibles») no. Cada
    ramificación hace depender un turno del funcionario de la respuesta a un
    turno **anterior** (así no puede haber ciclos):

        - **Turno 6:** si Turno 4 es negado o desconocido
        - **Turno 8:** si Turno 4 = «Sí, traje mi cédula.»; si Turno 6 es afirmado

    Varias condiciones separadas por «;» deben cumplirse todas. La composición
    da la frase con que se juntan las tarjetas de una pregunta abierta:

        - **Turno 4:** «Traje {items}.»
    """
    por_n = {t["n"]: t for t in turnos}

    def documentadas(n: int) -> list:
        siguiente = por_n.get(n + 1)
        out = [siguiente["texto"]] if siguiente and siguiente["rol"] == "sordo" else []
        return out + [r["texto"] for p in pares if p["turno"] == n
                      for r in p["respuestas"]]

    def del_funcionario(n: int, donde: str) -> bool:
        t = por_n.get(n)
        if t is None or t["rol"] != "funcionario":
            errores.append(f"{eid} {donde}: el turno {n} no es una pregunta "
                           "del funcionario de este escenario")
            return False
        return True

    ramas, hijos = [], set()
    for etiqueta, contenido, linea in esc.get("ramificaciones", []):
        donde = f"línea {linea}"
        m = re.fullmatch(r"Turno (\d+)", etiqueta.strip())
        if not m:
            errores.append(f"{eid} {donde}: ramificación sin «Turno N»: «{etiqueta}»")
            continue
        n = int(m.group(1))
        if not del_funcionario(n, donde):
            continue
        if n in hijos:
            errores.append(f"{eid} {donde}: el turno {n} ya tiene ramificación; "
                           "junta sus condiciones con «;»")
            continue
        hijos.add(n)
        condiciones, valida = [], True
        for clausula in [c for c in re.split(r";\s*", contenido.strip()) if c]:
            c = _RAMA.fullmatch(clausula.strip().rstrip("."))
            if not c:
                errores.append(f"{eid} {donde}: «{clausula}» no es «si Turno N "
                               "es <estado>» ni «si Turno N = «respuesta»»")
                valida = False
                continue
            p = int(c.group(1))
            if not del_funcionario(p, donde):
                valida = False
                continue
            if p >= n:
                errores.append(f"{eid} {donde}: el turno {n} solo puede depender "
                               f"de un turno anterior, no del {p} (evita ciclos)")
                valida = False
                continue
            respuestas = documentadas(p)
            if c.group(2).lower() == "es":
                estados = [s for s in re.split(r"\s*(?:,|·|\bo\b)\s*",
                                               c.group(3).strip().lower()) if s]
                for s in estados:
                    if s not in ESTADOS:
                        errores.append(f"{eid} {donde}: estado desconocido «{s}» "
                                       f"(se espera {', '.join(ESTADOS)})")
                        valida = False
                    elif s not in {_estado(r) for r in respuestas}:
                        errores.append(f"{eid} {donde}: ninguna respuesta "
                                       f"documentada del turno {p} es «{s}»")
                        valida = False
                condiciones.append({"turno": p, "estados": estados})
            else:
                elegidas = _comillas(c.group(3))
                if not elegidas:
                    errores.append(f"{eid} {donde}: falta la respuesta entre «»")
                    valida = False
                for r in elegidas:
                    if r not in respuestas:
                        errores.append(f"{eid} {donde}: «{r}» no es una respuesta "
                                       f"documentada del turno {p}")
                        valida = False
                condiciones.append({"turno": p, "respuestas": elegidas})
        if valida and condiciones:
            ramas.append({"turno": n, "condiciones": condiciones})

    composicion, vistos = [], set()
    for etiqueta, contenido, linea in esc.get("composicion", []):
        donde = f"línea {linea}"
        m = re.fullmatch(r"Turno (\d+)", etiqueta.strip())
        plantillas = _comillas(contenido)
        if not m or len(plantillas) != 1:
            errores.append(f"{eid} {donde}: la composición es «- **Turno N:** "
                           "«Frase con {items}.»»")
            continue
        n, plantilla = int(m.group(1)), plantillas[0]
        if not del_funcionario(n, donde):
            continue
        if n in vistos:
            errores.append(f"{eid} {donde}: el turno {n} ya tiene composición")
            continue
        vistos.add(n)
        if plantilla.count("{items}") != 1 or re.sub(r"\{items\}", "",
                                                     plantilla).count("{"):
            errores.append(f"{eid} {donde}: la plantilla lleva «{{items}}» una "
                           "sola vez y ningún otro hueco")
            continue
        composicion.append({"turno": n, "plantilla": plantilla})
    return ramas, composicion


def construir(fuentes, hechos, escenarios, errores, avisos,
              hoy: str | None = None, archivos: list | None = None) -> dict:
    hoy = hoy or os.environ.get("RAG_HOY") or datetime.date.today().isoformat()
    vistos = set()

    def documento_local(quien: str, url: str) -> None:
        ruta, pagina = _documento_local(url)
        if not os.path.exists(ruta):
            errores.append(f"{quien}: el documento {url} no existe en "
                           f"{_rel(DOCUMENTOS)}")
        elif pagina is not None and ruta.lower().endswith(".pdf"):
            total = _paginas_pdf(ruta)
            if total is None:
                avisos.append(f"{quien}: sin pypdf no se comprueba la página {pagina}")
            elif not 1 <= pagina <= total:
                errores.append(f"{quien}: página {pagina} fuera de {url} "
                               f"({total} páginas)")

    for fid, f in fuentes.items():
        if _documento_local(f["url"]) is not None:
            documento_local(fid, f["url"])
        else:
            if not f["url"].startswith("https://"):
                avisos.append(f"{fid}: URL sin https: {f['url']}")
            dominio = re.sub(r"https?://([^/]+).*", r"\1", f["url"])
            if not (dominio.endswith(".gob.bo") or dominio.endswith(".bo")
                    or dominio.endswith(".org.bo")):
                avisos.append(f"{fid}: fuente fuera de dominios oficiales ({dominio})")
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", f["consultado"]):
            errores.append(f"{fid}: fecha de consulta inválida «{f['consultado']}»")
    for hid, h in hechos.items():
        for fid in h["fuentes"]:
            if fid not in fuentes:
                errores.append(f"{hid}: cita la fuente inexistente {fid}")
        if not h["fuentes"] and not h["verificar"] and h["tipo"] != "dato_en_vivo":
            errores.append(f"{hid}: hecho sin fuente y sin [VERIFICAR]")
        plazos = _HASTA.findall(f"{h['hecho']} {h['vigencia']}")
        h["vence"] = max(plazos) if plazos else None
        h["vencido"] = bool(h["vence"] and h["vence"] < hoy)
        if h["vencido"]:
            avisos.append(f"{hid}: venció el {h['vence']}; sus turnos dejan de "
                          "mostrarse hasta actualizar el dato")

    # Una misma área (ESC-DDRR-…) nombra una sola institución.
    instituciones = {}
    for esc in escenarios:
        area = esc["id"].split("-")[1]
        nombre = esc["meta"].get("institucion", "")
        previa = instituciones.setdefault(area, (nombre, esc["id"]))
        if previa[0] != nombre:
            avisos.append(f"{esc['id']}: institución «{nombre}» distinta de "
                          f"«{previa[0]}» ({previa[1]}); la app usa la primera")

    salida = []
    for esc in escenarios:
        eid = esc["id"]
        if eid in vistos:
            errores.append(f"{eid}: escenario repetido")
        vistos.add(eid)
        meta = esc["meta"]
        for campo in ("institucion", "tramite", "tipo", "inicia", "situacion"):
            if campo not in meta:
                errores.append(f"{eid}: falta «{campo}»")
        if meta.get("tipo") not in TIPOS:
            errores.append(f"{eid}: tipo desconocido «{meta.get('tipo')}»")
        if not esc["turnos"]:
            errores.append(f"{eid}: sin diálogo")
            continue

        ficticios = [_norm(v) for v in _valores_ficticios(esc["ficticios"])]

        def evaluar(texto: str, rol: str, citados: list, proposito: str = "") -> tuple:
            motivos = []
            if "[VERIFICAR]" in texto or any(
                    hechos.get(h, {}).get("verificar") for h in citados):
                motivos.append("dato_sin_verificar")
            if any(hechos.get(h, {}).get("vencido") for h in citados):
                motivos.append("dato_vencido")
            if any(hechos.get(h, {}).get("vigenciaSinConfirmar")
                   for h in citados):
                motivos.append("vigencia_sin_confirmar")
            if rol == "funcionario" and _META.search(texto):
                motivos.append("habla_de_la_fuente")
            if rol == "sordo":
                if (_dato_concreto(texto)
                        or _norm(proposito) == "dato ficticio"
                        or any(v and v in _norm(texto) for v in ficticios)):
                    motivos.append("dato_personal_de_ejemplo")
            return motivos

        turnos = []
        for i, t in enumerate(esc["turnos"], 1):
            if t["n"] != str(i):
                errores.append(f"{eid}: turno {t['n']} fuera de orden (se esperaba {i})")
            rol = ROLES.get(t["rol"])
            if rol is None:
                errores.append(f"{eid} turno {t['n']}: rol desconocido «{t['rol']}»")
                continue
            citados = [] if t["hechos"] in ("—", "-", "") else _ids(t["hechos"], "H")
            for h in citados:
                if h not in hechos:
                    errores.append(f"{eid} turno {t['n']}: cita el hecho inexistente {h}")
            maximo = MAX_PALABRAS_SORDO if rol == "sordo" else MAX_PALABRAS_FUNCIONARIO
            if _palabras(t["texto"]) > maximo:
                avisos.append(f"{eid} turno {t['n']}: {_palabras(t['texto'])} palabras "
                              f"(máximo {maximo})")
            if (rol == "funcionario" and re.search(r"\bBs\b|\d", t["texto"])
                    and not citados):
                avisos.append(f"{eid} turno {t['n']}: menciona una cifra sin citar hecho")
            motivos = evaluar(t["texto"], rol, citados, t["proposito"])
            turnos.append({
                "n": i, "rol": rol, "texto": t["texto"],
                "proposito": t["proposito"], "hechos": citados,
                "mostrable": not motivos, "motivos": motivos,
            })

        # «Turno N (Funcionario)»: otras formas de la misma pregunta.
        # «Respuestas»: respuestas posibles a la pregunta anterior.
        pares = []
        for etiqueta, contenido, linea in esc["variantes"]:
            m = re.match(r"Turno (\d+) \((Funcionario|Usuario Sordo)\)", etiqueta)
            if m:
                n = int(m.group(1))
                referido = next((t for t in turnos if t["n"] == n), None)
                if referido is None:
                    errores.append(f"{eid}: variante del turno inexistente {n}")
                    continue
                if referido["rol"] != "funcionario":
                    avisos.append(f"{eid}: las variantes del «turno {n}» son preguntas "
                                  "del funcionario, pero ese turno es del usuario sordo")
                elif ("?" not in referido["texto"]
                      and any("?" in q for q in _comillas(contenido))):
                    # Sus respuestas se ofrecen para cada variante: si el
                    # turno no pregunta, nada asegura que respondan lo mismo.
                    avisos.append(f"{eid}: las variantes del turno {n} son preguntas "
                                  "pero el turno no lo es; revisa que todas se "
                                  "respondan con las mismas «Respuestas»")
                pares.append({"turno": n, "preguntas": _comillas(contenido),
                              "respuestas": []})
            elif etiqueta.startswith("Respuestas"):
                if not pares:
                    errores.append(f"{eid} línea {linea}: respuestas sin pregunta")
                    continue
                pares[-1]["respuestas"] = [
                    {"texto": r,
                     "mostrable": not (m := evaluar(r, "sordo", [])),
                     "motivos": m}
                    for r in _comillas(contenido)
                ]
            else:
                avisos.append(f"{eid} línea {linea}: variante no reconocida «{etiqueta}»")

        # De dónde sale el escenario: la página del documento que lo propone
        # y las fuentes que lo respaldan. Se citan en cada pregunta.
        documento = meta.get("documento", "")
        if documento:
            if _documento_local(documento) is None:
                errores.append(f"{eid}: «Documento» debe ser un archivo de "
                               f"{_rel(DOCUMENTOS)} («documentos/x.pdf#p=3»)")
            else:
                documento_local(eid, documento)
        referencias = _ids(meta.get("referencia", ""), "F")
        for fid in referencias:
            if fid not in fuentes:
                errores.append(f"{eid}: cita la fuente inexistente {fid}")

        ramas, composicion = leer_relaciones(eid, esc, turnos, pares, errores)

        salida.append({
            "id": eid,
            "archivo": esc["archivo"],
            "titulo": esc["titulo"],
            "institucion": meta.get("institucion", ""),
            "tramite": meta.get("tramite", ""),
            "tipo": meta.get("tipo", ""),
            "inicia": ROLES.get(meta.get("inicia", ""), meta.get("inicia", "")),
            "situacion": meta.get("situacion", ""),
            "turnos": turnos,
            "variantes": pares,
            **({"documento": documento} if documento else {}),
            **({"referencias": referencias} if referencias else {}),
            **({"ramificaciones": ramas} if ramas else {}),
            **({"composicion": composicion} if composicion else {}),
        })

    return {
        "version": 2,
        "archivos": archivos or [],
        "fuentes": fuentes,
        "hechos": hechos,
        "escenarios": salida,
    }


# Una palabra sin seña en el catálogo del avatar. La Lambda la deletrea
# (F-O-L-I-O), pero no es LSB: es una seña que falta. Se muestra como
# «seña a incorporar» con la palabra, y queda en la lista de vocabulario por
# crecer. Las siglas (NUREJ, CRPVA) sí se deletrean en LSB y no se tocan.
SENA_PENDIENTE = "SENA_PENDIENTE:"


def _es_letra(glosa: str) -> bool:
    return len(glosa) == 1 and glosa.isalpha()


def _es_sigla(palabra: str, texto: str) -> bool:
    """Si en el texto la palabra aparece escrita como sigla (NUREJ, WebID)."""
    for w in re.findall(r"\w+", texto):
        if _norm(w) == _norm(palabra) and sum(c.isupper() for c in w) >= 2:
            return True
    return False


def _es_nombre_propio(palabras: list, texto: str) -> bool:
    """Si las palabras van seguidas en el texto y todas con mayúscula."""
    w = re.findall(r"\w+", texto)
    n = len(palabras)
    return any(
        all(_norm(a) == _norm(b) and a[:1].isupper()
            for a, b in zip(w[i:i + n], palabras))
        for i in range(len(w) - n + 1))


def _mayuscula_interior(palabra: str, texto: str) -> bool:
    """Si [palabra] va con mayúscula dentro de la frase: es un nombre propio
    («Folio Real», «Derechos Reales») y no se cambia por otra seña."""
    for m in re.finditer(r"\w+", texto):
        antes = texto[:m.start()].rstrip()
        if (_norm(m.group()) == _norm(palabra) and m.group()[:1].isupper()
                and antes and antes[-1] not in ".?!¿¡:"):
            return True
    return False


def cargar_equivalencias(ruta: str = EQUIVALENCIAS) -> dict:
    """{palabra normalizada: seña} de las equivalencias aprobadas."""
    if not os.path.exists(ruta):
        return {}
    with open(ruta, encoding="utf-8") as f:
        datos = json.load(f)
    return {_norm(p.replace("_", " ")): e["sena"] for p, e in datos.items()
            if e.get("estado") == "aprobada" and e.get("sena")}


def marcar_senas_pendientes(glosas: list | None, correcciones: list,
                            texto: str,
                            equivalencias: dict | None = None) -> list | None:
    """Cambia cada palabra deletreada por no tener seña en una seña pendiente.

    La Lambda informa en `correcciones` («concepto_sin_catalogo») qué palabras
    deletreó, en orden. Si las letras no coinciden con la palabra informada
    se dejan tal cual: mejor deletreo que una palabra equivocada. Dos señas
    pendientes seguidas que en el texto forman un nombre propio («Derechos
    Reales», «Folio Real») son una sola; «es mi fiscal» no.
    """
    if not glosas:
        return glosas
    palabras = [c["palabra"] for c in correcciones
                if c.get("accion") == "concepto_sin_catalogo" and c.get("palabra")]
    salida, i = [], 0
    while i < len(glosas):
        if not _es_letra(glosas[i]) or not palabras:
            salida.append(glosas[i])
            i += 1
            continue
        # La Lambda informa las palabras en el orden del español; las glosas
        # van en el orden de LSB. Se busca la que empieza aquí (la más larga,
        # para que «DE» no se coma el comienzo de «DENUNCIA»).
        def letras_de(p: str) -> list:
            return [c for c in _norm(p).upper() if c.isalnum()]

        candidatas = [
            p for p in palabras
            if [_norm(g).upper() for g in glosas[i:i + len(letras_de(p))]]
            == letras_de(p)]
        if not candidatas:
            salida.append(glosas[i])
            i += 1
            continue
        palabra = max(candidatas, key=lambda p: len(letras_de(p)))
        letras = letras_de(palabra)
        palabras.remove(palabra)
        equivalente = (equivalencias or {}).get(_norm(palabra.replace("_", " ")))
        if _norm(palabra) == "pregunta" and "pregunt" not in _norm(texto):
            # La marca de interrogación que añade el modelo: en LSB la
            # pregunta va en la cara (cejas, cabeza), no es una seña que falte.
            pass
        elif _es_sigla(palabra, texto):
            salida.extend(glosas[i:i + len(letras)])
        elif equivalente and not _mayuscula_interior(palabra, texto):
            # Una seña oficial que significa lo mismo (revisada o con
            # evidencia del catálogo): se hace la seña, no se espera. Si la
            # frase ya la tiene («CUANTOS … C-U-A-N-T-O»), no se repite.
            if _norm(equivalente) not in {_norm(g) for g in glosas
                                          if not _es_letra(g)}:
                salida.append(equivalente)
        else:
            nombre = palabra.upper().replace(" ", "_")
            anterior = salida[-1] if salida else ""
            if (anterior.startswith(SENA_PENDIENTE)
                    and _es_nombre_propio(anterior[len(SENA_PENDIENTE):]
                                          .split("_") + [palabra], texto)):
                salida[-1] = f"{anterior}_{nombre}"
            else:
                salida.append(SENA_PENDIENTE + nombre)
        i += len(letras)
    return salida


def senas_pendientes(corpus: dict) -> dict:
    """Palabras sin seña del corpus y cuántas tarjetas las usan."""
    cuenta = {}
    for e in corpus["escenarios"]:
        tarjetas = e["turnos"] + [r for p in e["variantes"] for r in p["respuestas"]]
        for t in tarjetas:
            for g in t.get("glosas") or []:
                if g.startswith(SENA_PENDIENTE):
                    palabra = g[len(SENA_PENDIENTE):].replace("_", " ")
                    cuenta[palabra] = cuenta.get(palabra, 0) + 1
    return cuenta


def vocabulario_md(corpus: dict) -> str:
    """Las señas a incorporar, de la más usada a la menos, con un ejemplo.

    Es la lista de trabajo para crecer el vocabulario: cada palabra que se
    incorpora al catálogo (con su seña y su animación) deja de verse en azul
    en todas las tarjetas que la usan. También se listan las equivalencias
    con señas existentes, con su origen, y las que se rechazaron.
    """
    usos, ejemplo, areas = {}, {}, {}
    for e in corpus["escenarios"]:
        area = e["id"].split("-")[1]
        tarjetas = e["turnos"] + [r for p in e["variantes"] for r in p["respuestas"]]
        for t in tarjetas:
            for g in t.get("glosas") or []:
                if not g.startswith(SENA_PENDIENTE):
                    continue
                palabra = g[len(SENA_PENDIENTE):].replace("_", " ")
                usos[palabra] = usos.get(palabra, 0) + 1
                ejemplo.setdefault(palabra, t["texto"])
                areas.setdefault(palabra, set()).add(area)
    equivalencias = {}
    if os.path.exists(EQUIVALENCIAS):
        with open(EQUIVALENCIAS, encoding="utf-8") as f:
            equivalencias = json.load(f)
    notas = {}
    for p, e in equivalencias.items():
        if e.get("estado") == "rechazada" and e.get("sena"):
            notas[p.replace("_", " ")] = f"no es {e['sena']} (revisado)"
    orden = sorted(usos, key=lambda p: (-usos[p], _norm(p)))
    lineas = [
        "# Señas a incorporar",
        "",
        "Generado por `tool/build_rag_corpus.py` desde el corpus RAG. No editar a mano.",
        "",
        "Palabras de los trámites de Cochabamba que no tienen seña en el "
        "catálogo del avatar. En la app se ven en azul claro («seña a "
        "incorporar») y el avatar dice «En espera para su avatar». Al "
        "incorporar una seña (catálogo + animación) y regenerar el corpus, "
        "deja de verse en azul en todas sus tarjetas.",
        "",
        f"**{len(usos)} palabras · {sum(usos.values())} usos.** "
        "Las siglas (NUREJ, CRPVA…) no están: en LSB se deletrean.",
        "",
    ]
    aprobadas = [(p, e) for p, e in sorted(equivalencias.items())
                 if e.get("estado") == "aprobada" and e.get("sena")]
    if aprobadas:
        lineas += [
            "## Ya resueltas con una seña existente",
            "",
            "La primera columna es lo que dejó la traducción automática, a "
            "veces mal escrito (COUCHABAMBA por Cochabamba); la segunda, la "
            "seña correcta que se hace.",
            "",
            "| Dejó la traducción | Seña | Origen |",
            "|---|---|---|",
        ]
        for p, e in aprobadas:
            origen = ("catálogo oficial" if e.get("origen") == "catalogo"
                      else "Bedrock, revisado")
            lineas.append(f"| {p.replace('_', ' ')} | {e['sena']} | {origen} |")
        lineas.append("")
    lineas += [
        "## Por incorporar",
        "",
        "| # | Palabra | Usos | Instituciones | Ejemplo | Nota |",
        "|---:|---|---:|---|---|---|",
    ]
    for i, p in enumerate(orden, 1):
        ej = ejemplo[p].replace("|", "/")
        lineas.append(f"| {i} | {p} | {usos[p]} | "
                      f"{', '.join(sorted(areas[p]))} | {ej} | "
                      f"{notas.get(p, '')} |")
    return "\n".join(lineas) + "\n"


def _ofrecible(t: dict) -> bool:
    """Una respuesta de la persona sorda que se puede ofrecer como tarjeta."""
    return (t.get("rol", "sordo") == "sordo" and t["mostrable"]
            and bool(t.get("glosas")))


def _documentadas(e: dict, n: int) -> list:
    """Todas las respuestas escritas al turno [n]: el turno siguiente de la
    persona sorda y las «Respuestas» de sus variantes."""
    siguiente = next((t for t in e["turnos"] if t["n"] == n + 1), None)
    out = [siguiente] if siguiente and siguiente["rol"] == "sordo" else []
    return out + [r for p in e["variantes"] if p["turno"] == n
                  for r in p["respuestas"]]


def respuestas_de(e: dict, n: int) -> list:
    """Lo que respondió la persona sorda al turno [n] del funcionario."""
    return [t for t in _documentadas(e, n) if _ofrecible(t)]


def turnos_pregunta_posibles(e: dict) -> list:
    """Turnos del funcionario que serán preguntas en cuanto tengan glosas:
    mostrables y con alguna respuesta mostrable."""
    return [t for t in e["turnos"]
            if t["rol"] == "funcionario" and t["mostrable"]
            and any(r.get("rol", "sordo") == "sordo" and r["mostrable"]
                    for r in _documentadas(e, t["n"]))]


def frases_a_traducir(e: dict) -> list:
    """Turnos y respuestas de [e] que necesitan glosas, sin repetir texto: lo
    de la persona sorda y las preguntas del funcionario (también las nuevas,
    cuyas respuestas aún no tienen glosas)."""
    candidatas = [t for t in e["turnos"] if t["rol"] == "sordo"]
    candidatas += [r for p in e["variantes"] for r in p["respuestas"]]
    candidatas += turnos_pregunta_posibles(e)
    vistas, out = set(), []
    for t in candidatas:
        if t["mostrable"] and t["texto"] not in vistas:
            vistas.add(t["texto"])
            out.append(t)
    return out


def turnos_pregunta(e: dict) -> list:
    """Turnos del funcionario que se responden con tarjetas.

    Son las mismas claves que busca `RagRetriever`: un turno mostrable del
    funcionario con alguna respuesta que se puede ofrecer.
    """
    return [t for t in e["turnos"]
            if t["rol"] == "funcionario" and t["mostrable"]
            and respuestas_de(e, t["n"])]


_EMOJI_AREA = {
    "SEGIP": "🪪", "SERECI": "📜", "FELCC": "🚓", "FELCV": "🛡️", "FIS": "⚖️",
    "OJ": "🏛️", "SEPDEP": "🧑‍⚖️", "SEPDAVI": "🧑‍⚖️", "IMP": "💰",
    "DDRR": "🏠", "NOT": "✍️", "SLIM": "🤝", "DNA": "🧒", "DISC": "♿",
    "LSB": "🤟",
}


def _estado(texto: str) -> str:
    t = _norm(texto)
    if t.startswith("no se") or t.startswith("no recuerdo"):
        return "desconocido"
    if re.match(r"no\b", t):
        return "negado"
    return "afirmado"


def _leer(ruta: str) -> dict:
    if not os.path.exists(ruta):
        return {}
    with open(ruta, encoding="utf-8") as f:
        return json.load(f)


def datos_de_zonas() -> dict:
    """Zona y forma en español de cada seña y seña a incorporar."""
    senas = {_norm(g): (g, z) for g, z in _leer(ZONAS_SENAS).items()}
    formas = {_norm(g): f for g, f in _leer(FORMAS_SENAS).items()}
    palabras = {p: d["zona"] for p, d in _leer(ZONAS_PALABRAS).items()
                if d.get("zona")}
    return {"senas": senas, "formas": formas, "palabras": palabras}


def _tarjeta(glosa: str, zonas: dict) -> tuple | None:
    """(zona, etiqueta, frase) de una glosa, o None si no tiene zona."""
    if glosa.startswith(SENA_PENDIENTE):
        palabra = glosa[len(SENA_PENDIENTE):]
        zona = zonas["palabras"].get(palabra)
        legible = palabra.replace("_", " ").lower()
        return (zona, legible.capitalize(), legible) if zona else None
    clave = _norm(glosa)
    if clave not in zonas["senas"] or len(glosa) <= 1 or clave in _PARTICULAS:
        return None
    _, zona = zonas["senas"][clave]
    formas = zonas["formas"].get(clave) or [glosa.replace("_", " ").lower()]
    # El significado de la seña («casa», «papel»), no el fragmento de oración
    # del catálogo («mi nombre es», «debo volver»), que no se junta en lista.
    # Si el catálogo da la misma palabra con su artículo («una fotocopia»),
    # se usa esa: «Traje un certificado y una fotocopia».
    frase = formas[0].lower()
    for forma in formas[1:]:
        if re.fullmatch(r"(?:el|la|los|las|un|una|unos|unas|mi|mis)\s+"
                        + re.escape(frase), forma.lower()):
            frase = forma.lower()
            break
    return zona, formas[0], frase


# Una pregunta abierta («¿Qué documentos trajo?») se puede contestar
# juntando tarjetas; una de sí o no («¿Trajo su cédula?»), no.
_PREGUNTA_ABIERTA = re.compile(
    r"¿\s*(?:(?:a|de|en|con|para|desde|hasta)\s+)?"
    r"(?:qu[eé]|cu[aá]l(?:es)?|cu[aá]nt[oa]s?|d[oó]nde|ad[oó]nde|"
    r"cu[aá]ndo|c[oó]mo|qui[eé]n(?:es)?)\b",
    re.IGNORECASE)


def es_pregunta_abierta(texto: str) -> bool:
    return bool(_PREGUNTA_ABIERTA.search(texto))


def tarjetas_de_zona(respuestas: list, zonas: dict) -> list:
    """Tarjetas sueltas para contestar una pregunta de un trámite.

    Salen solo de las respuestas **afirmativas** documentadas para esa
    pregunta (si se respondió «Traje la boleta y el papel», BOLETA y PAPEL),
    nunca del resto del escenario: la pregunta del funcionario, otra
    pregunta o una respuesta negativa («No traje la boleta») no dan
    tarjetas. Solo cuentan las señas de cosas y datos
    ([ZONAS_DE_RESPUESTA]); una partícula o un sujeto suelto no es una
    respuesta. Se juntan cosas de una misma zona («la boleta y el papel»),
    no «ayer y casa». Con menos de dos no hay nada que juntar: la frase
    documentada ya lo dice.
    """
    por_zona, vistas = {}, set()
    for r in respuestas:
        if _estado(r["texto"]) != "afirmado":
            continue
        for g in r.get("glosas") or []:
            info = _tarjeta(g, zonas)
            if (not info or info[0] not in ZONAS_DE_RESPUESTA
                    or _norm(g) in vistas):
                continue
            vistas.add(_norm(g))
            zona, etiqueta, frase = info
            por_zona.setdefault(zona, []).append({
                "estado": "afirmado", "etiqueta": etiqueta, "frase": frase,
                "glosas": [g], "glosasPropias": True, "zona": zona,
            })
    grupo = max(por_zona.values(), key=len, default=[])
    if len(grupo) < 2:
        return []
    return [{**t, "id": f"z{i}"} for i, t in enumerate(grupo[:MAX_TARJETAS], 1)]


# Las unidades de respuesta de una pregunta de sí o no: la seña del
# catálogo, lo que se lee y su estado. Solo se ofrecen si el escenario
# documenta una respuesta de ese estado que empieza con esa partícula: así
# la unidad sale del corpus, no se supone. (La traducción de esa respuesta
# puede no llevar la seña: «Sí, la tengo.» → YO TENER.)
UNIDADES_POLARES = (
    ("afirmado", "si", "SÍ", "Sí", re.compile(r"si\b")),
    ("negado", "no", "NO", "No", re.compile(r"no\b")),
    ("desconocido", "no_se", "NO_SABER", "No sé", re.compile(r"no se\b")),
)


def es_pregunta_polar(texto: str) -> bool:
    """Una pregunta de sí o no: ni abierta («¿Qué…?») ni disyuntiva («¿Es
    víctima o persona denunciada?», que se contesta con una de las dos)."""
    if "?" not in texto or es_pregunta_abierta(texto):
        return False
    pregunta = texto[texto.find("¿") + 1:texto.rfind("?")]
    return not re.search(r"\b[ou]\b", pregunta, re.IGNORECASE)


def unidades_polares(opciones: list) -> list:
    """Las unidades SÍ, NO y NO_SABER fundadas en [opciones].

    Su frase es la partícula sola («Sí.»): no se pone en boca de la persona
    nada que no señó. Una respuesta documentada que ya es solo la partícula
    («No.») se convierte en la unidad en vez de repetirse."""
    unidades = []
    for estado, uid, glosa, etiqueta, patron in UNIDADES_POLARES:
        fundadas = [o for o in opciones
                    if o["estado"] == estado and patron.match(_norm(o["frase"]))]
        if not fundadas:
            continue
        sola = next((o for o in fundadas
                     if _norm(o["frase"]).strip(" .!") == _norm(etiqueta)), None)
        if sola is not None:
            opciones.remove(sola)
        unidades.append({
            "estado": estado, "etiqueta": etiqueta,
            "frase": sola["frase"] if sola else f"{etiqueta}.",
            "glosas": [glosa], "glosasPropias": True, "id": uid,
            "polar": True,
            "origen": f"unidad {glosa}, fundada en «{fundadas[0]['frase']}»",
        })
    return unidades


def glosas_canonicas(glosas: list) -> list:
    """Cada glosa con la forma del catálogo («SI» → «SÍ», «DONDE» →
    «DÓNDE»), si la correspondencia es única. Letras, cifras y señas a
    incorporar quedan igual."""
    global _canonicas
    if _canonicas is None:
        claves = {}
        for g in list(_leer(FORMAS_SENAS)) + list(_leer(ZONAS_SENAS)):
            claves.setdefault(_norm(g), set()).add(g)
        _canonicas = {k: next(iter(v)) for k, v in claves.items() if len(v) == 1}
    return [g if len(g) <= 1 or g.startswith(SENA_PENDIENTE)
            else _canonicas.get(_norm(g), g) for g in glosas]


_canonicas = None


def _origen(corpus: dict, e: dict, t: dict) -> dict:
    """De dónde sale una pregunta: escenario, turno, archivo y las fuentes
    (con su página, si es un documento) de sus hechos y del escenario."""
    hechos = corpus.get("hechos", {})
    fuentes = corpus.get("fuentes", {})
    ids = [f for h in t.get("hechos", []) for f in hechos.get(h, {}).get("fuentes", [])]
    ids += e.get("referencias", [])
    urls = [fuentes[f]["url"] for f in dict.fromkeys(ids) if f in fuentes]
    if e.get("documento"):
        urls.append(e["documento"])
    return {"escenario": e["id"], "turno": t["n"],
            **({"archivo": e["archivo"]} if e.get("archivo") else {}),
            "fuentes": list(dict.fromkeys(urls))}


def _condiciones(e: dict, rama: dict, preguntas: dict, avisos: list) -> list | None:
    """El `cuando` de un paso según su ramificación, o None si alguna
    pregunta o respuesta de la que depende no se ofrece (sin glosas, o con un
    dato no mostrable): entonces el paso no entra en el recorrido, en vez de
    aparecer siempre."""
    cuando = []
    for c in rama["condiciones"]:
        padre = preguntas.get(c["turno"])
        if padre is None:
            avisos.append(f"{e['id']} turno {rama['turno']}: depende del turno "
                          f"{c['turno']}, que no se ofrece; no entra en el "
                          "recorrido")
            return None
        qid, opciones = padre
        if "estados" in c:
            presentes = {o["estado"] for o in opciones}
            estados = [s for s in c["estados"] if s in presentes]
            if not estados:
                avisos.append(f"{e['id']} turno {rama['turno']}: ninguna "
                              f"respuesta ofrecida del turno {c['turno']} es "
                              f"{' o '.join(c['estados'])}; no entra en el "
                              "recorrido")
                return None
            cuando.append({"pregunta": qid, "estados": estados})
        else:
            ids = [o["id"] for o in opciones
                   if not o.get("zona") and o["frase"] in c["respuestas"]]
            if len(ids) < len(c["respuestas"]):
                avisos.append(f"{e['id']} turno {rama['turno']}: alguna respuesta "
                              f"de la que depende no se ofrece en el turno "
                              f"{c['turno']}")
            if not ids:
                return None
            cuando.append({"pregunta": qid, "opciones": ids})
    return cuando


def banco_tramites(corpus: dict, avisos: list | None = None) -> dict:
    """Preguntas, recorridos y contextos de la familia «Trámites».

    Una pregunta por turno del funcionario con respuestas (`R.<escenario>.<n>`,
    el mismo turno que encuentra el RAG), con su formulación en LSB y una
    opción por respuesta documentada distinta, cada una con su secuencia de
    glosas completa. Un recorrido por trámite: sus pasos van en el orden del
    diálogo y solo dependen unos de otros donde el escenario lo declara
    (`### Ramificaciones`); al cambiar una respuesta, el flujo guiado borra
    lo que dependía de ella.
    """
    avisos = [] if avisos is None else avisos
    preguntas, recorridos, contextos = [], {}, []
    zonas = datos_de_zonas()
    for e in corpus["escenarios"]:
        pasos = []
        ramas = {r["turno"]: r for r in e.get("ramificaciones", [])}
        plantillas = {c["turno"]: c["plantilla"] for c in e.get("composicion", [])}
        ofrecidas = {}
        for t in turnos_pregunta(e):
            qid = f"R.{e['id']}.{t['n']}"
            siguiente = next((x for x in e["turnos"] if x["n"] == t["n"] + 1), None)
            opciones, vistas = [], set()
            for r in respuestas_de(e, t["n"]):
                if r["texto"] in vistas:
                    continue
                vistas.add(r["texto"])
                opciones.append({
                    "estado": _estado(r["texto"]),
                    "etiqueta": r["texto"],
                    "frase": r["texto"],
                    "glosas": glosas_canonicas(r["glosas"]),
                    "glosasPropias": True,
                    "id": f"r{len(opciones) + 1}",
                    "origen": (f"turno {t['n'] + 1}" if r is siguiente
                               else f"respuestas del turno {t['n']}"),
                })
            glosas = glosas_canonicas(t.get("glosas") or [])
            # Una pregunta de sí o no se contesta primero con SÍ, NO o NO SÉ;
            # las respuestas documentadas más largas siguen como alternativas.
            unidades = (unidades_polares(opciones)
                        if es_pregunta_polar(t["texto"]) else [])
            # Las tarjetas sueltas: solo en una pregunta abierta, o donde el
            # escenario declara cómo se juntan.
            tarjetas = [
                {**z, "glosas": glosas_canonicas(z["glosas"])}
                for z in (tarjetas_de_zona(respuestas_de(e, t["n"]), zonas)
                          if t["n"] in plantillas
                          or es_pregunta_abierta(t["texto"]) else [])]
            if t["n"] in plantillas and not tarjetas:
                avisos.append(f"{e['id']} turno {t['n']}: la composición no tiene "
                              "tarjetas que juntar; se responde con sus frases")
            if tarjetas:
                # Una frase documentada se elige sola; las tarjetas se juntan.
                for o in opciones:
                    o["salida"] = True
            preguntas.append({
                "acto": "pregunta" if "?" in t["texto"] else "indicacion",
                "campo": "tramite",
                "campos": ["tramite"],
                **({"control": "seleccion_multiple", "maximo": len(tarjetas),
                    "plantilla": plantillas.get(t["n"], "{items}.")} if tarjetas
                   else {"control": "polar3"} if len(unidades) == 3
                   else {"control": "polar2"}
                   if [u["id"] for u in unidades] == ["si", "no"]
                   else {"control": "seleccion_unica"}),
                "dominio": "tramite",
                "entidad": "Tramite",
                "formulacion": t["texto"],
                "formulacionLsb": {
                    "estado": "GRAMMAR_PROVISIONAL",
                    "glosas": glosas,
                    "utilizable": bool(glosas),
                },
                "id": qid,
                "modo": "frase",
                "noOfrecer": [],
                "nodos": [],
                "opciones": unidades + opciones + tarjetas,
                "origen": _origen(corpus, e, t),
                "variantes": [],
            })
            paso = {"pregunta": qid}
            if t["n"] in ramas:
                cuando = _condiciones(e, ramas[t["n"]], ofrecidas, avisos)
                if cuando is None:
                    continue
                paso["cuando"] = cuando
                paso["padre"] = cuando[0]["pregunta"]
            ofrecidas[t["n"]] = (qid, unidades + opciones + tarjetas)
            pasos.append(paso)
        if not pasos:
            continue
        area = e["id"].split("-")[1]
        cid = "tramite_" + e["id"].lower().removeprefix("esc-").replace("-", "_")
        recorridos[cid] = {"nombre": e["tramite"], "pasos": pasos}
        contextos.append({
            "id": cid,
            "nombre": e["tramite"],
            "institucion": e["institucion"],
            "area": area,
            "emoji": _EMOJI_AREA.get(area, "📄"),
            "escenario": e["id"],
        })
    return {"preguntas": preguntas, "recorridos": recorridos,
            "contextos": contextos}


def dart_tramites(banco: dict) -> str:
    datos = json.dumps(banco, ensure_ascii=False, sort_keys=True,
                       separators=(",", ":"))
    assert "'''" not in datos
    return (
        "// GENERADO por tool/build_rag_corpus.py desde el corpus RAG\n"
        "// (docs/negocio/rag/escenarios/*.md y glosas_cache.json). No editar a mano.\n"
        "\n"
        "/// Trámites de Cochabamba como recorridos del banco de preguntas: cada\n"
        "/// pregunta del funcionario con sus glosas y las respuestas documentadas\n"
        "/// de la persona sorda como opciones. Lo lee `RagTramites`.\n"
        f"const String kRagTramitesJson = r'''{datos}''';\n"
    )


def aplicar_equivalencias(glosas: list, texto: str,
                          equivalencias: dict) -> list:
    """Las señas a incorporar con equivalencia aprobada pasan a su seña (en
    glosas que ya vienen marcadas, como las corregidas)."""
    presentes = {_norm(g) for g in glosas if not g.startswith(SENA_PENDIENTE)}
    salida = []
    for g in glosas:
        palabra = g[len(SENA_PENDIENTE):] if g.startswith(SENA_PENDIENTE) else None
        equivalente = (equivalencias.get(_norm(palabra.replace("_", " ")))
                       if palabra else None)
        if equivalente and not _mayuscula_interior(palabra, texto):
            if _norm(equivalente) not in presentes:
                salida.append(equivalente)
                presentes.add(_norm(equivalente))
        else:
            salida.append(g)
    return salida


LAMBDA = os.path.join(ROOT, "aws", "lambda_text_to_lsb.py")
_GLOSA = re.compile(r"[A-ZÁÉÍÓÚÜÑ0-9]+(?:_[A-ZÁÉÍÓÚÜÑ0-9]+)*")
_validas = None


def glosas_conocidas() -> set | None:
    """Glosas que existen (sin tildes): las del catálogo del avatar y los
    compuestos que arma la Lambda (`_COMPOUND_SPECS`: COMO_ESTAS, NO_SABER…).
    None si el catálogo no está."""
    global _validas
    if _validas is None and os.path.exists(FORMAS_SENAS):
        conocidas = {_norm(g) for g in _leer(FORMAS_SENAS)}
        conocidas |= {_norm(g) for g in _leer(ZONAS_SENAS)}
        if os.path.exists(LAMBDA):
            with open(LAMBDA, encoding="utf-8") as f:
                fuente = f.read()
            m = re.search(r"^_COMPOUND_SPECS = \{\n(.*?)^\}", fuente,
                          re.MULTILINE | re.DOTALL)
            if m:
                conocidas |= {_norm(g) for g in
                              re.findall(r'^    "([A-Z_]+)": \{', m.group(1),
                                         re.MULTILINE)}
        _validas = conocidas
    return _validas


def glosas_invalidas(glosas: list | None) -> list:
    """Los elementos de [glosas] que no son una glosa: cada uno debe ser una
    seña del catálogo o un compuesto de la Lambda, una letra o cifra
    (dactilología), o `SENA_PENDIENTE:PALABRA`. Una frase en español, con
    espacios, minúsculas o signos, nunca lo es."""
    conocidas = glosas_conocidas()
    malas = []
    for g in glosas or []:
        if g.startswith(SENA_PENDIENTE):
            ok = bool(_GLOSA.fullmatch(g[len(SENA_PENDIENTE):]))
        elif re.fullmatch(r"[A-ZÑ]|\d+", g):
            ok = True
        else:
            ok = bool(_GLOSA.fullmatch(g)) and (
                conocidas is None or _norm(g) in conocidas)
        if not ok:
            malas.append(g)
    return malas


def poner_glosas(corpus: dict, avisos: list) -> None:
    """Glosas precalculadas en cada tarjeta del usuario sordo que se muestra."""
    cache = {}
    if os.path.exists(GLOSAS):
        with open(GLOSAS, encoding="utf-8") as f:
            cache = json.load(f)
    equivalencias = cargar_equivalencias()
    corregidas = {}
    if os.path.exists(CORRECCIONES):
        with open(CORRECCIONES, encoding="utf-8") as f:
            corregidas = json.load(f)
    faltan = 0
    for e in corpus["escenarios"]:
        tarjetas = [t for t in e["turnos"] if t["rol"] == "sordo"]
        tarjetas += [r for p in e["variantes"] for r in p["respuestas"]]
        # Primero las respuestas: qué turnos del funcionario son preguntas
        # de un trámite depende de que tengan alguna respuesta con glosas.
        for fase in (tarjetas, None):
            for t in fase if fase is not None else turnos_pregunta(e):
                if not t["mostrable"]:
                    continue
                if t["texto"] in corregidas:
                    t["glosas"] = aplicar_equivalencias(
                        corregidas[t["texto"]]["glosas"], t["texto"],
                        equivalencias)
                    continue
                traduccion = cache.get(t["texto"])
                t["glosas"] = marcar_senas_pendientes(
                    traduccion["glosas"], traduccion.get("correcciones") or [],
                    t["texto"], equivalencias) if traduccion else None
                if traduccion is None:
                    faltan += 1
        for t in tarjetas + turnos_pregunta(e):
            malas = glosas_invalidas(t.get("glosas"))
            if malas:
                # Una frase en español guardada como glosa («SÍ, LA TRAJE»)
                # o una seña que no existe: no se ofrece como si fuera LSB.
                avisos.append(f"{e['id']}: «{t['texto']}» tiene elementos que "
                              f"no son glosas ({', '.join(malas)}); no se ofrece "
                              "hasta corregirlo (tool/rag_corregir_glosas.py)")
                t["glosas"] = None
    if faltan:
        avisos.append(f"{faltan} tarjetas sin glosas: ejecuta "
                      "tool/rag_precalcular_glosas.py")


def resumen(corpus: dict) -> list:
    turnos = [t for e in corpus["escenarios"] for t in e["turnos"]]
    sordo = [t for t in turnos if t["rol"] == "sordo"]
    respuestas = [r for e in corpus["escenarios"] for p in e["variantes"]
                  for r in p["respuestas"]]
    motivos = {}
    for t in turnos + respuestas:
        for m in t["motivos"]:
            motivos[m] = motivos.get(m, 0) + 1
    return [
        f"archivos: {len(corpus['archivos'])} · "
        f"escenarios: {len(corpus['escenarios'])} · fuentes: {len(corpus['fuentes'])} · "
        f"hechos: {len(corpus['hechos'])} "
        f"({sum(h['verificar'] for h in corpus['hechos'].values())} por verificar, "
        f"{sum(h['vigenciaSinConfirmar'] and not h['verificar'] for h in corpus['hechos'].values())} "
        "con vigencia a confirmar, "
        f"{sum(h['vencido'] for h in corpus['hechos'].values())} vencidos)",
        f"turnos: {len(turnos)} ({len(sordo)} del usuario sordo) · "
        f"mostrables: {sum(t['mostrable'] for t in turnos)}",
        f"respuestas alternativas: {len(respuestas)} · "
        f"mostrables: {sum(r['mostrable'] for r in respuestas)}",
        "no mostrables por motivo: " + ", ".join(
            f"{k} {v}" for k, v in sorted(motivos.items())),
        _linea_pendientes(senas_pendientes(corpus)),
    ]


def _linea_pendientes(cuenta: dict) -> str:
    mas = sorted(cuenta.items(), key=lambda kv: (-kv[1], kv[0]))[:8]
    return (f"señas a incorporar: {len(cuenta)} palabras en "
            f"{sum(cuenta.values())} usos · más usadas: "
            + ", ".join(f"{p} {n}" for p, n in mas))


def main() -> int:
    fuentes, hechos, escenarios, errores, avisos, archivos = leer_todos()
    corpus = construir(fuentes, hechos, escenarios, errores, avisos,
                       archivos=archivos)
    poner_glosas(corpus, avisos)
    banco = banco_tramites(corpus, avisos) if not errores else None
    for a in avisos:
        print(f"aviso: {a}")
    if errores:
        for e in errores:
            print(f"ERROR: {e}")
        print(f"{len(errores)} errores: no se escribe nada; el corpus activo "
              "no cambió.")
        return 1
    texto = json.dumps(corpus, ensure_ascii=False, indent=1) + "\n"
    salidas = {SALIDA: texto, SALIDA_TRAMITES: dart_tramites(banco),
               SALIDA_VOCABULARIO: vocabulario_md(corpus)}
    for linea in resumen(corpus):
        print(linea)
    print(f"trámites: {len(banco['contextos'])} recorridos · "
          f"{len(banco['preguntas'])} preguntas · "
          f"{sum(len(q['opciones']) for q in banco['preguntas'])} respuestas")
    if "--check" in sys.argv:
        viejas = [r for r, t in salidas.items()
                  if not os.path.exists(r) or open(r, encoding="utf-8").read() != t]
        for r in viejas:
            print(f"desactualizado: {os.path.relpath(r, ROOT)}")
        if viejas:
            print("Ejecuta: python tool/build_rag_corpus.py")
            return 1
        print("Corpus RAG al día y coherente con su fuente.")
        return 0
    for ruta, contenido in salidas.items():
        os.makedirs(os.path.dirname(ruta), exist_ok=True)
        with open(ruta, "w", encoding="utf-8", newline="") as f:
            f.write(contenido)
        print(f"escrito: {os.path.relpath(ruta, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
