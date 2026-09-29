"""Genera las clases cerradas de lectura semántica desde una sola fuente.

    python tool/build_semantica_lsb.py          # escribe
    python tool/build_semantica_lsb.py --check  # falla si algo está desactualizado

Fuente: docs/negocio/config/semantica_lsb.json (interrogativos, núcleos,
negadores, raíces que piden describir, vocabulario de ranuras…).

Salidas:
    lib/core/domain/conversation/lsb_gloss_semantics_data.g.dart  la app
    aws/lambda_text_to_lsb.py (bloque entre marcas)                 la Lambda

La Lambda de texto a LSB se despliega como un solo archivo, así que no lee
el JSON en tiempo de ejecución: el generador reescribe solo el bloque entre
`# >>> GENERADO` y `# <<< GENERADO`. Añadir una señal es editar el JSON y
ejecutar esto; para que la Lambda desplegada la use hay que redesplegarla.
"""

from __future__ import annotations

import io
import json
import os
import sys
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FUENTE = os.path.join(ROOT, "docs", "negocio", "config", "semantica_lsb.json")
OUT_DART = os.path.join(ROOT, "lib", "core", "domain", "conversation",
                        "lsb_gloss_semantics_data.g.dart")
OUT_PY = os.path.join(ROOT, "aws", "lambda_text_to_lsb.py")

MARCA_INICIO = "# >>> GENERADO por tool/build_semantica_lsb.py"
MARCA_FIN = "# <<< GENERADO por tool/build_semantica_lsb.py"

# Tablas de mapa (clave -> ranura) y de conjunto, con su nombre en cada lado.
MAPAS = [
    # (clave JSON, constante Dart, constante Python)
    ("interrogativeSlots", "kInterrogativeSlots", "_SLOT_POR_INTERROGATIVO"),
    ("headSlots", "kHeadSlots", "_SLOT_POR_NUCLEO"),
    ("spokenInterrogativeSlots", "kSpokenInterrogativeSlots",
     "_SLOT_POR_INTERROGATIVO_HABLADO"),
    ("spokenHeadSlots", "kSpokenHeadSlots", "_SLOT_POR_NUCLEO_HABLADO"),
    ("spokenWordSlots", "kSpokenWordSlots", "_SLOT_POR_PALABRA"),
    ("spokenStemSlots", "kSpokenStemSlots", "_SLOT_POR_RAIZ_HABLADA"),
    ("spokenAfterHowSlots", "kSpokenAfterHowSlots", "_SLOT_TRAS_COMO_HABLADO"),
]
CONJUNTOS = [
    ("openInterrogatives", "kOpenInterrogatives", "_INTERROGATIVOS_ABIERTOS"),
    ("negators", "kNegators", "_NEGADORES"),
    ("spokenOpenInterrogatives", "kSpokenOpenInterrogatives",
     "_INTERROGATIVOS_ABIERTOS_HABLADOS"),
    ("questionPrepositions", "kQuestionPrepositions",
     "_PREPOSICIONES_INTERROGATIVAS"),
]


def cargar(path: str = FUENTE) -> OrderedDict:
    with io.open(path, encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=OrderedDict)


def validar(d: dict) -> list[str]:
    """Lo que el JSON tiene que cumplir para generarse."""
    errores = []
    vocab = d.get("slotVocabulary")
    if not isinstance(vocab, list) or not vocab:
        return ["slotVocabulary vacío"]
    ranuras = set(vocab)
    for clave, _, _ in MAPAS:
        mapa = d.get(clave)
        if not isinstance(mapa, dict):
            errores.append(f"{clave}: falta o no es un objeto")
            continue
        for k, v in mapa.items():
            if k != k.upper() or not k.strip():
                errores.append(f"{clave}: «{k}» debe ir en mayúsculas")
            if v not in ranuras:
                errores.append(f"{clave}: ranura desconocida «{v}» en «{k}»")
    for clave, _, _ in CONJUNTOS:
        valores = d.get(clave)
        if not isinstance(valores, list) or not valores:
            errores.append(f"{clave}: falta o está vacío")
            continue
        for v in valores:
            if v != v.upper():
                errores.append(f"{clave}: «{v}» debe ir en mayúsculas")
    wear = d.get("spokenWearSlots") or {}
    if not wear.get("verbs") or not wear.get("words"):
        errores.append("spokenWearSlots: faltan verbs o words")
    if wear.get("slot") not in ranuras:
        errores.append(f"spokenWearSlots: ranura desconocida «{wear.get('slot')}»")
    return errores


def _dart_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def _dart_coleccion(cabecera: str, abre: str, cierra: str, items: list[str]) -> list[str]:
    """Como la deja `dart format`: en una línea si cabe en 80 columnas; si no,
    un elemento por línea con coma final."""
    una = f"{cabecera}{abre}{', '.join(items)}{cierra};"
    if len(una) <= 80:
        return [una]
    return [f"{cabecera}{abre}"] + [f"  {i}," for i in items] + [f"{cierra};"]


def render_dart(d: dict) -> str:
    lineas = [
        "// GENERADO por tool/build_semantica_lsb.py desde",
        "// docs/negocio/config/semantica_lsb.json. No editar a mano.",
        "",
        "// Clases cerradas de lectura semántica, compartidas con la Lambda de",
        "// texto a LSB (aws/lambda_text_to_lsb.py).",
        "",
    ]
    lineas += _dart_coleccion("const List<String> kSlotVocabulary = ", "[", "]",
                              [_dart_str(s) for s in d["slotVocabulary"]])
    lineas.append("")
    for clave, dart, _ in MAPAS:
        lineas += _dart_coleccion(
            f"const Map<String, String> {dart} = ", "{", "}",
            [f"{_dart_str(k)}: {_dart_str(v)}" for k, v in d[clave].items()])
        lineas.append("")
    for clave, dart, _ in CONJUNTOS:
        lineas += _dart_coleccion(f"const Set<String> {dart} = ", "{", "}",
                                  [_dart_str(v) for v in d[clave]])
        lineas.append("")
    wear = d["spokenWearSlots"]
    lineas += _dart_coleccion("const Set<String> kSpokenWearVerbs = ", "{", "}",
                              [_dart_str(v) for v in wear["verbs"]])
    lineas.append("")
    lineas += _dart_coleccion("const Set<String> kSpokenWearWords = ", "{", "}",
                              [_dart_str(v) for v in wear["words"]])
    lineas += ["", f"const String kSpokenWearSlot = {_dart_str(wear['slot'])};", ""]
    return "\n".join(lineas)


def _py_str(s: str) -> str:
    return json.dumps(s, ensure_ascii=False)


def _py_conjunto(nombre: str, valores: list) -> list[str]:
    return [f"{nombre} = {{"] + [f"    {_py_str(v)}," for v in valores] + ["}"]


def render_bloque_py(d: dict) -> str:
    lineas = [
        MARCA_INICIO,
        "# desde docs/negocio/config/semantica_lsb.json: no editar a mano. Son las",
        "# mismas clases cerradas que usa la app (lsb_gloss_semantics_data.g.dart):",
        "# interrogativos y núcleos que dicen qué dato se pide, negadores, raíces que",
        "# piden describir a alguien (DESCRIBIR no tiene seña y la traducción lo",
        "# deletrea, así que solo el texto lo conserva), verbos y palabras de llevar",
        "# puesto («¿qué ropa llevaba?» pide la ropa; «¿qué ropa le robaron?», el",
        "# objeto) y CÓMO + ser/lucir en pasado («¿cómo era?»).",
    ]
    for clave, _, py in MAPAS:
        lineas.append(f"{py} = {{")
        lineas += [f"    {_py_str(k)}: {_py_str(v)}," for k, v in d[clave].items()]
        lineas.append("}")
    for clave, _, py in CONJUNTOS:
        lineas += _py_conjunto(py, d[clave])
    wear = d["spokenWearSlots"]
    lineas += _py_conjunto("_VERBOS_DE_VESTIR", wear["verbs"])
    lineas += _py_conjunto("_PALABRAS_DE_VESTIR", wear["words"])
    lineas.append(f"_SLOT_DE_VESTIR = {_py_str(wear['slot'])}")
    lineas.append(MARCA_FIN)
    return "\n".join(lineas)


def render_py(actual: str, d: dict) -> str:
    """[actual] con el bloque generado reemplazado, con sus mismos saltos de
    línea (el archivo puede estar en CRLF)."""
    inicio = actual.find(MARCA_INICIO)
    fin = actual.find(MARCA_FIN)
    if inicio < 0 or fin < inicio:
        raise SystemExit(f"{OUT_PY}: faltan las marcas del bloque generado")
    nl = "\r\n" if "\r\n" in actual else "\n"
    bloque = render_bloque_py(d).replace("\n", nl)
    return actual[:inicio] + bloque + actual[fin + len(MARCA_FIN):]


def _leer(path: str, crudo: bool = False) -> str:
    with io.open(path, encoding="utf-8", newline="" if crudo else None) as f:
        return f.read()


def salidas(d: dict) -> dict[str, str]:
    return {OUT_DART: render_dart(d), OUT_PY: render_py(_leer(OUT_PY, crudo=True), d)}


def main() -> int:
    d = cargar()
    errores = validar(d)
    if errores:
        for e in errores:
            print(f"ERROR: {e}")
        print(f"{len(errores)} errores: no se escribe nada.")
        return 1
    out = salidas(d)
    if "--check" in sys.argv:
        # Sin distinguir CRLF de LF: depende de cómo se clonó el repositorio.
        viejos = [
            p for p, t in out.items()
            if not os.path.exists(p)
            or _leer(p) != t.replace("\r\n", "\n")
        ]
        if viejos:
            for p in viejos:
                print(f"desactualizado: {os.path.relpath(p, ROOT)}")
            print("Ejecuta: python tool/build_semantica_lsb.py")
            return 1
        print("Semántica LSB al día en la app y en la Lambda.")
        return 0
    for p, t in out.items():
        with io.open(p, "w", encoding="utf-8", newline="") as f:
            f.write(t)
        print(f"escrito: {os.path.relpath(p, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
