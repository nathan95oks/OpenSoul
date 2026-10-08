"""Construye el paquete de despliegue de `lambda_function.py`.

    python aws/deploy/build_package.py

No sube nada. Escribe `aws/deploy/lambda_function.zip` y su SHA-256, y antes
comprueba que los tres archivos compilen y que la suite local pase: empaquetar
algo que no pasa sus propias pruebas es empaquetar un problema.

`lambda_function.py` no es autocontenido. Al arrancar importa
`guided_composer.py` (que lee `question_bank.json` del disco) y
`rag_consulta.py` (que lee el corpus RAG, el mismo de la app:
`assets/rag/escenarios_cbba.json`, empaquetado como `rag_escenarios_cbba.json`).
Todo va en el mismo ZIP, en la raíz: si falta algo, la Lambda no arranca,
certifica redacciones que ya no coinciden con el banco o no puede consultar
el RAG.
"""

from __future__ import annotations

import compileall
import hashlib
import os
import py_compile
import subprocess
import sys
import zipfile

AQUI = os.path.dirname(os.path.abspath(__file__))
AWS = os.path.dirname(AQUI)
ROOT = os.path.dirname(AWS)

FUENTE = os.path.join(AWS, "lambda_function.py")
# Los tres archivos que `lambda_function.py` necesita para arrancar: se
# empaquetan juntos, en la raíz del ZIP.
FUENTES = [
    FUENTE,
    os.path.join(AWS, "guided_composer.py"),
    os.path.join(AWS, "question_bank.json"),
    os.path.join(AWS, "rag_consulta.py"),
    os.path.join(AWS, "rag_equivalencias.py"),
    os.path.join(AWS, "rag_revision.py"),
    os.path.join(AWS, "catalogo_senas.json"),
    # Léxico LSB (M1–M4, diccionarios y catálogo) de tool/build_lexico_lsb.py.
    os.path.join(AWS, "lexico_lsb.json"),
    # Glosa → rol y forma en español (tool/sync_vocabulary.dart).
    os.path.join(AWS, "gloss_lexicon.py"),
    os.path.join(AWS, "rag_zonas.py"),
    os.path.join(AWS, "zonas_senas.json"),
]
# (origen, nombre dentro del ZIP) de archivos que viven fuera de aws/.
EXTRAS = [
    (os.path.join(ROOT, "assets", "rag", "escenarios_cbba.json"),
     "rag_escenarios_cbba.json"),
]
DESTINO = os.path.join(AQUI, "lambda_function.zip")


def comprobar_sintaxis() -> None:
    for archivo in FUENTES + [origen for origen, _ in EXTRAS]:
        if archivo.endswith(".py"):
            py_compile.compile(archivo, doraise=True)
        elif not os.path.exists(archivo):
            raise SystemExit(f"Falta {archivo}: no se empaqueta.")
    print("sintaxis: ok")


def ejecutar_pruebas() -> None:
    print("ejecutando la suite del backend…")
    r = subprocess.run(
        [sys.executable, "-m", "unittest", "discover", "-s",
         os.path.join("aws", "tests")],
        cwd=ROOT, capture_output=True, text=True,
    )
    ultima = [l for l in (r.stderr or "").strip().split("\n") if l.strip()]
    print("  " + (ultima[-1] if ultima else "sin salida"))
    if r.returncode != 0:
        raise SystemExit("La suite del backend falla: no se empaqueta.")


def version_declarada() -> tuple:
    """Lee las versiones que el módulo anuncia, sin importarlo."""
    contrato = generador = None
    with open(FUENTE, encoding="utf-8") as f:
        for linea in f:
            if linea.startswith("BACKEND_CONTRACT_VERSION"):
                contrato = int(linea.split("=")[1].strip())
            elif linea.startswith("GENERATOR_VERSION"):
                generador = int(linea.split("=")[1].strip())
    if contrato is None or generador is None:
        raise SystemExit("Faltan BACKEND_CONTRACT_VERSION o GENERATOR_VERSION.")
    return contrato, generador


def empaquetar() -> str:
    if os.path.exists(DESTINO):
        os.remove(DESTINO)
    # Sin dependencias externas: `boto3` lo provee el entorno de Lambda.
    with zipfile.ZipFile(DESTINO, "w", zipfile.ZIP_DEFLATED) as z:
        for archivo in FUENTES:
            z.write(archivo, arcname=os.path.basename(archivo))
        for origen, nombre in EXTRAS:
            z.write(origen, arcname=nombre)
    with open(DESTINO, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def main() -> None:
    comprobar_sintaxis()
    compileall.compile_file(FUENTE, quiet=1)
    for modulo in ("guided_composer.py", "rag_consulta.py",
                   "rag_equivalencias.py", "rag_revision.py",
                   "rag_zonas.py"):
        compileall.compile_file(os.path.join(AWS, modulo), quiet=1)
    ejecutar_pruebas()

    contrato, generador = version_declarada()
    sha = empaquetar()

    print()
    print(f"contractVersion   : {contrato}")
    print(f"generatorVersion  : {generador}")
    print(f"paquete           : {os.path.relpath(DESTINO, ROOT)}")
    print(f"tamaño            : {os.path.getsize(DESTINO) / 1024:.0f} KB")
    print(f"SHA-256           : {sha}")
    print()
    print("Listo para desplegar. El procedimiento está en aws/deploy/README.md;")
    print("este script NO sube nada.")


if __name__ == "__main__":
    main()
