"""Zona de cada palabra sin seña: a qué grupo de tarjetas pertenece.

`action: "zonas"` de `lambda_function.py`. Las zonas son las categorías del
catálogo oficial con las que la app agrupa las tarjetas (Tiempo, Lugares,
Documentos, Objetos, Identificación, Acciones…). Una seña del catálogo ya
tiene la suya (`zonas_senas.json`); una palabra sin seña (una seña a
incorporar) no, y sin zona no puede ofrecerse como tarjeta.

Para cada palabra deciden dos señales independientes:

1. **Titan**: la zona cuyas señas se parecen más en significado a la
   palabra (el vector de la palabra frente al de cada zona).
2. **Bedrock**: la zona que elige leyendo las frases donde aparece.

Si coinciden, la palabra entra a esa zona. Si no, queda sin zona: sin
revisión humana, pero tampoco a ciegas.
"""

from __future__ import annotations

import json
import math
import os
import re

AQUI = os.path.dirname(os.path.abspath(__file__))
ZONAS_PATH = os.path.join(AQUI, "zonas_senas.json")

MAX_PALABRAS = 10
MAX_TOKENS = 700
# Categorías del catálogo que no son zonas de respuesta: el deletreo.
_NO_ZONAS = {"Abecedario"}
_EJEMPLOS_POR_ZONA = 25


def cargar_zonas(ruta: str | None = None) -> dict:
    """{glosa: zona} de las señas oficiales, o {}."""
    ruta = ruta or ZONAS_PATH
    if not os.path.exists(ruta):
        return {}
    with open(ruta, encoding="utf-8") as f:
        return json.load(f)


def zonas_con_senas(zonas: dict, formas: dict) -> dict:
    """{zona: [significados de sus señas]}: cómo se describe cada zona."""
    out = {}
    for glosa, zona in sorted(zonas.items()):
        if zona in _NO_ZONAS:
            continue
        significado = (formas.get(glosa) or [glosa.replace("_", " ").lower()])[0]
        out.setdefault(zona, [])
        if len(out[zona]) < _EJEMPLOS_POR_ZONA:
            out[zona].append(significado)
    return out


def validar_pedido(body: dict) -> tuple:
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
                    if isinstance(e, str) and 0 < len(e) <= 300][:3]
        limpias.append({"palabra": palabra.strip(), "ejemplos": ejemplos})
    return limpias, None


def prompt(palabras: list, zonas: dict) -> str:
    lista = "\n".join(f"- {z}: {', '.join(ej[:12])}"
                      for z, ej in sorted(zonas.items()))
    pedidas = "\n".join(
        f"{i + 1}. {p['palabra'].replace('_', ' ')}: "
        + " | ".join(f"«{e}»" for e in p["ejemplos"])
        for i, p in enumerate(palabras))
    return f"""Clasifica cada palabra del español en la zona de tarjetas de Lengua de
Señas Boliviana a la que pertenece, según su significado en esas frases.
Cada zona se describe con algunas de sus señas.

Zonas:
{lista}

Palabras:
{pedidas}

Elige exactamente una zona de la lista, escrita igual. Si ninguna encaja,
responde null.
Responde SOLO con JSON: [{{"n": 1, "zona": "..."}}, ...]"""


def coseno(a: list, b: list) -> float:
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if not na or not nb:
        return 0.0
    return sum(x * y for x, y in zip(a, b)) / (na * nb)


def zonas_de_bedrock(texto: str, n: int, zonas: dict) -> list:
    """La zona que eligió el modelo para cada palabra, por su número; solo
    zonas de la lista."""
    try:
        inicio, fin = texto.index("["), texto.rindex("]") + 1
        crudo = json.loads(texto[inicio:fin])
    except (ValueError, json.JSONDecodeError):
        crudo = []
    por_n = {}
    for x in crudo if isinstance(crudo, list) else []:
        if isinstance(x, dict) and x.get("zona") in zonas:
            por_n[x.get("n")] = x["zona"]
    return [por_n.get(i + 1) for i in range(n)]


def clasificar(palabras: list, zonas: dict, embed, invocar,
               vectores_zona: dict | None = None) -> list:
    """[{palabra, zona, titan, similitud, bedrock}]; `zona` solo si Titan y
    Bedrock coinciden. [vectores_zona]: caché {zona: vector}."""
    vectores = vectores_zona if vectores_zona is not None else {}
    for z, ej in zonas.items():
        if z not in vectores:
            vectores[z] = embed(f"{z}: {', '.join(ej)}")
    elegidas = zonas_de_bedrock(invocar(prompt(palabras, zonas)),
                                len(palabras), zonas)
    salida = []
    for p, bedrock in zip(palabras, elegidas):
        v = embed(p["palabra"].replace("_", " ").lower())
        puntajes = sorted(((coseno(v, vz), z) for z, vz in vectores.items()),
                          reverse=True)
        similitud, titan = puntajes[0] if puntajes else (0.0, None)
        salida.append({
            "palabra": p["palabra"], "titan": titan,
            "similitud": round(similitud, 4), "bedrock": bedrock,
            "zona": titan if titan and titan == bedrock else None,
        })
    return salida
