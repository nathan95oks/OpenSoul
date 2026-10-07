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
   Con el léxico LSB (`aws/lexico_lsb.json`: M1–M4 y diccionarios) hay
   dos formas de entrar:
   * **forma 1**: la palabra se escribe igual que una seña del léxico. Va
     como `candidata` con su módulo y tema, y el modelo confirma que es el
     mismo sentido («mi fiscal» no es FISCAL de «escuela fiscal», M3);
   * **forma 2**: no está; el modelo propone una seña sinónima o una
     combinación de hasta tres señas del léxico (`senas`).
3. **Confirmación automática**, sin revisión humana: una propuesta de
   Bedrock se aprueba sola si además (a) la seña es de la misma zona que la
   palabra (la que le dieron Titan y Bedrock en `tool/rag_zonas.py`), cuando
   es una sola seña con zona, y (b) una frase real con las señas en lugar de
   la palabra dice lo mismo que la original (`action: "retrotraducir"`: no
   falta la palabra ni sobra ninguna seña). Si falla una señal, se rechaza
   sola. Compartir la raíz no basta (FISCAL no es FISCALÍA).

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

from build_rag_corpus import (GLOSAS, ROOT, _OMITIDAS,  # noqa: E402
                              _es_sigla, _norm, cargar_lexico, lexico_directo)

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
                    or _norm(p) in _OMITIDAS or _es_sigla(p, texto)
                    or not re.fullmatch(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ_ ]+", p)):
                continue
            out.setdefault(p.upper(), [])
            if len(out[p.upper()]) < 3 and texto not in out[p.upper()]:
                out[p.upper()].append(texto)
    return out


def version_lexico() -> str | None:
    """Huella corta del léxico con que se decide, o None sin léxico."""
    from build_rag_corpus import LEXICO
    if not os.path.exists(LEXICO):
        return None
    import hashlib
    with open(LEXICO, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()[:12]


def endpoint() -> str:
    from rag_indexar_embeddings import endpoint as lambda_url
    return lambda_url()


def pedir_bedrock(url: str, tanda: list) -> list:
    from rag_indexar_embeddings import llamar
    r = llamar(url, {"action": "equivalencias", "palabras": tanda})
    if r.get("generated") is not True:
        raise SystemExit(f"La Lambda no propuso nada: {r.get('reason') or r}")
    return r["propuestas"]


def decidir(palabra: str, propuesta: dict, cat: dict,
            candidata: str | None = None) -> dict:
    """La propuesta de Bedrock como entrada de senas_equivalentes.json. Una
    combinación va en `senas`; una sola seña, también en `sena`."""
    senas = propuesta.get("senas") or (
        [propuesta["sena"]] if propuesta.get("sena") else [])
    base = {"razon": propuesta.get("razon", ""),
            "origen": "lexico+bedrock" if candidata else "bedrock"}
    if candidata:
        base["candidata"] = candidata
    if propuesta.get("descartada"):
        base["descartada"] = propuesta["descartada"]
    if not senas:
        return {**base, "sena": None, "estado": "sin_equivalente"}
    if len(senas) > 1:
        return {**base, "sena": None, "senas": senas, "estado": "propuesta"}
    return {**base, "sena": senas[0], "estado": "propuesta",
            "misma_raiz": comparte_raiz(palabra, senas[0], cat)}


def _frases_con_glosas() -> dict:
    """{frase: glosas con sus señas pendientes marcadas}, de la caché de
    traducción y no del corpus: en un archivo con el léxico estricto, una
    tarjeta con una palabra sin seña no lleva glosas en el corpus, y es
    justo la frase con que se confirma su equivalencia."""
    from build_rag_corpus import (CORRECCIONES, aplicar_equivalencias,
                                  cargar_equivalencias,
                                  marcar_senas_pendientes)
    with open(GLOSAS, encoding="utf-8") as f:
        cache = json.load(f)
    corregidas = {}
    if os.path.exists(CORRECCIONES):
        with open(CORRECCIONES, encoding="utf-8") as f:
            corregidas = json.load(f)
    # Solo las equivalencias ya aprobadas, no las palabras de M1–M4: una
    # palabra del módulo que se está confirmando («maestro») tiene que
    # seguir marcada como pendiente en su frase. Con las del módulo ya
    # puestas, nunca aparecía, se rechazaba «sin frase con la palabra» y ese
    # rechazo le quitaba su seña del módulo.
    equivalencias = cargar_equivalencias()
    out = {}
    for texto, v in cache.items():
        if texto in corregidas:
            glosas = aplicar_equivalencias(corregidas[texto]["glosas"], texto,
                                           equivalencias)
        else:
            glosas = marcar_senas_pendientes(
                v.get("glosas"), v.get("correcciones") or [], texto,
                equivalencias)
        if glosas:
            out[texto] = glosas
    return out


def confirmar(url: str, salida: dict) -> None:
    """Decide sola cada propuesta de Bedrock no revisada a mano: aprobada si
    Titan y la vuelta al español la confirman, rechazada si no."""
    from rag_indexar_embeddings import llamar
    from rag_zonas import DESTINO as ZONAS
    sys.path.insert(0, os.path.join(ROOT, "aws"))
    from rag_revision import conjugada  # noqa: E402
    zona_de = {}
    if os.path.exists(ZONAS):
        with open(ZONAS, encoding="utf-8") as f:
            zona_de = {p: d.get("zona") for p, d in json.load(f).items()}
    with open(os.path.join(ROOT, "aws", "zonas_senas.json"),
              encoding="utf-8") as f:
        zona_sena = {_norm(g): z for g, z in json.load(f).items()}
    frases = _frases_con_glosas()
    for palabra, e in sorted(salida.items()):
        senas = e.get("senas") or ([e["sena"]] if e.get("sena") else [])
        if e.get("estado") != "propuesta" or e.get("revisado") or not senas:
            continue
        clave = palabra.replace(" ", "_")
        zona = zona_de.get(clave)
        # La zona solo se puede comparar con una seña sola que tenga zona (las
        # del catálogo). Una combinación o una seña de M1–M4 sin zona depende
        # del sentido que confirmó el modelo y de la vuelta al español.
        con_zona = len(senas) == 1 and _norm(senas[0]) in zona_sena
        titan = (bool(zona) and zona_sena.get(_norm(senas[0])) == zona
                 if con_zona else None)
        # Una frase real con la seña en lugar de la palabra.
        vuelta, detalle = False, "sin frase con la palabra"
        marca = "SENA_PENDIENTE:" + clave
        for texto in e.get("ejemplos") or []:
            glosas = frases.get(texto)
            if not glosas or marca not in glosas:
                continue
            nuevas = []
            for g in glosas:
                nuevas += senas if g == marca else [g]
            r = llamar(url, {"action": "retrotraducir", "items": [
                {"texto": texto, "glosas": nuevas}]})
            if r.get("generated") is not True:
                detalle = f"sin respuesta: {r.get('reason')}"
                break
            res = r["items"][0]
            falta = any(conjugada(w, [palabra]) or _norm(w) == _norm(palabra)
                        for w in res["faltan"])
            sobra = bool({_norm(s) for s in senas}
                         & {_norm(s) for s in res["sobran"]})
            vuelta = not falta and not sobra
            detalle = (f"«{texto}» → falta {res['faltan']} sobra "
                       f"{res['sobran']}")
            break
        e["senales"] = {"bedrock": senas, "zona_palabra": zona,
                        "zona_sena": (zona_sena.get(_norm(senas[0]))
                                      if con_zona else None),
                        "titan": titan, "vuelta": vuelta,
                        "vuelta_detalle": detalle}
        e["estado"] = ("aprobada" if vuelta and titan is not False
                       else "rechazada")
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
    # Forma 1: palabras que se escriben como una seña del léxico (M1–M4,
    # diccionarios). No se aprueban por cómo se escriben: van a Bedrock como
    # candidatas, con su tema, para confirmar el sentido.
    candidatas = lexico_directo()
    if not cargar_lexico():
        print("aviso: falta aws/lexico_lsb.json (python "
              "tool/build_lexico_lsb.py): solo se busca en el catálogo")
    hoy = datetime.date.today().isoformat()
    version = version_lexico()
    salida = {p: e for p, e in previas.items() if e.get("revisado")}
    faltan = []
    for p, frases in sorted(palabras.items()):
        if p in salida:
            continue
        evidencia = por_catalogo(p, cat)
        if evidencia:
            salida[p] = {**evidencia, "ejemplos": frases, "fecha": hoy}
        elif (p in previas and "bedrock" in previas[p].get("origen", "")
              and (previas[p].get("estado") == "aprobada"
                   or previas[p].get("lexico") == version)):
            # Una decisión de Bedrock se reutiliza mientras el léxico con que
            # se tomó no cambie; una aprobada, siempre. Una «sin
            # equivalente» de antes del léxico se vuelve a pedir: ahora hay
            # señas de M1–M4 y diccionarios que antes no estaban.
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
            tanda = []
            for p in faltan[i:i + TANDA]:
                pedido = {"palabra": p, "ejemplos": palabras[p]}
                candidata = candidatas.get(_norm(p.replace("_", " ")))
                if candidata:
                    pedido["candidata"] = candidata
                tanda.append(pedido)
            for pedido, prop in zip(tanda, pedir_bedrock(url, tanda)):
                p = pedido["palabra"]
                salida[p] = {**decidir(p, prop, cat, pedido.get("candidata")),
                             "ejemplos": palabras[p], "fecha": hoy,
                             "lexico": version}
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
