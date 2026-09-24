"""Lleva las configuraciones de negocio al asset que empaqueta la app.

    python tool/build_business_assets.py

Fuente única: `docs/negocio/config/perfiles_institucionales.json`. Los perfiles
se editan ahí y **nunca** en `assets/`, que es una copia generada.

Antes de escribir nada se ejecuta `tool/validate_business_config.py`: si una
intención no existe en el grafo, si una brecha declarada sí está en el
catálogo o si un ámbito no existe en `context_catalog.dart`, no se genera el
asset. Publicar una configuración que el repositorio contradice es peor que
no publicarla.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import corpus_dialogue as C  # noqa: E402
import validate_business_config as V  # noqa: E402

ORIGEN = os.path.join(C.ROOT, "docs", "negocio", "config",
                      "perfiles_institucionales.json")
DESTINO = os.path.join(C.ROOT, "assets", "business", "institution_profiles.json")


def build() -> dict:
    doc = json.load(open(ORIGEN, encoding="utf-8"))

    # El asset lleva solo lo que la aplicación necesita en tiempo de
    # ejecución. Las notas de procedencia y de verificación se quedan en la
    # documentación: no cambian el comportamiento y abultan el paquete.
    perfiles = []
    for p in doc["perfiles"]:
        con_cobertura = [i["id"] for i in p["intencionesPropuestas"]
                         if i["origen"] == "grafo"]
        sin_cobertura = [
            {"id": i["id"], "necesidad": i["necesidad"],
             "brechaLexica": i.get("brechaLexica", [])}
            for i in p["intencionesPropuestas"] if i["origen"] != "grafo"
        ]
        perfiles.append({
            "id": p["id"],
            "nombre": p["nombre"],
            "tipoServicio": p["tipoServicio"],
            "necesidadesPrioritarias": p["necesidadesPrioritarias"],
            "ambitosIniciales": p["ambitosIniciales"],
            "intenciones": [
                {"id": i["id"], "necesidad": i["necesidad"]}
                for i in p["intencionesPropuestas"] if i["origen"] == "grafo"
            ],
            # Viaja para poder DECIRLO en la interfaz, no para ocultarlo: una
            # intención sin cobertura se ofrece explicando qué falta.
            "intencionesSinCobertura": sin_cobertura,
            "unidades": [
                {"id": u["id"], "nombre": u["nombre"]}
                for u in p.get("unidades", [])
            ],
            "cobertura": {
                "conCobertura": len(con_cobertura),
                "sinCobertura": len(sin_cobertura),
            },
        })

    return {
        "version": doc["version"],
        "necesidades": [
            {"id": n["id"], "etiqueta": n["etiqueta"],
             "descripcion": n["descripcion"], "puntoDePartida": n["puntoDePartida"]}
            for n in doc["necesidades"]
        ],
        "perfiles": perfiles,
    }


def main():
    codigo = V.main()
    if codigo != 0:
        print("La configuración no valida: no se genera el asset.")
        raise SystemExit(codigo)

    asset = build()
    os.makedirs(os.path.dirname(DESTINO), exist_ok=True)
    with open(DESTINO, "w", encoding="utf-8") as f:
        json.dump(asset, f, ensure_ascii=False, indent=1)
        f.write("\n")

    print(f"perfiles en el asset: {len(asset['perfiles'])}")
    print(f"necesidades: {len(asset['necesidades'])}")
    print(f"escrito: {os.path.relpath(DESTINO, C.ROOT)}")


if __name__ == "__main__":
    main()
