"""Genera el banco de intenciones y recorridos desde el grafo de diálogo.

    python tool/build_intent_bank.py

Escribe `docs/negocio/03_Banco_Intenciones_Recorridos.md` y su gemelo
procesable `docs/negocio/banco_intenciones.json`.

Distingue dos cosas que el encargo pide no confundir:

  representar la pregunta   el enunciado del oyente pasa a LSB para el avatar
  ofrecer respuestas a ella las tarjetas con que la persona sorda contesta

Un nodo de la sección 6 sirve a lo segundo: su enunciado es la entrada, y sus
opciones son la respuesta. Que exista el nodo no implica que la pregunta tenga
representación en señas; eso lo dice la cobertura de sus propios conceptos.
"""

from __future__ import annotations

import json
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import corpus_dialogue as C  # noqa: E402

OUT_DIR = os.path.join(C.ROOT, "docs", "negocio")
GRAPH = os.path.join(C.ROOT, "assets", "dialogue", "dialogue_graph.json")
PERFILES = os.path.join(OUT_DIR, "config", "perfiles_institucionales.json")

# Ámbito del grafo → necesidades del modo personal. Igual que en la matriz de
# vocabulario: se declara una vez y se reutiliza.
NECESIDAD_POR_AMBITO = {
    "denuncia_robo": ["denuncias"],
    "violencia": ["denuncias"],
    "amenaza_digital": ["denuncias"],
    "engano_dinero": ["denuncias"],
    "seguimiento": ["tramites", "consultas"],
    "identificacion": ["denuncias", "tramites", "consultas"],
    "preguntas": ["denuncias", "tramites", "consultas"],
    "otro": ["denuncias", "tramites", "consultas"],
}

PROPOSITO_POR_MODO = {
    "A": "independiente",
    "B": "inicio_conversacion",
    "C": "respuesta",
}


def build():
    graph = json.load(open(GRAPH, encoding="utf-8"))
    perfiles = json.load(open(PERFILES, encoding="utf-8"))

    perfiles_por_intencion = defaultdict(list)
    for p in perfiles["perfiles"]:
        for it in p["intencionesPropuestas"]:
            perfiles_por_intencion[it["id"]].append(p["id"])

    nodos = {n["id"]: n for n in graph["nodes"]}
    por_intencion = defaultdict(list)
    for n in graph["nodes"]:
        por_intencion[n["intent"]].append(n)

    bank = []
    for intent, ns in sorted(por_intencion.items()):
        ambitos = sorted({n["scope"] for n in ns})
        necesidades = sorted({
            need for a in ambitos for need in NECESIDAD_POR_AMBITO.get(a, [])})
        propositos = sorted({
            PROPOSITO_POR_MODO[m] for n in ns for m in n["modes"]})
        campos = sorted({s for n in ns for s in n["slots"]})
        actos = sorted({n["speechAct"] for n in ns})
        secciones = sorted({n["provenance"]["section"] for n in ns})

        tarjetas, pendientes = {}, {}
        for n in ns:
            for o in n["options"]:
                if o.get("gloss"):
                    tarjetas[o["gloss"]] = o["coverage"]
            for p in n.get("pendingOptions", []):
                pendientes[p["concept"]] = p["reason"]

        # Continuación: a qué otras intenciones se puede pasar.
        siguientes = set()
        for n in ns:
            for t in n.get("transitions", []):
                destino = nodos.get(t["to"])
                if destino and destino["intent"] != intent:
                    siguientes.add(destino["intent"])

        # Aclaración necesaria: cuando la intención tiene nodos con actos
        # distintos, o conceptos pendientes, hace falta preguntar antes de
        # asumir qué se está haciendo.
        aclaraciones = []
        if len(actos) > 1:
            aclaraciones.append(
                "La misma intención aparece como pregunta y como declaración: "
                "confirmar el acto antes de redactar.")
        if pendientes:
            aclaraciones.append(
                "Conceptos sin cobertura en esta intención: "
                + ", ".join(sorted(pendientes)) + ".")
        if "polarity" in campos and len(campos) > 1:
            aclaraciones.append(
                "Admite respuesta cerrada y detalle: el detalle solo se pide "
                "si la persona lo elige, no por omisión.")

        bank.append({
            "intencion": intent,
            "nodos": [n["id"] for n in ns],
            "secciones": secciones,
            "ambitos": ambitos,
            "necesidades": necesidades,
            "propositos": propositos,
            "actos": actos,
            "camposRequeridos": campos,
            "condicionEntrada": {
                "enunciados": [n["provenance"]["spanish"] for n in ns][:6],
                "palabrasClave": sorted({
                    k for n in ns for k in n["entry"]["keywords"]})[:16],
            },
            "tarjetasValidas": sorted(tarjetas),
            "conceptosPendientes": pendientes,
            "aclaraciones": aclaraciones,
            "transicionesAIntenciones": sorted(siguientes)[:10],
            "condicionFinalizacion": (
                "Todos los campos requeridos tienen valor, o la persona elige "
                "finalizar. Un campo sin responder no equivale a una negación."),
            "perfilesQueLaPriorizan": sorted(perfiles_por_intencion.get(intent, [])),
            "representacionDeLaPregunta": (
                "sujeta a la cobertura de sus propios conceptos; tener nodo NO "
                "implica que el enunciado tenga señas"),
        })
    return bank


def write(bank):
    with open(os.path.join(OUT_DIR, "banco_intenciones.json"), "w",
              encoding="utf-8") as f:
        json.dump({"version": 1, "intenciones": bank}, f,
                  ensure_ascii=False, indent=1)
        f.write("\n")

    sin_perfil = [b for b in bank if not b["perfilesQueLaPriorizan"]]
    con_pendientes = [b for b in bank if b["conceptosPendientes"]]

    L = [
        "# Banco de intenciones y recorridos",
        "",
        "Generado por `tool/build_intent_bank.py` desde "
        "`assets/dialogue/dialogue_graph.json` y "
        "`config/perfiles_institucionales.json`. No editar a mano.",
        "",
        "**Representar la pregunta no es ofrecer respuestas a ella.** Un nodo "
        "de la sección 6 sirve para que la persona sorda conteste: su "
        "enunciado es la entrada y sus opciones son la respuesta. Que exista "
        "el nodo no demuestra que la pregunta del funcionario tenga "
        "representación en señas.",
        "",
        "Los 209 ejemplos del corpus son **referencias**, no un límite de "
        "mensajes ni prueba de que todo el grafo sea alcanzable desde la "
        "interfaz.",
        "",
        "## Resumen",
        "",
        "| Indicador | Valor |",
        "|---|---:|",
        f"| Intenciones distintas | {len(bank)} |",
        f"| Intenciones sin perfil que las priorice | {len(sin_perfil)} |",
        f"| Intenciones con conceptos pendientes | {len(con_pendientes)} |",
        "",
        "## Intenciones",
        "",
    ]

    for b in bank:
        L += [
            f"### `{b['intencion']}`",
            "",
            f"- **Procedencia**: secciones {', '.join(str(s) for s in b['secciones'])} "
            f"del corpus · {len(b['nodos'])} nodo(s)",
            f"- **Ámbitos**: {', '.join(b['ambitos'])}",
            f"- **Necesidades**: {', '.join(b['necesidades'])}",
            f"- **Propósitos en que se activa**: {', '.join(b['propositos'])}",
            f"- **Actos comunicativos**: {', '.join(b['actos'])}",
            f"- **Datos requeridos**: {', '.join(b['camposRequeridos'])}",
            f"- **Tarjetas válidas** ({len(b['tarjetasValidas'])}): "
            + (", ".join(f"`{g}`" for g in b["tarjetasValidas"]) or "—"),
        ]
        if b["conceptosPendientes"]:
            L.append("- **Conceptos pendientes**: "
                     + ", ".join(f"`{k}`" for k in sorted(b["conceptosPendientes"])))
        if b["aclaraciones"]:
            L.append("- **Aclaraciones necesarias**:")
            for a in b["aclaraciones"]:
                L.append(f"  - {a}")
        L += [
            f"- **Transiciones**: "
            + (", ".join(f"`{i}`" for i in b["transicionesAIntenciones"]) or "—"),
            f"- **Perfiles que la priorizan**: "
            + (", ".join(f"`{p}`" for p in b["perfilesQueLaPriorizan"]) or "ninguno"),
            f"- **Finaliza cuando**: {b['condicionFinalizacion']}",
            "- **Enunciados de entrada**:",
        ]
        for e in b["condicionEntrada"]["enunciados"]:
            L.append(f"  - {e}")
        L.append("")

    with open(os.path.join(OUT_DIR, "03_Banco_Intenciones_Recorridos.md"), "w",
              encoding="utf-8") as f:
        f.write("\n".join(L))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    bank = build()
    write(bank)
    print(f"intenciones: {len(bank)}")
    print(f"  sin perfil que las priorice: "
          f"{sum(1 for b in bank if not b['perfilesQueLaPriorizan'])}")
    print(f"  con conceptos pendientes: "
          f"{sum(1 for b in bank if b['conceptosPendientes'])}")
    print("escrito: docs/negocio/03_Banco_Intenciones_Recorridos.md, "
          "banco_intenciones.json")


if __name__ == "__main__":
    main()
