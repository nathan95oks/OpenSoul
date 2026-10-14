"""Reporte del QA de Conversación → documento de flujos.

    REPORTE_QA=reporte.json flutter test test/qa_conversacion_test.dart ...
    python tool/qa_flujos_md.py reporte.json docs/FLUJOS_CONVERSACION_AAAA-MM-DD.md

Escribe, por cada guion de `test/qa/guiones_conversacion.json`, lo que pasó
en cada turno: qué escribe el funcionario, qué glosas hace el avatar, qué se
abre, qué tarjetas toca la persona sorda y qué vuelve al chat. Las partes que
las escribe una persona (cabecera, observaciones) se leen de `--plantilla`, el
documento anterior; solo se rehacen los turnos.
"""

import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUIONES = os.path.join(ROOT, "test", "qa", "guiones_conversacion.json")
RESPUESTAS = os.path.join(ROOT, "test", "qa", "lambda_respuestas.json")
NADA = ("nada. Es una instrucción o charla, no una pregunta que la persona "
        "sorda deba responder con tarjetas.")
SELECTOR_SOLO = ("el selector de casos (la pregunta sola no dice de qué caso "
                 "se trata)")


def _palabras(frase):
    """Las palabras de lo que dijo el funcionario, en mayúsculas y sin tildes
    (la Ñ se queda)."""
    frase = unicodedata.normalize("NFD", frase.upper())
    # La Ñ es NFD «N» + tilde combinada (U+0303): se junta antes de quitar tildes.
    frase = frase.replace("N\u0303", "\u00d1")
    frase = "".join(c for c in frase if unicodedata.category(c) != "Mn")
    return re.findall(r"[A-Z\u00d10-9]+", frase)


def _separar(letras, palabras):
    """Las letras seguidas del informe son una o más palabras deletreadas;
    cuáles, lo dice la frase: «P-E-R-S-O-N-A-A-C-O-S-A» son PERSONA y ACOSA.
    Se parte en las palabras de la frase, las menos posibles; si no se puede,
    queda como una sola."""
    corrida = "".join(letras)
    conocidas = sorted(set(palabras), key=len, reverse=True)
    mejor = {}

    def partir(i):
        if i == len(corrida):
            return []
        if i in mejor:
            return mejor[i]
        resultado = None
        for w in conocidas:
            if corrida.startswith(w, i):
                resto = partir(i + len(w))
                if resto is not None and (resultado is None
                                          or len(resto) + 1 < len(resultado)):
                    resultado = [w] + resto
        mejor[i] = resultado
        return resultado

    return partir(0) or [corrida]


_GRABADAS = {}


def _palabras_deletreadas(frase):
    """Las palabras que la Lambda grabada dice haber deletreado
    (`fidelityFixes`): «tocó» se deletrea TOCAR, que la frase no trae."""
    if not _GRABADAS and os.path.exists(RESPUESTAS):
        for clave, v in json.load(open(RESPUESTAS, encoding="utf-8")).items():
            if not clave.startswith("texto/translate|"):
                continue
            try:
                texto = json.loads(clave.split("|", 1)[1])["text"]
                fixes = json.loads(v["cuerpo"]).get("fidelityFixes") or []
            except (ValueError, KeyError, TypeError):
                continue
            _GRABADAS.setdefault(texto, set()).update(
                w for f in fixes for w in _palabras(f.get("palabra", "")))
    return _GRABADAS.get(frase, set())


def glosas_del_avatar(glosas, frase=""):
    """«C O N» son letras sueltas: se dicen «deletreo C-O-N»."""
    palabras = _palabras(frase) + sorted(_palabras_deletreadas(frase))
    out, letras = [], []

    def cerrar():
        for w in _separar(letras, palabras):
            out.append("deletreo " + "-".join(w))

    for g in glosas:
        if len(g) == 1 and not g.isdigit():
            letras.append(g)
            continue
        if letras:
            cerrar()
            letras = []
        out.append(g)
    if letras:
        cerrar()
    return " · ".join(out)


def nombres_de_contextos(plantilla, informe, guiones):
    """id de contexto → nombre que ve la persona («denuncia_robo» → «Denunciar
    robo»). Los nombres están en la app, no en el informe; se aprenden del
    documento anterior, turno por turno."""
    viejo = {}
    caso = None
    for linea in plantilla.splitlines():
        m = re.match(r"### (C\d+)$", linea)
        if m:
            caso = m.group(1)
            turno = 0
            continue
        m = re.match(r"\*\*Turno (\d+)", linea)
        if m and caso:
            turno = int(m.group(1))
            continue
        m = re.match(r"- Se abre: «([^»]+)»", linea) or \
            re.match(r"- Toca «Tarjetas LSB» y elige el caso «([^»]+)»", linea) or \
            re.match(r"- Se abre: el selector de casos; la persona sorda elige «([^»]+)»", linea)
        if m and caso:
            viejo[(caso, turno)] = m.group(1)
    nombres = {}
    for c in informe:
        for i, t in enumerate(c["turnos"], 1):
            ctx = (t.get("abre") or {}).get("contexto") or t.get("contexto")
            if ctx is None:
                g = next(x for x in guiones if x["id"] == c["id"])
                ctx = ((g["turnos"][i - 1].get("sorda") or {}).get("contexto")
                       if isinstance(g["turnos"][i - 1].get("sorda"), dict) else None)
            nombre = viejo.get((c["id"], i))
            if ctx and nombre:
                nombres.setdefault(ctx, nombre)
    return nombres


def lineas_anteriores(plantilla):
    """(caso, turno) → su línea «Glosas del avatar» del documento anterior."""
    out, caso, turno = {}, None, 0
    for linea in plantilla.splitlines():
        m = re.match(r"### (C\d+)$", linea)
        if m:
            caso = m.group(1)
            continue
        m = re.match(r"\*\*Turno (\d+)", linea)
        if m:
            turno = int(m.group(1))
            continue
        if linea.startswith("- Glosas del avatar: ") and caso:
            out[(caso, turno)] = linea
    return out


def _huella(linea):
    return re.sub(r"deletreo |[-\s·]", "", linea.split(": ", 1)[1])


def turno_md(c, i, t, guion, nombres, anteriores=None):
    L = []
    if "sorda_inicia" in t:
        L += [f"**Turno {i} — empieza la persona sorda**", "",
              f"- Toca «Tarjetas LSB» y elige el caso «{nombres[t['contexto']]}»."]
    else:
        L += [f"**Turno {i}**", "", f"- Caja de texto (funcionario): «{t['oyente']}»"]
        if "rechazado" in t:
            L.append(f"- La app no lo envía y avisa: «{t['rechazado']}»")
            return L
        linea = f"- Glosas del avatar: {glosas_del_avatar(t['glosas'], t['oyente'])}"
        # Si dice lo mismo que el documento anterior, se conserva cómo partió
        # las palabras deletreadas: la separación no está en el informe.
        antes = (anteriores or {}).get((c["id"], i))
        if antes and _huella(antes) == _huella(linea):
            linea = antes
        L.append(linea)
        abre = t["abre"]
        tarjetas = t.get("tarjetas") or []
        if abre["contexto"] is None:
            if tarjetas:
                ctx = guion["turnos"][i - 1]["sorda"]["contexto"]
                L.append("- Se abre: el selector de casos; la persona sorda "
                         f"elige «{nombres[ctx]}»")
            elif (t.get("sorda") or "").startswith("(elige"):
                L.append(f"- Se abre: {SELECTOR_SOLO}")
            else:
                L.append(f"- Se abre: {NADA}")
        else:
            preguntas = abre["preguntas"]
            L.append(f"- Se abre: «{nombres[abre['contexto']]}», pregunta "
                     f"«{preguntas[0]['formulacion']}»" if preguntas else
                     f"- Se abre: «{nombres[abre['contexto']]}»")
            for p in preguntas[1:]:
                L.append(f"  - también: «{p['formulacion']}»")
    if "sorda_inicia" in t:
        for tj in t["tarjetas"]:
            L.append(f"- Tarjeta: «{tj['tarjeta']}» [{' · '.join(tj['glosas'])}]"
                     f" — responde a «{tj['pregunta']}»")
        L.append(f"- Vuelve al chat: «{t['sorda_inicia']}»")
        return L
    for tj in t.get("tarjetas") or []:
        L.append(f"- Tarjeta: «{tj['tarjeta']}» [{' · '.join(tj['glosas'])}]"
                 f" — responde a «{tj['pregunta']}»")
    contestadas = {tj["pregunta"] for tj in t.get("tarjetas") or []}
    pide_dato = any(
        re.search(r"nombre|número|monto|cuánto|cuanto", p["formulacion"], re.I)
        for p in t["abre"]["preguntas"] if p["formulacion"] not in contestadas)
    if t["abre"]["contexto"] and (not t.get("tarjetas") or pide_dato):
        L.append("- Vuelve al chat: la persona sorda tiene que escribir el dato "
                 "en la tarjeta (nombre, número, monto…); la prueba no lo escribe.")
    if t.get("tarjetas") and t.get("sorda"):
        L.append(f"- Vuelve al chat: «{t['sorda']}»")
        if t.get("glosas_sorda"):
            L.append(f"  - glosas de la respuesta: {' · '.join(t['glosas_sorda'])}")
    return L


def main(argv):
    informe = json.load(open(argv[1], encoding="utf-8"))
    destino = argv[2]
    plantilla = open(argv[3] if len(argv) > 3 else destino, encoding="utf-8").read()
    guiones = json.load(open(GUIONES, encoding="utf-8"))["conversaciones"]
    nombres = nombres_de_contextos(plantilla, informe, guiones)
    anteriores = lineas_anteriores(plantilla)
    casos = {}
    for c in informe:
        g = next(x for x in guiones if x["id"] == c["id"])
        L = [f"### {c['id']}", "", f"**{c['titulo']}**", ""]
        for i, t in enumerate(c["turnos"], 1):
            L += turno_md(c, i, t, g, nombres, anteriores) + [""]
        casos[c["id"]] = "\n".join(L).rstrip() + "\n"
    # Se reemplaza cada «### Cxx» del documento por el rehecho, en su lugar.
    partes = re.split(r"(?m)^(?=### C\d+$)", plantilla)
    salida = []
    for p in partes:
        m = re.match(r"### (C\d+)$", p, re.M)
        if not m:
            salida.append(p)
            continue
        resto = ""
        corte = re.search(r"(?m)^## ", p)
        if corte:
            resto = p[corte.start():]
        salida.append(casos[m.group(1)] + "\n" + resto)
    open(destino, "w", encoding="utf-8").write("".join(salida))


if __name__ == "__main__":
    main(sys.argv)
