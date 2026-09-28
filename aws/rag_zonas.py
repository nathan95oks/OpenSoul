"""Zona de cada palabra sin seña: a qué grupo de tarjetas pertenece.

`action: "zonas"` de `lambda_function.py`. Las zonas son las categorías del
catálogo oficial con las que la app agrupa las tarjetas (Tiempo, Lugares,
Documentos, Objetos, Identificación, Acciones…). Una seña del catálogo ya
tiene la suya (`zonas_senas.json`); una palabra sin seña (una seña a
incorporar) no, y sin zona no puede ofrecerse como tarjeta.

Para cada palabra deciden dos señales independientes, las dos con la misma
definición escrita de cada zona (`DEFINICIONES`):

1. **Titan**: la zona cuya definición se parece más en significado a la
   palabra en su frase («boleta: Sí tengo mi última boleta.»).
2. **Bedrock**: la zona que elige leyendo esas definiciones y la frase.

Si coinciden, la palabra entra a esa zona. Si no, queda sin zona: sin
revisión humana, pero tampoco a ciegas. Un verbo en infinitivo (así llegan
las señas a incorporar de verbos: CONFIRMAR, PAGAR) va a Acciones sin
consultar a nadie.

Antes se comparaba con las señas sueltas de cada zona, y Titan juntaba por
forma (BOLETA con BOLSA y PLAZA) y la zona más grande (Acciones, 87 señas)
ganaba casi todas las votaciones.
"""

from __future__ import annotations

import json
import math
import os
import re

AQUI = os.path.dirname(os.path.abspath(__file__))
ZONAS_PATH = os.path.join(AQUI, "zonas_senas.json")

MAX_PALABRAS = 10

# Qué significa cada zona, con miembros típicos (del catálogo y de los
# trámites). Es lo que comparan Titan y Bedrock: se escribe una vez para
# toda la zona, no palabra por palabra.
DEFINICIONES = {
    "Documentos": "papeles y comprobantes de un trámite: documento, "
                  "certificado, boleta, factura, recibo, formulario, folio, "
                  "expediente, escritura, carátula, copia, fotocopia, sello, "
                  "carpeta, placa, licencia, memorial, página",
    "Objetos": "cosas que se tienen, se pierden o se compran, y el dinero: "
               "celular, vehículo, auto, moto, mochila, ropa, llave, "
               "computadora, billetes, dinero, monto, deuda, costo, precio, "
               "cuota, pago",
    "Lugares": "sitios y direcciones: casa, calle, avenida, barrio, oficina, "
               "plaza, mercado, tienda, banco, escuela, edificio, inmueble, "
               "terreno, ciudad, provincia, Cochabamba",
    "Tiempo": "cuándo: días, meses, años, horas, fechas, plazos del "
              "calendario: hoy, ayer, mañana, lunes, semana, mes, año, hora, "
              "horario, fecha, antes, después, siempre",
    "Identificación": "personas y sus datos: familia, padre, madre, hijo, "
                      "sobrino, pareja, amigo, niño, adulto, edad, nombre, "
                      "sordo, oyente, testigo, víctima, persona",
    "Instituciones": "entidades y quienes trabajan en ellas: policía, "
                     "fiscalía, juzgado, tribunal, alcaldía, defensoría, "
                     "hospital, abogado, juez, fiscal, médico, intérprete, "
                     "oficial, investigador",
    "Conceptos jurídicos": "ideas del derecho y de los procesos: ley, norma, "
                           "derecho, justicia, trámite, proceso, "
                           "procedimiento, audiencia, denuncia, resolución, "
                           "investigación, testimonio, patrocinio, acceso",
    "Acciones": "lo que alguien hace, verbos: pagar, confirmar, comprar, "
                "buscar, enviar, escribir, esperar, llamar, ir, venir, "
                "decir, pedir, registrar, solicitar, presentar",
    "Hechos y urgencia": "lo que le pasó a alguien, delitos y emergencias: "
                         "robo, violencia, amenaza, golpe, herida, dolor, "
                         "engaño, pérdida, auxilio, urgente",
    "Descripción": "cómo es algo: nuevo, antiguo, bueno, malo, caro, barato, "
                   "diferente, difícil, físico, presencial, igual, tipo, "
                   "modalidad, color",
    "Estado y emoción": "cómo se siente alguien: miedo, confianza, "
                        "preocupación, tristeza, tranquilidad",
    "Respuesta": "respuestas cortas a una pregunta: sí, no, no sé, tal vez, "
                 "verdad, mentira, entiendo, de acuerdo",
    "Preguntas": "pronombres y a quién se refiere: yo, tú, él, ella, "
                 "nosotros, ellos, ambos, varios, suyo, tuyo",
    "Cortesía": "saludos y fórmulas de cortesía: hola, gracias, por favor, "
                "permiso, lo siento, hasta luego",
    "Números": "números y cantidades: uno, dos, tres, diez, cien, mil, "
               "treinta, número",
}

# Infinitivos que no son verbos (sustantivos en -ar/-er/-ir).
_NO_VERBOS = {"LUGAR", "HOGAR", "MUJER", "PLACER", "NIVEL", "ALTAR",
              "COLLAR", "SOLAR", "MAR", "BAR"}
MAX_TOKENS = 700
# Dimensiones de los vectores de zonas (el RAG usa 256). Con 256 y palabras
# sueltas, Titan juntaba por forma (BOLETA con MIEDO y HOLA).
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
    lista = "\n".join(f"- {z}: {DEFINICIONES.get(z, ', '.join(ej[:12]))}"
                      for z, ej in sorted(zonas.items()))
    pedidas = "\n".join(
        f"{i + 1}. {p['palabra'].replace('_', ' ')}: "
        + " | ".join(f"«{e}»" for e in p["ejemplos"])
        for i, p in enumerate(palabras))
    return f"""Clasifica cada palabra del español en la zona de tarjetas de Lengua de
Señas Boliviana a la que pertenece, según su significado en esas frases.

Zonas:
{lista}

Reglas: un verbo va en Acciones (nunca en Respuesta); el dinero (deuda,
monto, costo, precio) va en Objetos; un papel o comprobante, en Documentos.

Palabras:
{pedidas}

Elige siempre la zona más cercana de la lista, escrita igual.
Responde SOLO con JSON: [{{"n": 1, "zona": "..."}}, ...]"""


def es_verbo(palabra: str) -> bool:
    """Una seña a incorporar de un verbo llega en infinitivo (CONFIRMAR)."""
    p = palabra.upper()
    return ("_" not in p and len(p) > 3 and p not in _NO_VERBOS
            and p.endswith(("AR", "ER", "IR")))


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


def texto_palabra(palabra: dict) -> str:
    """La palabra con la frase donde aparece: «boleta: Sí tengo mi última
    boleta.». Sola, Titan no sabe qué significa."""
    legible = palabra["palabra"].replace("_", " ").lower()
    ejemplo = (palabra.get("ejemplos") or [""])[0]
    return f"{legible}: {ejemplo}".strip(": ")


def zona_por_definicion(vector: list, vectores: dict) -> tuple:
    """(zona, parecido) de la definición más parecida."""
    puntajes = sorted(((coseno(vector, v), z) for z, v in vectores.items()),
                      reverse=True)
    if not puntajes:
        return None, 0.0
    return puntajes[0][1], round(puntajes[0][0], 4)


def clasificar(palabras: list, zonas_desc: dict, embed, invocar,
               vectores_definicion: dict | None = None) -> list:
    """[{palabra, zona, titan, similitud, bedrock}]; `zona` solo si Titan y
    Bedrock coinciden (o si es un verbo: Acciones). [vectores_definicion]:
    caché {zona: vector de su definición}."""
    vectores = vectores_definicion if vectores_definicion is not None else {}
    for z in zonas_desc:
        if z not in vectores:
            vectores[z] = embed(f"{z}: {DEFINICIONES.get(z, z)}")
    elegidas = zonas_de_bedrock(invocar(prompt(palabras, zonas_desc)),
                                len(palabras), zonas_desc)
    salida = []
    for p, bedrock in zip(palabras, elegidas):
        if es_verbo(p["palabra"]) and "Acciones" in zonas_desc:
            salida.append({"palabra": p["palabra"], "titan": "Acciones",
                           "similitud": 1.0, "bedrock": bedrock,
                           "zona": "Acciones", "regla": "verbo"})
            continue
        titan, similitud = zona_por_definicion(embed(texto_palabra(p)),
                                               vectores)
        salida.append({
            "palabra": p["palabra"], "titan": titan, "similitud": similitud,
            "bedrock": bedrock,
            "zona": titan if titan and titan == bedrock else None,
        })
    return salida
