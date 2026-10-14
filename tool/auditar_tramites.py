"""Auditoría de los trámites de Conversación (corpus RAG y banco de preguntas).

    python tool/auditar_tramites.py            # imprime el resumen
    python tool/auditar_tramites.py --escribir # y escribe el informe en
                                               # docs/negocio/rag/auditoria_tramites.md

Lee el corpus ya generado (`assets/rag/escenarios_cbba.json`) y el banco de
recorridos (`lib/core/domain/rag/tramites_data.g.dart`) y responde:

* ¿qué escenarios no llegan a ser un recorrido? (ninguna pregunta se ofrece);
* ¿cuáles son poco profundos? (≤ 6 turnos, o sin ramificaciones);
* ¿cuáles se parecen tanto que en la lista se ven como el mismo trámite?
* ¿qué dimensiones de un trámite real cubre cada institución: requisitos,
  documentos faltantes, costos, observaciones, seguimiento, derivación y
  cierre?
* ¿qué hechos documentados ningún turno ejercita, y cuáles no se pueden
  mostrar (sin verificar, vencidos o con vigencia sin confirmar)?

No cambia nada: es solo lectura.
"""

from __future__ import annotations

import collections
import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORPUS = os.path.join(ROOT, "assets", "rag", "escenarios_cbba.json")
TRAMITES = os.path.join(ROOT, "lib", "core", "domain", "rag", "tramites_data.g.dart")
INFORME = os.path.join(ROOT, "docs", "negocio", "rag", "auditoria_tramites.md")

PROFUNDO = 8          # turnos: por debajo, el recorrido es corto

# Qué busca cada dimensión en el texto de un escenario (turnos y variantes).
DIMENSIONES = {
    "requisitos": r"\b(tiene|trae|trajo|requisit|document|cedula|carnet|certificad|formulario|matricula|crpva)\w*",
    "documento faltante": r"\b(no tengo|no traje|no tiene|falta\w*|sin (?:el|la|mi|su))\b",
    "costos": r"\b(cost\w*|arancel\w*|pag\w+|cuota\w*|deposit\w*|boleta|bs|gratuit\w*|gratis)\b",
    "observaciones": r"\b(observ\w*|reingres\w*|correg\w*|corrig\w*|subsan\w*|rectific\w*)\b",
    "seguimiento": r"\b(seguimiento|estado|nurej|webid|numero de (?:caso|tramite)|consultar|constancia)\b",
    "derivación": r"\b(derivar|derivo|no corresponde|oficina equivocada|acuda|vaya a|ir a|llegar a)\b",
    "cierre": r"\b(vuelva|regrese|confirme|anot[oó]|entendi\w*|listo|gracias|por escrito)\b",
}


def _norm(s: str) -> str:
    s = unicodedata.normalize("NFD", s.lower())
    return re.sub(r"\s+", " ", "".join(c for c in s if unicodedata.category(c) != "Mn"))


def cargar() -> tuple:
    corpus = json.load(open(CORPUS, encoding="utf-8"))
    s = open(TRAMITES, encoding="utf-8").read()
    banco = json.loads(s[s.index("r'''") + 4:s.rindex("'''")])
    return corpus, banco


def textos(e: dict) -> str:
    partes = [t["texto"] for t in e["turnos"]]
    for p in e["variantes"]:
        partes += p["preguntas"] + [r["texto"] for r in p["respuestas"]]
    return _norm(" ".join(partes))


def institucion_area(e: dict) -> str:
    return e["id"].split("-")[1]


def similitud(a: str, b: str) -> float:
    ta = {w for w in re.findall(r"[a-zñ]{4,}", _norm(a))}
    tb = {w for w in re.findall(r"[a-zñ]{4,}", _norm(b))}
    return len(ta & tb) / len(ta | tb) if ta | tb else 0.0


def analizar() -> dict:
    corpus, banco = cargar()
    E = corpus["escenarios"]
    H = corpus["hechos"]
    con_ruta = {c["escenario"] for c in banco["contextos"]}
    preguntas_por_esc = collections.Counter(
        p["id"].split(".")[1] for p in banco["preguntas"])
    out = {"total": len(E), "con_recorrido": len(con_ruta)}

    out["sin_recorrido"] = [e["id"] for e in E if e["id"] not in con_ruta]
    out["poco_profundos"] = [
        (e["id"], len(e["turnos"])) for e in E
        if len(e["turnos"]) < PROFUNDO and e["id"] in con_ruta]
    out["sin_ramificaciones"] = [
        e["id"] for e in E if e["id"] in con_ruta and not e.get("ramificaciones")]

    # Parecidos dentro de una institución: mismo tema, uno claramente más
    # profundo que el otro.
    pares = []
    por_area = collections.defaultdict(list)
    for e in E:
        por_area[institucion_area(e)].append(e)
    for area, lista in por_area.items():
        for i, a in enumerate(lista):
            for b in lista[i + 1:]:
                s = similitud(a["tramite"], b["tramite"])
                if s >= 0.5:
                    corto, largo = sorted((a, b), key=lambda x: len(x["turnos"]))
                    pares.append((round(s, 2), corto["id"], largo["id"],
                                  corto["tramite"], largo["tramite"]))
    out["parecidos"] = sorted(pares, reverse=True)

    cubre = collections.defaultdict(lambda: collections.Counter())
    for e in E:
        t = textos(e)
        for dim, rx in DIMENSIONES.items():
            if re.search(rx, t):
                cubre[institucion_area(e)][dim] += 1
        cubre[institucion_area(e)]["escenarios"] += 1
        if e.get("ramificaciones"):
            cubre[institucion_area(e)]["con ramificaciones"] += 1
    out["dimensiones"] = {k: dict(v) for k, v in cubre.items()}

    usados = collections.Counter(
        h for e in E for t in e["turnos"] for h in t.get("hechos", []))
    out["hechos_sin_usar"] = [h for h in H if not usados[h]]
    out["hechos_no_mostrables"] = {
        h: ("sin verificar" if v["verificar"] else
            "vigencia sin confirmar" if v.get("vigenciaSinConfirmar") else
            "vencido" if v.get("vencido") else "")
        for h, v in H.items()
        if v["verificar"] or v.get("vigenciaSinConfirmar") or v.get("vencido")}
    out["preguntas"] = len(banco["preguntas"])
    out["escenarios_por_area"] = dict(collections.Counter(
        institucion_area(e) for e in E))
    out["consolidados"] = {e["id"]: e["consolidadoEn"]
                           for e in E if e.get("consolidadoEn")}
    out["editables"] = [e["id"] for e in E if e.get("datosEditables")]
    return out


def informe(a: dict) -> str:
    L = ["# Auditoría de trámites (Conversación)", "",
         "Generada por `python tool/auditar_tramites.py --escribir`. No se edita a mano.",
         "",
         f"- Escenarios en el corpus: **{a['total']}**; con recorrido en «Trámites»: "
         f"**{a['con_recorrido']}**; preguntas del banco: **{a['preguntas']}**.",
         f"- Escenarios **sin recorrido** (ninguna pregunta se ofrece): "
         f"**{len(a['sin_recorrido'])}**.",
         f"- Recorridos **poco profundos** (menos de {PROFUNDO} turnos): "
         f"**{len(a['poco_profundos'])}**.",
         f"- Recorridos **sin ramificaciones**: **{len(a['sin_ramificaciones'])}** "
         f"de {a['con_recorrido']}.",
         f"- Escenarios marcados como consolidados en otro (los que tenían recorrido dejan de listarse): "
         f"**{len(a['consolidados'])}**; con datos editables: "
         f"**{len(a['editables'])}**.", "",
         "## Sin recorrido", "",
         ", ".join(a["sin_recorrido"]) or "—", "",
         "## Poco profundos", "",
         ", ".join(f"{i} ({n})" for i, n in a["poco_profundos"]) or "—", "",
         "## Trámites que se ven como el mismo", "",
         "| Parecido | Más corto | Más profundo | Títulos |", "|---|---|---|---|"]
    for s, c, l, tc, tl in a["parecidos"]:
        L.append(f"| {s} | {c} | {l} | {tc} / {tl} |")
    L += ["", "## Dimensiones por institución", "",
          "Escenarios de la institución cuyo texto toca cada dimensión.", ""]
    dims = list(DIMENSIONES) + ["con ramificaciones"]
    L.append("| Área | Escenarios | " + " | ".join(dims) + " |")
    L.append("|---|---|" + "---|" * len(dims))
    for area, c in sorted(a["dimensiones"].items()):
        L.append(f"| {area} | {c.get('escenarios', 0)} | "
                 + " | ".join(str(c.get(d, 0)) for d in dims) + " |")
    L += ["", "## Hechos", "",
          f"- Sin usar por ningún turno: {', '.join(a['hechos_sin_usar']) or '—'}.",
          "- No se pueden mostrar:"]
    for h, m in a["hechos_no_mostrables"].items():
        L.append(f"  - {h}: {m}")
    return "\n".join(L) + "\n"


def main() -> int:
    a = analizar()
    print(f"escenarios {a['total']} · con recorrido {a['con_recorrido']} · "
          f"sin recorrido {len(a['sin_recorrido'])} · poco profundos "
          f"{len(a['poco_profundos'])} · sin ramificaciones "
          f"{len(a['sin_ramificaciones'])} · parecidos {len(a['parecidos'])}")
    if "--escribir" in sys.argv:
        with open(INFORME, "w", encoding="utf-8") as f:
            f.write(informe(a))
        print("escrito:", os.path.relpath(INFORME, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
