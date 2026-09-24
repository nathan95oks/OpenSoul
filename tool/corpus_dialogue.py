"""Lectura del corpus maestro y resolución de sus conceptos contra la app.

Fuente: `docs/Corpus_Maestro_Unificado_LSB_v4_Auditado (2).md`, secciones 6, 7 y
8 (98 preguntas del funcionario, 60 del ciudadano y 51 declaraciones) y la
sección 12 (303 glosas del apéndice).

Lo que el corpus llama «conceptos LSB objetivo» es un objetivo semántico, no
una secuencia validada ni prueba de que exista una animación. Este módulo
mantiene separadas las cuatro cosas que el encargo pide no confundir:

  - concepto del corpus            (lo que hay que decir)
  - glosa del catálogo de la app   (lo que se puede elegir en pantalla)
  - mecanismo de representación    (seña directa, dactilología, número)
  - recurso de avatar              (lo que el .glb sabe ejecutar)

Se usa desde `tool/build_dialogue_graph.py` y desde las pruebas de cobertura.
"""

from __future__ import annotations

import json
import os
import re
import unicodedata
from dataclasses import dataclass, field, asdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CORPUS_PATH = os.path.join(
    ROOT, "docs", "Corpus_Maestro_Unificado_LSB_v4_Auditado (2).md"
)
CORPUS_FALLBACK = os.path.join(
    ROOT, "docs", "Corpus_Maestro_Unificado_LSB_v4_Auditado.md"
)
DICTIONARY_PATH = os.path.join(
    ROOT, "assets", "dictionary", "official_dictionary.json"
)
RESOLVER_PATH = os.path.join(
    ROOT, "lib", "core", "domain", "services", "animation_url_resolver.dart"
)

# Estados de cobertura, en el vocabulario que pide el encargo.
DIRECT_SIGN = "direct_sign"
DACTYLOLOGY = "dactylology"
VALIDATED_COMPOSITION = "validated_composition"
NEEDS_VALIDATION = "needs_validation"
UNSUPPORTED = "unsupported"

# Mecanismos que no son glosas del catálogo pero sí recursos reales.
MECHANISM_NUMBER = "number"
MECHANISM_SPELLING = "spelling"


def strip_accents(s: str) -> str:
    return "".join(
        c for c in unicodedata.normalize("NFD", s)
        if unicodedata.category(c) != "Mn"
    )


def norm(s: str) -> str:
    """Clave de comparación: sin tildes, sin signos, en mayúsculas.

    La Ñ se conserva: es una letra del alfabeto dactilológico, no un acento.
    """
    s = s.replace("Ñ", "\u0001").replace("ñ", "\u0001")
    s = strip_accents(s).upper().replace("\u0001", "Ñ")
    s = s.replace("¿", "").replace("?", "").replace("¡", "").replace("!", "")
    s = re.sub(r"[\-\s]+", "_", s.strip())
    return s.strip("_")


# --------------------------------------------------------------------------
# Corpus
# --------------------------------------------------------------------------

def corpus_path() -> str:
    return CORPUS_PATH if os.path.exists(CORPUS_PATH) else CORPUS_FALLBACK


def _clean_cell(c: str) -> str:
    c = c.replace("**", "")
    c = c.replace("\\#", "#").replace("\\[", "[").replace("\\]", "]")
    c = c.replace("\\", "")
    c = re.sub(r"\s+", " ", c)
    return c.strip()


def _read_tables(text: str, start: int, end: int, default_subsection: str = ""):
    """Devuelve [(subseccion, [fila, ...]), ...] entre dos líneas del archivo.

    La sección 8 no lleva encabezados `##`: su tabla cuelga directamente del
    título de sección, así que recibe un nombre por defecto en vez de dejar
    nodos sin procedencia legible.
    """
    lines = text.split("\n")[start - 1:end - 1]
    out, subsection, header, rows = [], default_subsection, None, []

    def flush():
        if header and rows:
            out.append((subsection, list(rows)))

    for line in lines:
        s = line.strip()
        if s.startswith("## "):
            flush()
            header, rows = None, []
            subsection = _clean_cell(s[3:])
            continue
        if s.startswith("|") and s.endswith("|"):
            cells = [_clean_cell(c) for c in s.strip("|").split("|")]
            if all(set(c) <= set("-: ") for c in cells):
                continue
            if header is None:
                header = cells
                continue
            rows.append(dict(zip(header, cells)))
        elif header is not None and not s:
            continue
    flush()
    return out


# Límites de sección, localizados por su encabezado para no depender de
# números de línea que cambian al reformatear el documento.
SECTION_TITLES = {
    6: "# 6. Banco ampliado de preguntas del funcionario/receptor",
    7: "# 7. Banco ampliado de preguntas del ciudadano sordo",
    8: "# 8. Declaraciones y respuestas frecuentes del ciudadano sordo",
    9: "# 9. Escenarios funcionales cubiertos",
    12: "# 12. Diccionario maestro",
    13: "# 13. Fuentes y trazabilidad",
}


def _section_bounds(text: str, number: int) -> tuple:
    lines = text.split("\n")
    wanted = SECTION_TITLES[number]

    def find(prefix):
        for i, l in enumerate(lines):
            if _clean_cell(l).startswith(prefix):
                return i + 1
        return None

    start = find(wanted)
    if start is None:
        raise SystemExit(f"No se encontró la sección {number} en el corpus.")
    nxt = None
    for i, l in enumerate(lines[start:], start=start):
        if _clean_cell(l).startswith("# ") and not _clean_cell(l).startswith(wanted):
            nxt = i + 1
            break
    return start, (nxt or len(lines) + 1)


# Marcadores gramaticales que el corpus escribe entre barras: no son glosas
# que elegir sino rasgos del enunciado (polaridad, condicionalidad). Se
# extraen antes de trocear la celda para que no se confundan con
# alternativas léxicas ni con una glosa inexistente.
MARKERS = {
    "/neg/": "negation",
    "/cond/": "condition",
    "/interr/": "interrogative",
}


@dataclass
class CorpusEntry:
    """Una intervención de ejemplo de los bancos 6, 7 u 8."""
    entry_id: str
    section: int
    subsection: str
    number: int
    spanish: str
    intent: str
    concepts_raw: str
    note: str
    speaker: str  # 'hearing' | 'deaf'
    speech_act: str  # 'question' | 'statement'


def load_corpus_entries() -> list:
    text = open(corpus_path(), encoding="utf-8").read()
    entries = []

    for section, speaker, act in ((6, "hearing", "question"),
                                  (7, "deaf", "question"),
                                  (8, "deaf", "statement")):
        a, b = _section_bounds(text, section)
        default = ("Declaraciones y respuestas frecuentes"
                   if section == 8 else "")
        for subsection, rows in _read_tables(text, a, b, default):
            for row in rows:
                spanish = (row.get("Pregunta en español")
                           or row.get("Pregunta del ciudadano")
                           or row.get("Declaración/respuesta")
                           or row.get("Frase en español")
                           or "")
                intent = (row.get("Intención") or row.get("Intencion") or "")
                concepts = (row.get("Conceptos LSB objetivo")
                            or row.get("Conceptos/glosas objetivo")
                            or row.get("Conceptos objetivo") or "")
                note = (row.get("Estado/nota") or row.get("Estado") or "")
                number = row.get("#") or row.get("\\#") or "0"
                if not spanish:
                    continue
                try:
                    n = int(re.sub(r"\D", "", number) or 0)
                except ValueError:
                    n = 0
                entries.append(CorpusEntry(
                    entry_id=f"S{section}-{norm(subsection)[:18]}-{n:02d}",
                    section=section,
                    subsection=subsection,
                    number=n,
                    spanish=spanish,
                    intent=intent or "SIN_INTENCION",
                    concepts_raw=concepts,
                    note=note,
                    speaker=speaker,
                    speech_act=act,
                ))
    return entries


def load_corpus_glosses() -> dict:
    """Las 303 glosas del apéndice 12, indexadas por clave normalizada."""
    text = open(corpus_path(), encoding="utf-8").read()
    a, b = _section_bounds(text, 12)
    out = {}
    for _, rows in _read_tables(text, a, b):
        for row in rows:
            gloss = row.get("Glosa") or ""
            if not gloss:
                continue
            out[norm(gloss)] = {
                "gloss": gloss,
                "spanish": row.get("Español/Fuente léxica", ""),
                "sourceId": row.get("ID", ""),
                "reference": row.get("Referencia", ""),
                "audit": row.get("Auditoría", ""),
            }
    return out


def load_pending_concepts() -> dict:
    """Sección 4: conceptos jurídicos sin correspondencia directa segura."""
    text = open(corpus_path(), encoding="utf-8").read()
    lines = text.split("\n")
    start = next(i for i, l in enumerate(lines)
                 if _clean_cell(l).startswith("# 4. Conceptos jurídicos")) + 1
    end = next(i for i, l in enumerate(lines[start:], start=start)
               if _clean_cell(l).startswith("# 5.")) + 1
    out = {}
    for _, rows in _read_tables(text, start, end):
        for row in rows:
            concept = row.get("Concepto", "")
            if not concept:
                continue
            for part in concept.split("/"):
                out[norm(part)] = {
                    "concept": concept,
                    "status": row.get("Estado", ""),
                    "treatment": row.get("Tratamiento seguro para el software", ""),
                }
    return out


# --------------------------------------------------------------------------
# Catálogo de la app y avatar
# --------------------------------------------------------------------------

def load_app_glosses() -> dict:
    doc = json.load(open(DICTIONARY_PATH, encoding="utf-8"))
    out = {}
    for e in doc["entries"]:
        out[norm(e["gloss"])] = e
        canonical = e.get("canonicalGloss")
        if canonical:
            out.setdefault(norm(canonical), e)
    return out


def _dart_string_set(name: str, source: str) -> set:
    m = re.search(name + r"\s*=\s*\{(.*?)\};", source, re.DOTALL)
    if not m:
        return set()
    return {g.strip().strip("'\"") for g in re.findall(r"'([^']*)'", m.group(1))}


def load_avatar_inventory() -> dict:
    """Lo que el avatar sabe ejecutar de verdad, leído del resolutor real.

    No se cuentan las entradas con `animationFile` del diccionario: ese campo
    no demuestra que la animación exista en el .glb empaquetado.
    """
    source = open(RESOLVER_PATH, encoding="utf-8").read()
    return {
        "baked": _dart_string_set("available3DGlosses", source),
        "spelled": _dart_string_set("wordsToSpell", source),
    }


# --------------------------------------------------------------------------
# Resolución de conceptos
# --------------------------------------------------------------------------

NUMBER_RE = re.compile(r"^(NUM|NÚM)\(")

@dataclass
class ConceptResolution:
    concept: str
    status: str
    mechanism: str = ""
    app_gloss: str = ""
    corpus_source: str = ""
    avatar: str = "placeholder"  # 'baked' | 'spelled' | 'placeholder'
    reason: str = ""
    alternatives: list = field(default_factory=list)


class ConceptResolver:
    def __init__(self):
        self.app = load_app_glosses()
        self.corpus = load_corpus_glosses()
        self.pending = load_pending_concepts()
        avatar = load_avatar_inventory()
        self.baked = {norm(g) for g in avatar["baked"]}
        self.spelled = {norm(g) for g in avatar["spelled"]}

    def _avatar_state(self, key: str) -> str:
        if key in self.baked:
            return "baked"
        if key in self.spelled:
            return "spelled"
        return "placeholder"

    def resolve_token(self, token: str) -> ConceptResolution:
        raw = token.strip()
        if not raw:
            return ConceptResolution(concept=raw, status=UNSUPPORTED,
                                     reason="token vacío")

        # Alternativas del corpus: "VENIR / ACOMPAÑAR".
        if "/" in raw:
            parts = [p for p in (p.strip() for p in raw.split("/")) if p]
            resolutions = [self.resolve_token(p) for p in parts]
            best = min(resolutions, key=lambda r: _STATUS_RANK[r.status])
            best.alternatives = [r.concept for r in resolutions
                                 if r.concept != best.concept]
            return best

        # Concepto marcado como pendiente por el propio corpus: [DENUNCIA].
        bracketed = raw.startswith("[") and raw.endswith("]")
        inner = raw[1:-1] if bracketed else raw

        # Mecanismo de número: NÚM(1), NÚM(...).
        if NUMBER_RE.match(norm(inner).replace("_", "")) or NUMBER_RE.match(inner):
            return ConceptResolution(
                concept=raw, status=DIRECT_SIGN, mechanism=MECHANISM_NUMBER,
                app_gloss="", avatar="baked",
                reason="mecanismo de número; el avatar trae CERO..DIEZ",
            )

        # Dactilología explícita del corpus: d(FISCALÍA).
        m = re.match(r"^d\((.+)\)$", inner.strip(), re.IGNORECASE)
        if m:
            return ConceptResolution(
                concept=raw, status=DACTYLOLOGY, mechanism=MECHANISM_SPELLING,
                app_gloss="", avatar="spelled",
                reason="dactilología pedida por el corpus",
            )

        key = norm(inner)

        if bracketed or key in self.pending:
            info = self.pending.get(key)
            if key in self.spelled:
                return ConceptResolution(
                    concept=raw, status=DACTYLOLOGY,
                    mechanism=MECHANISM_SPELLING, avatar="spelled",
                    reason=(info or {}).get("treatment",
                                            "concepto pendiente de validación"),
                )
            return ConceptResolution(
                concept=raw, status=NEEDS_VALIDATION,
                avatar=self._avatar_state(key),
                reason=(info or {}).get(
                    "treatment",
                    "el corpus lo marca como concepto, no como seña directa"),
            )

        entry = self.app.get(key)
        if entry is not None:
            return ConceptResolution(
                concept=raw, status=DIRECT_SIGN, app_gloss=entry["gloss"],
                corpus_source=self.corpus.get(key, {}).get("sourceId", ""),
                avatar=self._avatar_state(key),
                reason="presente en el catálogo de la app",
            )

        if key in self.corpus:
            return ConceptResolution(
                concept=raw, status=NEEDS_VALIDATION,
                corpus_source=self.corpus[key]["sourceId"],
                avatar=self._avatar_state(key),
                reason="documentada en el corpus pero ausente del catálogo "
                       "que carga la app",
            )

        if key in self.spelled:
            return ConceptResolution(
                concept=raw, status=DACTYLOLOGY, mechanism=MECHANISM_SPELLING,
                avatar="spelled",
                reason="se deletrea; no hay seña directa documentada",
            )

        return ConceptResolution(
            concept=raw, status=UNSUPPORTED,
            avatar=self._avatar_state(key),
            reason="ni en el catálogo, ni en el corpus, ni deletreable",
        )

    def markers_in(self, cell: str) -> list:
        return [name for token, name in MARKERS.items() if token in cell]

    def resolve_cell(self, cell: str) -> list:
        """Resuelve una celda «conceptos LSB objetivo» completa."""
        if not cell:
            return []
        cell = cell.replace("→", "·")
        for token in MARKERS:
            cell = cell.replace(token, " ")
        tokens = [t for t in (t.strip() for t in re.split(r"[·+]", cell)) if t]
        return [self.resolve_token(t) for t in tokens]


_STATUS_RANK = {
    DIRECT_SIGN: 0,
    VALIDATED_COMPOSITION: 1,
    DACTYLOLOGY: 2,
    NEEDS_VALIDATION: 3,
    UNSUPPORTED: 4,
}


def entry_status(resolutions: list) -> str:
    """Estado de una intervención entera: manda el eslabón más débil."""
    if not resolutions:
        return UNSUPPORTED
    worst = max(resolutions, key=lambda r: _STATUS_RANK[r.status])
    return worst.status


def resolution_to_json(r: ConceptResolution) -> dict:
    return asdict(r)
