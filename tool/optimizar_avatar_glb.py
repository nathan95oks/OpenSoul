"""Aligera el modelo del avatar sin cambiar lo que se ve.

    python tool/optimizar_avatar_glb.py                      # optimiza en su sitio
    python tool/optimizar_avatar_glb.py --entrada X.glb --salida Y.glb
    python tool/optimizar_avatar_glb.py --solo-verificar ORIGINAL.glb OPTIMIZADO.glb

Todas las señas están horneadas en un mismo .glb exportado desde Blender. El
exportador escribe, para cada una de las ~157 animaciones, una pista de
traslación, rotación y escala por cada uno de los 74 huesos (222 pistas por
seña, ~35 000 en total), cada una con su propio tiempo y su propio acceso en
el JSON. El visor tiene que leer ese JSON (~8 MB) y crear una pista de
animación por cada entrada antes de poder hacer la primera seña: es lo que
tardaba en el teléfono.

Lo que hace, en este orden:

1. Quita, en cada seña, las pistas que **no se mueven en esa seña** y valen
   lo mismo que la pose de reposo del hueso. El motor del visor (three.js)
   devuelve a su pose de reposo todo hueso que la seña en curso no anima,
   también durante el fundido entre dos señas: sin la pista, el hueso hace
   exactamente lo mismo que con ella.
2. Comparte los tiempos: cada seña tiene solo dos líneas de tiempo distintas
   pero las repetía en cada pista.
3. Guarda una sola vez los datos idénticos (pistas constantes con el mismo
   valor).
4. Guarda las rotaciones como enteros de 16 bits normalizados, que el
   estándar glTF admite para animaciones sin ninguna extensión ni
   decodificador (Draco, meshopt y KTX2 se descartan: el visor descarga sus
   decodificadores de internet y la app debe funcionar sin conexión).
5. Junta todos los datos de animación en un solo bloque.
6. Reduce las texturas a [TEXTURA_MAXIMA] px de lado (1024 → 512): cuatro
   veces menos memoria gráfica, la que más pesa en un teléfono de gama media.
   El avatar se ve en un recuadro de unos pocos cientos de píxeles, así que
   no se nota.

Mallas, esqueletos, morfologías y nombres de las señas se copian tal cual. Al terminar **verifica** cada seña cuadro a cuadro contra el
original (cada tiempo de cada pista y los puntos intermedios) y no escribe
nada si alguna diferencia supera lo imperceptible.
"""

from __future__ import annotations

import argparse
import array
import io
import json
import math
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELO = os.path.join(ROOT, "assets", "models", "avatar_test.glb")

# Tolerancias de la verificación: por debajo de esto no se ve.
TOL_POSICION = 1e-4      # metros (0,1 mm) en traslación; factor en escala
TOL_ANGULO = 0.05        # grados (rotación)
# Una pista está quieta en su reposo si ningún valor se aparta más que esto.
TOL_CONSTANTE = 5e-5
# Lado máximo de una textura.
TEXTURA_MAXIMA = 512
CALIDAD_JPEG = 88

COMPONENTES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
FORMATOS = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
ESCALA_NORMALIZADA = {5120: 127.0, 5121: 255.0, 5122: 32767.0, 5123: 65535.0}
REPOSO = {"translation": [0.0, 0.0, 0.0], "rotation": [0.0, 0.0, 0.0, 1.0],
          "scale": [1.0, 1.0, 1.0]}


# --------------------------------------------------------------------------
# Lectura y escritura del GLB
# --------------------------------------------------------------------------

class Glb:
    def __init__(self, datos: bytes):
        magia, version, _ = struct.unpack("<4sII", datos[:12])
        if magia != b"glTF" or version != 2:
            raise SystemExit("no es un glTF binario 2.0")
        largo_json, tipo = struct.unpack("<I4s", datos[12:20])
        assert tipo == b"JSON"
        self.json = json.loads(datos[20:20 + largo_json])
        pos = 20 + largo_json
        largo_bin, tipo = struct.unpack("<I4s", datos[pos:pos + 8])
        assert tipo == b"BIN\x00"
        self.bin = datos[pos + 8:pos + 8 + largo_bin]

    @classmethod
    def abrir(cls, ruta: str) -> "Glb":
        with open(ruta, "rb") as f:
            return cls(f.read())

    def vista(self, indice: int) -> bytes:
        v = self.json["bufferViews"][indice]
        inicio = v.get("byteOffset", 0)
        return self.bin[inicio:inicio + v["byteLength"]]

    def leer(self, indice: int) -> list:
        """Los valores del acceso como floats (desnormaliza si hace falta)."""
        a = self.json["accessors"][indice]
        if "sparse" in a:
            raise SystemExit("accesos dispersos no soportados")
        n = COMPONENTES[a["type"]] * a["count"]
        if "bufferView" not in a:
            return [0.0] * n
        fmt = FORMATOS[a["componentType"]]
        v = self.json["bufferViews"][a["bufferView"]]
        inicio = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        tam = struct.calcsize(fmt)
        paso = v.get("byteStride") or COMPONENTES[a["type"]] * tam
        if paso != COMPONENTES[a["type"]] * tam:
            raise SystemExit("accesos intercalados no soportados en animación")
        arr = array.array(fmt)
        arr.frombytes(self.bin[inicio:inicio + n * tam])
        valores = list(arr)
        if a.get("normalized"):
            escala = ESCALA_NORMALIZADA[a["componentType"]]
            valores = [max(x / escala, -1.0) for x in valores]
        return valores


def escribir_glb(documento: dict, binario: bytes) -> bytes:
    texto = json.dumps(documento, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    texto += b" " * ((4 - len(texto) % 4) % 4)
    binario += b"\x00" * ((4 - len(binario) % 4) % 4)
    total = 12 + 8 + len(texto) + 8 + len(binario)
    return (struct.pack("<4sII", b"glTF", 2, total)
            + struct.pack("<I4s", len(texto), b"JSON") + texto
            + struct.pack("<I4s", len(binario), b"BIN\x00") + binario)


# --------------------------------------------------------------------------
# Optimización
# --------------------------------------------------------------------------

def _quieta_en_reposo(glb: Glb, nodo: int, propiedad: str, salida: int) -> bool:
    """La pista no se mueve en su seña y vale la pose de reposo del hueso."""
    if propiedad not in REPOSO:
        return False
    reposo = glb.json["nodes"][nodo].get(propiedad, REPOSO[propiedad])
    ancho = len(reposo)
    valores = glb.leer(salida)
    return all(abs(valores[i] - reposo[i % ancho]) <= TOL_CONSTANTE
               for i in range(len(valores)))


def _vistas_de(acceso: dict) -> list:
    """Bloques de datos que usa un acceso (el suyo y los dispersos)."""
    vistas = [acceso["bufferView"]] if "bufferView" in acceso else []
    if "sparse" in acceso:
        vistas += [acceso["sparse"]["indices"]["bufferView"],
                   acceso["sparse"]["values"]["bufferView"]]
    return vistas


def _firma(glb: "Glb", indice: int):
    """Un acceso de malla tal como se guarda: sus campos y sus bytes."""
    a = glb.json["accessors"][indice]
    campos = {k: v for k, v in a.items() if k not in ("bufferView", "sparse")}
    datos = [glb.vista(v) for v in _vistas_de(a)]
    if "sparse" in a:
        campos["sparse"] = {
            "count": a["sparse"]["count"],
            "indices": {k: v for k, v in a["sparse"]["indices"].items() if k != "bufferView"},
            "values": {k: v for k, v in a["sparse"]["values"].items() if k != "bufferView"},
        }
    return campos, datos


def _referencias_no_animacion(j: dict) -> set:
    usados = set()
    for malla in j.get("meshes", []):
        for p in malla["primitives"]:
            usados.update(p["attributes"].values())
            if "indices" in p:
                usados.add(p["indices"])
            for objetivo in p.get("targets", []):
                usados.update(objetivo.values())
    for piel in j.get("skins", []):
        if "inverseBindMatrices" in piel:
            usados.add(piel["inverseBindMatrices"])
    return usados


def reducir_textura(datos: bytes, mime: str, lado: int) -> bytes:
    """La textura con su lado mayor en [lado] px como mucho, mismo formato.
    Si ya cabe, se devuelve tal cual."""
    from PIL import Image  # solo hace falta para optimizar

    imagen = Image.open(io.BytesIO(datos))
    if max(imagen.size) <= lado:
        return datos
    escala = lado / max(imagen.size)
    nueva = imagen.resize(
        (max(1, round(imagen.width * escala)), max(1, round(imagen.height * escala))),
        Image.LANCZOS)
    salida = io.BytesIO()
    if mime == "image/png":
        nueva.save(salida, format="PNG", optimize=True)
    else:
        if nueva.mode not in ("RGB", "L"):
            nueva = nueva.convert("RGB")
        nueva.save(salida, format="JPEG", quality=CALIDAD_JPEG, optimize=True)
    return salida.getvalue()


def optimizar(glb: Glb, lado_textura: int = TEXTURA_MAXIMA) -> tuple[dict, bytes, dict]:
    j = json.loads(json.dumps(glb.json))
    vista_de_imagen = {im["bufferView"]: im.get("mimeType", "image/jpeg")
                       for im in j.get("images", []) if "bufferView" in im}

    # --- Lo que no es animación se copia tal cual -------------------------
    accesos_fijos = sorted(_referencias_no_animacion(j))
    vistas_fijas = sorted({v for a in accesos_fijos
                           for v in _vistas_de(j["accessors"][a])}
                          | {im["bufferView"] for im in j.get("images", [])
                             if "bufferView" in im})
    binario = bytearray()
    nueva_vista = {}
    vistas = []
    for vieja in vistas_fijas:
        binario += b"\x00" * ((4 - len(binario) % 4) % 4)
        v = dict(j["bufferViews"][vieja])
        datos = glb.vista(vieja)
        if vieja in vista_de_imagen and lado_textura:
            datos = reducir_textura(datos, vista_de_imagen[vieja], lado_textura)
            v["byteLength"] = len(datos)
        v["byteOffset"] = len(binario)
        v["buffer"] = 0
        binario += datos
        nueva_vista[vieja] = len(vistas)
        vistas.append(v)
    nuevo_acceso = {}
    accesos = []
    for viejo in accesos_fijos:
        a = dict(j["accessors"][viejo])
        # Sin bloque de datos el estándar lo llena de ceros: se copia igual.
        if "bufferView" in a:
            a["bufferView"] = nueva_vista[a["bufferView"]]
        if "sparse" in a:
            dispersos = json.loads(json.dumps(a["sparse"]))
            for parte in ("indices", "values"):
                dispersos[parte]["bufferView"] = nueva_vista[dispersos[parte]["bufferView"]]
            a["sparse"] = dispersos
        nuevo_acceso[viejo] = len(accesos)
        accesos.append(a)
    for malla in j.get("meshes", []):
        for p in malla["primitives"]:
            p["attributes"] = {k: nuevo_acceso[v] for k, v in p["attributes"].items()}
            if "indices" in p:
                p["indices"] = nuevo_acceso[p["indices"]]
            p["targets"] = [{k: nuevo_acceso[v] for k, v in t.items()}
                            for t in p.get("targets", [])] or None
            if p["targets"] is None:
                del p["targets"]
    for piel in j.get("skins", []):
        if "inverseBindMatrices" in piel:
            piel["inverseBindMatrices"] = nuevo_acceso[piel["inverseBindMatrices"]]
    for im in j.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = nueva_vista[im["bufferView"]]

    # --- Animación: un solo bloque, datos compartidos ---------------------
    bloque = bytearray()
    indice_bloque = len(vistas)
    vistas.append({"buffer": 0, "byteOffset": 0, "byteLength": 0})
    por_contenido: dict = {}

    def acceso_animacion(valores: list, tipo: str, rotacion: bool,
                         minimo_maximo: bool) -> int:
        if rotacion:
            enteros = [max(-32767, min(32767, int(round(x * 32767)))) for x in valores]
            datos = array.array("h", enteros).tobytes()
            componente, normalizado = 5122, True
        else:
            datos = array.array("f", valores).tobytes()
            componente, normalizado = 5126, False
        clave = (tipo, componente, datos)
        if clave in por_contenido:
            return por_contenido[clave]
        bloque.extend(b"\x00" * ((4 - len(bloque) % 4) % 4))
        a = {"bufferView": indice_bloque, "byteOffset": len(bloque),
             "componentType": componente, "count": len(valores) // COMPONENTES[tipo],
             "type": tipo}
        if normalizado:
            a["normalized"] = True
        if minimo_maximo:  # los tiempos de entrada exigen min y max
            a["min"] = [min(valores)]
            a["max"] = [max(valores)]
        bloque.extend(datos)
        por_contenido[clave] = len(accesos)
        accesos.append(a)
        return len(accesos) - 1

    quitadas = 0
    for animacion in j["animations"]:
        canales, muestreos = [], []
        duracion = max(glb.leer(s["input"])[-1] for s in animacion["samplers"])
        fin_conservado = 0.0
        for canal in animacion["channels"]:
            destino = canal["target"]
            viejo = animacion["samplers"][canal["sampler"]]
            if _quieta_en_reposo(glb, destino["node"], destino["path"], viejo["output"]):
                quitadas += 1
                continue
            tiempos = glb.leer(viejo["input"])
            fin_conservado = max(fin_conservado, tiempos[-1])
            salida_tipo = glb.json["accessors"][viejo["output"]]["type"]
            nuevo = {
                "input": acceso_animacion(tiempos, "SCALAR", False, True),
                "output": acceso_animacion(glb.leer(viejo["output"]), salida_tipo,
                                           destino["path"] == "rotation", False),
                "interpolation": viejo.get("interpolation", "LINEAR"),
            }
            canales.append({"sampler": len(muestreos), "target": dict(destino)})
            muestreos.append(nuevo)
        if abs(fin_conservado - duracion) > 1e-6:
            raise SystemExit(f"{animacion.get('name')}: quitar pistas acortaría la seña")
        animacion["channels"], animacion["samplers"] = canales, muestreos

    binario += b"\x00" * ((4 - len(binario) % 4) % 4)
    vistas[indice_bloque]["byteOffset"] = len(binario)
    vistas[indice_bloque]["byteLength"] = len(bloque)
    binario += bloque

    j["accessors"], j["bufferViews"] = accesos, vistas
    j["buffers"] = [{"byteLength": len(binario)}]
    resumen = {"pistas_quitadas": quitadas}
    return j, bytes(binario), resumen


# --------------------------------------------------------------------------
# Verificación
# --------------------------------------------------------------------------

def _slerp(a, b, t):
    d = sum(x * y for x, y in zip(a, b))
    if d < 0:
        b, d = [-x for x in b], -d
    if d > 0.9995:
        r = [x + t * (y - x) for x, y in zip(a, b)]
    else:
        th = math.acos(min(1.0, d))
        s = math.sin(th)
        r = [(math.sin((1 - t) * th) * x + math.sin(t * th) * y) / s
             for x, y in zip(a, b)]
    n = math.sqrt(sum(x * x for x in r)) or 1.0
    return [x / n for x in r]


def _evaluar(tiempos, valores, ancho, interp, rotacion, t):
    if t <= tiempos[0]:
        return valores[:ancho]
    if t >= tiempos[-1]:
        return valores[(len(tiempos) - 1) * ancho:len(tiempos) * ancho]
    i = max(k for k in range(len(tiempos)) if tiempos[k] <= t)
    a = valores[i * ancho:(i + 1) * ancho]
    if interp == "STEP" or i + 1 >= len(tiempos):
        return a
    b = valores[(i + 1) * ancho:(i + 2) * ancho]
    u = (t - tiempos[i]) / (tiempos[i + 1] - tiempos[i])
    if rotacion:
        return _slerp(a, b, u)
    return [x + u * (y - x) for x, y in zip(a, b)]


def _error(propiedad, a, b):
    if propiedad == "rotation":
        na = math.sqrt(sum(x * x for x in a)) or 1.0
        nb = math.sqrt(sum(x * x for x in b)) or 1.0
        d = abs(sum(x * y for x, y in zip(a, b))) / (na * nb)
        return math.degrees(2 * math.acos(min(1.0, d)))
    return max(abs(x - y) for x, y in zip(a, b))


def verificar(original: Glb, optimizado: Glb) -> dict:
    """Compara cada seña cuadro a cuadro. Devuelve los errores máximos."""
    jo, jn = original.json, optimizado.json
    for clave in ("nodes", "meshes", "skins", "materials", "textures", "scenes"):
        if len(jo.get(clave, [])) != len(jn.get(clave, [])):
            raise SystemExit(f"cambió el número de {clave}")
    if jo["nodes"] != jn["nodes"]:
        raise SystemExit("cambiaron los nodos")
    from PIL import Image

    for i, (a, b) in enumerate(zip(jo.get("images", []), jn.get("images", []))):
        va, vb = original.vista(a["bufferView"]), optimizado.vista(b["bufferView"])
        if va == vb:
            continue
        ia, ib = Image.open(io.BytesIO(va)), Image.open(io.BytesIO(vb))
        # Solo se admite reducida: mismo formato, misma proporción, más pequeña.
        if (a.get("mimeType") != b.get("mimeType")
                or max(ib.size) >= max(ia.size)
                or abs(ia.width / ia.height - ib.width / ib.height) > 0.01):
            raise SystemExit(f"cambió la textura {i}")
    for i, (ma, mb) in enumerate(zip(jo["meshes"], jn["meshes"])):
        for pa, pb in zip(ma["primitives"], mb["primitives"]):
            pares = [(pa["attributes"][k], pb["attributes"][k]) for k in pa["attributes"]]
            if "indices" in pa:
                pares.append((pa["indices"], pb["indices"]))
            for ta, tb in zip(pa.get("targets", []), pb.get("targets", [])):
                pares += [(ta[k], tb[k]) for k in ta]
            for x, y in pares:
                if _firma(original, x) != _firma(optimizado, y):
                    raise SystemExit(f"cambió la malla {i}")
    for i, (pa, pb) in enumerate(zip(jo.get("skins", []), jn.get("skins", []))):
        if ("inverseBindMatrices" in pa and
                _firma(original, pa["inverseBindMatrices"])
                != _firma(optimizado, pb["inverseBindMatrices"])):
            raise SystemExit(f"cambió el esqueleto {i}")
    nombres_o = [a.get("name") for a in jo["animations"]]
    nombres_n = [a.get("name") for a in jn["animations"]]
    if nombres_o != nombres_n:
        raise SystemExit("cambiaron los nombres u orden de las señas")

    peor = {"translation": 0.0, "rotation": 0.0, "scale": 0.0}
    for ao, an in zip(jo["animations"], jn["animations"]):
        dur_o = max(original.leer(s["input"])[-1] for s in ao["samplers"])
        dur_n = max(optimizado.leer(s["input"])[-1] for s in an["samplers"])
        if abs(dur_o - dur_n) > 1e-6:
            raise SystemExit(f"{ao.get('name')}: cambió la duración")
        nuevos = {}
        for c in an["channels"]:
            s = an["samplers"][c["sampler"]]
            nuevos[(c["target"]["node"], c["target"]["path"])] = (
                optimizado.leer(s["input"]), optimizado.leer(s["output"]),
                s.get("interpolation", "LINEAR"))
        for c in ao["channels"]:
            nodo, prop = c["target"]["node"], c["target"]["path"]
            s = ao["samplers"][c["sampler"]]
            t_o, v_o = original.leer(s["input"]), original.leer(s["output"])
            interp = s.get("interpolation", "LINEAR")
            ancho = len(v_o) // len(t_o)
            instantes = list(t_o) + [(x + y) / 2 for x, y in zip(t_o, t_o[1:])]
            for t in instantes:
                esperado = _evaluar(t_o, v_o, ancho, interp, prop == "rotation", t)
                if (nodo, prop) in nuevos:
                    t_n, v_n, i_n = nuevos[(nodo, prop)]
                    obtenido = _evaluar(t_n, v_n, ancho, i_n, prop == "rotation", t)
                else:
                    obtenido = jn["nodes"][nodo].get(prop, REPOSO[prop])
                peor[prop] = max(peor[prop], _error(prop, esperado, obtenido))
    if peor["rotation"] > TOL_ANGULO:
        raise SystemExit(f"rotación distinta: {peor['rotation']:.5f}°")
    for prop in ("translation", "scale"):
        if peor[prop] > TOL_POSICION:
            raise SystemExit(f"{prop} distinta: {peor[prop]:.2e}")
    return peor


def contar(glb: Glb) -> dict:
    j = glb.json
    return {
        "bytes": 12 + 8 + len(json.dumps(j, separators=(",", ":")).encode()) + 8 + len(glb.bin),
        "json": len(json.dumps(j, separators=(",", ":")).encode()),
        "pistas": sum(len(a["channels"]) for a in j["animations"]),
        "accesos": len(j["accessors"]),
        "vistas": len(j["bufferViews"]),
        "texturas": sum(v["byteLength"] for im in j.get("images", [])
                        if "bufferView" in im
                        for v in [j["bufferViews"][im["bufferView"]]]),
        "señas": len(j["animations"]),
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--entrada", default=MODELO)
    p.add_argument("--salida", default=None)
    p.add_argument("--solo-verificar", nargs=2, metavar=("ORIGINAL", "OPTIMIZADO"))
    p.add_argument("--textura", type=int, default=TEXTURA_MAXIMA,
                   help="lado máximo de las texturas en px (0 = no tocarlas)")
    args = p.parse_args()

    if args.solo_verificar:
        peor = verificar(Glb.abrir(args.solo_verificar[0]), Glb.abrir(args.solo_verificar[1]))
        print(f"idénticos a la vista: {peor}")
        return 0

    original = Glb.abrir(args.entrada)
    documento, binario, resumen = optimizar(original, args.textura)
    datos = escribir_glb(documento, binario)
    optimizado = Glb(datos)
    peor = verificar(original, optimizado)

    antes, despues = contar(original), contar(optimizado)
    for k in antes:
        print(f"{k:>8}: {antes[k]:>10,} -> {despues[k]:>10,}")
    print(f"pistas quitadas (quietas en su reposo): {resumen['pistas_quitadas']:,}")
    print("error máximo: traslación {translation:.2e} m, rotación {rotation:.5f}°, "
          "escala {scale:.2e}".format(**peor))
    salida = args.salida or args.entrada
    with open(salida, "wb") as f:
        f.write(datos)
    print(f"escrito: {os.path.relpath(salida, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
