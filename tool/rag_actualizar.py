"""Actualiza el corpus RAG tras añadir o editar escenarios.

    python tool/rag_actualizar.py

1. Valida todos los `docs/negocio/rag/escenarios/*.md` y genera el corpus.
2. Si hay tarjetas del usuario sordo sin glosas, las traduce con la Lambda
   Texto→LSB (`LSB_TEXT_API_URL` de `.env`); solo las que faltan.
3. Vuelve a generar el corpus con esas glosas y comprueba que quedó al día.

Si el paso 1 encuentra errores, se detiene sin tocar nada.
"""

from __future__ import annotations

import os
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(AQUI)


def paso(*args: str) -> int:
    return subprocess.run([sys.executable, *args], cwd=ROOT).returncode


def main() -> int:
    constructor = os.path.join(AQUI, "build_rag_corpus.py")
    if paso(constructor) != 0:
        print("Corrige los errores del corpus y vuelve a ejecutar.")
        return 1
    if paso(os.path.join(AQUI, "rag_precalcular_glosas.py")) != 0:
        print("Algunas frases no se tradujeron; vuelve a ejecutar para reintentar.")
        return 1
    if paso(constructor) != 0:
        return 1
    return paso(constructor, "--check")


if __name__ == "__main__":
    raise SystemExit(main())
