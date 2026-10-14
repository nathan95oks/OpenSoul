"""Trámites profundizados de Conversación (2026-10-14).

    python -m pytest tool/tests/test_tramites_profundizados.py -q

Dos partes. La primera prueba el constructor con un escenario mínimo: los
«Datos editables» y el «Consolidado en». La segunda recorre los escenarios
nuevos (`ESC-*-301`) tal como quedaron en `assets/rag/escenarios_cbba.json` y
en el banco de recorridos, y comprueba lo que se prometió de ellos: que
tengan profundidad y ramificaciones, que no inventen montos, que cada
institución cite solo sus hechos (salvo derivaciones declaradas) y que los
pasos dependan solo de lo anterior.

Sin red.
"""

import json
import os
import re
import sys
import tempfile
import unittest
from unittest import mock

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))

import build_rag_corpus as B  # noqa: E402
import auditar_tramites as A  # noqa: E402

MD = """# Prueba

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|

## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|

## ESC-OJ-90 — Consultar una causa

- **Institución:** Órgano Judicial
- **Trámite:** Consulta de prueba
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** Prueba.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Tiene el número de su caso? | — | — |
| 2 | Usuario Sordo | Sí, tengo el número. | — | — |

### Variantes

- **Turno 1 (Funcionario):** «¿Conoce el número de su caso?»
- **Respuestas:** «No, no tengo el número.» · «No sé cuál es el número.»

### Datos editables

- **Turno 1:** documento_numero · «Sí, mi número de caso es {numero}.»

## ESC-OJ-91 — Consulta corta

- **Institución:** Órgano Judicial
- **Trámite:** Consulta corta de prueba
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** Prueba.
- **Consolidado en:** ESC-OJ-90

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Tiene el número de su caso? | — | — |
| 2 | Usuario Sordo | Sí, tengo el número. | — | — |
"""

GLOSAS = {
    "¿Tiene el número de su caso?": ["TENER", "NÚMERO", "CASA"],
    "¿Conoce el número de su caso?": ["CONOCER", "NÚMERO", "CASA"],
    "Sí, tengo el número.": ["SÍ", "TENER"],
    "No, no tengo el número.": ["NO", "TENER"],
    "No sé cuál es el número.": ["NO_SABER", "CUÁL"],
}


def construir(md: str, glosas: dict = GLOSAS) -> tuple:
    with tempfile.TemporaryDirectory() as d:
        ruta = os.path.join(d, "esc.md")
        with open(ruta, "w", encoding="utf-8") as f:
            f.write(md)
        fuentes, hechos, escenarios, errores, avisos = B.leer(ruta)
        corpus = B.construir(fuentes, hechos, escenarios, errores, avisos,
                             hoy="2026-10-14", archivos=["esc.md"])
        cache = os.path.join(d, "cache.json")
        with open(cache, "w", encoding="utf-8") as f:
            json.dump({k: {"glosas": v} for k, v in glosas.items()}, f)
        nada = os.path.join(d, "no_existe.json")
        with mock.patch.multiple(B, GLOSAS=cache, CORRECCIONES=nada,
                                 EQUIVALENCIAS=nada):
            B.poner_glosas(corpus, avisos)
    return corpus, B.banco_tramites(corpus, avisos), errores, avisos


class DatosEditables(unittest.TestCase):
    def setUp(self):
        self.corpus, self.banco, self.errores, self.avisos = construir(MD)

    def pregunta(self):
        return next(q for q in self.banco["preguntas"]
                    if q["id"] == "R.ESC-OJ-90.1")

    def test_el_si_admite_escribir_el_dato_y_es_opcional(self):
        self.assertEqual(self.errores, [])
        si = next(o for o in self.pregunta()["opciones"] if o["id"] == "si")
        self.assertEqual(si["editor"], "documento_numero")
        self.assertTrue(si["editorOpcional"])
        self.assertEqual(si["frase"], "Sí, mi número de caso es {numero}.")
        # Sin el dato, «Sí» dice lo de siempre.
        self.assertEqual(si["fraseSinValor"], "Sí, tengo el número.")

    def test_no_y_no_se_no_piden_dato(self):
        for o in self.pregunta()["opciones"]:
            if o["id"] != "si":
                self.assertNotIn("editor", o)

    def test_el_valor_nunca_va_en_el_escenario(self):
        cuerpo = MD.replace("{numero}", "123456")
        _, _, errores, _ = construir(cuerpo)
        self.assertTrue(any("huecos" in e for e in errores), errores)

    def test_el_editor_tiene_que_existir(self):
        _, _, errores, _ = construir(
            MD.replace("documento_numero ·", "inventado ·"))
        self.assertTrue(any("editor desconocido" in e for e in errores), errores)

    def test_el_hueco_debe_ser_del_editor(self):
        _, _, errores, _ = construir(MD.replace("{numero}", "{placa}"))
        self.assertTrue(any("huecos" in e for e in errores), errores)

    def test_solo_una_pregunta_del_funcionario_lleva_dato(self):
        malo = MD.replace("- **Turno 1:** documento_numero",
                          "- **Turno 2:** documento_numero")
        _, _, errores, _ = construir(malo)
        self.assertTrue(any("no es una pregunta" in e for e in errores), errores)

    def test_el_dato_se_escribe_al_contestar_si(self):
        malo = MD.replace("«Sí, mi número de caso es {numero}.»",
                          "«Mi número de caso es {numero}.»")
        _, _, errores, _ = construir(malo)
        self.assertTrue(any("Sí," in e for e in errores), errores)


class Consolidados(unittest.TestCase):
    def test_el_consolidado_no_se_ve_en_la_lista_pero_sigue_siendo_un_recorrido(self):
        corpus, banco, errores, avisos = construir(MD)
        self.assertEqual(errores, [])
        por_esc = {c["escenario"]: c for c in banco["contextos"]}
        self.assertEqual(por_esc["ESC-OJ-91"]["consolidadoEn"], "ESC-OJ-90")
        self.assertNotIn("consolidadoEn", por_esc["ESC-OJ-90"])
        self.assertIn("tramite_oj_91", banco["recorridos"])

    def test_dos_trámites_iguales_no_avisan_si_uno_esta_consolidado(self):
        md = MD.replace("Consulta corta de prueba", "Consulta de prueba")
        _, _, _, avisos = construir(md)
        self.assertFalse(any("mismo nombre" in a for a in avisos), avisos)

    def test_se_consolida_en_un_escenario_que_existe(self):
        _, _, errores, _ = construir(MD.replace("ESC-OJ-90\n\n|", "ESC-OJ-99\n\n|"))
        self.assertTrue(any("no existe" in e for e in errores), errores)

    def test_solo_dentro_de_la_misma_institucion(self):
        md = MD.replace("## ESC-OJ-91", "## ESC-FIS-91").replace(
            "ESC-OJ-90\n\n|", "ESC-OJ-90\n\n|", 1)
        _, _, errores, _ = construir(md)
        self.assertTrue(any("misma institución" in e for e in errores), errores)


# ----------------------------------------------------------------------------
# El corpus real
# ----------------------------------------------------------------------------

CORPUS, BANCO = A.cargar()
NUEVOS = [e for e in CORPUS["escenarios"] if re.fullmatch(r"ESC-[A-Z]+-30\d", e["id"])]
HECHOS = CORPUS["hechos"]
# Una derivación cita al hecho de la institución a la que manda a la persona,
# y solo a esa: la Fiscalía no explica los trámites del SEGIP.
DERIVACIONES = {("SEPDEP", "SEPDAVI"), ("SEGIP", "SERECI"), ("FELCV", "SLIM")}
# Quien recibe nombra, sin explicarla, a la institución de la que llega.
PROCEDENCIAS = {("SEPDAVI", "FELCV")}


def area_de_hecho(h: str) -> str:
    return h.split("-")[1]


@unittest.skipUnless(NUEVOS, "sin escenarios nuevos")
class EscenariosNuevos(unittest.TestCase):
    def test_hay_doce_y_cada_uno_es_profundo(self):
        self.assertGreaterEqual(len(NUEVOS), 12)
        for e in NUEVOS:
            with self.subTest(e["id"]):
                self.assertGreaterEqual(len(e["turnos"]), 11)
                self.assertLessEqual(len(e["turnos"]), 18)
                self.assertTrue(e.get("ramificaciones"), "sin ramificaciones")
                self.assertGreaterEqual(len(e["ramificaciones"]), 2)

    def test_cada_escenario_nuevo_es_un_recorrido(self):
        con_ruta = {c["escenario"] for c in BANCO["contextos"]}
        for e in NUEVOS:
            with self.subTest(e["id"]):
                self.assertIn(e["id"], con_ruta)

    def test_cierra_el_funcionario_y_empieza_la_persona_sorda(self):
        for e in NUEVOS:
            with self.subTest(e["id"]):
                self.assertEqual(e["turnos"][0]["rol"], "sordo")
                cierre = [t for t in e["turnos"] if t["rol"] == "funcionario"][-1]
                self.assertEqual(cierre["n"], len(e["turnos"]), "el cierre es del funcionario")

    def test_cada_pregunta_de_si_o_no_tiene_las_tres_respuestas(self):
        for e in NUEVOS:
            preguntas = [q for q in BANCO["preguntas"]
                         if q["origen"]["escenario"] == e["id"] and q.get("control") == "polar3"]
            self.assertGreaterEqual(len(preguntas), 4, e["id"])
            for q in preguntas:
                with self.subTest(q["id"]):
                    self.assertEqual([o["estado"] for o in q["opciones"]],
                                     ["afirmado", "negado", "desconocido"])
                    # Las tres con frase propia, no la partícula suelta.
                    for o in q["opciones"]:
                        self.assertGreater(len(o["frase"].split()), 2,
                                           f"{q['id']} {o['id']}: «{o['frase']}»")

    def test_las_respuestas_de_la_persona_sorda_son_cortas_y_sin_datos(self):
        for e in NUEVOS:
            textos = [t["texto"] for t in e["turnos"] if t["rol"] == "sordo"]
            for p in e["variantes"]:
                textos += [r["texto"] for r in p["respuestas"]]
            for t in textos:
                with self.subTest(f"{e['id']} {t}"):
                    self.assertLessEqual(len(t.split()), 12)
                    self.assertFalse(re.search(r"\d", t), "un dato concreto")

    def test_todo_turno_se_puede_mostrar(self):
        for e in NUEVOS:
            for t in e["turnos"]:
                with self.subTest(f"{e['id']} turno {t['n']}"):
                    self.assertTrue(t["mostrable"], t["motivos"])
            for p in e["variantes"]:
                for r in p["respuestas"]:
                    self.assertTrue(r["mostrable"], f"{e['id']}: {r['texto']}")


@unittest.skipUnless(NUEVOS, "sin escenarios nuevos")
class SinInventar(unittest.TestCase):
    def test_todo_hecho_citado_existe_y_vale(self):
        for e in NUEVOS:
            for t in e["turnos"]:
                for h in t["hechos"]:
                    with self.subTest(f"{e['id']} {h}"):
                        self.assertIn(h, HECHOS)
                        self.assertFalse(HECHOS[h]["verificar"])
                        self.assertFalse(HECHOS[h].get("vigenciaSinConfirmar"))
                        self.assertFalse(HECHOS[h].get("vencido"))

    def test_ninguna_cifra_del_funcionario_falta_en_sus_hechos(self):
        """Un monto, número o horario que dice el funcionario sale de un hecho
        que ese turno cita: no se inventan montos."""
        for e in NUEVOS:
            for t in e["turnos"]:
                if t["rol"] != "funcionario":
                    continue
                cifras = set(re.findall(r"\d+", t["texto"]))
                if not cifras:
                    continue
                with self.subTest(f"{e['id']} turno {t['n']}"):
                    self.assertTrue(t["hechos"], "cifra sin hecho")
                    fuente = " ".join(HECHOS[h]["hecho"] for h in t["hechos"])
                    permitidas = set(re.findall(r"\d+", fuente))
                    self.assertLessEqual(cifras, permitidas,
                                         f"«{t['texto']}» dice cifras que no están en {t['hechos']}")

    def test_las_variantes_no_agregan_cifras(self):
        """Una formulación alternativa no puede decir un monto distinto."""
        for e in NUEVOS:
            citados = " ".join(HECHOS[h]["hecho"] for t in e["turnos"]
                               for h in t["hechos"])
            permitidas = set(re.findall(r"\d+", citados))
            for p in e["variantes"]:
                for q in p["preguntas"]:
                    with self.subTest(f"{e['id']} {q}"):
                        self.assertLessEqual(set(re.findall(r"\d+", q)), permitidas)

    def test_los_montos_son_los_documentados(self):
        esperados = {"ESC-SEGIP-301": {"17"}, "ESC-NOT-301": {"50", "180"},
                     "ESC-SERECI-301": {"34"}}
        for eid, montos in esperados.items():
            e = next(x for x in NUEVOS if x["id"] == eid)
            dichos = set()
            for t in e["turnos"]:
                dichos |= set(re.findall(r"Bs\s*(\d+)", t["texto"]))
            self.assertEqual(dichos, montos, eid)

    def test_los_escenarios_sin_costos_no_dicen_bolivianos(self):
        """«Costos sin inventar montos»: donde no hay un monto documentado el
        escenario habla del costo sin cifra."""
        for e in NUEVOS:
            citados = " ".join(HECHOS[h]["hecho"] for t in e["turnos"] for h in t["hechos"])
            if "Bs" in citados:
                continue
            for t in e["turnos"]:
                with self.subTest(f"{e['id']} turno {t['n']}"):
                    self.assertNotRegex(t["texto"], r"\bBs\b")

    def test_no_agregan_palabras_sin_sena_nuevas(self):
        """«Trabajar con las palabras que se tienen»: el diccionario de
        palabras sin seña que sale del corpus es el mismo con y sin los
        escenarios nuevos."""
        ids_nuevos = {e["id"] for e in NUEVOS}
        sin_nuevos = dict(CORPUS, escenarios=[
            e for e in CORPUS["escenarios"] if e["id"] not in ids_nuevos])
        con = B.info_sin_sena(CORPUS, [], [])
        sin = B.info_sin_sena(sin_nuevos, [], [])
        self.assertEqual(sorted(con["palabras"]), sorted(sin["palabras"]))
        with open(os.path.join(B.ROOT, "assets", "dictionary",
                               "senas_sin_sena.json"), encoding="utf-8") as f:
            self.assertEqual(sorted(json.load(f)["palabras"]),
                             sorted(con["palabras"]))

    def test_el_costo_de_imp_301_se_explica_sin_monto(self):
        e = next(x for x in NUEVOS if x["id"] == "ESC-IMP-301")
        texto = " ".join(t["texto"] for t in e["turnos"])
        self.assertIn("base imponible", texto)
        self.assertNotRegex(texto, r"\d")


@unittest.skipUnless(NUEVOS, "sin escenarios nuevos")
class SinCruces(unittest.TestCase):
    def test_cada_institucion_cita_sus_hechos_o_los_de_su_derivacion(self):
        for e in NUEVOS:
            area = e["id"].split("-")[1]
            for t in e["turnos"]:
                for h in t["hechos"]:
                    with self.subTest(f"{e['id']} {h}"):
                        otra = area_de_hecho(h)
                        if otra != area:
                            self.assertIn((area, otra), DERIVACIONES)

    def test_la_derivacion_se_declara_en_la_ruta(self):
        """Quien deriva nombra a la otra institución; quien no deriva no la
        nombra: ningún escenario habla de una institución que no es suya."""
        nombres = {"SEPDAVI": "SEPDAVI", "SEPDEP": "SEPDEP", "SERECI": "SERECI",
                   "SLIM": "SLIM", "FELCV": "FELCV", "FELCC": "FELCC",
                   "SEGIP": "SEGIP", "SIREJ": "SIREJ"}
        for e in NUEVOS:
            area = e["id"].split("-")[1]
            permitidas = ({area} | {b for a, b in DERIVACIONES if a == area}
                          | {b for a, b in PROCEDENCIAS if a == area})
            dicho = {a for a in nombres
                     for t in e["turnos"] if re.search(rf"\b{a}\b", t["texto"])}
            with self.subTest(e["id"]):
                self.assertLessEqual(dicho - permitidas - {"SIREJ"}, set())

    def test_las_tarjetas_de_un_escenario_no_traen_glosas_de_otro_tramite(self):
        """Cada pregunta cita su escenario: ninguna se comparte."""
        ids = {}
        for q in BANCO["preguntas"]:
            ids.setdefault(q["id"], set()).add(q["origen"]["escenario"])
        for qid, escenarios in ids.items():
            self.assertEqual(len(escenarios), 1, qid)


@unittest.skipUnless(NUEVOS, "sin escenarios nuevos")
class Continuidad(unittest.TestCase):
    def test_un_paso_solo_depende_de_una_pregunta_anterior_de_su_recorrido(self):
        for e in NUEVOS:
            cid = "tramite_" + e["id"].lower().removeprefix("esc-").replace("-", "_")
            pasos = BANCO["recorridos"][cid]["pasos"]
            vistas = []
            for p in pasos:
                for c in p.get("cuando", []):
                    with self.subTest(f"{e['id']} {p['pregunta']}"):
                        self.assertIn(c["pregunta"], vistas)
                        self.assertTrue(c["estados"])
                vistas.append(p["pregunta"])

    def test_cada_estado_abre_el_paso_que_le_toca_y_ninguno_queda_sin_salida(self):
        """Para cada pregunta con respuestas, alguna de ellas lleva a otra
        pregunta o a un cierre: la conversación no se queda detenida."""
        for e in NUEVOS:
            cid = "tramite_" + e["id"].lower().removeprefix("esc-").replace("-", "_")
            pasos = BANCO["recorridos"][cid]["pasos"]
            for p in pasos:
                if p.get("soloConversacion"):
                    continue
                q = next(x for x in BANCO["preguntas"] if x["id"] == p["pregunta"])
                with self.subTest(f"{e['id']} {p['pregunta']}"):
                    self.assertTrue(q["opciones"])

    def test_los_estados_de_una_rama_existen_en_la_pregunta_padre(self):
        por_id = {q["id"]: q for q in BANCO["preguntas"]}
        for e in NUEVOS:
            cid = "tramite_" + e["id"].lower().removeprefix("esc-").replace("-", "_")
            for p in BANCO["recorridos"][cid]["pasos"]:
                for c in p.get("cuando", []):
                    presentes = {o["estado"] for o in por_id[c["pregunta"]]["opciones"]}
                    with self.subTest(f"{e['id']} {p['pregunta']}"):
                        self.assertLessEqual(set(c["estados"]), presentes)

    def test_la_primera_pregunta_no_depende_de_nadie(self):
        for e in NUEVOS:
            cid = "tramite_" + e["id"].lower().removeprefix("esc-").replace("-", "_")
            primero = BANCO["recorridos"][cid]["pasos"][0]
            with self.subTest(e["id"]):
                self.assertNotIn("cuando", primero)

    def test_los_datos_editables_son_opcionales_y_de_un_editor_conocido(self):
        con_dato = [e for e in NUEVOS if e.get("datosEditables")]
        self.assertGreaterEqual(len(con_dato), 2)
        for e in con_dato:
            for d in e["datosEditables"]:
                q = next(x for x in BANCO["preguntas"]
                         if x["id"] == f"R.{e['id']}.{d['turno']}")
                si = next(o for o in q["opciones"] if o["estado"] == "afirmado")
                with self.subTest(q["id"]):
                    self.assertIn(si["editor"], B.EDITORES)
                    self.assertTrue(si["editorOpcional"])
                    self.assertTrue(si["fraseSinValor"])


class ConsolidadosReales(unittest.TestCase):
    def test_un_consolidado_apunta_a_otro_mas_profundo_de_su_institucion(self):
        por_id = {e["id"]: e for e in CORPUS["escenarios"]}
        for e in CORPUS["escenarios"]:
            destino = e.get("consolidadoEn")
            if not destino:
                continue
            with self.subTest(e["id"]):
                otro = por_id[destino]
                self.assertEqual(e["id"].split("-")[1], otro["id"].split("-")[1])
                self.assertGreater(len(otro["turnos"]), len(e["turnos"]))
                self.assertIn(destino, {c["escenario"] for c in BANCO["contextos"]})

    def test_un_consolidado_conserva_su_recorrido(self):
        tiene = {c["escenario"]: c for c in BANCO["contextos"]}
        for e in CORPUS["escenarios"]:
            if e.get("consolidadoEn") and e["id"] in tiene:
                self.assertEqual(tiene[e["id"]]["consolidadoEn"], e["consolidadoEn"])


if __name__ == "__main__":
    unittest.main()
