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


def respuestas_de(e: dict, n: int) -> list:
    """Lo que respondió la persona sorda al turno [n] del funcionario."""
    siguiente = next((t for t in e["turnos"] if t["n"] == n + 1), None)
    out = [siguiente] if siguiente and siguiente["rol"] == "sordo" else []
    out += [r for p in e["variantes"] if p["turno"] == n for r in p["respuestas"]]
    return [t for t in out if _ofrecible(t)]


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


def banco_tramites(corpus: dict) -> dict:
    """Preguntas, recorridos y contextos de la familia «Trámites».

    Una pregunta por turno del funcionario con respuestas (`R.<escenario>.<n>`,
    el mismo turno que encuentra el RAG), con su formulación en LSB y una
    opción por respuesta documentada distinta. Un recorrido por trámite.
    """
    preguntas, recorridos, contextos = [], {}, []
    for e in corpus["escenarios"]:
        pasos = []
        for t in turnos_pregunta(e):
            qid = f"R.{e['id']}.{t['n']}"
            opciones, vistas = [], set()
            for r in respuestas_de(e, t["n"]):
                if r["texto"] in vistas:
                    continue
                vistas.add(r["texto"])
                opciones.append({
                    "estado": _estado(r["texto"]),
                    "etiqueta": r["texto"],
                    "frase": r["texto"],
                    "glosas": r["glosas"],
                    "glosasPropias": True,
                    "id": f"r{len(opciones) + 1}",
                })
            glosas = t.get("glosas") or []
            preguntas.append({
                "acto": "pregunta" if "?" in t["texto"] else "indicacion",
                "campo": "tramite",
                "campos": ["tramite"],
                "control": "seleccion_unica",
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
                "opciones": opciones,
                "variantes": [],
            })
            pasos.append({"pregunta": qid})
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
    for a in avisos:
        print(f"aviso: {a}")
    if errores:
        for e in errores:
            print(f"ERROR: {e}")
        print(f"{len(errores)} errores: no se escribe nada.")
        return 1
    texto = json.dumps(corpus, ensure_ascii=False, indent=1) + "\n"
    banco = banco_tramites(corpus)
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
