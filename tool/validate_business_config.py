"""Valida las configuraciones propuestas contra las fuentes del repositorio.

    python tool/validate_business_config.py

Comprueba, y falla con código 1 si algo no cuadra:

  1. Los IDs de intención marcados `origen: "grafo"` existen en
     `assets/dialogue/dialogue_graph.json`.
  2. Los marcados `origen: "propuesta_sin_cobertura"` NO existen (si alguno
     existiera, está mal clasificado y la brecha sería falsa).
  3. Cada brecha léxica declarada es realmente una ausencia del catálogo.
  4. Los ámbitos iniciales de cada perfil existen en `context_catalog.dart`.
  5. No hay perfiles ni intenciones duplicados dentro de un perfil.
  6. Las necesidades referenciadas existen.
  7. La matriz de aceptación referencia perfiles y necesidades que existen.

Emite además un informe de cobertura real por intención: cuántos nodos la
sirven y cuántas de sus opciones son ofrecibles con el catálogo actual.

No ejecuta la aplicación ni las Lambdas: valida datos, que es lo que esta
fase produce.
"""

from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import corpus_dialogue as C  # noqa: E402

NEGOCIO = os.path.join(C.ROOT, "docs", "negocio")
PERFILES = os.path.join(NEGOCIO, "config", "perfiles_institucionales.json")
ACEPTACION = os.path.join(NEGOCIO, "config", "matriz_aceptacion.json")
GRAPH = os.path.join(C.ROOT, "assets", "dialogue", "dialogue_graph.json")
CATALOGO_DART = os.path.join(
    C.ROOT, "lib", "core", "domain", "services", "context_catalog.dart")

INFORME = os.path.join(NEGOCIO, "02_Perfiles_Institucionales_cobertura.md")


def contextos_del_catalogo() -> set:
    """Los contextos realmente seleccionables, leídos del catálogo Dart.

    Se leen del código y no de una lista escrita a mano para que la propuesta
    no pueda referirse a un contexto que ya no exista —como 'tramite' y
    'consulta', que el enrutador menciona pero el catálogo no ofrece.
    """
    src = open(CATALOGO_DART, encoding="utf-8").read()
    ids = set()
    # Contextos declarados en el nivel superior del archivo.
    for m in re.finditer(r"SemanticContext\(\s*\n\s*id:\s*'([a-z_]+)'", src):
        ids.add(m.group(1))
    return ids


def main() -> int:
    errores, avisos = [], []

    perfiles_doc = json.load(open(PERFILES, encoding="utf-8"))
    graph = json.load(open(GRAPH, encoding="utf-8"))
    resolver = C.ConceptResolver()

    intenciones_grafo = set(graph["intents"].keys())
    nodos_por_intencion = graph["intents"]
    contextos = contextos_del_catalogo()
    necesidades = {n["id"] for n in perfiles_doc["necesidades"]}

    vistos = set()
    cobertura = []

    for perfil in perfiles_doc["perfiles"]:
        pid = perfil["id"]
        if pid in vistos:
            errores.append(f"perfil duplicado: {pid}")
        vistos.add(pid)

        for n in perfil["necesidadesPrioritarias"]:
            if n not in necesidades:
                errores.append(f"{pid}: necesidad inexistente '{n}'")

        for a in perfil["ambitosIniciales"]:
            if a not in contextos:
                errores.append(
                    f"{pid}: ámbito inicial '{a}' no existe en "
                    f"context_catalog.dart (existen: {sorted(contextos)})")

        ids_intencion = set()
        for it in perfil["intencionesPropuestas"]:
            iid = it["id"]
            if iid in ids_intencion:
                errores.append(f"{pid}: intención duplicada '{iid}'")
            ids_intencion.add(iid)

            if it["necesidad"] not in necesidades:
                errores.append(
                    f"{pid}/{iid}: necesidad inexistente '{it['necesidad']}'")

            if it["origen"] == "grafo":
                if iid not in intenciones_grafo:
                    errores.append(
                        f"{pid}/{iid}: marcada como del grafo pero no existe "
                        "en dialogue_graph.json")
                else:
                    nodos = nodos_por_intencion[iid]
                    ofrecibles = _ofrecibles(graph, nodos)
                    cobertura.append({
                        "perfil": pid, "intencion": iid,
                        "necesidad": it["necesidad"],
                        "nodos": len(nodos), "glosas": len(ofrecibles),
                        "estado": "cubierta" if ofrecibles else "sin opciones",
                    })
            elif it["origen"] == "propuesta_sin_cobertura":
                if iid in intenciones_grafo:
                    errores.append(
                        f"{pid}/{iid}: declarada sin cobertura pero sí existe "
                        "en el grafo; la brecha es falsa")
                for concepto in it.get("brechaLexica", []):
                    if C.norm(concepto) in resolver.app:
                        errores.append(
                            f"{pid}/{iid}: '{concepto}' se declara brecha "
                            "pero sí está en el catálogo")
                cobertura.append({
                    "perfil": pid, "intencion": iid,
                    "necesidad": it["necesidad"],
                    "nodos": 0, "glosas": 0,
                    "estado": "sin cobertura — brecha: "
                              + ", ".join(it.get("brechaLexica", []) or ["—"]),
                })
            else:
                errores.append(f"{pid}/{iid}: origen desconocido "
                               f"'{it['origen']}'")

        if not ids_intencion:
            avisos.append(f"{pid}: sin intenciones propuestas")

    # Matriz de aceptación, si ya existe.
    if os.path.exists(ACEPTACION):
        casos = json.load(open(ACEPTACION, encoding="utf-8"))
        ids_caso = set()
        for caso in casos["casos"]:
            if caso["id"] in ids_caso:
                errores.append(f"caso duplicado: {caso['id']}")
            ids_caso.add(caso["id"])
            perfil = caso.get("institucion")
            if perfil and perfil not in vistos:
                errores.append(
                    f"{caso['id']}: institución '{perfil}' sin perfil")
            necesidad = caso.get("necesidad")
            if necesidad and necesidad not in necesidades:
                errores.append(
                    f"{caso['id']}: necesidad '{necesidad}' inexistente")
            if caso.get("modo") not in ("personal", "ventanilla", None):
                errores.append(f"{caso['id']}: modo inválido "
                               f"'{caso.get('modo')}'")
            for g in caso.get("prohibido", {}).get("glosas", []):
                # Prohibir una glosa que no existe no prueba nada.
                if C.norm(g) not in resolver.app:
                    avisos.append(
                        f"{caso['id']}: prohíbe '{g}', que no está en el "
                        "catálogo (la prohibición es trivialmente cierta)")
        print(f"casos de aceptación: {len(casos['casos'])}")

    _escribir_informe(cobertura)

    print(f"perfiles: {len(perfiles_doc['perfiles'])}")
    print(f"intenciones verificadas: {len(cobertura)}")
    print(f"  con cobertura en el grafo: "
          f"{sum(1 for c in cobertura if c['estado'] == 'cubierta')}")
    print(f"  sin cobertura declarada: "
          f"{sum(1 for c in cobertura if c['estado'].startswith('sin cobertura'))}")

    for a in avisos:
        print(f"AVISO  {a}")
    for e in errores:
        print(f"ERROR  {e}")
    return 1 if errores else 0


def _ofrecibles(graph, nodos_ids) -> set:
    ids = set(nodos_ids)
    out = set()
    for n in graph["nodes"]:
        if n["id"] not in ids:
            continue
        for o in n.get("options", []):
            if o.get("gloss"):
                out.add(o["gloss"])
    return out


def _escribir_informe(cobertura):
    L = [
        "# Cobertura real por intención de los perfiles propuestos",
        "",
        "Generado por `tool/validate_business_config.py`. No editar a mano.",
        "",
        "«Cubierta» significa que la intención tiene nodos en el grafo y que "
        "esos nodos ofrecen glosas del catálogo actual. **No** significa que "
        "la composición esté validada lingüísticamente ni que el servicio "
        "institucional esté cubierto por completo.",
        "",
        "| Perfil | Intención | Necesidad | Nodos | Glosas ofrecibles | Estado |",
        "|---|---|---|---:|---:|---|",
    ]
    for c in sorted(cobertura, key=lambda x: (x["perfil"], x["intencion"])):
        L.append(f"| `{c['perfil']}` | `{c['intencion']}` | {c['necesidad']} "
                 f"| {c['nodos']} | {c['glosas']} | {c['estado']} |")
    L.append("")
    with open(INFORME, "w", encoding="utf-8") as f:
        f.write("\n".join(L))


if __name__ == "__main__":
    raise SystemExit(main())
