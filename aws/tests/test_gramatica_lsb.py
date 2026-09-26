"""Estado gramatical LSB de las formulaciones del banco.

Estas pruebas NO demuestran que una secuencia sea gramatical en LSB: eso
solo puede afirmarlo una persona competente (corpus v4 §3.1 nivel D y §10).
Comprueban consistencia técnica:

- toda glosa de formulación existe en el Corpus Maestro Unificado LSB v4;
- toda pregunta tiene un estado gramatical auditable;
- ningún estado es más optimista que la evidencia, y ninguno se promueve
  solo a GRAMMAR_VALIDATED;
- el estado gramatical no cambia el banco de ejecución (preguntas,
  opciones, estados producidos, frases).
"""

import copy
import json
import os
import sys
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tool"))

import build_question_matrix as B  # noqa: E402
import corpus_dialogue as CD  # noqa: E402


class GramaticaLsb(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        (cls.banco, cls.acep, cls.catalogo, cls.grafo,
         cls.contextos, cls.horneadas) = B.cargar()
        cls.resolver = CD.ConceptResolver()
        cls.analisis = B.analizar_gramatica(cls.banco, cls.grafo, cls.resolver)
        with open(os.path.join(ROOT, "assets", "dictionary", "official_dictionary.json"),
                  encoding="utf-8") as f:
            cls.v4 = {e["gloss"] for e in json.load(f)["entries"]}

    def errores(self, banco):
        errores = []
        B.validar_gramatica(banco, self.grafo, errores, self.resolver)
        return errores

    def con_estado(self, qid, estado, validacion=None):
        banco = copy.deepcopy(self.banco)
        for q in banco["preguntas"]:
            if q["id"] == qid:
                q["gramaticaLsb"] = {"estado": estado}
                if validacion is not None:
                    q["gramaticaLsb"]["validacion"] = validacion
        return banco

    # 1 y 2 -----------------------------------------------------------------
    def test_all_formulation_glosses_exist_in_corpus_v4(self):
        fuera = [f"{n['id']}: {g}" for n in self.grafo["nodes"]
                 for g in n.get("formulationGlosses", []) if g not in self.v4]
        for q in self.banco["preguntas"]:
            fuera += [f"{q['id']} (noOfrecer): {g}" for g in q.get("noOfrecer", {})
                      if g not in self.v4]
        self.assertEqual([], fuera)

    def test_el_analisis_confirma_v4_en_todas_las_preguntas(self):
        self.assertTrue(all(a["todasEnV4"] for a in self.analisis.values()))

    # 3 ---------------------------------------------------------------------
    def test_todas_las_preguntas_tienen_estado_gramatical(self):
        sin_estado = [q["id"] for q in self.banco["preguntas"]
                      if (q.get("gramaticaLsb") or {}).get("estado") not in B.ESTADOS_GRAMATICA]
        self.assertEqual([], sin_estado)
        self.assertEqual([], self.errores(self.banco))

    def test_el_estado_registrado_es_el_que_permite_la_evidencia(self):
        for q in self.banco["preguntas"]:
            with self.subTest(pregunta=q["id"]):
                self.assertEqual(self.analisis[q["id"]]["estadoMaximo"],
                                 q["gramaticaLsb"]["estado"])

    # 4 ---------------------------------------------------------------------
    def test_el_analisis_nunca_declara_validada_una_secuencia(self):
        self.assertNotIn("GRAMMAR_VALIDATED",
                         {a["estadoMaximo"] for a in self.analisis.values()})

    def test_provisional_no_se_promueve_sin_registro_humano(self):
        errores = self.errores(self.con_estado("Q.HEC.QUE_OCURRIO", "GRAMMAR_VALIDATED"))
        self.assertTrue(any("nunca se promueve" in e for e in errores), errores)

    def test_la_validacion_tiene_que_ser_de_la_secuencia_actual(self):
        otra = {"validador": "intérprete LSB", "fecha": "2026-09-26",
                "evidencia": "sesión de validación", "secuencia": ["NARRAR", "¿QUÉ?"]}
        errores = self.errores(self.con_estado("Q.HEC.QUE_OCURRIO", "GRAMMAR_VALIDATED", otra))
        self.assertTrue(any("otra secuencia" in e for e in errores), errores)

    def test_un_registro_humano_completo_si_permite_validar(self):
        # El mecanismo existe para cuando haya validación real; aquí solo se
        # comprueba que el validador lo acepta, no que la secuencia lo sea.
        actual = self.analisis["Q.HEC.QUE_OCURRIO"]["secuencias"][0]["tokens"]
        registro = {"validador": "persona sorda señante (Cochabamba)", "fecha": "2026-09-26",
                    "evidencia": "acta de validación", "secuencia": actual}
        self.assertEqual([], self.errores(
            self.con_estado("Q.HEC.QUE_OCURRIO", "GRAMMAR_VALIDATED", registro)))

    def test_sin_secuencia_no_puede_ser_provisional_ni_validada(self):
        for estado in ("GRAMMAR_PROVISIONAL", "GRAMMAR_VALIDATED"):
            errores = self.errores(self.con_estado("I.PREG.ELEGIR", estado))
            self.assertTrue(any("sin secuencia LSB" in e for e in errores), (estado, errores))

    def test_un_hueco_lexico_no_puede_ocultarse(self):
        errores = self.errores(self.con_estado("Q.DEN.INTENCION", "GRAMMAR_PROVISIONAL"))
        self.assertTrue(any("LEXICAL_GAP" in e for e in errores), errores)

    def test_un_registro_de_validacion_exige_el_estado_validado(self):
        registro = {"validador": "x", "fecha": "2026-09-26", "evidencia": "y", "secuencia": []}
        errores = self.errores(self.con_estado("Q.ROB.QUE", "GRAMMAR_PROVISIONAL", registro))
        self.assertTrue(any("registro de validación" in e for e in errores), errores)

    # Correcciones seguras aplicadas ----------------------------------------
    RESTITUIDAS = {
        "Q.ORI.SEPDAVI": ["ASISTENCIA", "SEPDAVI", "QUERER"],
        "Q.SEG.DEFENSA_PUBLICA": ["ABOGADO", "GRATIS", "SEPDEP", "NECESITAR"],
        "Q.SEG.DONDE_FISCALIA": ["FISCALIA", "DÓNDE"],
        "Q.SEG.DERIVACION_FISCALIA": ["FISCALIA", "IR"],
    }

    def test_dactilologia_institucional_en_su_posicion_del_corpus(self):
        for qid, esperada in self.RESTITUIDAS.items():
            with self.subTest(pregunta=qid):
                sec = self.analisis[qid]["secuencias"][0]
                self.assertEqual(esperada, sec["formulationGlosses"])
                # Misma posición que en el corpus: d(SIGLA) ↔ SIGLA.
                tokens = [CD.norm(t.strip("¿?")).removeprefix("D(").removesuffix(")")
                          for t in sec["tokens"]]
                self.assertEqual([CD.norm(g) for g in esperada], tokens)

    def test_la_correccion_no_promueve_ningun_estado(self):
        for qid in self.RESTITUIDAS:
            q = next(x for x in self.banco["preguntas"] if x["id"] == qid)
            self.assertEqual("GRAMMAR_PROVISIONAL", q["gramaticaLsb"]["estado"])

    def test_no_queda_ninguna_pieza_del_corpus_sin_restituir(self):
        pendientes = {qid: a["propuestas"] for qid, a in self.analisis.items() if a["propuestas"]}
        self.assertEqual({}, pendientes)

    # 5 y 6 -----------------------------------------------------------------
    def test_el_estado_gramatical_no_cambia_el_banco_de_ejecucion(self):
        ejecucion = B.banco_ejecucion(self.banco, self.acep)
        self.assertFalse(any("gramaticaLsb" in q for q in ejecucion["preguntas"]))
        with open(os.path.join(ROOT, "aws", "question_bank.json"), encoding="utf-8") as f:
            desplegado = json.load(f)
        self.assertEqual(desplegado, json.loads(json.dumps(ejecucion)))

    def test_el_banco_sigue_siendo_valido(self):
        errores, _ = B.validar(self.banco, self.acep, self.catalogo, self.grafo, self.contextos)
        self.assertEqual([], errores)

    def test_toda_pendiente_indica_que_validar(self):
        for qid, a in self.analisis.items():
            with self.subTest(pregunta=qid):
                self.assertTrue(a["validar"], "sin punto concreto que validar")


if __name__ == "__main__":
    unittest.main()
