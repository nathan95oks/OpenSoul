"""Equivalencias de palabras sin seña con señas del catálogo oficial.

`action: "equivalencias"` de `lambda_function.py`. Para cada palabra que la
traducción Texto→LSB dejó sin seña (y sus frases de ejemplo del corpus RAG),
Bedrock propone una seña del catálogo oficial que signifique lo mismo, o
ninguna. No inventa señas: solo puede nombrar glosas del catálogo, y toda
glosa que no esté en él se descarta aquí, diga lo que diga el modelo. Una
seña «parecida» o «relacionada» tampoco vale: solo la equivalente.

El catálogo es `catalogo_senas.json` (junto a este archivo, versionado y
empaquetado en el ZIP): las señas «Catálogo Oficial» de la app, que tienen
seña documentada, con sus formas en español. Las «Variante / Alias
Semántico» (PAGAR, DENUNCIAR) son reglas del ensamblador de texto, sin seña
detrás, y no están. Se regenera con
`python tool/rag_equivalencias.py --actualizar-catalogo`.

Si está empaquetado el léxico LSB (`lexico_lsb.json`, de
`tool/build_lexico_lsb.py`: M1–M4, los diccionarios y el catálogo), se
propone con él y no solo con el catálogo:

* **Forma 1.** La palabra ya es una seña del léxico, pero solo por cómo se
  escribe: el modelo confirma que el sentido de la frase es el de esa seña
  (`candidata`, con su módulo y tema). «Mi fiscal» no es FISCAL de «escuela
  fiscal» (M3, Escuela).
* **Forma 2.** La palabra no está: el modelo propone una seña sinónima o
  una combinación de hasta tres señas del léxico que la explican
  (`senas`), o ninguna.

Lo que se propone aquí no se aplica solo: `tool/rag_equivalencias.py` lo
guarda para revisar y decide qué se aprueba.
"""

from __future__ import annotations

import json
import os
import re
import unicodedata

AQUI = os.path.dirname(os.path.abspath(__file__))
CATALOGO_PATH = os.path.join(AQUI, "catalogo_senas.json")
LEXICO_PATH = os.path.join(AQUI, "lexico_lsb.json")

MAX_PALABRAS = 10
MAX_EJEMPLOS = 3
# Diez palabras con combinaciones de hasta tres señas y su razón.
MAX_TOKENS = 1400
# Una combinación más larga ya no explica una palabra: la reemplaza por una
# frase.
MAX_SENAS = 3


def _norm(texto: str) -> str:
    sin = unicodedata.normalize("NFD", texto.upper())
    return "".join(c for c in sin if unicodedata.category(c) != "Mn")


def cargar_formas(ruta: str | None = None) -> dict:
    """{glosa: [formas en español]} de las señas oficiales, o {}."""
    ruta = ruta or CATALOGO_PATH
    if not os.path.exists(ruta):
        return {}
    with open(ruta, encoding="utf-8") as f:
        return json.load(f)


def cargar_catalogo(ruta: str | None = None) -> dict:
    """{glosa: significado} de las señas oficiales, o {} sin catálogo."""
    return {g: "; ".join(f) for g, f in cargar_formas(ruta).items()}


def _describir(dato: dict) -> str:
    """«Fiscal [M3 · Escuela]»: las formas y de dónde sale la seña."""
    formas = "; ".join(dato.get("formas") or [])
    temas = []
    for f in dato.get("fuentes") or []:
        if f.get("fuente") == "catalogo":
            continue
        if f.get("tema"):
            tema = f"{f.get('fuente')} · {f.get('tema')}"
        elif f.get("definicion"):
            # Un diccionario: su definición dice el sentido de la seña.
            tema = f"{f.get('fuente')} · {f.get('definicion')}"
        else:
            tema = str(f.get("fuente"))
        if tema not in temas:
            temas.append(tema)
    return f"{formas} [{'; '.join(temas)}]" if temas else formas


def cargar_lexico(ruta: str | None = None) -> dict:
    """{glosa: descripción con su tema} del léxico LSB; sin léxico, el
    catálogo."""
    ruta = ruta or LEXICO_PATH
    if not os.path.exists(ruta):
        return cargar_catalogo()
    with open(ruta, encoding="utf-8") as f:
        glosas = json.load(f).get("glosas") or {}
    return {g: _describir(d) for g, d in glosas.items()}


def validar_pedido(body: dict) -> tuple:
    """(palabras, error). Cada palabra: {palabra, ejemplos, candidata?}."""
    palabras = body.get("palabras")
    if not isinstance(palabras, list) or not 1 <= len(palabras) <= MAX_PALABRAS:
        return None, f"palabras: entre 1 y {MAX_PALABRAS}."
    limpias = []
    for p in palabras:
        if not isinstance(p, dict):
            return None, "cada palabra es un objeto."
        palabra = p.get("palabra")
        if not isinstance(palabra, str) or not re.fullmatch(
                r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ_ ]{1,40}", palabra):
            return None, "palabra inválida."
        ejemplos = [e for e in (p.get("ejemplos") or [])
                    if isinstance(e, str) and 0 < len(e) <= 300]
        limpia = {"palabra": palabra.strip(),
                  "ejemplos": ejemplos[:MAX_EJEMPLOS]}
        candidata = p.get("candidata")
        if candidata is not None:
            if not isinstance(candidata, str) or not re.fullmatch(
                    r"[A-ZÁÉÍÓÚÜÑ0-9_]{1,60}", candidata):
                return None, "candidata inválida."
            limpia["candidata"] = candidata
        limpias.append(limpia)
    return limpias, None


def prompt(palabras: list, catalogo: dict) -> str:
    lista = "\n".join(f"- {g}: {s}" for g, s in sorted(catalogo.items()))

    def pedida(p: dict) -> str:
        linea = f"- {p['palabra']}: " + " | ".join(f"«{e}»" for e in p["ejemplos"])
        if p.get("candidata"):
            linea += (f"\n  candidata: {p['candidata']} "
                      f"({catalogo.get(p['candidata'], 'sin descripción')})")
        return linea

    pedidas = "\n".join(pedida(p) for p in palabras)
    return f"""Eres un asistente de Lengua de Señas Boliviana (LSB).

Estas palabras del español no tienen seña confirmada. Para cada una, junto a
las frases donde aparece, decide qué señas de la lista la expresan en ESAS
frases.

Reglas:
- Solo puedes elegir glosas de la lista, escritas igual.
- Una seña EQUIVALENTE (mismo significado en esas frases), o una
  combinación de hasta {MAX_SENAS} señas de la lista que juntas explican la
  palabra («FISCALÍA» → OFICINA + FISCAL). Nunca una seña solo parecida,
  relacionada o más general.
- Cada seña lleva entre corchetes el módulo y el tema donde se enseña. Una
  «candidata» se escribe igual que la palabra: acéptala solo si su tema
  corresponde al sentido de la frase («escuela fiscal», tema Escuela, no es
  «mi fiscal» del Ministerio Público).
- Ante la duda, null. Una seña equivocada es peor que ninguna.

Señas (glosa: formas en español [módulo · tema]):
{lista}

Palabras sin seña:
{pedidas}

Responde SOLO con JSON, una entrada por palabra:
[{{"palabra": "...", "senas": ["GLOSA", ...] o null, "razon": "una frase"}}]"""


def texto_de_respuesta(respuesta: dict) -> str:
    """El texto que generó el modelo (Nova, Claude u otro)."""
    if isinstance(respuesta.get("output"), dict):
        partes = respuesta["output"].get("message", {}).get("content", [])
        return "".join(p.get("text", "") for p in partes)
    if isinstance(respuesta.get("content"), list):
        return "".join(p.get("text", "") for p in respuesta["content"])
    if isinstance(respuesta.get("results"), list):
        return respuesta["results"][0].get("outputText", "")
    return str(respuesta.get("generation", ""))


def validar(texto: str, palabras: list, catalogo: dict) -> list:
    """Una propuesta por palabra pedida; `senas` solo si todas están en la
    lista (léxico o catálogo). `sena` es la seña cuando es una sola."""
    por_norma = {_norm(g): g for g in catalogo}
    try:
        inicio, fin = texto.index("["), texto.rindex("]") + 1
        crudo = json.loads(texto[inicio:fin])
    except (ValueError, json.JSONDecodeError):
        crudo = []
    respuestas = {}
    for r in crudo if isinstance(crudo, list) else []:
        if isinstance(r, dict) and isinstance(r.get("palabra"), str):
            respuestas[_norm(r["palabra"])] = r
    salida = []
    for p in palabras:
        r = respuestas.get(_norm(p["palabra"]), {})
        crudas = r.get("senas")
        if crudas is None and isinstance(r.get("sena"), str):
            crudas = [r["sena"]]
        if isinstance(crudas, str):
            crudas = [crudas]
        if not isinstance(crudas, list):
            crudas = []
        crudas = [c for c in crudas
                  if isinstance(c, str) and c.strip().lower() != "null"]
        senas = [por_norma.get(_norm(c)) for c in crudas]
        valida = (0 < len(senas) <= MAX_SENAS and all(senas)
                  and len(set(senas)) == len(senas))
        salida.append({
            "palabra": p["palabra"],
            "sena": senas[0] if valida and len(senas) == 1 else None,
            "senas": senas if valida else None,
            "razon": str(r.get("razon") or "")[:300],
            # Lo que dijo el modelo si no valía (una glosa fuera de la
            # lista, o más de MAX_SENAS): se registra, no se usa. Una
            # combinación con una sola glosa inventada se descarta entera.
            "descartada": " + ".join(crudas) if crudas and not valida else None,
        })
    return salida


def proponer(palabras: list, catalogo: dict, invocar) -> list:
    """Propuestas validadas. [invocar] recibe el prompt y devuelve el texto."""
    return validar(invocar(prompt(palabras, catalogo)), palabras, catalogo)
