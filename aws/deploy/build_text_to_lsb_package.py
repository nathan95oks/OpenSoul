"""ZIP de la Lambda Texto→LSB (`lambda_text_to_lsb.py`).

    python aws/deploy/build_text_to_lsb_package.py

Escribe `aws/deploy/lambda_text_to_lsb.zip` (ignorado por git): el handler
como `lambda_function.py` (y una copia con su nombre) y `formas_verbales.json`,
la tabla de formas conjugadas que la Lambda lee junto al código. Controlador:
`lambda_function.lambda_handler`. Sin este JSON la Lambda solo conoce un puñado
de formas («va», «tiene»…), no todas.
"""

import os
import zipfile

AQUI = os.path.dirname(os.path.abspath(__file__))
AWS = os.path.dirname(AQUI)
SALIDA = os.path.join(AQUI, "lambda_text_to_lsb.zip")


def main() -> None:
    codigo = open(os.path.join(AWS, "lambda_text_to_lsb.py"), "rb").read()
    formas = open(os.path.join(AWS, "formas_verbales.json"), "rb").read()
    with zipfile.ZipFile(SALIDA, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("lambda_function.py", codigo)
        z.writestr("lambda_text_to_lsb.py", codigo)
        z.writestr("formas_verbales.json", formas)
    with zipfile.ZipFile(SALIDA) as z:
        for i in z.infolist():
            print(f"{i.filename:28} {i.file_size:>8}")
    print("escrito:", os.path.relpath(SALIDA, os.path.dirname(AWS)))


if __name__ == "__main__":
    main()
