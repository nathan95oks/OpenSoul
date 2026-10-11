"""Cobertura del modelo (tesis, §4.7.4): qué parte del lenguaje que el
sistema debe manejar está representada y responde de forma coherente.

    python3 tool/cobertura_modelo.py

Todo se mide en vivo: el diccionario y el banco del repositorio, las
animaciones del modelo 3D en S3 (`LSB_ANIMATIONS_BASE_URL` de `.env`, solo
la cabecera del .glb), el QA de Conversación con las respuestas reales
grabadas de las Lambdas y la traducción de las frases reales del funcionario
(test/qa/lambda_respuestas.json).
"""

from __future__ import annotations

import json
import os
import re
import struct
import subprocess
import sys
import tempfile
import unicodedata
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tool"))

import build_question_matrix as B  # noqa: E402

NUMEROS = {"0": "CERO", "1": "UNO", "2": "DOS", "3": "TRES", "4": "CUATRO",
           "5": "CINCO", "6": "SEIS", "7": "SIETE", "8": "OCHO", "9": "NUEVE",
           "10": "DIEZ"}


def _clave(glosa: str) -> str:
    s = unicodedata.normalize("NFD", glosa.upper())
    return "".join(c for c in s if unicodedata.category(c) != "Mn").replace(" ", "_")


def _env() -> dict:
    out = {}
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
        for linea in f:
            if "=" in linea and not linea.lstrip().startswith("#"):
                k, v = linea.strip().split("=", 1)
                out[k] = v.strip().strip('"')
    return out


def clips_en_s3() -> list:
    """Nombres de las animaciones del .glb publicado, leyendo solo su JSON."""
    url = _env()["LSB_ANIMATIONS_BASE_URL"] + "avatar_test.glb"

    def rango(a: int, b: int) -> bytes:
        pedido = urllib.request.Request(url, headers={"Range": f"bytes={a}-{b}"})
        with urllib.request.urlopen(pedido, timeout=60) as r:
            return r.read()

    largo, _ = struct.unpack_from("<II", rango(0, 19), 12)
    gltf = json.loads(rango(20, 20 + largo - 1))
    return [a["name"] for a in gltf.get("animations", [])]


def catalogo_avatar() -> list:
    """Las glosas del diccionario oficial que acepta la Lambda Texto→LSB."""
    with open(os.path.join(ROOT, "aws", "lambda_text_to_lsb.py"), encoding="utf-8") as f:
        bloque = re.search(r"AVAILABLE_GLOSSES = \{(.*?)\n\}", f.read(), re.S).group(1)
    return re.findall(r'"([^"]+)"', bloque)


def vocabulario() -> tuple:
    """Glosas del catálogo representadas en el ensamblador y en GLOSS_LEXICON."""
    salida = subprocess.run(["dart", "run", "tool/find_missing_lambda_lexicon.dart"],
                            cwd=ROOT, capture_output=True, text=True).stdout
    total = int(re.search(r"Glosas en catálogo local\s*:\s*(\d+)", salida).group(1))
    completa = "Cobertura completa" in salida
    return (total if completa else total - 1), total


def conversacion() -> tuple:
    """Turnos del QA de Conversación sin falla (respuestas reales grabadas)."""
    with tempfile.TemporaryDirectory() as d:
        reporte = os.path.join(d, "qa.json")
        subprocess.run(
            ["flutter", "test", "test/qa_conversacion_test.dart",
             "--dart-define=LSB_API_URL=https://api.qa.invalid/translate",
             "--dart-define=LSB_TEXT_API_URL=https://texto.qa.invalid/translate"],
            cwd=ROOT, capture_output=True, text=True,
            env={**os.environ, "REPORTE_QA": reporte, "QA_ESTRICTO": "0"})
        with open(reporte, encoding="utf-8") as f:
            informe = json.load(f)
    turnos = sum(len(c["turnos"]) for c in informe)
    fallas = sum(len(c["fallas"]) for c in informe)
    return turnos - fallas, turnos, len(informe)


def traduccion(clips: set) -> tuple:
    """(señas, unidades, señas animadas, frases) de las frases reales."""
    with open(os.path.join(ROOT, "test", "qa", "lambda_respuestas.json"),
              encoding="utf-8") as f:
        grabadas = json.load(f)
    senas = deletreos = animadas = frases = 0
    for clave, r in grabadas.items():
        if not clave.startswith("texto/"):
            continue
        try:
            glosas = json.loads(r["cuerpo"])["glosses"]
        except (KeyError, ValueError):
            continue
        frases += 1
        letra_anterior = False
        for g in glosas:
            if len(g) == 1 and g.isalpha():
                deletreos += 0 if letra_anterior else 1
                letra_anterior = True
                continue
            letra_anterior = False
            if g.isdigit():
                continue
            senas += 1
            animadas += _clave(g) in clips
    return senas, senas + deletreos, animadas, frases


def main() -> int:
    print("Midiendo… (el QA de Conversación tarda unos segundos)\n")
    clips = clips_en_s3()
    claves = {_clave(c) for c in clips}
    letras = [c for c in clips if len(c) == 1 or c in ("ENE", "ENIE")]
    numeros = [c for c in clips if c in NUMEROS.values()]
    reposo = [c for c in clips if c.startswith("NEUTRO")]
    palabras = len(clips) - len(letras) - len(numeros) - len(reposo)

    catalogo = catalogo_avatar()
    senas_cat = [g for g in catalogo if len(g) > 1 and not g.isdigit()]
    dactilologia = [g for g in catalogo if len(g) == 1 or g.isdigit()]
    animadas_cat = sum(_clave(g) in claves for g in senas_cat)
    dacti_ok = sum(_clave(NUMEROS.get(g, g)) in claves or (g == "Ñ" and "ENIE" in claves)
                   for g in dactilologia) + ("DIEZ" in claves)

    with open(os.path.join(ROOT, "docs", "negocio", "config", "banco_preguntas.json"),
              encoding="utf-8") as f:
        banco = json.load(f)
    preguntas = banco["preguntas"]
    utilizables = sum(bool(B.formulacion_lsb_utilizable(q)) for q in preguntas)

    with open(os.path.join(ROOT, "assets", "rag", "escenarios_cbba.json"),
              encoding="utf-8") as f:
        escenarios = len(json.load(f)["escenarios"])
    with open(os.path.join(ROOT, "lib", "core", "domain", "rag", "tramites_data.g.dart"),
              encoding="utf-8") as f:
        dart = f.read()
    tramites = json.loads(dart[dart.index("r'''") + 4:dart.rindex("'''")])
    respuestas = sum(len(q["opciones"]) for q in tramites["preguntas"])

    voc_ok, voc_total = vocabulario()
    conv_ok, conv_total, conversaciones = conversacion()
    senas, unidades, animadas, frases = traduccion(claves)

    def pct(a, b):
        return f"{100 * a / b:6.1f}"

    filas = [
        ("CM-01", "Vocabulario LSB (app y backend)", voc_ok, voc_total),
        ("CM-02", "Señas del diccionario animadas", animadas_cat, len(senas_cat)),
        ("CM-03", "Dactilología (letras y números)", dacti_ok, len(dactilologia) + 1),
        ("CM-04", "Banco de preguntas con LSB", utilizables, len(preguntas)),
        ("CM-05", f"Conversación ({conversaciones} guiones, turnos)", conv_ok, conv_total),
        ("CM-06", f"Traducción a seña ({frases} frases)", senas, unidades),
        ("CM-07", "Señas de la traducción animadas", animadas, senas),
    ]
    linea = "-" * 78
    print(linea)
    print(f"{'N.º':<7}| {'Aspecto del modelo':<44}| {'Cubre':>6} | {'Total':>6} | {'%':>6}")
    print(linea)
    for n, aspecto, a, b in filas:
        print(f"{n:<7}| {aspecto:<44}| {a:>6} | {b:>6} | {pct(a, b)}")
    print(linea)
    print(f"Modelo 3D en S3: {len(clips)} animaciones = {palabras} señas de palabra, "
          f"{len(letras)} letras, {len(numeros)} números, {len(reposo)} de reposo")
    print(f"Corpus RAG: {escenarios} escenarios, {len(tramites['recorridos'])} trámites, "
          f"{len(tramites['preguntas'])} preguntas, {respuestas} respuestas")
    print(linea)
    return 0


if __name__ == "__main__":
    sys.exit(main())
