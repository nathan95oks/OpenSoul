"""Control de las glosas del corpus RAG: ¿dicen lo mismo que la frase?

`action: "retrotraducir"` de `lambda_function.py`. Para cada frase del corpus
y sus glosas LSB precalculadas:

1. Bedrock traduce las glosas de vuelta al español, sin mirar la frase
   original: solo lo que dicen las glosas.
2. Titan compara el significado de esa vuelta con la frase original.

Una similitud baja señala una traducción que perdió o añadió algo («Compré
un auto…» sin AUTO; «mi casa» con un CASO de más). No corrige nada: marca
frases para que una persona las revise. Comparar palabra por palabra no
sirve (TRAER no es «traje», PAPEL·IDENTIDAD es «cédula»); comparar
significados sí.

Las glosas llegan como las ve la persona sorda: una seña a incorporar
(`SENA_PENDIENTE:FOLIO_REAL`) cuenta como su palabra, que se muestra.
"""

from __future__ import annotations

import json
import math
import re

MAX_ITEMS = 8
MAX_TOKENS = 700
PENDIENTE = "SENA_PENDIENTE:"


def legibles(glosas: list) -> list:
    """Las glosas como se leen: la seña a incorporar con su palabra y las
    letras de un deletreo juntas («F O L I O» → «FOLIO»)."""
    out, letras = [], ""
    for g in glosas:
        if len(g) == 1 and g.isalpha():
            letras += g
            continue
        if letras:
            out.append(letras)
            letras = ""
        out.append(g[len(PENDIENTE):] if g.startswith(PENDIENTE) else g)
    if letras:
        out.append(letras)
    return [g.replace("_", " ") for g in out]


def validar_pedido(body: dict) -> tuple:
    """(items, error). Cada item: {texto, glosas}."""
    items = body.get("items")
    if not isinstance(items, list) or not 1 <= len(items) <= MAX_ITEMS:
        return None, f"items: entre 1 y {MAX_ITEMS}."
    limpios = []
    for it in items:
        if not isinstance(it, dict):
            return None, "cada item es un objeto."
        texto, glosas = it.get("texto"), it.get("glosas")
        if not isinstance(texto, str) or not 0 < len(texto) <= 400:
            return None, "texto inválido."
        if (not isinstance(glosas, list) or not 0 < len(glosas) <= 60
                or not all(isinstance(g, str) and 0 < len(g) <= 80
                           for g in glosas)):
            return None, "glosas inválidas."
        limpios.append({"texto": texto, "glosas": glosas})
    return limpios, None


def prompt(items: list) -> str:
    lineas = "\n".join(
        f"{i + 1}. {' · '.join(legibles(it['glosas']))}"
        for i, it in enumerate(items))
    return f"""Traduce al español estas secuencias de glosas de Lengua de Señas
Boliviana (LSB). Cada glosa es una seña; las glosas en español sin seña
propia también cuentan. Escribe una frase natural por secuencia con SOLO lo
que dicen las glosas: no añadas nada que no esté y no quites nada que esté.
Si una secuencia es una pregunta, escríbela como pregunta.

{lineas}

Responde SOLO con JSON: ["frase 1", "frase 2", ...], en el mismo orden."""


def frases_de_respuesta(texto: str, n: int) -> list:
    """Las [n] frases del JSON del modelo; vacías si no se puede leer."""
    try:
        inicio, fin = texto.index("["), texto.rindex("]") + 1
        crudo = json.loads(texto[inicio:fin])
    except (ValueError, json.JSONDecodeError):
        crudo = []
    frases = [str(f) if isinstance(f, (str, int, float)) else ""
              for f in (crudo if isinstance(crudo, list) else [])]
    return (frases + [""] * n)[:n]


def coseno(a: list, b: list) -> float:
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if not na or not nb:
        return 0.0
    return sum(x * y for x, y in zip(a, b)) / (na * nb)


def revisar(items: list, invocar, embed) -> list:
    """[{texto, vuelta, similitud}]. [invocar]: prompt → texto del modelo;
    [embed]: texto → vector (Titan)."""
    vueltas = frases_de_respuesta(invocar(prompt(items)), len(items))
    salida = []
    for it, vuelta in zip(items, vueltas):
        limpia = re.sub(r"\s+", " ", vuelta).strip()
        similitud = (round(coseno(embed(it["texto"]), embed(limpia)), 4)
                     if limpia else 0.0)
        salida.append({"texto": it["texto"], "vuelta": limpia,
                       "similitud": similitud})
    return salida
