"""Zona de cada palabra sin seña: a qué grupo de tarjetas pertenece.

`action: "zonas"` de `lambda_function.py`. Las zonas son las categorías del
catálogo oficial con las que la app agrupa las tarjetas (Tiempo, Lugares,
Documentos, Objetos, Identificación, Acciones…). Una seña del catálogo ya
tiene la suya (`zonas_senas.json`); una palabra sin seña (una seña a
incorporar) no, y sin zona no puede ofrecerse como tarjeta.

Para cada palabra deciden dos señales independientes:

1. **Titan**: las señas del catálogo más parecidas en significado a la
   palabra (sus vecinas); la zona es la que más pesa entre ellas. BOLETA
   queda junto a FACTURA, PAPEL, CERTIFICADO: Documentos. Los vectores de
   las señas se calculan una vez y se guardan (`indexar_senas`).
2. **Bedrock**: la zona que elige leyendo las frases donde aparece.

Si coinciden, la palabra entra a esa zona. Si no, queda sin zona: sin
revisión humana, pero tampoco a ciegas.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import re

AQUI = os.path.dirname(os.path.abspath(__file__))
ZONAS_PATH = os.path.join(AQUI, "zonas_senas.json")

MAX_PALABRAS = 10
MAX_TOKENS = 700
VECINAS = 5
# Vectores de señas por llamada: con 40, la llamada (más leer y guardar el
# índice en S3) pasaba los 29 s de API Gateway y nunca se guardaba.
LOTE_INDICE = 15
# Dimensiones de los vectores de este índice. Con 256 y palabras sueltas,
# Titan juntaba por forma (BOLETA con MIEDO y HOLA; AUTO con 5 y 4); con la
# palabra en su frase y 1024 dimensiones compara significados.
DIMENSIONES = 1024
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

Elige siempre la zona más cercana de la lista, escrita igual (un verbo
suele ir en Acciones; un papel o comprobante, en Documentos).
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


def textos_senas(zonas: dict, formas: dict) -> dict:
    """{glosa: texto que se vectoriza} de las señas con zona de respuesta:
    la seña con su significado en español («papel: papel; el documento»)."""
    return {g: f"{g.replace('_', ' ').lower()}: "
               + "; ".join(formas.get(g) or [g.replace("_", " ").lower()])
            for g, z in sorted(zonas.items()) if z not in _NO_ZONAS}


def texto_palabra(palabra: dict) -> str:
    """La palabra con la frase donde aparece: «boleta: Sí tengo mi última
    boleta.». Sola, Titan no sabe qué significa."""
    legible = palabra["palabra"].replace("_", " ").lower()
    ejemplo = (palabra.get("ejemplos") or [""])[0]
    return f"{legible}: {ejemplo}".strip(": ")


def clave_indice(modelo: str, textos: dict) -> str:
    huella = hashlib.sha256(json.dumps(textos, sort_keys=True,
                                       ensure_ascii=False).encode()).hexdigest()
    return (f"zonas-senas-{modelo.replace(':', '_').replace('.', '_')}-"
            f"{DIMENSIONES}-{huella[:16]}")


def indexar_senas(textos: dict, indice: dict, embed,
                  lote: int = LOTE_INDICE) -> dict:
    """Añade al índice hasta [lote] vectores de señas que faltan."""
    vectores = dict(indice.get("vectores") or {})
    for g in [g for g in textos if g not in vectores][:lote]:
        vectores[g] = embed(textos[g])
    return {"vectores": vectores}


def zona_por_vecinas(vector: list, vectores: dict, zonas: dict,
                     k: int = VECINAS) -> tuple:
    """(zona, parecido, vecinas): la zona que más pesa entre las [k] señas
    más parecidas, sumando su parecido."""
    cercanas = sorted(((coseno(vector, v), g) for g, v in vectores.items()),
                      reverse=True)[:k]
    peso = {}
    for s, g in cercanas:
        peso[zonas[g]] = peso.get(zonas[g], 0.0) + s
    if not peso:
        return None, 0.0, []
    zona = max(peso, key=peso.get)
    return zona, round(cercanas[0][0], 4), [g for _, g in cercanas]


def clasificar(palabras: list, zonas_desc: dict, vectores: dict, zonas: dict,
               embed, invocar) -> list:
    """[{palabra, zona, titan, similitud, vecinas, bedrock}]; `zona` solo si
    Titan (por vecinas) y Bedrock coinciden."""
    elegidas = zonas_de_bedrock(invocar(prompt(palabras, zonas_desc)),
                                len(palabras), zonas_desc)
    salida = []
    for p, bedrock in zip(palabras, elegidas):
        v = embed(texto_palabra(p))
        titan, similitud, vecinas = zona_por_vecinas(v, vectores, zonas)
        salida.append({
            "palabra": p["palabra"], "titan": titan, "similitud": similitud,
            "vecinas": vecinas, "bedrock": bedrock,
            "zona": titan if titan and titan == bedrock else None,
        })
    return salida
