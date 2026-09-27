"""Busca señas del catálogo equivalentes para las palabras sin seña del RAG.

    python tool/rag_equivalencias.py            # catálogo + Bedrock (Lambda)
    python tool/rag_equivalencias.py --sin-red  # solo la evidencia del catálogo

Las palabras salen de `docs/negocio/rag/glosas_cache.json`: las que la
traducción Texto→LSB marcó «concepto_sin_catalogo», menos las siglas (NUREJ,
CRPVA), que en LSB se deletrean. Para cada una:

1. **Catálogo.** Si una seña oficial de `aws/catalogo_senas.json` se
   escribe exactamente así en español («el documento» → PAPEL, «mi» →
   MÍO), queda aprobada: la evidencia es el propio catálogo, con su fuente.
2. **Bedrock.** Si no, la Lambda LSB→Texto/Audio (`action: "equivalencias"`)
   pide al modelo una seña oficial equivalente en esas frases, o ninguna. La
   Lambda descarta cualquier glosa fuera del catálogo. Lo que propone queda
   «propuesta» hasta que una persona lo revise: compartir la raíz no basta
   (FISCAL no es FISCALÍA, JUDICIAL no es ÓRGANO_JUDICIAL). `misma_raiz`
   solo ayuda a revisar.

Escribe `docs/negocio/rag/senas_equivalentes.json`.

    python tool/rag_equivalencias.py --actualizar-catalogo

regenera `aws/catalogo_senas.json` desde la exportación del catálogo
(`assets/dictionary/glosas_opensoul.csv`, de `tool/generate_csv.py`), que no
se versiona. Para revisar a mano, se
cambia `estado` a «aprobada» o «rechazada» y se pone `"revisado": true`: una
entrada revisada no se vuelve a tocar. `tool/build_rag_corpus.py` usa solo
las aprobadas.
"""

from __future__ import annotations

import csv
import datetime
import json
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

from build_rag_corpus import GLOSAS, ROOT, _es_sigla, _norm  # noqa: E402

CSV_CATALOGO = os.path.join(ROOT, "assets", "dictionary", "glosas_opensoul.csv")
FOTO_CATALOGO = os.path.join(ROOT, "aws", "catalogo_senas.json")
SALIDA = os.path.join(ROOT, "docs", "negocio", "rag", "senas_equivalentes.json")
TANDA = 10
_ARTICULOS = ("el ", "la ", "los ", "las ", "un ", "una ")


def catalogo() -> dict:
    """{glosa: [formas en español]} de las señas oficiales."""
    with open(FOTO_CATALOGO, encoding="utf-8") as f:
        return json.load(f)


def actualizar_catalogo() -> int:
    """Regenera la foto versionada desde la exportación local del catálogo."""
    with open(CSV_CATALOGO, encoding="utf-8-sig") as f:
        filas = list(csv.DictReader(f))
    foto = {
        r["Glosa"]: list(dict.fromkeys(
            v.strip() for v in (r["Significado_Espanol"],
                                r["Forma_Espanol_Oracion"])
            if v and v.strip()))
        for r in filas if r["Tipo_Entrada"].startswith("Cat")
    }
    with open(FOTO_CATALOGO, "w", encoding="utf-8", newline="") as f:
        json.dump({k: foto[k] for k in sorted(foto)}, f,
                  ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"catálogo: {len(foto)} señas · {os.path.relpath(FOTO_CATALOGO, ROOT)}")
    # La zona de cada seña: su categoría en el diccionario oficial.
    with open(os.path.join(ROOT, "assets", "dictionary",
                           "official_dictionary.json"), encoding="utf-8") as f:
        zonas = {e["gloss"]: e["categoryId"] for e in json.load(f)["entries"]}
    destino = os.path.join(ROOT, "aws", "zonas_senas.json")
    with open(destino, "w", encoding="utf-8", newline="") as f:
        json.dump({k: zonas[k] for k in sorted(zonas)}, f,
                  ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"zonas: {len(zonas)} señas · {os.path.relpath(destino, ROOT)}")
    return 0


def _sin_articulo(forma: str) -> str:
    f = _norm(forma).strip()
    for a in _ARTICULOS:
        if f.startswith(a):
            return f[len(a):]
    return f


def por_catalogo(palabra: str, cat: dict) -> dict | None:
    """La seña cuya forma en español es exactamente [palabra], si es una."""
    clave = _norm(palabra.replace("_", " "))
    senas = [g for g, formas in cat.items()
             if any(_sin_articulo(f) == clave for f in formas)]
    if len(senas) != 1:
        return None
    g = senas[0]
    return {"sena": g, "origen": "catalogo", "estado": "aprobada",
            "razon": f"El catálogo oficial escribe {g} como «"
                     + "» / «".join(cat[g]) + "»."}


def _raiz(texto: str) -> str:
    return _norm(texto)[:5] if len(texto) >= 5 else _norm(texto)


def comparte_raiz(palabra: str, sena: str, cat: dict) -> bool:
    """AYUDA y AYUDAR: una pista para quien revisa, no una prueba (FISCAL y
    FISCALÍA comparten raíz y no significan lo mismo)."""
    raiz = _raiz(palabra)
    if len(raiz) < 4:
        return False
    candidatas = [sena.replace("_", " ")] + cat.get(sena, [])
    return any(_raiz(w) == raiz
               for c in candidatas for w in re.findall(r"[\wÁÉÍÓÚÑáéíóúñ]+", c))


def palabras_sin_sena() -> dict:
    """{PALABRA: [frases]} de la caché de glosas, sin siglas."""
    with open(GLOSAS, encoding="utf-8") as f:
        cache = json.load(f)
    out = {}
    for texto, v in cache.items():
        for c in v.get("correcciones") or []:
            p = c.get("palabra")
            if (c.get("accion") != "concepto_sin_catalogo" or not p
                    or _es_sigla(p, texto)
                    or not re.fullmatch(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ_ ]+", p)):
                continue
            out.setdefault(p.upper(), [])
            if len(out[p.upper()]) < 3 and texto not in out[p.upper()]:
                out[p.upper()].append(texto)
    return out


def endpoint() -> str:
    from rag_indexar_embeddings import endpoint as lambda_url
    return lambda_url()


def pedir_bedrock(url: str, tanda: list) -> list:
    from rag_indexar_embeddings import llamar
    r = llamar(url, {"action": "equivalencias", "palabras": tanda})
    if r.get("generated") is not True:
        raise SystemExit(f"La Lambda no propuso nada: {r.get('reason') or r}")
    return r["propuestas"]


def decidir(palabra: str, propuesta: dict, cat: dict) -> dict:
    sena = propuesta.get("sena")
    base = {"razon": propuesta.get("razon", ""), "origen": "bedrock"}
    if propuesta.get("descartada"):
        base["descartada"] = propuesta["descartada"]
    if not sena:
        return {**base, "sena": None, "estado": "sin_equivalente"}
    return {**base, "sena": sena, "estado": "propuesta",
            "misma_raiz": comparte_raiz(palabra, sena, cat)}


def main() -> int:
    if "--actualizar-catalogo" in sys.argv:
        return actualizar_catalogo()
    cat = catalogo()
    previas = {}
    if os.path.exists(SALIDA):
        with open(SALIDA, encoding="utf-8") as f:
            previas = json.load(f)
    palabras = palabras_sin_sena()
    hoy = datetime.date.today().isoformat()
    salida = {p: e for p, e in previas.items() if e.get("revisado")}
    faltan = []
    for p, frases in sorted(palabras.items()):
        if p in salida:
            continue
        evidencia = por_catalogo(p, cat)
        if evidencia:
            salida[p] = {**evidencia, "ejemplos": frases, "fecha": hoy}
        elif p in previas and previas[p].get("origen", "").startswith("bedrock"):
            salida[p] = previas[p]
        else:
            faltan.append(p)
    if faltan and "--sin-red" not in sys.argv:
        url = endpoint()
        for i in range(0, len(faltan), TANDA):
            tanda = [{"palabra": p, "ejemplos": palabras[p]}
                     for p in faltan[i:i + TANDA]]
            for p, prop in zip(faltan[i:i + TANDA], pedir_bedrock(url, tanda)):
                salida[p] = {**decidir(p, prop, cat), "ejemplos": palabras[p],
                             "fecha": hoy}
            print(f"  {min(i + TANDA, len(faltan))}/{len(faltan)}", flush=True)
    with open(SALIDA, "w", encoding="utf-8", newline="") as f:
        json.dump({k: salida[k] for k in sorted(salida)}, f,
                  ensure_ascii=False, indent=1)
        f.write("\n")
    estados = {}
    for e in salida.values():
        estados[e["estado"]] = estados.get(e["estado"], 0) + 1
    print(f"palabras sin seña: {len(palabras)} · " + ", ".join(
        f"{k} {v}" for k, v in sorted(estados.items())))
    if faltan and "--sin-red" in sys.argv:
        print(f"sin consultar a Bedrock: {len(faltan)}")
    print(f"escrito: {os.path.relpath(SALIDA, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
