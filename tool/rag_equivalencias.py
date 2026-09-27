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
   Lambda descarta cualquier glosa fuera del catálogo.
3. **Confirmación automática**, sin revisión humana: una propuesta de
   Bedrock se aprueba sola si además (a) Titan pone esa seña entre las 5
   más parecidas a la palabra (sus vecinas, de `tool/rag_zonas.py`) y (b)
   una frase real con la seña en lugar de la palabra dice lo mismo que la
   original (`action: "retrotraducir"`: no falta la palabra ni sobra la
   seña). Si falla una señal, se rechaza sola. Compartir la raíz no basta
   (FISCAL no es FISCALÍA): por eso hacen falta las tres.

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


def _frases_con_glosas() -> dict:
    """{frase: glosas} del corpus construido."""
    from build_rag_corpus import SALIDA as CORPUS
    with open(CORPUS, encoding="utf-8") as f:
        corpus = json.load(f)
    out = {}
    for e in corpus["escenarios"]:
        for t in e["turnos"] + [r for p in e["variantes"] for r in p["respuestas"]]:
            if t.get("glosas"):
                out.setdefault(t["texto"], t["glosas"])
    return out


def confirmar(url: str, salida: dict) -> None:
    """Decide sola cada propuesta de Bedrock no revisada a mano: aprobada si
    Titan y la vuelta al español la confirman, rechazada si no."""
    from rag_indexar_embeddings import llamar
    from rag_zonas import DESTINO as ZONAS
    sys.path.insert(0, os.path.join(ROOT, "aws"))
    from rag_revision import conjugada  # noqa: E402
    vecinas = {}
    if os.path.exists(ZONAS):
        with open(ZONAS, encoding="utf-8") as f:
            vecinas = {p: d.get("vecinas") or [] for p, d in json.load(f).items()}
    frases = _frases_con_glosas()
    for palabra, e in sorted(salida.items()):
        if e.get("estado") != "propuesta" or e.get("revisado") or not e.get("sena"):
            continue
        sena = e["sena"]
        clave = palabra.replace(" ", "_")
        cercanas = vecinas.get(clave, [])
        titan = _norm(sena) in {_norm(v) for v in cercanas}
        # Una frase real con la seña en lugar de la palabra.
        vuelta, detalle = False, "sin frase con la palabra"
        marca = "SENA_PENDIENTE:" + clave
        for texto in e.get("ejemplos") or []:
            glosas = frases.get(texto)
            if not glosas or marca not in glosas:
                continue
            nuevas = [sena if g == marca else g for g in glosas]
            r = llamar(url, {"action": "retrotraducir", "items": [
                {"texto": texto, "glosas": nuevas}]})
            if r.get("generated") is not True:
                detalle = f"sin respuesta: {r.get('reason')}"
                break
            res = r["items"][0]
            falta = any(conjugada(w, [palabra]) or _norm(w) == _norm(palabra)
                        for w in res["faltan"])
            sobra = _norm(sena) in {_norm(s) for s in res["sobran"]}
            vuelta = not falta and not sobra
            detalle = (f"«{texto}» → falta {res['faltan']} sobra "
                       f"{res['sobran']}")
            break
        e["senales"] = {"bedrock": sena, "titan_vecinas": cercanas,
                        "titan": titan, "vuelta": vuelta,
                        "vuelta_detalle": detalle}
        e["estado"] = "aprobada" if titan and vuelta else "rechazada"
        e["origen"] = "bedrock+titan+vuelta"
        e["automatica"] = True


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
            if previas[p].get("automatica") is None and previas[p].get("sena"):
                # Decidida antes a mano o sin confirmar: se vuelve a decidir
                # con las tres señales.
                salida[p]["estado"] = "propuesta"
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
    if "--sin-red" not in sys.argv:
        confirmar(endpoint(), salida)
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
