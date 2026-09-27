"""RAG por significado: situaciones reales de Cochabamba (fase 2).

La app busca primero por palabras, sin red. Cuando eso no encuentra nada
(«¿Está en peligro ahorita?» frente a «¿Está en un lugar seguro ahora?»),
pregunta aquí: se compara el significado de lo dicho con cada pregunta
documentada del funcionario usando embeddings de Bedrock (Titan).

El corpus es el mismo que usa la app (`assets/rag/escenarios_cbba.json`, que
`aws/deploy/build_package.py` empaqueta como `rag_escenarios_cbba.json`). Qué
se puede ofrecer ya lo decidió `tool/build_rag_corpus.py`: aquí solo se
recupera, nunca se redacta.

Los vectores de las preguntas se calculan una vez (acción `rag_indexar`, por
tandas) y se guardan en S3 bajo una huella del corpus: si el corpus cambia, la
huella cambia y la consulta responde «sin índice» hasta reindexar, en vez de
comparar con vectores de otro corpus.

Nada de este módulo toca boto3: `embed` y el almacenamiento se inyectan, para
probarlo sin red.
"""

from __future__ import annotations

import hashlib
import json
import math
import os

AQUI = os.path.dirname(os.path.abspath(__file__))
# En el ZIP de la Lambda va junto a este archivo; en el repositorio se lee el
# mismo corpus que empaqueta la app.
CORPUS_PATH = os.path.join(AQUI, "rag_escenarios_cbba.json")
CORPUS_REPO = os.path.join(os.path.dirname(AQUI), "assets", "rag",
                           "escenarios_cbba.json")

# Similitud del coseno mínima para ofrecer respuestas. Calibrada con la Lambda
# real (tool/rag_calibrar.py, 2026-09-27, Titan v2 256 dims): la charla de
# ventanilla sin trámite («La oficina cierra a las cuatro», «¿Cuál es su
# dirección?») llega a 0.568, así que con 0.46 inventaba respuestas. Con 0.59
# solo pasan paráfrasis claras (5 de 15; la búsqueda por palabras del teléfono
# cubre las demás que comparten vocabulario). Se puede ajustar sin desplegar
# código con la variable de entorno.
MIN_SIMILARITY = float(os.environ.get("RAG_MIN_SIMILARITY", "0.59"))
# Solo se juntan preguntas casi tan parecidas como la mejor.
MARGIN = 0.05
# Ventaja del trámite del que ya se venía hablando (desempate).
TOPIC_BONUS = 0.02
MAX_LIMIT = 8
BATCH = 25

# Un área previa no se abandona por una pregunta genérica que coincide en
# otra institución. Solo estos identificadores explícitos autorizan el cambio.
_SWITCH_CUES = {
    "sepdep", "sepdavi", "felcc", "felcv", "segip", "sereci",
    "fiscalia", "fiscalía", "roma", "nurej", "webid", "juzgado", "tribunal",
}


def cargar_corpus(ruta: str | None = None) -> dict | None:
    """El corpus empaquetado, o `None` si no hay (la consulta se desactiva)."""
    for candidata in ([ruta] if ruta else [CORPUS_PATH, CORPUS_REPO]):
        if os.path.exists(candidata):
            try:
                with open(candidata, encoding="utf-8") as f:
                    return json.load(f)
            except (OSError, UnicodeError, json.JSONDecodeError):
                continue
    return None


def _ofrecible(turno: dict) -> bool:
    return (turno.get("rol", "sordo") == "sordo" and turno.get("mostrable")
            and bool(turno.get("glosas")))


def entradas(corpus: dict) -> list:
    """Preguntas documentadas del funcionario con las respuestas del usuario
    sordo que las siguieron. Mismo índice que `RagRetriever` en la app."""
    out = []
    for esc in corpus.get("escenarios", []):
        turnos = {t["n"]: t for t in esc.get("turnos", [])}

        def respuestas_tras(n: int) -> list:
            siguiente = turnos.get(n + 1)
            out_r = [siguiente] if siguiente and _ofrecible(siguiente) else []
            for v in esc.get("variantes", []):
                if v.get("turno") == n:
                    out_r += [r for r in v.get("respuestas", []) if _ofrecible(r)]
            return out_r

        base = {
            "escenario": esc["id"],
            "area": esc["id"].split("-")[1] if esc["id"].count("-") >= 2 else esc["id"],
            "institucion": esc.get("institucion", ""),
            "tramite": esc.get("tramite", ""),
        }
        for t in esc.get("turnos", []):
            # Lo que el constructor marcó como no mostrable (habla de la
            # fuente, depende de un dato sin verificar o vencido) tampoco es
            # algo que un funcionario diga: como clave solo atrae ruido.
            if t.get("rol") != "funcionario" or not t.get("mostrable"):
                continue
            resp = respuestas_tras(t["n"])
            if resp:
                out.append({**base, "texto": t["texto"], "respuestas": resp})
        for v in esc.get("variantes", []):
            resp = [r for r in v.get("respuestas", []) if _ofrecible(r)]
            if not resp:
                continue
            for q in v.get("preguntas", []):
                out.append({**base, "texto": q, "respuestas": resp})
    return out


def huella(lista: list) -> str:
    """Identifica el conjunto de preguntas indexadas (y su orden)."""
    h = hashlib.sha256()
    for e in lista:
        h.update(f"{e['escenario']}\x1f{e['texto']}\x1e".encode("utf-8"))
    return h.hexdigest()[:16]


def _normalizar(v: list) -> list:
    norma = math.sqrt(sum(x * x for x in v)) or 1.0
    return [x / norma for x in v]


def indexar(lista: list, indice: dict, embed, lote: int = BATCH) -> dict:
    """Calcula los vectores que faltan, como mucho [lote] por llamada.

    [indice] es {"vectores": {"<posición>": [...]}}; se devuelve ampliado.
    Solo se indexan textos del corpus empaquetado: nadie puede usar esta
    acción para calcular embeddings de textos arbitrarios.
    """
    vectores = dict(indice.get("vectores") or {})
    faltan = [i for i in range(len(lista)) if str(i) not in vectores]
    for i in faltan[:lote]:
        vectores[str(i)] = [round(x, 5) for x in _normalizar(embed(lista[i]["texto"]))]
    return {"vectores": vectores}


def consultar(texto: str, lista: list, indice: dict, embed, *,
              prefer_area: str | None = None, limite: int = 4,
              minimo: float = MIN_SIMILARITY, diagnostico: dict | None = None
              ) -> list:
    """Respuestas documentadas de las preguntas más parecidas en significado.

    Vacío si ninguna supera [minimo]. Cada respuesta lleva su similitud. Si se
    pasa [diagnostico], se rellena con la pregunta más parecida y su
    similitud aunque no supere el umbral: sirve para calibrarlo.
    """
    vectores = indice.get("vectores") or {}
    if not texto.strip() or not vectores:
        return []
    q = _normalizar(embed(texto))
    todas = []
    for clave, v in vectores.items():
        i = int(clave)
        if i < len(lista):
            todas.append((sum(a * b for a, b in zip(q, v)), lista[i]))
    if not todas:
        return []
    mejor_sim, mejor_e = max(todas, key=lambda x: x[0])
    if diagnostico is not None:
        diagnostico.update({"score": round(mejor_sim, 4),
                            "scenarioId": mejor_e["escenario"],
                            "question": mejor_e["texto"]})
    puntuadas = sorted(
        ((sim + (TOPIC_BONUS if e["area"] == prefer_area else 0), sim, e)
         for sim, e in todas if sim >= minimo),
        key=lambda x: -x[0],
    )
    if not puntuadas:
        return []
    if prefer_area and not any(e["area"] == prefer_area
                               for _, _, e in puntuadas):
        palabras = set("".join(
            c for c in texto.lower()
            if c.isalnum() or c.isspace()).split())
        if not palabras.intersection(_SWITCH_CUES):
            return []
    mejor = puntuadas[0][0]
    # Solo la institución de la mejor coincidencia: las similitudes por
    # significado quedan muy juntas y mezclar trámites pondría «Soy la persona
    # denunciada» ante «¿Está en peligro?».
    area = puntuadas[0][2]["area"]
    out = []
    for orden, sim, e in puntuadas:
        if orden < mejor - MARGIN:
            break
        if e["area"] != area:
            continue
        for r in e["respuestas"]:
            if any(s["text"] == r["texto"] for s in out):
                continue
            out.append({
                "text": r["texto"],
                "glosses": r["glosas"],
                "scenarioId": e["escenario"],
                "institution": e["institucion"],
                "procedure": e["tramite"],
                "score": round(sim, 4),
            })
            if len(out) >= limite:
                return out
    return out


def clave_indice(modelo: str, lista: list) -> str:
    return f"rag-embeddings-{modelo.replace(':', '_').replace('.', '_')}-{huella(lista)}"


def serializar(indice: dict) -> str:
    return json.dumps(indice, separators=(",", ":"))
