"""El generador del banco acepta escenarios nuevos declarados con datos y
rechaza los que no encajan con el repositorio.

Un recorrido con su bloque `contexto`, preguntas con `ranuras` y la tabla
`zonasOyente` se validan contra el vocabulario del repositorio (familias,
zonas, ranuras) antes de generar nada.
"""

import copy
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tool"))

import build_question_matrix as B  # noqa: E402

BANCO, ACEP, CATALOGO, GRAFO, CONTEXTOS, _ = B.cargar()
REPO = B.cargar_repositorio()

ESCENARIO = {
    "nombre": "Pérdida de un objeto o documento",
    "contexto": {
        "nombre": "Perdí algo",
        "familia": "tramites",
        "descripcion": "Pérdida del carnet, el celular u otro objeto",
        "emoji": "📄",
    },
    "pasos": [
        {"pregunta": "Q.FALTA.QUE", "obligatoria": True},
        {"pregunta": "Q.TIE.CUANDO"},
        {"pregunta": "Q.LUG.DONDE"},
    ],
}


def errores(banco):
    return B.validar(banco, ACEP, CATALOGO, GRAFO, CONTEXTOS, REPO)[0]


def con_escenario(**cambios):
    banco = copy.deepcopy(BANCO)
    r = copy.deepcopy(ESCENARIO)
    r["contexto"].update(cambios)
    banco["recorridos"]["extravio_documento"] = r
    return banco


class EscenarioNuevo(unittest.TestCase):
    def test_el_banco_actual_es_valido(self):
        self.assertEqual([], errores(BANCO))

    def test_un_recorrido_con_contexto_declarado_es_valido(self):
        self.assertEqual([], errores(con_escenario()))

    def test_llega_a_la_app_y_a_la_lambda(self):
        ejecucion = B.banco_ejecucion(con_escenario(), ACEP)
        r = ejecucion["recorridos"]["extravio_documento"]
        self.assertEqual("tramites", r["contexto"]["familia"])
        self.assertIn("zonasOyente", ejecucion)
        preguntas = {q["id"]: q for q in ejecucion["preguntas"]}
        self.assertEqual(["person"], preguntas["Q.PER.CONOCE"]["ranuras"])

    def test_sin_contexto_ni_en_el_catalogo_se_rechaza(self):
        banco = copy.deepcopy(BANCO)
        r = copy.deepcopy(ESCENARIO)
        del r["contexto"]
        banco["recorridos"]["extravio_documento"] = r
        self.assertTrue(any("extravio_documento sin contexto" in e
                            for e in errores(banco)))

    def test_familia_desconocida(self):
        self.assertTrue(any("familia desconocida" in e
                            for e in errores(con_escenario(familia="compras"))))

    def test_faltan_datos_del_contexto(self):
        self.assertTrue(any("le falta «nombre»" in e
                            for e in errores(con_escenario(nombre=""))))

    def test_campo_de_contexto_desconocido(self):
        self.assertTrue(any("campo de contexto desconocido" in e
                            for e in errores(con_escenario(color="rojo"))))

    def test_no_se_declara_dos_veces_un_contexto_del_catalogo(self):
        banco = copy.deepcopy(BANCO)
        banco["recorridos"]["denuncia_robo"]["contexto"] = ESCENARIO["contexto"]
        self.assertTrue(any("ya está en context_catalog.dart" in e
                            for e in errores(banco)))

    def test_una_pregunta_inexistente_en_el_escenario(self):
        banco = con_escenario()
        banco["recorridos"]["extravio_documento"]["pasos"].append(
            {"pregunta": "Q.NO.EXISTE"})
        self.assertTrue(any("pregunta inexistente Q.NO.EXISTE" in e
                            for e in errores(banco)))


class RanurasYZonas(unittest.TestCase):
    def test_ranura_desconocida(self):
        banco = copy.deepcopy(BANCO)
        q = next(q for q in banco["preguntas"] if q["id"] == "Q.PER.CONOCE")
        q["ranuras"] = ["tatuaje"]
        self.assertTrue(any("ranura desconocida «tatuaje»" in e
                            for e in errores(banco)))

    def test_zona_o_pregunta_desconocida(self):
        banco = copy.deepcopy(BANCO)
        banco["zonasOyente"]["mascotas"] = ["Q.LUG.DONDE"]
        banco["zonasOyente"]["lugar"] = ["Q.LUG.INVENTADA"]
        e = errores(banco)
        self.assertTrue(any("zona desconocida «mascotas»" in x for x in e))
        self.assertTrue(any("pregunta inexistente Q.LUG.INVENTADA" in x for x in e))

    def test_las_zonas_existen_en_el_repositorio(self):
        for zona in BANCO["zonasOyente"]:
            self.assertIn(zona, REPO["zonas"])


if __name__ == "__main__":
    unittest.main()
