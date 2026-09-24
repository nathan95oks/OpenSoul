"""Renderiza los documentos revisables desde las configuraciones JSON.

    python tool/build_business_docs.py

Escribe `02_Perfiles_Institucionales.md` y `06_Matriz_Aceptacion.md` desde
`config/perfiles_institucionales.json` y `config/matriz_aceptacion.json`, para
que el documento y el dato no se separen. La cobertura por intención la
calcula `tool/validate_business_config.py`, que debe ejecutarse antes.
"""

from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import corpus_dialogue as C  # noqa: E402

NEGOCIO = os.path.join(C.ROOT, "docs", "negocio")
PERFILES = os.path.join(NEGOCIO, "config", "perfiles_institucionales.json")
ACEPTACION = os.path.join(NEGOCIO, "config", "matriz_aceptacion.json")


def perfiles_md():
    doc = json.load(open(PERFILES, encoding="utf-8"))
    L = [
        "# Perfiles institucionales propuestos",
        "",
        "Generado por `tool/build_business_docs.py` desde "
        "`config/perfiles_institucionales.json`. No editar a mano.",
        "",
        "**Incluir un perfil no demuestra cobertura lingüística de sus "
        "servicios.** La cobertura real por intención está en "
        "`02_Perfiles_Institucionales_cobertura.md`, calculada contra el grafo "
        "y el catálogo.",
        "",
        "## Las tres necesidades",
        "",
        "| Necesidad | Etiqueta | Parte de |",
        "|---|---|---|",
    ]
    for n in doc["necesidades"]:
        L.append(f"| `{n['id']}` | {n['etiqueta']} | {n['puntoDePartida']} |")

    L += [
        "",
        "Las tres **no** son grupos exclusivos de instituciones: se puede "
        "consultar en DDRR, preguntar por un documento en la Policía o pedir "
        "orientación sobre una denuncia.",
        "",
        "## Perfiles",
        "",
    ]

    for p in doc["perfiles"]:
        con_cobertura = [i for i in p["intencionesPropuestas"]
                         if i["origen"] == "grafo"]
        sin_cobertura = [i for i in p["intencionesPropuestas"]
                         if i["origen"] != "grafo"]
        L += [
            f"### `{p['id']}` — {p['nombre']}",
            "",
        ]
        if p.get("denominacionLarga"):
            L.append(f"- **Denominación**: {p['denominacionLarga']}")
        L += [
            f"- **Fuente de la denominación**: {p['fuenteDenominacion']}",
            f"- **Tipo de servicio**: `{p['tipoServicio']}`",
            f"- **Necesidades prioritarias**: "
            + ", ".join(f"`{n}`" for n in p["necesidadesPrioritarias"]),
            f"- **Ámbitos iniciales**: "
            + ", ".join(f"`{a}`" for a in p["ambitosIniciales"]),
        ]
        if p.get("unidades"):
            L.append("- **Unidades**: " + ", ".join(
                f"`{u['id']}` ({u['nombre']})" for u in p["unidades"]))
        L += [
            f"- **Regla de organización**: {p['reglaOrganizacion']}",
            "",
            f"**Intenciones con cobertura ({len(con_cobertura)})**: "
            + (", ".join(f"`{i['id']}`" for i in con_cobertura) or "ninguna"),
            "",
        ]
        if sin_cobertura:
            L += [
                f"**Intenciones propuestas sin cobertura ({len(sin_cobertura)})**",
                "",
                "| Intención | Necesidad | Brecha léxica |",
                "|---|---|---|",
            ]
            for i in sin_cobertura:
                L.append(
                    f"| `{i['id']}` | {i['necesidad']} | "
                    + ", ".join(f"`{b}`" for b in i.get("brechaLexica", []))
                    + " |")
            L.append("")

    L += [
        "## Ampliación de alcance",
        "",
        "El corpus maestro cubre la **etapa preliminar judicial**. Los "
        "perfiles registral (Derechos Reales), notarial y municipal (GAMC) "
        "amplían ese alcance sin corpus que los respalde: sus intenciones "
        "propias figuran arriba como «sin cobertura», con la brecha léxica "
        "concreta.",
        "",
        "Efectos a registrar en el proyecto de grado: objetivos, alcances, "
        "límites, corpus y evaluación. La decisión de incluir un perfil es una "
        "decisión de producto, no una demostración de cobertura.",
        "",
    ]
    return "\n".join(L)


def aceptacion_md():
    doc = json.load(open(ACEPTACION, encoding="utf-8"))
    casos = doc["casos"]
    conf = [c for c in casos if c["comprobacion"] == "configuracion"]
    iface = [c for c in casos if c["comprobacion"] == "interfaz_pendiente"]

    L = [
        "# Matriz de aceptación",
        "",
        "Generado por `tool/build_business_docs.py` desde "
        "`config/matriz_aceptacion.json`. No editar a mano.",
        "",
        "Se separan dos cosas que no deben mezclarse:",
        "",
        f"- **Comprobable sobre las configuraciones de esta fase** ({len(conf)} "
        "casos): se verifica con `tool/validate_business_config.py` y con los "
        "datos generados.",
        f"- **Pendiente de prueba de interfaz** ({len(iface)} casos): exige "
        "código que todavía no existe. **Ninguno está aprobado.**",
        "",
        "## Resumen",
        "",
        "| Caso | Título | Modo | Institución | Comprobación |",
        "|---|---|---|---|---|",
    ]
    for c in casos:
        L.append(
            f"| `{c['id']}` | {c['titulo']} | {c.get('modo') or '—'} | "
            f"`{c.get('institucion') or '—'}` | {c['comprobacion']} |")

    L += ["", "## Detalle", ""]
    for c in casos:
        L += [
            f"### `{c['id']}` — {c['titulo']}",
            "",
            f"- **Entrada**: {c['entrada']}",
            f"- **Modo**: {c.get('modo') or 'cualquiera'}",
            f"- **Institución**: `{c.get('institucion') or '—'}`",
            f"- **Necesidad**: `{c.get('necesidad') or '—'}`",
        ]
        if c.get("intencion"):
            L.append(f"- **Intención**: `{c['intencion']}`")
        L.append("- **Salida esperada**:")
        for e in c["esperado"]:
            L.append(f"  - {e}")
        proh = c.get("prohibido", {})
        if proh.get("glosas"):
            L.append("- **Glosas prohibidas entre las primeras opciones**: "
                     + ", ".join(f"`{g}`" for g in proh["glosas"]))
        if proh.get("comportamientos"):
            L.append("- **Contenido y comportamiento prohibidos**:")
            for b in proh["comportamientos"]:
                L.append(f"  - {b}")
        L += [f"- **Comprobación**: {c['comprobacion']}", ""]

    return "\n".join(L)


def main():
    with open(os.path.join(NEGOCIO, "02_Perfiles_Institucionales.md"), "w",
              encoding="utf-8") as f:
        f.write(perfiles_md())
    with open(os.path.join(NEGOCIO, "06_Matriz_Aceptacion.md"), "w",
              encoding="utf-8") as f:
        f.write(aceptacion_md())
    print("escrito: 02_Perfiles_Institucionales.md, 06_Matriz_Aceptacion.md")


if __name__ == "__main__":
    main()
