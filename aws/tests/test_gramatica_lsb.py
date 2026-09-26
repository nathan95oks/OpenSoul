"""Formulación LSB de las preguntas del banco.

Estas pruebas NO demuestran que una secuencia sea gramatical en LSB: eso
solo puede afirmarlo una persona competente (corpus v4 §3.1 nivel D y §10).
Comprueban consistencia técnica:

- toda pieza de una formulación es glosa del Corpus Maestro Unificado LSB v4,
  dactilología d(SIGLA) o el mecanismo numérico NÚM(...);
- toda pregunta tiene un estado auditable y ninguno se promueve solo a
  GRAMMAR_VALIDATED;
- una pregunta sí/no no lleva SÍ/NO en su formulación y una QU- lleva su
  interrogativo;
- ninguna pieza de la fila del corpus se pierde sin justificarlo;
- banco canónico, banco de ejecución (app y Lambda) y grafo dicen lo mismo;
- la formulación no cambia preguntas, opciones, estados ni frases.
"""

import copy
import hashlib
import json
import os
import sys
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tool"))

import build_question_matrix as B  # noqa: E402
import corpus_dialogue as CD  # noqa: E402

# Huella del banco de ejecución sin `formulacionLsb`, tomada de 6320bcc
# (antes de esta fase). Si cambia, algo distinto de la formulación cambió:
# preguntas, opciones, estados, frases o recorridos.
HUELLA_SIN_FORMULACION = "23184d21361f9e09a618d65112e5d95105793e8219cd16f8316424e87b1186f0"


class GramaticaLsb(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        (cls.banco, cls.acep, cls.catalogo, cls.grafo,
         cls.contextos, cls.horneadas) = B.cargar()
        cls.resolver = CD.ConceptResolver()
        cls.analisis = B.analizar_gramatica(cls.banco, cls.grafo, cls.resolver)
        cls.v4 = {e["gloss"] for e in cls.resolver.app.values()}
        cls.letras = {g for g in cls.v4 if len(CD.norm(g)) == 1 and not g.isdigit()}
        with open(os.path.join(ROOT, "aws", "question_bank.json"), encoding="utf-8") as f:
            cls.ejecucion = json.load(f)

    def errores(self, banco):
        errores = []
        B.validar_gramatica(banco, self.grafo, errores, self.resolver)
        return errores

    def cambiar(self, qid, **cambios):
        banco = copy.deepcopy(self.banco)
        for q in banco["preguntas"]:
            if q["id"] == qid:
                q["gramaticaLsb"].update(cambios)
        return banco

    def g(self, qid):
        return next(q for q in self.banco["preguntas"] if q["id"] == qid)["gramaticaLsb"]

    # Vocabulario ---------------------------------------------------------
    def test_all_formulation_glosses_exist_in_corpus_v4(self):
        fuera = [f"{n['id']}: {t}" for n in self.grafo["nodes"]
                 for t in n.get("formulationGlosses", [])
                 if not B.token_valido(t, self.v4, self.letras)]
        for q in self.banco["preguntas"]:
            fuera += [f"{q['id']}: {t}" for t in q["gramaticaLsb"].get("secuencia", [])
                      if not B.token_valido(t, self.v4, self.letras)]
            fuera += [f"{q['id']} (noOfrecer): {g}" for g in q.get("noOfrecer", {}) if g not in self.v4]
        self.assertEqual([], fuera)

    def test_la_dactilologia_solo_usa_letras_del_alfabeto_v4(self):
        self.assertFalse(B.token_valido("d(FISCAL1)", self.v4, self.letras))
        self.assertFalse(B.token_valido("DINERO", self.v4, self.letras))
        self.assertTrue(B.token_valido("d(FISCALÍA)", self.v4, self.letras))
        self.assertTrue(B.token_valido("NÚM(...)", self.v4, self.letras))

    # Estados ---------------------------------------------------------------
    def test_todas_las_preguntas_tienen_estado_y_el_banco_es_coherente(self):
        sin_estado = [q["id"] for q in self.banco["preguntas"]
                      if (q.get("gramaticaLsb") or {}).get("estado") not in B.ESTADOS_GRAMATICA]
        self.assertEqual([], sin_estado)
        self.assertEqual([], self.errores(self.banco))

    def test_el_estado_registrado_es_el_que_permite_la_evidencia(self):
        for q in self.banco["preguntas"]:
            with self.subTest(pregunta=q["id"]):
                self.assertEqual(self.analisis[q["id"]]["estadoMaximo"], q["gramaticaLsb"]["estado"])

    def test_ninguna_secuencia_esta_validada(self):
        self.assertNotIn("GRAMMAR_VALIDATED", {q["gramaticaLsb"]["estado"] for q in self.banco["preguntas"]})
        self.assertNotIn("GRAMMAR_VALIDATED", {a["estadoMaximo"] for a in self.analisis.values()})

    def test_provisional_no_se_promueve_sin_registro_humano(self):
        errores = self.errores(self.cambiar("Q.HEC.QUE_OCURRIO", estado="GRAMMAR_VALIDATED"))
        self.assertTrue(any("nunca se promueve" in e for e in errores), errores)

    def test_la_validacion_tiene_que_ser_de_la_secuencia_actual(self):
        otra = {"validador": "intérprete LSB", "fecha": "2026-09-26",
                "evidencia": "sesión de validación", "secuencia": ["NARRAR", "QUÉ"]}
        errores = self.errores(self.cambiar("Q.HEC.QUE_OCURRIO", estado="GRAMMAR_VALIDATED", validacion=otra))
        self.assertTrue(any("otra secuencia" in e for e in errores), errores)

    def test_un_registro_humano_completo_si_permite_validar(self):
        registro = {"validador": "persona sorda señante (Cochabamba)", "fecha": "2026-09-26",
                    "evidencia": "acta de validación",
                    "secuencia": self.analisis["Q.HEC.QUE_OCURRIO"]["secuencia"]}
        self.assertEqual([], self.errores(
            self.cambiar("Q.HEC.QUE_OCURRIO", estado="GRAMMAR_VALIDATED", validacion=registro)))

    def test_pendiente_sin_secuencia_y_con_motivo(self):
        errores = self.errores(self.cambiar("I.PREG.CUANDO", estado="GRAMMAR_PROVISIONAL"))
        self.assertTrue(any("sin secuencia LSB" in e for e in errores), errores)
        errores = self.errores(self.cambiar("I.PREG.CUANDO", motivo=""))
        self.assertTrue(any("sin motivo" in e for e in errores), errores)
        for q in self.banco["preguntas"]:
            g = q["gramaticaLsb"]
            if g["estado"] == "GRAMMAR_PENDING":
                self.assertEqual([], g.get("secuencia", []), q["id"])
                self.assertTrue(g.get("motivo"), q["id"])

    def test_un_hueco_lexico_no_puede_ocultarse(self):
        errores = self.errores(self.cambiar("Q.DEN.INTENCION", estado="GRAMMAR_PROVISIONAL"))
        self.assertTrue(any("LEXICAL_GAP" in e for e in errores), errores)

    def test_fallback_visual_deriva_de_secuencia_estado_y_tratamiento(self):
        decisiones = {
            q["id"]: B.formulacion_lsb_utilizable(q)
            for q in self.banco["preguntas"]
        }
        self.assertEqual(134, sum(decisiones.values()))
        self.assertEqual(9, len(decisiones) - sum(decisiones.values()))
        self.assertTrue(decisiones["Q.HEC.QUE_OCURRIO"])
        self.assertFalse(decisiones["I.PREG.CUANDO"])
        self.assertFalse(decisiones["Q.EVI.QUE_TIENE"])
        self.assertTrue(decisiones["Q.DEN.INTENCION"])
        self.assertTrue(decisiones["Q.SEG.DONDE_FISCALIA"])

        ejecucion = {
            q["id"]: q["formulacionLsb"]["utilizable"]
            for q in B.banco_ejecucion(self.banco, self.acep)["preguntas"]
        }
        self.assertEqual(decisiones, ejecucion)

    def test_un_registro_de_validacion_exige_el_estado_validado(self):
        registro = {"validador": "x", "fecha": "2026-09-26", "evidencia": "y", "secuencia": []}
        errores = self.errores(self.cambiar("Q.ROB.QUE", validacion=registro))
        self.assertTrue(any("registro de validación" in e for e in errores), errores)

    # Estructura --------------------------------------------------------------
    def test_las_polares_no_llevan_si_ni_no(self):
        for q in self.banco["preguntas"]:
            g = q["gramaticaLsb"]
            if g.get("tipo") == "polar":
                with self.subTest(pregunta=q["id"]):
                    self.assertFalse({"SÍ", "NO", "NO_SABER"} & set(g["secuencia"]))
        errores = self.errores(self.cambiar("Q.SAL.HERIDO", secuencia=["HERIDA", "TENER", "SÍ"]))
        self.assertTrue(any("son respuestas" in e for e in errores), errores)

    def test_las_qu_llevan_su_interrogativo(self):
        for q in self.banco["preguntas"]:
            g = q["gramaticaLsb"]
            if g.get("tipo") in ("qu", "disyuntiva"):
                with self.subTest(pregunta=q["id"]):
                    self.assertIn(g["interrogativo"], g["secuencia"])
        errores = self.errores(self.cambiar("Q.ROB.QUE", secuencia=["ROBAR", "DÓNDE"], interrogativo="DÓNDE"))
        self.assertTrue(any("no se pregunta con" in e for e in errores), errores)

    def test_compuestos_y_dactilologia_se_conservan(self):
        self.assertEqual([["PAPEL", "IDENTIDAD"]], self.g("Q.ID.DOC_TIENE")["compuestos"])
        self.assertEqual(["d(FISCALÍA)", "DÓNDE", "SABER", "NECESITAR"], self.g("Q.SEG.DONDE_FISCALIA")["secuencia"])
        self.assertEqual(["d(FISCALÍA)", "IR"], self.g("Q.SEG.DERIVACION_FISCALIA")["secuencia"])
        self.assertEqual(["ASISTENCIA", "d(SEPDAVI)", "QUERER"], self.g("Q.ORI.SEPDAVI")["secuencia"])
        self.assertEqual(["ABOGADO", "GRATIS", "d(SEPDEP)", "NECESITAR"], self.g("Q.SEG.DEFENSA_PUBLICA")["secuencia"])
        self.assertEqual(["d(FISCAL)", "HABLAR", "NECESITAR"], self.g("Q.SEG.HABLAR_FISCAL")["secuencia"])
        errores = self.errores(self.cambiar("Q.ID.DOC_TIENE", secuencia=["PAPEL", "TENER", "IDENTIDAD"]))
        self.assertTrue(any("no es contiguo" in e for e in errores), errores)

    def test_ninguna_pieza_del_corpus_se_pierde_sin_justificar(self):
        perdidas = {qid: a["omitidos"] for qid, a in self.analisis.items() if a["omitidos"]}
        self.assertEqual({}, perdidas)
        errores = self.errores(self.cambiar("Q.RIE.MIEDO_CASA", secuencia=["MIEDO", "VOLVER"]))
        self.assertTrue(any("pierde" in e for e in errores), errores)

    def test_toda_formulacion_tiene_regla_y_evidencia(self):
        for q in self.banco["preguntas"]:
            g = q["gramaticaLsb"]
            if g.get("secuencia"):
                with self.subTest(pregunta=q["id"]):
                    self.assertTrue(g.get("regla") and g.get("evidencia"))

    # Sincronía y no regresión ------------------------------------------------
    def test_app_lambda_y_grafo_usan_la_misma_formulacion(self):
        canonica = {q["id"]: q["gramaticaLsb"].get("secuencia", []) for q in self.banco["preguntas"]}
        ejecucion = {q["id"]: (q.get("formulacionLsb") or {}).get("glosas", [])
                     for q in self.ejecucion["preguntas"]}
        self.assertEqual(canonica, ejecucion)
        dart = open(os.path.join(ROOT, "lib", "core", "domain", "guided", "question_bank_data.g.dart"),
                    encoding="utf-8").read()
        datos = json.loads(dart[dart.index("r'''") + 4:dart.rindex("'''")])
        self.assertEqual(self.ejecucion, datos)
        for n in self.grafo["nodes"]:
            if n.get("bankQuestion"):
                with self.subTest(nodo=n["id"]):
                    self.assertEqual(canonica[n["bankQuestion"]], n["formulationGlosses"])

    def test_la_formulacion_no_cambia_preguntas_opciones_ni_frases(self):
        resto = copy.deepcopy(self.ejecucion)
        for q in resto["preguntas"]:
            q.pop("formulacionLsb", None)
        huella = hashlib.sha256(json.dumps(resto, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
        self.assertEqual(HUELLA_SIN_FORMULACION, huella)

    def test_toda_pregunta_indica_que_validar(self):
        for qid, a in self.analisis.items():
            with self.subTest(pregunta=qid):
                self.assertTrue(a["validar"], "sin punto concreto que validar")


if __name__ == "__main__":
    unittest.main()
