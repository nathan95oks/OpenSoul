"""Control de las glosas del corpus RAG: ¿dicen lo mismo que la frase?

`action: "retrotraducir"` de `lambda_function.py`. Para cada frase del corpus
y sus glosas LSB precalculadas hace dos cosas:

1. **Comparación verificable.** Bedrock ve la frase y sus glosas y dice qué
   palabras de la frase no tienen glosa (`faltan`) y qué glosas no están en
   la frase (`sobran`). Cada respuesta se comprueba: una palabra que falta
   tiene que estar en la frase y una glosa que sobra, en las glosas; lo
   demás se descarta. Así se ve «Compré un auto…» sin AUTO o «mi casa» con
   un CASO de más, sin depender de interpretar nada.
2. **Vuelta al español + Titan.** Bedrock traduce las glosas de vuelta al
   español sin ver la frase, y Titan compara su significado con la
   original. Es una segunda señal para ordenar la revisión. Si la vuelta
   sale escrita como glosas («PAPEL IDENTIDAD NUEVO NECESITAR») no es
   español y no se compara (`similitud: null`): antes eso hundía frases
   correctas.

No corrige nada: marca frases para que una persona las revise. Las glosas
llegan como las ve la persona sorda: una seña a incorporar
(`SENA_PENDIENTE:FOLIO_REAL`) cuenta como su palabra, que se muestra.
"""

from __future__ import annotations

import json
import math
import re
import unicodedata

MAX_ITEMS = 8
MAX_TOKENS = 900
PENDIENTE = "SENA_PENDIENTE:"

# Palabras del español que LSB no signa: su ausencia en las glosas no es
# una pérdida. Artículos, preposiciones, conjunciones, pronombres átonos y el
# verbo copulativo (LSB no signa «ser»/«estar» como cópula).
_FUNCION = frozenset("""
a al algo ante aunque con de del desde e el ella ellas ellos en entonces
entre era eran eres es esa ese eso esta estaba estaban estamos estan este
esto estoy fue fueron ha han hasta hay hacia la las le les lo los me mi mis
ni nos o para pero pues por porque que se sea segun ser si sin sobre somos
son soy su sus tambien te tu tus u un una unas uno unos y ya yo
""".split())

# Sujetos que el español calla («Tengo») y LSB signa (YO TENER): no sobran.
_SUJETOS = frozenset({"yo", "tu", "el", "ella", "nosotros", "ellos", "ellas",
                      "usted", "ustedes"})

# Verbos auxiliares o de modo: si solo faltan estos, la pérdida es menor.
_AUXILIARES = frozenset("""
quiero quiere queremos quieren debo debe deben puedo puede pueden necesito
necesita tengo tiene tienen voy va vamos
""".split())

_NUMEROS = frozenset("""
cero uno una dos tres cuatro cinco seis siete ocho nueve diez once doce
veinte treinta cien mil primero primera segundo
""".split())


def _norm(texto: str) -> str:
    sin = unicodedata.normalize("NFD", texto.lower())
    return "".join(c for c in sin if unicodedata.category(c) != "Mn")


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
    """(items, error). Cada item: {texto, glosas, rol?}."""
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
        rol = it.get("rol") if it.get("rol") in ("sordo", "funcionario") else None
        limpios.append({"texto": texto, "glosas": glosas, "rol": rol})
    return limpios, None


_QUIEN = {"sordo": "la persona sorda", "funcionario": "el funcionario",
          None: "alguien"}

_GRAMATICA = """Cómo leer las glosas de LSB:
- Los verbos van en infinitivo: conjúgalos según quién habla (YO NECESITAR
  → «necesito»).
- MÍO es «mi»/«mío»; TÚ/TUYO es «usted»/«su» si habla el funcionario.
- PAPEL IDENTIDAD es «cédula de identidad»; PAPEL solo es «documento».
- El orden es tema-comentario: reordénalo como en español.
- Los artículos, preposiciones y pronombres no se signan: añádelos."""


def prompt_vuelta(items: list) -> str:
    lineas = "\n".join(
        f"{i + 1}. (habla {_QUIEN[it['rol']]}) "
        f"{' · '.join(legibles(it['glosas']))}"
        for i, it in enumerate(items))
    return f"""Traduce al español estas secuencias de glosas de Lengua de Señas
Boliviana (LSB), dichas en una oficina pública de Cochabamba.

{_GRAMATICA}

Escribe una frase en español correcto por secuencia, con SOLO lo que dicen
las glosas: no añadas información que no esté ni quites la que esté. Nunca
respondas con las glosas: escribe español normal.

Ejemplos:
- (habla la persona sorda) YO · PAPEL · IDENTIDAD · PERDER → «Perdí mi cédula
  de identidad.»
- (habla el funcionario) TÚ · ABOGADO · TENER → «¿Usted tiene abogado?»
- (habla la persona sorda) SÍ · MÍO · NOMBRE · CASA → «Sí, la casa está a mi
  nombre.»

Secuencias:
{lineas}

Responde SOLO con JSON: ["frase 1", "frase 2", ...], en el mismo orden."""


def prompt_comparar(items: list) -> str:
    lineas = "\n".join(
        f"{i + 1}. Frase: «{it['texto']}» | Glosas: "
        f"{' · '.join(legibles(it['glosas']))}"
        for i, it in enumerate(items))
    return f"""Compara cada frase en español con su traducción a glosas de Lengua
de Señas Boliviana (LSB).

{_GRAMATICA}

Para cada par indica:
- "faltan": palabras de la frase con significado propio (sustantivos, verbos,
  adjetivos, números, negaciones) que ninguna glosa expresa. Copia la
  palabra tal como está en la frase.
- "sobran": glosas que añaden algo que la frase no dice. Copia la glosa tal
  como está.
No cuentes como faltantes los artículos, preposiciones o pronombres, ni una
palabra expresada con otra glosa equivalente (cédula = PAPEL IDENTIDAD).

Ejemplo: Frase «Compré un auto. Quiero pasarlo a mi nombre.» | Glosas:
COMPRAR · MÍO · NOMBRE · PASAR → {{"faltan": ["auto", "Quiero"], "sobran": []}}
Ejemplo: Frase «Tengo deuda de mi casa.» | Glosas: CASO · DEUDA · MÍO · CASA
→ {{"faltan": ["Tengo"], "sobran": ["CASO"]}}

Pares:
{lineas}

Responde SOLO con JSON, una entrada por par en el mismo orden:
[{{"faltan": [...], "sobran": [...]}}, ...]"""


def _json_lista(texto: str) -> list:
    try:
        inicio, fin = texto.index("["), texto.rindex("]") + 1
        crudo = json.loads(texto[inicio:fin])
    except (ValueError, json.JSONDecodeError):
        return []
    return crudo if isinstance(crudo, list) else []


def frases_de_respuesta(texto: str, n: int) -> list:
    """Las [n] frases del JSON del modelo; vacías si no se puede leer."""
    frases = [str(f) if isinstance(f, (str, int, float)) else ""
              for f in _json_lista(texto)]
    return (frases + [""] * n)[:n]


def es_espanol(vuelta: str, glosas: list) -> bool:
    """Si la vuelta es una frase y no las glosas copiadas.

    Nova a veces devuelve «PAPEL IDENTIDAD NUEVO NECESITAR» o «Comprar mío
    nombre pasar»: eso no es español y compararlo con la frase hunde el
    parecido de una traducción correcta.
    """
    palabras = re.findall(r"[A-Za-zÁÉÍÓÚÑáéíóúñ]+", vuelta)
    if not palabras:
        return False
    mayusculas = sum(1 for p in palabras if len(p) > 1 and p.isupper())
    if mayusculas * 2 > len(palabras):
        return False
    glosa = {_norm(w) for g in legibles(glosas) for w in g.split()}
    iguales = sum(1 for p in palabras if _norm(p) in glosa)
    # Una sola palabra que es su propia glosa («Llamar») tampoco es frase,
    # pero sí lo es «Fue robo.»: se exige algo que no sea glosa, salvo en
    # frases de una palabra corta (Sí, No).
    return iguales < len(palabras) or len(palabras) == 1 and len(vuelta) <= 4


def conjugada(palabra: str, glosas: list) -> bool:
    """Si [palabra] es una forma de alguna glosa: PERDIMOS de PERDER,
    COMPRÉ de COMPRAR. Entonces no falta. QUIERO/QUERER o TENGO/TENER no
    comparten raíz y sí se marcan: esas glosas no están."""
    palabra = _norm(palabra)
    for g in legibles(glosas):
        for w in (_norm(x) for x in g.split()):
            if len(palabra) >= 4 and w[:4] == palabra[:4]:
                return True
            # Verbos cortos: IR → «iré», VER → «verla».
            if 2 <= len(w) <= 3 and palabra.startswith(w):
                return True
    return False


def _en_la_frase(glosa: str, texto: str) -> bool:
    """Si la glosa dice algo que la frase sí dice: la misma palabra sin
    tildes (SI/«Sí», QUE/«¿Qué?»), otra forma (CUANTOS/«cuánto») o un número
    escrito con cifras o letras (2, 0, 5 en «2025»; 6 en «seis»)."""
    palabras = [_norm(w) for w in
                re.findall(r"[A-Za-zÁÉÍÓÚÑáéíóúñ0-9]+", texto)]
    partes = [_norm(w) for w in glosa.split()]
    if all(p.isdigit() for p in partes):
        return any(w.isdigit() or w in _NUMEROS for w in palabras)
    return all(any(w == p or len(p) >= 4 and w[:4] == p[:4]
                   for w in palabras) for p in partes)


def depurar(texto: str, glosas: list, faltan: list, sobran: list) -> dict:
    """Quita de lo que el modelo marcó lo que no es un error comprobable.

    Falta: debe estar en la frase, no ser una palabra que LSB no signa ni una
    forma de alguna glosa. Sobra: debe estar en las glosas, no ser un sujeto
    que el español calla ni algo que la frase sí dice. `leve` si solo faltan
    auxiliares («quiero», «debe») y no sobra nada.
    """
    en_frase = {_norm(w): w for w in
                re.findall(r"[A-Za-zÁÉÍÓÚÑáéíóúñ0-9]+", texto)}
    en_glosas = {_norm(g): g for g in legibles(glosas)}
    quedan_f = []
    for w in faltan:
        clave = _norm(str(w)).strip()
        if (clave in en_frase and clave not in _FUNCION
                and not conjugada(clave, glosas)
                and en_frase[clave] not in quedan_f):
            quedan_f.append(en_frase[clave])
    quedan_s = []
    for g in sobran:
        clave = _norm(str(g).replace("_", " ")).strip()
        if (clave in en_glosas and clave not in _SUJETOS
                and not _en_la_frase(clave, texto)
                and en_glosas[clave] not in quedan_s):
            quedan_s.append(en_glosas[clave])
    leve = bool(quedan_f) and not quedan_s and all(
        _norm(w) in _AUXILIARES for w in quedan_f)
    return {"faltan": quedan_f, "sobran": quedan_s, "leve": leve}


def comparaciones(texto: str, items: list) -> list:
    """{faltan, sobran} por item, comprobados contra la frase y las glosas."""
    crudo = _json_lista(texto)
    salida = []
    for i, it in enumerate(items):
        r = crudo[i] if i < len(crudo) and isinstance(crudo[i], dict) else {}
        salida.append(depurar(it["texto"], it["glosas"],
                              r.get("faltan") or [], r.get("sobran") or []))
    return salida


def coseno(a: list, b: list) -> float:
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if not na or not nb:
        return 0.0
    return sum(x * y for x, y in zip(a, b)) / (na * nb)


def revisar(items: list, invocar, embed) -> list:
    """[{texto, vuelta, similitud, faltan, sobran}].

    [invocar]: prompt → texto del modelo; [embed]: texto → vector (Titan).
    """
    comparadas = comparaciones(invocar(prompt_comparar(items)), items)
    vueltas = frases_de_respuesta(invocar(prompt_vuelta(items)), len(items))
    salida = []
    for it, vuelta, comp in zip(items, vueltas, comparadas):
        limpia = re.sub(r"\s+", " ", vuelta).strip()
        similitud = (round(coseno(embed(it["texto"]), embed(limpia)), 4)
                     if limpia and es_espanol(limpia, it["glosas"]) else None)
        salida.append({"texto": it["texto"], "vuelta": limpia,
                       "similitud": similitud, **comp})
    return salida


# ─────────────────────────────────────────────────────────────────────────────
# Corrección (`action: "corregir"`)
# ─────────────────────────────────────────────────────────────────────────────
#
# Para una frase marcada, Bedrock propone glosas corregidas con lo que falta
# y sin lo que sobra, usando solo señas del catálogo oficial. Toda glosa se
# comprueba y la corrección se vuelve a comparar con la frase: se acepta
# solo si deja menos errores que antes y ninguno nuevo que sobre.

def validar_pedido_correccion(body: dict) -> tuple:
    """(items, error). Cada item: {texto, glosas, faltan, sobran, rol?}."""
    items, error = validar_pedido(body)
    if error:
        return None, error
    for it, crudo in zip(items, body["items"]):
        for campo in ("faltan", "sobran"):
            valores = crudo.get(campo) or []
            if (not isinstance(valores, list) or len(valores) > 20
                    or not all(isinstance(v, str) and len(v) <= 60
                               for v in valores)):
                return None, f"{campo} inválido."
            it[campo] = valores
    return items, None


def prompt_corregir(items: list, catalogo: dict) -> str:
    lista = ", ".join(sorted(catalogo))
    pares = "\n".join(
        f"{i + 1}. (habla {_QUIEN[it['rol']]}) Frase: «{it['texto']}» | "
        f"Glosas: {' · '.join(legibles(it['glosas']))} | "
        f"Faltan: {', '.join(it['faltan']) or '—'} | "
        f"Sobran: {', '.join(it['sobran']) or '—'}"
        for i, it in enumerate(items))
    return f"""Corrige la traducción a glosas de Lengua de Señas Boliviana (LSB) de
cada frase: añade lo que falta, quita lo que sobra y conserva lo demás.

Reglas de las glosas:
- Una glosa por seña, en mayúsculas. Verbos en infinitivo (COMPRAR, QUERER).
- Sin artículos, preposiciones ni el verbo «ser/estar» como cópula.
- Orden LSB: tiempo, lugar, sujeto, objeto, verbo; la negación NO después
  del verbo; en una pregunta, la palabra interrogativa al final.
- Solo puedes usar glosas de este catálogo, escritas igual:
  {lista}
- Una palabra de la frase sin seña en el catálogo se escribe
  SENA_PENDIENTE:PALABRA (en infinitivo si es verbo): SENA_PENDIENTE:AUTO.
- Una sigla de la frase (NUREJ, SEGIP) se escribe tal cual; un número, con
  cifras (2025).
- No añadas nada que la frase no diga.

Ejemplo: Frase «Compré un auto. Quiero pasarlo a mi nombre.» | Glosas:
COMPRAR · MÍO · NOMBRE · PASAR | Faltan: auto, Quiero | Sobran: —
→ ["COMPRAR", "SENA_PENDIENTE:AUTO", "QUERER", "MÍO", "NOMBRE",
   "SENA_PENDIENTE:PASAR"]
Ejemplo: Frase «Tengo deuda de mi casa.» | Glosas: CASO · DEUDA · MÍO · CASA
| Faltan: Tengo | Sobran: CASO → ["MÍO", "CASA", "SENA_PENDIENTE:DEUDA",
"TENER"]

Frases:
{pares}

Responde SOLO con JSON: una lista de glosas por frase, en el mismo orden.
[["GLOSA", ...], ...]"""


def glosas_validas(tokens: list, texto: str, catalogo: dict) -> list | None:
    """Las glosas en el formato del corpus, o `None` si alguna no vale.

    Vale una glosa del catálogo (en su forma del catálogo), una seña a
    incorporar de una palabra que está en la frase, una sigla escrita así en
    la frase (se deletrea) o un número de la frase (cifra a cifra).
    """
    por_norma = {_norm(g).replace(" ", "_"): g for g in catalogo}
    palabras = re.findall(r"[A-Za-zÁÉÍÓÚÑáéíóúñ0-9]+", texto)
    siglas = {_norm(w): w.upper() for w in palabras
              if sum(c.isupper() for c in w) >= 2}
    cifras = {w for w in palabras if w.isdigit()}
    salida = []
    for t in tokens:
        if not isinstance(t, str) or not t.strip():
            return None
        t = t.strip()
        if t.upper().startswith(PENDIENTE):
            palabra = t[len(PENDIENTE):].strip().upper().replace(" ", "_")
            if not palabra or not any(
                    conjugada(p, [palabra.replace("_", " ")])
                    or _norm(p) == _norm(palabra) for p in palabras):
                return None
            salida.append(PENDIENTE + palabra)
            continue
        clave = _norm(t).replace(" ", "_")
        if clave in por_norma:
            salida.append(por_norma[clave])
        elif clave in siglas:
            salida.extend(list(_norm(siglas[clave]).upper()))
        elif t in cifras:
            salida.extend(list(t))
        else:
            return None
    return salida or None


def corregir(items: list, catalogo: dict, invocar) -> list:
    """[{texto, aceptada, glosas, faltan, sobran, motivo}]."""
    propuestas = _json_lista(invocar(prompt_corregir(items, catalogo)))
    candidatas = []
    for i, it in enumerate(items):
        tokens = propuestas[i] if i < len(propuestas) else None
        glosas = (glosas_validas(tokens, it["texto"], catalogo)
                  if isinstance(tokens, list) else None)
        candidatas.append(glosas)
    a_comparar = [{**it, "glosas": g}
                  for it, g in zip(items, candidatas) if g]
    comparadas = iter(comparaciones(
        invocar(prompt_comparar(a_comparar)), a_comparar)
        if a_comparar else [])
    salida = []
    for it, glosas in zip(items, candidatas):
        base = {"texto": it["texto"], "aceptada": False, "glosas": None,
                "faltan": it["faltan"], "sobran": it["sobran"]}
        if not glosas:
            salida.append({**base, "motivo": "glosas fuera del catálogo"})
            continue
        nueva = next(comparadas)
        antes = len(it["faltan"]) + len(it["sobran"])
        despues = len(nueva["faltan"]) + len(nueva["sobran"])
        if despues < antes and len(nueva["sobran"]) <= len(it["sobran"]):
            salida.append({**base, "aceptada": True, "glosas": glosas,
                           "faltan": nueva["faltan"],
                           "sobran": nueva["sobran"], "motivo": ""})
        else:
            salida.append({**base, "motivo":
                           f"no mejora ({antes} → {despues} errores)"})
    return salida
