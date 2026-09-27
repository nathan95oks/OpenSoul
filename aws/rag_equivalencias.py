"""Equivalencias de palabras sin seña con señas del catálogo oficial.

`action: "equivalencias"` de `lambda_function.py`. Para cada palabra que la
traducción Texto→LSB dejó sin seña (y sus frases de ejemplo del corpus RAG),
Bedrock propone una seña del catálogo oficial que signifique lo mismo, o
ninguna. No inventa señas: solo puede nombrar glosas del catálogo, y toda
glosa que no esté en él se descarta aquí, diga lo que diga el modelo. Una
seña «parecida» o «relacionada» tampoco vale: solo la equivalente.

El catálogo es `glosas_opensoul.csv` (el de la app), empaquetado en el ZIP;
solo cuentan las entradas «Catálogo Oficial», que tienen seña documentada.
Las «Variante / Alias Semántico» son reglas del ensamblador de texto (PAGAR,
DENUNCIAR): no hay seña detrás.

Lo que se propone aquí no se aplica solo: `tool/rag_equivalencias.py` lo
guarda para revisar y decide qué se aprueba.
"""

from __future__ import annotations

import csv
import json
import os
import re
import unicodedata

AQUI = os.path.dirname(os.path.abspath(__file__))
CATALOGO_PATH = os.path.join(AQUI, "glosas_opensoul.csv")
CATALOGO_REPO = os.path.join(os.path.dirname(AQUI), "assets", "dictionary",
                             "glosas_opensoul.csv")

MAX_PALABRAS = 10
MAX_EJEMPLOS = 3
MAX_TOKENS = 900


def _norm(texto: str) -> str:
    sin = unicodedata.normalize("NFD", texto.upper())
    return "".join(c for c in sin if unicodedata.category(c) != "Mn")


def cargar_catalogo(ruta: str | None = None) -> dict:
    """{glosa: significado} de las señas oficiales, o {} sin catálogo."""
    for candidata in ([ruta] if ruta else [CATALOGO_PATH, CATALOGO_REPO]):
        if not candidata or not os.path.exists(candidata):
            continue
        with open(candidata, encoding="utf-8-sig") as f:
            filas = list(csv.DictReader(f))
        return {
            r["Glosa"]: "; ".join(dict.fromkeys(
                v.strip() for v in (r.get("Significado_Espanol", ""),
                                    r.get("Forma_Espanol_Oracion", ""))
                if v and v.strip()))
            for r in filas
            if (r.get("Tipo_Entrada") or "").startswith("Cat")
            and r.get("Glosa")
        }
    return {}


def validar_pedido(body: dict) -> tuple:
    """(palabras, error). Cada palabra: {palabra, ejemplos}."""
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
        limpias.append({"palabra": palabra.strip(),
                        "ejemplos": ejemplos[:MAX_EJEMPLOS]})
    return limpias, None


def prompt(palabras: list, catalogo: dict) -> str:
    lista = "\n".join(f"- {g}: {s}" for g, s in sorted(catalogo.items()))
    pedidas = "\n".join(
        f"- {p['palabra']}: " + " | ".join(f"«{e}»" for e in p["ejemplos"])
        for p in palabras)
    return f"""Eres un asistente de Lengua de Señas Boliviana (LSB).

Estas palabras del español no tienen seña propia en el catálogo. Para cada
una, junto a las frases donde aparece, decide si ALGUNA seña del catálogo
significa exactamente lo mismo en esas frases.

Reglas:
- Solo puedes elegir glosas de la lista del catálogo, escritas igual.
- Solo una seña EQUIVALENTE: mismo significado en esas frases. Si solo es
  parecida, relacionada o más general, responde null.
- Ante la duda, null. Una seña equivocada es peor que ninguna.

Catálogo (glosa: significado en español):
{lista}

Palabras sin seña:
{pedidas}

Responde SOLO con JSON, una entrada por palabra:
[{{"palabra": "...", "sena": "GLOSA o null", "razon": "una frase"}}]"""


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
    """Una propuesta por palabra pedida; `sena` solo si está en el catálogo."""
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
        propuesta = r.get("sena")
        sena = (por_norma.get(_norm(propuesta))
                if isinstance(propuesta, str) else None)
        salida.append({
            "palabra": p["palabra"],
            "sena": sena,
            "razon": str(r.get("razon") or "")[:300],
            # Lo que dijo el modelo si no era del catálogo: se registra, no
            # se usa.
            "descartada": propuesta if (isinstance(propuesta, str)
                                        and sena is None
                                        and propuesta.lower() != "null")
            else None,
        })
    return salida


def proponer(palabras: list, catalogo: dict, invocar) -> list:
    """Propuestas validadas. [invocar] recibe el prompt y devuelve el texto."""
    return validar(invocar(prompt(palabras, catalogo)), palabras, catalogo)
