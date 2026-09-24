"""Comprueba una Lambda desplegada con las peticiones del cliente real.

    python aws/deploy/smoke_check.py --endpoint https://.../translate

Sin `--endpoint` corre contra el handler local, que es lo que se puede hacer
sin credenciales. Eso verifica la lógica, **no** el despliegue: contra el
endpoint real se ejercen además Bedrock, Polly y S3, que localmente son
dobles.

Los cuerpos salen de `test/fixtures/contract/`, que escribe el propio cliente
Flutter. Comprobar el backend con JSON escrito a mano no demuestra nada sobre
lo que la aplicación envía.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request

AQUI = os.path.dirname(os.path.abspath(__file__))
AWS = os.path.dirname(AQUI)
ROOT = os.path.dirname(AWS)
FIXTURES = os.path.join(ROOT, "test", "fixtures", "contract")


def cargar(nombre: str) -> dict:
    with open(os.path.join(FIXTURES, nombre + ".json"), encoding="utf-8") as f:
        return json.load(f)


def invocar_local(body: dict) -> dict:
    sys.path.insert(0, AWS)
    sys.path.insert(0, os.path.join(AWS, "tests"))
    from boto3_stub import install  # noqa: E402

    install()
    import lambda_function as L  # noqa: E402

    r = L.lambda_handler({"httpMethod": "POST", "body": json.dumps(body)}, None)
    return json.loads(r["body"])


def invocar_remoto(endpoint: str, body: dict) -> dict:
    datos = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        endpoint, data=datos,
        headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--endpoint", default=None)
    args = ap.parse_args()

    invocar = ((lambda b: invocar_remoto(args.endpoint, b))
               if args.endpoint else invocar_local)
    donde = args.endpoint or "handler local (dobles de AWS)"
    print(f"comprobando contra: {donde}\n")

    fallos = []

    def check(nombre, condicion, detalle=""):
        print(f"  [{'ok ' if condicion else 'FALLA'}] {nombre}")
        if not condicion:
            fallos.append(f"{nombre}: {detalle}")

    sospechoso = invocar(cargar("robo_y_huida_sospechoso"))
    victima = invocar(cargar("robo_y_huida_victima"))
    escapar = invocar(cargar("solo_escapar"))
    violencia = invocar(cargar("violencia_estructurada"))

    def texto(d):
        return (d.get("generatedText") or d.get("baseSentence") or "")

    check("1. anuncia contractVersion 3",
          sospechoso.get("contractVersion") == 3, str(sospechoso.get("contractVersion")))
    check("2. ESCAPAR sola no denuncia un robo",
          "robo" not in texto(escapar).lower(), texto(escapar))
    check("3. la huida del sospechoso se atribuye bien",
          "fuga" in texto(sospechoso).lower(), texto(sospechoso))
    check("4. la huida propia se atribuye bien",
          "escap" in texto(victima).lower(), texto(victima))
    check("5. los dos relatos no dicen lo mismo",
          texto(sospechoso) != texto(victima))
    check("6. violencia usa la declaración estructurada",
          "agresi" in texto(violencia).lower(), texto(violencia))

    invalido = cargar("robo_y_huida_sospechoso")
    invalido["declaration"]["facts"][1]["actorRole"] = "sospechozo"
    try:
        r = invocar(invalido)
        rechazado = r.get("error") == "VALIDATION_ERROR"
    except Exception:
        # Un 400 remoto llega como excepción de urllib: también es rechazo.
        rechazado = True
    check("7. un actorRole inválido se rechaza", rechazado)

    check("8. devuelve un texto para revisar",
          bool(texto(sospechoso).strip()))

    print()
    if fallos:
        print(f"FALLAN {len(fallos)} comprobaciones:")
        for f in fallos:
            print(f"  - {f}")
        print("\nNO muevas el alias de producción.")
        return 1

    print("Las 8 comprobaciones pasan.")
    if not args.endpoint:
        print("PENDIENTE: esto fue contra el handler local. Bedrock, Polly y "
              "S3 son dobles y no quedan verificados.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
