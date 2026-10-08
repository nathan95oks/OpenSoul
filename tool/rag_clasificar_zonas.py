"""Ubica cada palabra sin seña del corpus RAG en su zona de tarjetas.

    python tool/rag_clasificar_zonas.py           # solo las palabras nuevas
    python tool/rag_clasificar_zonas.py --todo    # vuelve a clasificar todas

Las zonas son las categorías del catálogo oficial (Tiempo, Lugares,
Documentos, Objetos…; ver `aws/zonas_senas.json`). Una seña del catálogo ya
tiene su zona. Una palabra sin seña (seña a incorporar) la recibe de la
Lambda LSB→Texto/Audio (`action: "zonas"`, ver `aws/rag_zonas.py`): Titan y
Bedrock eligen por separado comparando con una definición escrita de cada
zona y, si coinciden, esa es su zona; un verbo va a Acciones. Si no
coinciden, queda sin zona. Nadie aprueba nada a mano.

Escribe `docs/negocio/rag/zonas_palabras.json`.
"""

from __future__ import annotations

import concurrent.futures
import datetime
import json
import os
import re
import sys
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

from build_rag_corpus import RAG, ROOT, SALIDA, SENA_PENDIENTE  # noqa: E402

DESTINO = os.path.join(RAG, "zonas_palabras.json")
TANDA = 10
# De a una: cada llamada lee el índice de señas y vectoriza su tanda; dos a
# la vez saturaban Bedrock (error_modelo, 503).
HILOS = 1
REINTENTOS = 4


def palabras_sin_sena() -> dict:
    """{PALABRA: [frases]} de las señas a incorporar del corpus."""
    with open(SALIDA, encoding="utf-8") as f:
        corpus = json.load(f)
    out = {}
    for e in corpus["escenarios"]:
        tarjetas = e["turnos"] + [r for p in e["variantes"] for r in p["respuestas"]]
        for t in tarjetas:
            for g in t.get("glosas") or []:
                if g.startswith(SENA_PENDIENTE):
                    ejemplos = out.setdefault(g[len(SENA_PENDIENTE):], [])
                    if len(ejemplos) < 3 and t["texto"] not in ejemplos:
                        ejemplos.append(t["texto"])
    return out


# Zonas de cosas y datos (las que se ofrecen como tarjetas en un trámite).
_ZONAS_DE_COSAS = {"Documentos", "Objetos", "Lugares", "Tiempo",
                   "Identificación", "Instituciones", "Conceptos jurídicos",
                   "Números"}
# Lo que va antes de un sustantivo en la frase: «el expediente», «mi boleta».
_DETERMINANTES = {
    "el", "la", "los", "las", "un", "una", "unos", "unas", "su", "sus", "mi",
    "mis", "tu", "tus", "del", "al", "este", "esta", "estos", "estas", "ese",
    "esa", "esos", "esas", "otro", "otra", "cada", "ningun", "ninguna",
    "algun", "alguna", "nuestro", "nuestra", "cualquier", "que", "sin", "por",
    "con", "de", "en", "y", "o",
}


def es_sustantivo(palabra: str, ejemplos: list) -> bool:
    """Si en alguna frase real la palabra va tras un determinante («el
    expediente», «un duplicado», «mi boleta»). Un verbo («lo traje», «Queda
    entre…») o un adjetivo («deuda antigua») no. Un nombre de varias
    palabras (TRIBUNAL_DEPARTAMENTAL) cuenta como sustantivo."""
    sys.path.insert(0, os.path.join(ROOT, "aws"))
    from rag_revision import _IRREGULARES, _norm  # noqa: E402
    if "_" in palabra:
        return True
    clave = _norm(palabra)
    if any(clave in formas for formas in _IRREGULARES.values()):
        return False  # «traje» es de traer
    for e in ejemplos:
        w = [_norm(x) for x in re.findall(r"[A-Za-zÁÉÍÓÚÑáéíóúñ0-9]+", e)]
        for i, x in enumerate(w):
            misma = x == clave or len(clave) > 4 and x[:5] == clave[:5]
            # Tras un determinante, o con un adjetivo en medio («mi última
            # boleta»).
            if misma and (i > 0 and w[i - 1] in _DETERMINANTES
                          or i > 1 and w[i - 2] in _DETERMINANTES):
                return True
    return False


def zona_valida(palabra: str, zona: str | None,
                ejemplos: list | None = None) -> str | None:
    """La zona acordada, si la palabra encaja por su uso: en una zona de
    cosas y datos solo entra un sustantivo (ver `es_sustantivo`), así que no
    entran palabras de función (DE, CONTRA), verbos conjugados (QUEDA,
    CONSERVE) ni adjetivos (ANTIGUO, JUDICIAL)."""
    if not zona:
        return None
    if zona in _ZONAS_DE_COSAS and not es_sustantivo(palabra, ejemplos or []):
        return None
    return zona


def guardar(zonas: dict) -> None:
    with open(DESTINO, "w", encoding="utf-8", newline="") as f:
        json.dump({k: zonas[k] for k in sorted(zonas)}, f,
                  ensure_ascii=False, indent=1)
        f.write("\n")


def main() -> int:
    zonas = {}
    if os.path.exists(DESTINO) and "--todo" not in sys.argv:
        with open(DESTINO, encoding="utf-8") as f:
            zonas = json.load(f)
    palabras = palabras_sin_sena()
    zonas = {p: z for p, z in zonas.items() if p in palabras}
    pendientes = [p for p in sorted(palabras) if p not in zonas]
    print(f"palabras sin seña: {len(palabras)} · por clasificar: {len(pendientes)}")
    if pendientes:
        from rag_indexar_embeddings import endpoint, llamar
        url = endpoint()
        hoy = datetime.date.today().isoformat()

        def clasificar(tanda):
            r = {}
            for intento in range(REINTENTOS):
                try:
                    r = llamar(url, {"action": "zonas", "palabras": [
                        {"palabra": p, "ejemplos": palabras[p]} for p in tanda]})
                except SystemExit as e:
                    r = {"generated": False, "reason": str(e)}
                if r.get("generated") is True:
                    break
                time.sleep(3 * 2 ** intento)
            return tanda, r

        tandas = [pendientes[i:i + TANDA]
                  for i in range(0, len(pendientes), TANDA)]
        hechas = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=HILOS) as pool:
            for tanda, r in pool.map(clasificar, tandas):
                if r.get("generated") is not True:
                    print(f"  tanda sin clasificar: {r.get('reason') or r}")
                    continue
                for p, res in zip(tanda, r["palabras"]):
                    zonas[p] = {"zona": zona_valida(p, res["zona"],
                                                    palabras[p]),
                                "acordada": res["zona"], "titan": res["titan"],
                                "similitud": res["similitud"],
                                "regla": res.get("regla"),
                                "bedrock": res["bedrock"],
                                "ejemplos": palabras[p], "fecha": hoy}
                hechas += len(tanda)
                guardar(zonas)
                print(f"  {hechas}/{len(pendientes)}", flush=True)
    # Las reglas de forma se aplican también a lo ya clasificado.
    for p, z in zonas.items():
        z["zona"] = zona_valida(p, z.get("acordada", z["zona"]),
                                z.get("ejemplos"))
    guardar(zonas)
    con_zona = sum(1 for z in zonas.values() if z["zona"])
    por_zona = {}
    for z in zonas.values():
        if z["zona"]:
            por_zona[z["zona"]] = por_zona.get(z["zona"], 0) + 1
    print(f"con zona: {con_zona} de {len(zonas)} · " + ", ".join(
        f"{k} {v}" for k, v in sorted(por_zona.items(), key=lambda kv: -kv[1])))
    print(f"escrito: {os.path.relpath(DESTINO, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
