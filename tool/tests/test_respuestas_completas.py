"""Respuestas completas en «Trámites» (tarjetas LSB).

    python -m pytest tool/tests/test_respuestas_completas.py -q

Lo que se promete: una respuesta de sí o no dice de qué se trata (no «Sí.» a
secas), una indicación se puede contestar diciendo cuál, «¿Trajo algún
documento…?» se detalla con tarjetas por institución, y nada de eso agrega
vocabulario: solo palabras que el corpus ya usa y las señas de siempre.

Sin red.
"""

import json
import os
import re
import sys
import unicodedata
import unittest

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))

import auditar_tramites as A  # noqa: E402
import build_rag_corpus as B  # noqa: E402

CORPUS, BANCO = A.cargar()
DATOS = json.load(open(B.AMPLIADAS, encoding="utf-8"))
PREGUNTAS = BANCO["preguntas"]
POLARES = [q for q in PREGUNTAS if q["control"] == "polar3"]
VOCAB = B.palabras_del_corpus(CORPUS)


def _norm(s: str) -> str:
    s = unicodedata.normalize("NFD", s.lower())
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def palabras(texto: str) -> set:
    return set(re.findall(r"[a-zñ]{3,}", _norm(texto)))


class RespuestasDeSiONo(unittest.TestCase):
    def test_ninguna_respuesta_es_una_particula_suelta(self):
        for q in POLARES:
            for o in q["opciones"]:
                with self.subTest(f"{q['id']} {o['id']}"):
                    self.assertNotRegex(o["frase"], r"^(Sí|No|No sé)\.$")

    def test_cada_respuesta_dice_algo_de_lo_preguntado(self):
        """Toda respuesta afirmada o negada repite alguna palabra con
        contenido de la pregunta: «Sí, tengo abogado para este caso.»."""
        sin = {"tiene", "tienen", "para", "este", "esta", "esto", "usted",
               "sobre", "como", "tengo"}
        for q in POLARES:
            clave = {_norm(w)[:5] for w in re.findall(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{4,}",
                                                       q["formulacion"])
                     if _norm(w) not in sin}
            if not clave:
                continue
            for o in q["opciones"]:
                if o["estado"] == "desconocido":
                    continue
                dichas = {_norm(w)[:5] for w in re.findall(
                    r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{4,}", o["frase"])}
                with self.subTest(f"{q['id']} {o['id']}"):
                    self.assertTrue(clave & dichas,
                                    f"«{q['formulacion']}» → «{o['frase']}»")

    def test_las_tarjetas_siguen_siendo_si_no_y_no_se(self):
        for q in POLARES:
            with self.subTest(q["id"]):
                self.assertEqual([(o["id"], o["glosas"]) for o in q["opciones"]],
                                 [("si", ["SÍ"]), ("no", ["NO"]),
                                  ("no_se", ["NO_SABER"])])
                self.assertEqual([o["estado"] for o in q["opciones"]],
                                 ["afirmado", "negado", "desconocido"])

    def test_el_estado_de_cada_frase_es_el_de_su_tarjeta(self):
        inicio = {"afirmado": ("sí", "si"), "negado": ("no",),
                  "desconocido": ("no sé", "no se", "no recuerdo")}
        for q in POLARES:
            for o in q["opciones"]:
                with self.subTest(f"{q['id']} {o['id']}"):
                    self.assertTrue(_norm(o["frase"]).startswith(
                        tuple(_norm(x) for x in inicio[o["estado"]])),
                        o["frase"])

    def test_las_preguntas_de_documentos_ya_no_se_contestan_traje_documentos(self):
        docs = [q for q in POLARES
                if q["formulacion"] == "¿Trajo algún documento relacionado con su solicitud?"]
        self.assertGreaterEqual(len(docs), 30)
        for q in docs:
            self.assertEqual(q["opciones"][0]["frase"],
                             "Sí, traje documentos relacionados con mi solicitud.")


class SinVocabularioNuevo(unittest.TestCase):
    def test_toda_frase_ampliada_usa_palabras_del_corpus(self):
        frases = [f for r in DATOS["respuestas"].values() for f in r.values()]
        frases += [f.replace("{indicacion}", "")
                   for f in DATOS["indicacion"].values()]
        frases += [d["frase"] for lst in DATOS["documentos"].values() for d in lst]
        frases += [v["pregunta"] for v in DATOS["preguntas_de_documentos"].values()]
        for f in frases:
            with self.subTest(f):
                self.assertLessEqual(palabras(f) - VOCAB, set())

    def test_las_palabras_sin_sena_son_las_de_siempre(self):
        """Ampliar respuestas no toca el diccionario de palabras sin seña."""
        with open(os.path.join(B.ROOT, "assets", "dictionary",
                               "senas_sin_sena.json"), encoding="utf-8") as f:
            actual = json.load(f)
        self.assertEqual(sorted(actual["palabras"]),
                         sorted(B.info_sin_sena(CORPUS, [], [])["palabras"]))

    def test_las_glosas_de_las_tarjetas_nuevas_son_senas_conocidas(self):
        for q in PREGUNTAS:
            if q["id"].endswith(".docs") or q["acto"] == "indicacion":
                for o in q["opciones"]:
                    with self.subTest(f"{q['id']} {o['id']}"):
                        self.assertEqual(B.glosas_invalidas(o["glosas"]), [])
                        self.assertFalse(
                            any(g.startswith(B.SENA_PENDIENTE) for g in o["glosas"]))


class Indicaciones(unittest.TestCase):
    INDICACIONES = [q for q in PREGUNTAS if q["acto"] == "indicacion"
                    and any(o["id"] == "entendido" for o in q["opciones"])]

    def test_hay_indicaciones(self):
        self.assertGreaterEqual(len(self.INDICACIONES), 40)

    def test_entendido_y_no_entiendo_no_cambian(self):
        for q in self.INDICACIONES:
            ids = [o["id"] for o in q["opciones"]]
            with self.subTest(q["id"]):
                self.assertEqual(ids[:2], ["entendido", "no_entiendo"])
                self.assertEqual(q["opciones"][0]["frase"], "Entendido.")
                self.assertEqual(q["opciones"][1]["frase"], "No entiendo.")
                self.assertEqual(q["opciones"][0]["glosas"], ["COMPRENDER"])
                self.assertEqual(q["opciones"][1]["glosas"], ["COMPRENDER", "NO"])

    def test_se_puede_contestar_diciendo_cual_es_la_indicacion(self):
        for q in self.INDICACIONES:
            por_id = {o["id"]: o for o in q["opciones"]}
            ind = q["formulacion"].strip().rstrip(".!")
            with self.subTest(q["id"]):
                si, no = (por_id["respuesta_con_contexto_si"],
                          por_id["respuesta_con_contexto_no"])
                self.assertIn(f"«{ind}»", si["frase"])
                self.assertIn(f"«{ind}»", no["frase"])
                self.assertEqual(si["estado"], "afirmado")
                self.assertEqual(no["estado"], "negado")
                self.assertEqual(si["glosas"][-1], "COMPRENDER")
                self.assertEqual(no["glosas"][-2:], ["COMPRENDER", "NO"])


class DocumentosPorInstitucion(unittest.TestCase):
    DOCS = [q for q in PREGUNTAS if q["id"].endswith(".docs")]

    def test_cada_pregunta_de_documentos_abre_su_detalle(self):
        for q in POLARES:
            if q["formulacion"] not in DATOS["preguntas_de_documentos"]:
                continue
            area = q["origen"]["escenario"].split("-")[1]
            hijo = next((x for x in PREGUNTAS if x["id"] == f"{q['id']}.docs"), None)
            with self.subTest(q["id"]):
                if area in DATOS["documentos"]:
                    self.assertIsNotNone(hijo)
                else:
                    self.assertIsNone(hijo)

    def test_el_detalle_es_de_seleccion_multiple_con_su_plantilla(self):
        self.assertGreaterEqual(len(self.DOCS), 40)
        for q in self.DOCS:
            with self.subTest(q["id"]):
                self.assertEqual(q["control"], "seleccion_multiple")
                self.assertEqual(q["plantilla"].count("{items}"), 1)
                tarjetas = [o for o in q["opciones"] if o.get("zona")]
                self.assertGreaterEqual(len(tarjetas), 3)
                for o in q["opciones"]:
                    self.assertEqual(len(o["glosas"]), 1, o["id"])

    def test_solo_aparece_si_la_persona_dijo_si(self):
        for rid, r in BANCO["recorridos"].items():
            for p in r["pasos"]:
                if not p["pregunta"].endswith(".docs"):
                    continue
                padre = p["pregunta"][:-len(".docs")]
                with self.subTest(p["pregunta"]):
                    self.assertEqual(p["padre"], padre)
                    self.assertEqual(p["cuando"],
                                     [{"pregunta": padre, "estados": ["afirmado"]}])
                    previos = [x["pregunta"] for x in r["pasos"]]
                    self.assertLess(previos.index(padre),
                                    previos.index(p["pregunta"]))

    def test_las_etiquetas_de_documentos_usan_palabras_del_corpus(self):
        """Cada tarjeta de documento se llama con palabras que el corpus ya
        usa: no se inventa vocabulario."""
        for area, lista in DATOS["documentos"].items():
            for d in lista:
                with self.subTest(f"{area} {d['id']}"):
                    nucleo = palabras(d["etiqueta"]) - {"del", "los", "las", "una", "uno"}
                    self.assertLessEqual(nucleo - VOCAB, set())


class PreguntasCortas(unittest.TestCase):
    def test_un_entendio_solo_se_muestra_con_la_afirmacion_que_lo_precede(self):
        cortas = [q for q in POLARES if q["id"].split(".")[1].endswith("-301")
                  or "-30" in q["id"]]
        vistas = 0
        for q in cortas:
            if q["formulacion"].endswith(("¿Entendió?", "¿Entendió el costo?")):
                vistas += 1
                with self.subTest(q["id"]):
                    self.assertGreater(len(q["formulacion"].split()), 4)
        self.assertGreaterEqual(vistas, 6)


if __name__ == "__main__":
    unittest.main()
