"""Redacción de una intervención guiada a partir de respuestas tipadas.

Gemelo exacto de `lib/core/domain/guided/guided_composer.dart`. Los dos leen
el mismo banco (`question_bank.json`, generado por
`tool/build_question_matrix.py` desde `docs/negocio/config/banco_preguntas.json`)
y deben producir la misma oración para las mismas respuestas: lo comprueban
los fixtures que escribe el cliente (`test/fixtures/guided/`) y que
`aws/tests/test_guiado_v4.py` pasa por el handler.

Nada aquí interpreta ni completa: cada oración sale de la plantilla de la
opción elegida y de los valores escritos por la persona. Si una respuesta no
está, no se redacta; si es «no sé», se redacta «no sé».
"""

from __future__ import annotations

import json
import os
import re

BANK_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "question_bank.json")

_TOKEN = re.compile(r"\{([^{}]+)\}")

# Qué clave de valor rellena cada editor.
EDITOR_KEYS = {
    "texto_nombre": ("nombre",),
    "telefono": ("telefono",),
    "entero": ("n",),
    "edad": ("n",),
    "monto": ("monto", "moneda"),
    "texto_detalle": ("texto",),
    "lugar_literal": ("nombre",),
    "referencia": ("referencia",),
    "documento_numero": ("numero",),
    "hora": ("hora",),
}

ESTADOS = ("afirmado", "negado", "desconocido", "omitido")
PROPOSITOS = ("standalone", "initiative", "reply")


def load_bank(path: str = BANK_PATH) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def join_es(items: list, espacio: bool = False) -> str:
    items = [i for i in items if i]
    if espacio:
        return " ".join(items)
    if not items:
        return ""
    if len(items) == 1:
        return items[0]
    return ", ".join(items[:-1]) + " y " + items[-1]


def _normalize(text: str) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"\s+([.,;:?!»])", r"\1", text)
    text = re.sub(r"«\s+", "«", text)
    return text


def _capitalize(text: str) -> str:
    if not text:
        return text
    return text[0].upper() + text[1:]


class Composer:
    def __init__(self, bank: dict):
        self.bank = bank
        self.questions = {q["id"]: q for q in bank["preguntas"]}

    # ------------------------------------------------------------------
    def compose(self, guided: dict) -> str:
        return self.compose_traced(guided)[0]

    def confirmed_facts(self, guided: dict) -> set:
        """Opciones elegidas (no omitidas) que redactan algo, `'Q.ID#opcion'`.

        Gemelo de `GuidedComposer.confirmedFacts`. Las opciones que no
        redactan nada solo abren la pregunta que lleva el hecho.
        """
        out = set()
        for a in guided.get("respuestas") or []:
            if a.get("estado") == "omitido":
                continue
            q = self.questions.get(a.get("pregunta"))
            if q is None:
                continue
            for o in self._chosen(q, a):
                if _writes_something(o):
                    out.add(f"{a['pregunta']}#{o['id']}")
        return out

    def compose_traced(self, guided: dict) -> tuple:
        """(texto, opciones representadas). Gemelo de `composeTraced`."""
        self._answers = {}
        for a in guided.get("respuestas") or []:
            self._answers[a["pregunta"]] = a
        self._consumed = set()
        self._represented = set()
        self._reply = guided.get("proposito") == "reply"
        referenced = self._referenced_fragments()
        sentences = []

        for qid in self._order(guided):
            if qid in self._consumed:
                continue
            a = self._answers.get(qid)
            if not a or a.get("estado") == "omitido":
                continue
            q = self.questions.get(qid)
            if q is None:
                continue
            self._extras = []
            # Lo que se marque al redactar esta frase solo cuenta si la frase
            # llega al texto.
            antes = set(self._represented)
            if q.get("modo") == "fragmento":
                # Lo redacta la pregunta que lo cita; solo si ninguna lo cita
                # se usa su frase suelta.
                if qid in referenced:
                    continue
                frag = self._fragment(qid)
                if frag is None or not q.get("fraseSuelta"):
                    self._represented = antes
                    sentences.extend(self._finalize(e) for e in self._extras)
                    continue
                text = q["fraseSuelta"].replace("{frag}", frag)
            else:
                self._consumed.add(qid)
                text = self._sentence(q, a)
            text = self._finalize(text)
            if text:
                sentences.append(text)
            else:
                self._represented = antes
            sentences.extend(self._finalize(e) for e in self._extras)
        return " ".join(s for s in sentences if s), set(self._represented)

    def _referenced_fragments(self) -> set:
        """Preguntas en modo fragmento citadas por alguna respuesta elegida."""
        out = set()
        for qid, a in self._answers.items():
            q = self.questions.get(qid)
            if q is None or a.get("estado") == "omitido":
                continue
            for o in self._chosen(q, a):
                for token in _TOKEN.findall(self._phrase_of(o, a)):
                    if not token.startswith(("Q.", "I.")):
                        continue
                    ref = token.partition("|")[0]
                    target, atributo = self._resolve_ref(ref)
                    if target is None or atributo:
                        continue
                    ra = self._answers.get(target)
                    if (self.questions[target].get("modo") == "fragmento"
                            and ra and ra.get("estado") != "omitido"):
                        out.add(target)
        return out

    # ------------------------------------------------------------------
    def _order(self, guided: dict) -> list:
        orden = []
        rec = self.bank.get("recorridos", {}).get(guided.get("recorrido") or "")
        if rec:
            base = rec.get("ordenRedaccion") or [p["pregunta"] for p in rec["pasos"]]
        else:
            base = list(guided.get("pasos") or [])
        for qid in base:
            if qid not in orden:
                orden.append(qid)
        for a in guided.get("respuestas") or []:
            if a["pregunta"] not in orden:
                orden.append(a["pregunta"])
        return orden

    def _chosen(self, q: dict, a: dict) -> list:
        elegidas = set(a.get("opciones") or [])
        return [o for o in q.get("opciones", []) if o["id"] in elegidas]

    def _values(self, a: dict, o: dict) -> dict:
        return ((a.get("valores") or {}).get(o["id"])) or {}

    def _has_values(self, o: dict, vals: dict) -> bool:
        claves = EDITOR_KEYS.get(o.get("editor") or "", ())
        return bool(claves) and all(str(vals.get(k, "")).strip() for k in claves)

    def _phrase_of(self, o: dict, a: dict) -> str:
        vals = self._values(a, o)
        if o.get("editor"):
            if o.get("fraseSingular") and str(vals.get("n", "")) == "1":
                return o["fraseSingular"]
            if not self._has_values(o, vals) and o.get("fraseSinValor") is not None:
                return o["fraseSinValor"]
        return o.get("frase") or ""

    def _sentence(self, q: dict, a: dict) -> str:
        chosen = self._chosen(q, a)
        if not chosen:
            return ""
        salida = any(o.get("salida") for o in chosen)
        partes = []
        for o in chosen:
            texto = self._fill(o, self._phrase_of(o, a), a)
            if texto:
                partes.append(texto)
                self._represented.add(f"{a['pregunta']}#{o['id']}")
            if o.get("fraseExtra"):
                self._extras.append(o["fraseExtra"])
        if not partes:
            return ""
        if q.get("plantilla") and not salida:
            unidas = join_es(partes, espacio=q.get("unir") == "espacio")
            return q["plantilla"].replace("{items}", unidas)
        return " ".join(partes)

    def _fragment(self, qid: str):
        a = self._answers.get(qid)
        if not a or a.get("estado") == "omitido":
            return None
        q = self.questions.get(qid)
        if q is None:
            return None
        self._consumed.add(qid)
        partes = []
        for o in self._chosen(q, a):
            texto = self._fill(o, self._phrase_of(o, a), a)
            if texto:
                partes.append(texto)
                self._represented.add(f"{qid}#{o['id']}")
            if o.get("fraseExtra"):
                self._extras.append(o["fraseExtra"])
        if not partes:
            return None
        return join_es(partes)

    def _resolve_ref(self, ref: str):
        partes = ref.split(".")
        for n in range(len(partes), 1, -1):
            qid = ".".join(partes[:n])
            if qid in self.questions:
                return qid, ".".join(partes[n:])
        return None, None

    def _fill(self, o: dict, template: str, a: dict) -> str:
        vals = self._values(a, o)
        mencion = (a.get("mencion") or {}).get("frase") or ""

        def sustituir(m):
            token = m.group(1)
            if token.startswith(("Q.", "I.")):
                ref, _, respaldo = token.partition("|")
                qid, atributo = self._resolve_ref(ref)
                if qid is None:
                    return respaldo
                if atributo:
                    ra = self._answers.get(qid)
                    if not ra or ra.get("estado") != "afirmado":
                        return respaldo
                    for elegida in self._chosen(self.questions[qid], ra):
                        if elegida.get(atributo):
                            return elegida[atributo]
                    return respaldo
                ra = self._answers.get(qid)
                if not ra or ra.get("estado") in ("omitido",):
                    return respaldo
                frag = self._fragment(qid)
                return frag if frag else respaldo
            if token == "aprox":
                return "aproximadamente " if vals.get("aprox") == "si" else ""
            if token == "mencionado":
                return mencion or "eso"
            if token.startswith("?"):
                v = str(vals.get(token[1:], "")).strip()
                return " " + v if v else ""
            return str(vals.get(token, "")).strip()

        return _TOKEN.sub(sustituir, template)

    def _finalize(self, text: str) -> str:
        text = _normalize(text)
        if not text:
            return ""
        if not self._reply:
            for prefijo in ("Sí, ", "No, "):
                if text.startswith(prefijo):
                    text = text[len(prefijo):]
                    break
        text = _capitalize(text)
        if text[-1] not in ".?!":
            text += "."
        return text


def _writes_something(o: dict) -> bool:
    return any(str(o.get(k) or "").strip()
               for k in ("frase", "fraseSinValor", "fraseSingular"))


def compose(guided: dict, bank: dict = None) -> str:
    return Composer(bank or load_bank()).compose(guided)
