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

_VALOR = {
    "cero": 0, "uno": 1, "una": 1, "dos": 2, "tres": 3, "cuatro": 4,
    "cinco": 5, "seis": 6, "siete": 7, "ocho": 8, "nueve": 9, "diez": 10,
    "once": 11, "doce": 12, "trece": 13, "catorce": 14, "quince": 15,
    "veinte": 20, "treinta": 30, "cuarenta": 40, "cincuenta": 50,
    "sesenta": 60, "setenta": 70, "ochenta": 80, "noventa": 90, "cien": 100,
    "ciento": 100, "mil": 1000,
}
_NUMEROS = frozenset(_VALOR) | {"primero", "primera", "segundo"}


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


# Palabras que cambian de género o número sin cambiar de significado: OTRO
# es «otra», TODO es «toda». Un sustantivo no (CASO no es «casa»).
_VARIABLES = frozenset("""
otro todo mismo mucho poco nuevo bueno malo alto bajo gordo flaco negro rojo
oscuro corto lento caro ultimo proximo pasado primero segundo ninguno alguno
cuanto solo
""".split())


# Verbos irregulares frecuentes: sus formas no comparten raíz con la glosa.
_IRREGULARES = {
    "decir": "dije dijo dijeron dijiste digo dice dicen diga digan dicho",
    "venir": "vine vino vinieron vengo viene vienen venga",
    "ir": "fui fue fueron voy va van vaya iré irá",
    "ser": "fui fue fueron soy es son era eran sea",
    "hacer": "hice hizo hicieron hago hace hacen haga haré hará hecho",
    "tener": "tuve tuvo tuvieron tengo tiene tienen tenga tendré",
    "poder": "pude pudo pudieron puedo puede pueden pueda podré podrá",
    "saber": "supe supo sé sabe saben sepa sabré",
    "querer": "quise quiso quiero quiere quieren quiera querré",
    "poner": "puse puso pongo pone ponga pondré",
    "traer": "traje trajo trajeron traigo trae traiga",
}
_IRREGULARES = {k: {_norm(f) for f in v.split()} for k, v in _IRREGULARES.items()}


def _sin_final(w: str) -> str:
    w = w[:-1] if w.endswith("s") and len(w) > 3 else w
    return w[:-1] if w[-1:] in "aeo" and len(w) > 3 else w


def _forma_de(palabra: str, glosa: str) -> bool:
    """Si [palabra] es una forma irregular o de otro género de [glosa]:
    CONTAR/«cuente», ENTENDER/«entiendo», PODER/«puede» (diptongo de un
    verbo), OTRO/«otra», TODO/«toda» (género de una palabra variable)."""
    p, g = _norm(palabra), _norm(glosa)
    if p in _IRREGULARES.get(g, ()):
        return True
    if p.endswith("mente") and len(p) > 7:
        p = p[:-5]  # solamente → sola
    if g.endswith(("ar", "er", "ir")) and len(g) >= 3:
        # Diptongo (cuente → contar), e/i (sirve → servir) y raíz de tres
        # letras (estoy → estar, usando → usar).
        for forma in (p, p.replace("ue", "o").replace("ie", "e"),
                      p.replace("i", "e", 1)):
            raiz = _sin_final(forma)
            if len(raiz) >= 3 and (g.startswith(raiz) or raiz[:3] == g[:3]
                                   and len(g) <= 5):
                return True
        return False
    if g.rstrip("s") in _VARIABLES or g in _VARIABLES:
        return _sin_final(p) == _sin_final(g)
    # Un sustantivo con diptongo o en plural: COSTO/«cuesta», CUOTA/«cuotas».
    base = p.replace("ue", "o").replace("ie", "e")
    return len(g) >= 4 and (base[:4] == g[:4] or p.rstrip("s") == g.rstrip("s"))


def conjugada(palabra: str, glosas: list) -> bool:
    """Si [palabra] es una forma de alguna glosa: PERDIMOS de PERDER,
    COMPRÉ de COMPRAR. Entonces no falta. QUIERO/QUERER o TENGO/TENER no
    comparten raíz y sí se marcan: esas glosas no están."""
    palabra_n = _norm(palabra)
    for g in legibles(glosas):
        for x in g.split():
            w = _norm(x)
            if len(palabra_n) >= 4 and w[:4] == palabra_n[:4]:
                return True
            # Verbos cortos: IR → «iré», VER → «verla».
            if 2 <= len(w) <= 3 and palabra_n.startswith(w):
                return True
            if _forma_de(palabra, x):
                return True
    return False


def _nombre_propio(palabra: str, texto: str) -> bool:
    """Si [palabra] va con mayúscula dentro de la frase (Antezana, Beijing)."""
    for m in re.finditer(r"[A-Za-zÁÉÍÓÚÑáéíóúñ]+", texto):
        antes = texto[:m.start()].rstrip()
        if (m.group() == palabra and palabra[:1].isupper() and antes
                and antes[-1] not in ".?!¿¡:"):
            return True
    return False


def de_la_frase(palabra: str, texto: str) -> bool:
    """Si una palabra escrita en las glosas (una seña a incorporar) sale de
    la frase: la misma o una forma suya. Un nombre propio tiene que estar
    tal cual: ANTERIOR no es «Antezana» aunque empiecen igual."""
    if _norm(palabra) in _FUNCION or _norm(palabra) in ("ser", "estar"):
        return True  # ruido, no una palabra inventada
    palabras = re.findall(r"[A-Za-zÁÉÍÓÚÑáéíóúñ0-9]+", texto)
    # Una sigla de las iniciales de la frase: LSB = «Lengua de Señas Boliviana».
    iniciales = "".join(p[0] for p in palabras if p[:1].isupper())
    if palabra.isupper() and len(palabra) >= 2 and palabra in iniciales.upper():
        return True
    for p in palabras:
        if _norm(p).rstrip("s") == _norm(palabra).rstrip("s"):
            return True
        if not _nombre_propio(p, texto) and conjugada(p, [palabra]):
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
    # Control fijo, sin depender del modelo: una seña a incorporar escribe una
    # palabra; si la frase no la tiene, sobra (NEED por «necesita», ANTERIOR
    # por «Antezana»).
    for g in glosas:
        if g.startswith(PENDIENTE):
            palabra = g[len(PENDIENTE):]
            partes = palabra.split("_")
            if not all(de_la_frase(p, texto) for p in partes):
                legible = palabra.replace("_", " ")
                if legible not in quedan_s:
                    quedan_s.append(legible)
    for g in sobran:
        clave = _norm(str(g).replace("_", " ")).strip()
        if (clave in en_glosas and clave not in _SUJETOS
                and not _en_la_frase(clave, texto)
                and not all(de_la_frase(p, texto) for p in clave.split())
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

Responde SOLO con JSON, una entrada por frase con su número:
[{{"n": 1, "glosas": ["GLOSA", ...]}}, ...]"""


def _juntas(clave: str, palabras: list) -> list:
    """Las palabras seguidas de la frase que, pegadas, dan [clave]."""
    normas = [_norm(p) for p in palabras]
    for i in range(len(normas)):
        for j in range(i + 2, min(i + 4, len(normas)) + 1):
            if "".join(normas[i:j]) == clave.replace("_", ""):
                return [_norm(p) for p in palabras[i:j]]
    return []


def glosas_validas(tokens: list, texto: str, catalogo: dict) -> tuple:
    """(glosas en el formato del corpus o None, glosas que no valen).

    Vale una glosa del catálogo (en su forma del catálogo, y la compuesta si
    existe: NO + SABER → NO_SABER), una palabra de la frase sin seña (como
    seña a incorporar, la escriba el modelo marcada o no; si tiene seña en el
    catálogo, la seña), una sigla escrita así en la frase (se deletrea) o un
    número de la frase (cifra a cifra). Cualquier otra cosa invalida la
    corrección: el modelo no puede traer palabras que la frase no dice.
    """
    por_norma = {_norm(g).replace(" ", "_"): g for g in catalogo}
    palabras = re.findall(r"[A-Za-zÁÉÍÓÚÑáéíóúñ0-9]+", texto)
    siglas = {_norm(w): w.upper() for w in palabras
              if sum(c.isupper() for c in w) >= 2}
    cifras = {w for w in palabras if w.isdigit()}
    cifras |= {str(_VALOR[_norm(w)]) for w in palabras if _norm(w) in _VALOR}
    limpias = [t.strip() for t in tokens if isinstance(t, str) and t.strip()]
    if len(limpias) != len(tokens):
        return None, ["(vacía)"]
    salida, invalidas, i = [], [], 0
    while i < len(limpias):
        # La seña compuesta del catálogo gana a sus partes sueltas.
        for n in (3, 2):
            junta = "_".join(_norm(x) for x in limpias[i:i + n])
            if len(limpias[i:i + n]) == n and junta in por_norma:
                salida.append(por_norma[junta])
                i += n
                break
        else:
            t = limpias[i]
            i += 1
            marcada = t.upper().startswith(PENDIENTE)
            palabra = (t[len(PENDIENTE):] if marcada else t).strip()
            clave = _norm(palabra).replace(" ", "_")
            if clave in por_norma:
                salida.append(por_norma[clave])
            elif clave in _FUNCION:
                continue  # un artículo o preposición que LSB no signa
            elif clave in siglas:
                salida.extend(list(_norm(siglas[clave]).upper()))
            elif palabra in cifras:
                salida.extend(list(palabra))
            elif clave and all(de_la_frase(x, texto)
                               for x in palabra.replace("_", " ").split()):
                salida.append(PENDIENTE + palabra.upper().replace(" ", "_"))
            elif (juntas := _juntas(clave, palabras)):
                # Palabras seguidas de la frase escritas pegadas: PORCIENTO.
                salida.append(PENDIENTE + "_".join(juntas).upper())
            else:
                invalidas.append(t)
    if invalidas or not salida:
        return None, invalidas
    return salida, []


def propuestas_por_frase(texto: str, n: int) -> list:
    """La propuesta de cada frase, por su número: el modelo a veces corre las
    respuestas un lugar y a una frase le tocaban las glosas de la siguiente.
    Sin número (formato anterior), por orden."""
    crudo = _json_lista(texto)
    if crudo and all(isinstance(x, dict) for x in crudo):
        por_n = {x.get("n"): x.get("glosas") for x in crudo}
        return [por_n.get(i + 1) for i in range(n)]
    return (crudo + [None] * n)[:n]


def sin_sobras(glosas: list, sobran: list) -> list:
    """Las glosas sin las que sobran: ya se comprobó que la frase no las
    dice, así que quitarlas es seguro (un NO añadido cambia el sentido)."""
    quitar = {_norm(s).replace(" ", "_") for s in sobran}
    return [g for g in glosas
            if _norm(g[len(PENDIENTE):] if g.startswith(PENDIENTE) else g)
            .replace(" ", "_") not in quitar]


def corregir(items: list, catalogo: dict, invocar) -> list:
    """[{texto, aceptada, glosas, faltan, sobran, motivo}]."""
    propuestas = propuestas_por_frase(
        invocar(prompt_corregir(items, catalogo)), len(items))
    candidatas = []
    for i, it in enumerate(items):
        tokens = propuestas[i] if i < len(propuestas) else None
        glosas, invalidas = (glosas_validas(tokens, it["texto"], catalogo)
                             if isinstance(tokens, list) else (None, []))
        candidatas.append((glosas, invalidas, tokens))
    a_comparar = [{**it, "glosas": g}
                  for it, (g, _, _) in zip(items, candidatas) if g]
    comparadas = iter(comparaciones(
        invocar(prompt_comparar(a_comparar)), a_comparar)
        if a_comparar else [])
    salida = []
    for it, (glosas, invalidas, tokens) in zip(items, candidatas):
        base = {"texto": it["texto"], "aceptada": False, "glosas": None,
                "faltan": it["faltan"], "sobran": it["sobran"],
                "propuesta": tokens if isinstance(tokens, list) else None}
        if not glosas:
            motivo = ("glosas fuera del catálogo y de la frase: "
                      + ", ".join(invalidas)) if invalidas else \
                "sin propuesta legible"
            salida.append({**base, "motivo": motivo})
            continue
        nueva = next(comparadas)
        antes = len(it["faltan"]) + len(it["sobran"])
        despues = len(nueva["faltan"]) + len(nueva["sobran"])
        if despues < antes and len(nueva["sobran"]) <= len(it["sobran"]):
            salida.append({**base, "aceptada": True,
                           "glosas": sin_sobras(glosas, nueva["sobran"]),
                           "faltan": nueva["faltan"], "sobran": [],
                           "motivo": ""})
        else:
            salida.append({**base, "motivo":
                           f"no mejora ({antes} → {despues} errores)"})
    return salida
