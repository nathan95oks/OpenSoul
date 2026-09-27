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

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAG = os.path.join(ROOT, "docs", "negocio", "rag")
ESCENARIOS = os.path.join(RAG, "escenarios")
DOCUMENTOS = os.path.join(RAG, "documentos")
SALIDA = os.path.join(ROOT, "assets", "rag", "escenarios_cbba.json")
# Glosas de las frases del usuario sordo, traducidas una vez por la Lambda
# Texto→LSB (tool/rag_precalcular_glosas.py). Se leen sin red.
GLOSAS = os.path.join(RAG, "glosas_cache.json")

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
        lineas = f.read().splitlines()
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
                       "ficticios": [], "_linea": n, "archivo": archivo}
            else:
                seccion = None
            continue
        if linea.startswith("### "):
            sub = linea[4:].strip().lower()
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
    cerrar()
    return fuentes, hechos, escenarios, errores, avisos


def leer_todos(carpeta: str = ESCENARIOS) -> tuple:
    """Une todos los `.md` de [carpeta]. Un identificador solo puede definirse
    una vez en todo el corpus; una fuente puede repetirse si es la misma."""
    fuentes, hechos, escenarios, errores, avisos = {}, {}, [], [], []
    archivos = sorted(glob.glob(os.path.join(carpeta, "*.md")))
    if not archivos:
        errores.append(f"no hay escenarios en {_rel(carpeta)}")
    donde = {}
    for ruta in archivos:
        f, h, e, err, av = leer(ruta)
        errores += err
        avisos += av
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


def construir(fuentes, hechos, escenarios, errores, avisos,
              hoy: str | None = None, archivos: list | None = None) -> dict:
    hoy = hoy or os.environ.get("RAG_HOY") or datetime.date.today().isoformat()
    vistos = set()
    for fid, f in fuentes.items():
        local = _documento_local(f["url"])
        if local is not None:
            ruta, pagina = local
            if not os.path.exists(ruta):
                errores.append(f"{fid}: el documento {f['url']} no existe en "
                               f"{_rel(DOCUMENTOS)}")
            elif pagina is not None and ruta.lower().endswith(".pdf"):
                total = _paginas_pdf(ruta)
                if total is None:
                    avisos.append(f"{fid}: sin pypdf no se comprueba la página {pagina}")
                elif not 1 <= pagina <= total:
                    errores.append(f"{fid}: página {pagina} fuera de {f['url']} "
                                   f"({total} páginas)")
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
        })

    return {
        "version": 2,
        "archivos": archivos or [],
        "fuentes": fuentes,
        "hechos": hechos,
        "escenarios": salida,
    }


def poner_glosas(corpus: dict, avisos: list) -> None:
    """Glosas precalculadas en cada tarjeta del usuario sordo que se muestra."""
    cache = {}
    if os.path.exists(GLOSAS):
        with open(GLOSAS, encoding="utf-8") as f:
            cache = json.load(f)
    faltan = 0
    for e in corpus["escenarios"]:
        tarjetas = [t for t in e["turnos"] if t["rol"] == "sordo"]
        tarjetas += [r for p in e["variantes"] for r in p["respuestas"]]
        for t in tarjetas:
            if not t["mostrable"]:
                continue
            traduccion = cache.get(t["texto"])
            t["glosas"] = traduccion["glosas"] if traduccion else None
            if traduccion is None:
                faltan += 1
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
    ]


def main() -> int:
    fuentes, hechos, escenarios, errores, avisos, archivos = leer_todos()
    corpus = construir(fuentes, hechos, escenarios, errores, avisos,
                       archivos=archivos)
    poner_glosas(corpus, avisos)
    for a in avisos:
        print(f"aviso: {a}")
    if errores:
        for e in errores:
            print(f"ERROR: {e}")
        print(f"{len(errores)} errores: no se escribe nada.")
        return 1
    texto = json.dumps(corpus, ensure_ascii=False, indent=1) + "\n"
    for linea in resumen(corpus):
        print(linea)
    if "--check" in sys.argv:
        if not os.path.exists(SALIDA) or open(SALIDA, encoding="utf-8").read() != texto:
            print(f"desactualizado: {os.path.relpath(SALIDA, ROOT)}")
            print("Ejecuta: python tool/build_rag_corpus.py")
            return 1
        print("Corpus RAG al día y coherente con su fuente.")
        return 0
    os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
    with open(SALIDA, "w", encoding="utf-8", newline="") as f:
        f.write(texto)
    print(f"escrito: {os.path.relpath(SALIDA, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
