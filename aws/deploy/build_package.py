"""Construye el paquete de despliegue de `lambda_function.py`.

    python aws/deploy/build_package.py

No sube nada. Escribe `aws/deploy/lambda_function.zip` y su SHA-256, y antes
comprueba que el archivo compile y que la suite local pase: empaquetar algo
que no pasa sus propias pruebas es empaquetar un problema.
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
DESTINO = os.path.join(AQUI, "lambda_function.zip")


def comprobar_sintaxis() -> None:
    py_compile.compile(FUENTE, doraise=True)
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
        z.write(FUENTE, arcname="lambda_function.py")
    with open(DESTINO, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def main() -> None:
    comprobar_sintaxis()
    compileall.compile_file(FUENTE, quiet=1)
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
