"""Pruebas del constructor del corpus RAG con archivos temporales.

    python -m pytest tool/tests -q
"""

import json
import os
import sys
import tempfile
import unittest
from unittest import mock

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))

import build_rag_corpus as B  # noqa: E402


def escenario(area: str, n: int, hecho: str = "—") -> str:
    return f"""## ESC-{area}-{n:02d} — Trámite de prueba {n}
- **Institución:** Institución {area}
- **Trámite:** Trámite {n}
- **Tipo:** conocimiento_fijo
- **Inicia:** Funcionario
- **Situación:** Prueba.

| # | Rol | Mensaje | Propósito | Hechos |
|---|---|---|---|---|
| 1 | Funcionario | ¿Trae su cédula de identidad? | Requisito | {hecho} |
| 2 | Usuario Sordo | Sí, la tengo. | Confirmar | — |
"""


def documento(fuentes: str = "", hechos: str = "", cuerpo: str = "") -> str:
    return f"""# Parte

## Fuentes
| ID | Institución | Título | URL | Consultado |
|---|---|---|---|---|
{fuentes}
## Hechos verificados
| ID | Institución | Hecho | Tipo | Fuente | Vigencia |
|---|---|---|---|---|---|
{hechos}
{cuerpo}"""


class ConstructorRag(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.rag = self.tmp.name
        self.escenarios = os.path.join(self.rag, "escenarios")
        self.documentos = os.path.join(self.rag, "documentos")
        os.makedirs(self.escenarios)
        os.makedirs(self.documentos)
        self._rag, self._docs = B.RAG, B.DOCUMENTOS
        B.RAG, B.DOCUMENTOS = self.rag, self.documentos

    def tearDown(self):
        B.RAG, B.DOCUMENTOS = self._rag, self._docs
        self.tmp.cleanup()

    def escribir(self, nombre: str, texto: str):
        with open(os.path.join(self.escenarios, nombre), "w", encoding="utf-8") as f:
            f.write(texto)

    def construir(self, hoy: str = "2026-09-27"):
        f, h, e, err, av, archivos = B.leer_todos(self.escenarios)
        corpus = B.construir(f, h, e, err, av, hoy=hoy, archivos=archivos)
        return corpus, err, av

    def test_varios_archivos_se_suman(self):
        self.escribir("a.md", documento(cuerpo=escenario("AAA", 1)))
        self.escribir("b.md", documento(cuerpo=escenario("BBB", 1)))
        corpus, errores, _ = self.construir()
        self.assertEqual([], errores)
        self.assertEqual(["ESC-AAA-01", "ESC-BBB-01"],
                         [e["id"] for e in corpus["escenarios"]])
        self.assertEqual(2, len(corpus["archivos"]))
        self.assertTrue(corpus["escenarios"][1]["archivo"].endswith("b.md"))

    def test_un_identificador_repetido_entre_archivos_es_error(self):
        self.escribir("a.md", documento(cuerpo=escenario("AAA", 1)))
        self.escribir("b.md", documento(cuerpo=escenario("AAA", 1)))
        _, errores, _ = self.construir()
        self.assertTrue(any("ESC-AAA-01" in e and "a.md" in e and "b.md" in e
                            for e in errores), errores)

    def test_un_documento_local_se_puede_citar_por_pagina(self):
        from pypdf import PdfWriter
        pdf = PdfWriter()
        pdf.add_blank_page(width=100, height=100)
        pdf.add_blank_page(width=100, height=100)
        with open(os.path.join(self.documentos, "arancel.pdf"), "wb") as f:
            pdf.write(f)
        fuentes = ("| F-AAA-01 | Inst | Arancel | documentos/arancel.pdf#p=2 | 2026-09-27 |\n"
                   "| F-AAA-02 | Inst | Arancel | documentos/arancel.pdf#p=9 | 2026-09-27 |\n"
                   "| F-AAA-03 | Inst | Otro | documentos/no_existe.pdf | 2026-09-27 |\n")
        self.escribir("a.md", documento(fuentes=fuentes, cuerpo=escenario("AAA", 1)))
        _, errores, avisos = self.construir()
        self.assertFalse(any("F-AAA-01" in e for e in errores), errores)
        self.assertTrue(any("F-AAA-02" in e and "página 9" in e for e in errores))
        self.assertTrue(any("F-AAA-03" in e and "no existe" in e for e in errores))
        # Un documento local no es una web: no se avisa por su dominio.
        self.assertFalse(any("F-AAA-01" in a for a in avisos), avisos)

    def test_un_dato_con_plazo_vencido_deja_de_mostrarse(self):
        fuentes = "| F-AAA-01 | Inst | Aviso | https://x.gob.bo/a | 2026-09-27 |\n"
        hechos = ("| H-AAA-01 | Inst | Descuento del 10% hasta el 2026-10-05. | descuento "
                  "| F-AAA-01 | vigente |\n")
        self.escribir("a.md", documento(fuentes, hechos, escenario("AAA", 1, "H-AAA-01")))

        antes, _, _ = self.construir(hoy="2026-10-01")
        self.assertFalse(antes["hechos"]["H-AAA-01"]["vencido"])
        self.assertTrue(antes["escenarios"][0]["turnos"][0]["mostrable"])

        despues, _, avisos = self.construir(hoy="2026-10-06")
        self.assertTrue(despues["hechos"]["H-AAA-01"]["vencido"])
        turno = despues["escenarios"][0]["turnos"][0]
        self.assertFalse(turno["mostrable"])
        self.assertIn("dato_vencido", turno["motivos"])
        self.assertTrue(any("H-AAA-01" in a and "venció" in a for a in avisos))

    def test_vigencia_sin_confirmar_no_se_muestra_como_hecho(self):
        fuentes = "| F-AAA-01 | Inst | Aviso | https://x.gob.bo/a | 2026-09-27 |\n"
        hechos = ("| H-AAA-01 | Inst | El trámite no tiene costo. | costo "
                  "| F-AAA-01 | [VERIFICAR] vigencia actual |\n")
        self.escribir("a.md", documento(fuentes, hechos,
                                        escenario("AAA", 1, "H-AAA-01")))

        corpus, errores, _ = self.construir()
        self.assertEqual([], errores)
        hecho = corpus["hechos"]["H-AAA-01"]
        self.assertFalse(hecho["verificar"])
        self.assertTrue(hecho["vigenciaSinConfirmar"])
        turno = corpus["escenarios"][0]["turnos"][0]
        self.assertFalse(turno["mostrable"])
        self.assertIn("vigencia_sin_confirmar", turno["motivos"])



class SenasPendientes(unittest.TestCase):
    CORR = [{"palabra": "FOLIO", "accion": "concepto_sin_catalogo"},
            {"palabra": "REAL", "accion": "concepto_sin_catalogo"},
            {"palabra": "NUREJ", "accion": "concepto_sin_catalogo"},
            {"palabra": "No", "accion": "palabra_recuperada"}]

    def test_deletreo_sin_sena_es_una_sena_pendiente(self):
        glosas = ["YO", "NECESITAR", *"FOLIO", *"REAL", "CASA", *"NUREJ"]
        salida = B.marcar_senas_pendientes(
            glosas, self.CORR, "Necesito el Folio Real de mi casa y el NUREJ.")
        self.assertEqual(salida, ["YO", "NECESITAR", "SENA_PENDIENTE:FOLIO_REAL",
                                  "CASA", *"NUREJ"])

    def test_palabras_comunes_seguidas_no_se_juntan(self):
        salida = B.marcar_senas_pendientes(
            [*"FOLIO", *"REAL"], self.CORR[:2], "Mi folio real.")
        self.assertEqual(salida, ["SENA_PENDIENTE:FOLIO", "SENA_PENDIENTE:REAL"])

    def test_letras_que_no_coinciden_se_dejan_deletreadas(self):
        salida = B.marcar_senas_pendientes(
            ["YO", *"FOLI"], self.CORR[:1], "Folio")
        self.assertEqual(salida, ["YO", *"FOLI"])


class BancoTramites(unittest.TestCase):
    def test_palabras_en_otro_orden_que_el_espanol(self):
        corr = [{"palabra": "NORMA", "accion": "concepto_sin_catalogo"},
                {"palabra": "REGISTRO", "accion": "concepto_sin_catalogo"}]
        salida = B.marcar_senas_pendientes(
            [*"REGISTRO", "MANTENER", *"NORMA"], corr,
            "La norma mantiene el registro.")
        self.assertEqual(salida, ["SENA_PENDIENTE:REGISTRO", "MANTENER",
                                  "SENA_PENDIENTE:NORMA"])

    def test_cada_pregunta_con_respuestas_es_un_paso_del_tramite(self):
        corpus = {"escenarios": [{
            "id": "ESC-SERECI-02", "tramite": "Duplicado de matrimonio",
            "institucion": "SERECI",
            "turnos": [
                {"n": 1, "rol": "funcionario", "texto": "¿Necesita duplicado?",
                 "mostrable": True, "glosas": ["NECESITAR"]},
                {"n": 2, "rol": "sordo", "texto": "Sí.", "mostrable": True,
                 "glosas": ["SI"]},
                {"n": 3, "rol": "funcionario", "texto": "Confirme el valor.",
                 "mostrable": False},
                {"n": 4, "rol": "sordo", "texto": "Bien.", "mostrable": True,
                 "glosas": ["BIEN"]},
            ],
            "variantes": [{"turno": 1, "preguntas": ["¿Otra copia?"],
                           "respuestas": [{"texto": "No sé cuál.",
                                           "mostrable": True,
                                           "glosas": ["NO_SABER"]}]}],
        }]}
        banco = B.banco_tramites(corpus)
        self.assertEqual(list(banco["recorridos"]), ["tramite_sereci_02"])
        self.assertEqual(banco["recorridos"]["tramite_sereci_02"]["pasos"],
                         [{"pregunta": "R.ESC-SERECI-02.1"}])
        q = banco["preguntas"][0]
        self.assertEqual(q["formulacionLsb"]["glosas"], ["NECESITAR"])
        self.assertEqual([(o["etiqueta"], o["estado"]) for o in q["opciones"]],
                         [("Sí.", "afirmado"), ("No sé cuál.", "desconocido")])


class Equivalencias(unittest.TestCase):
    CORR = [{"palabra": "DOCUMENTO", "accion": "concepto_sin_catalogo"},
            {"palabra": "REAL", "accion": "concepto_sin_catalogo"}]
    # Claves normalizadas, como las deja `cargar_equivalencias`.
    EQ = {"documento": "PAPEL", "real": "VERDAD"}

    def test_una_equivalencia_aprobada_es_la_sena(self):
        salida = B.marcar_senas_pendientes(
            ["YO", *"DOCUMENTO", "FALTAR"], self.CORR[:1],
            "Me falta un documento.", self.EQ)
        self.assertEqual(salida, ["YO", "PAPEL", "FALTAR"])

    def test_una_correccion_usa_las_equivalencias_aprobadas(self):
        self.assertEqual(
            B.aplicar_equivalencias(
                ["SENA_PENDIENTE:DOCUMENTO", "SENA_PENDIENTE:AUTO", "PAPEL"],
                "Traje el documento del auto.", {"documento": "PAPEL"}),
            ["SENA_PENDIENTE:AUTO", "PAPEL"])

    def test_la_marca_pregunta_no_es_una_sena_que_falte(self):
        corr = [{"palabra": "PREGUNTA", "accion": "concepto_sin_catalogo"}]
        self.assertEqual(B.marcar_senas_pendientes(
            ["TENER", *"PREGUNTA"], corr, "¿Tiene la placa?"), ["TENER"])
        self.assertEqual(B.marcar_senas_pendientes(
            [*"PREGUNTA"], corr, "Tengo una pregunta."),
            ["SENA_PENDIENTE:PREGUNTA"])

    def test_la_sena_equivalente_no_se_repite(self):
        corr = [{"palabra": "CUANTO", "accion": "concepto_sin_catalogo"}]
        salida = B.marcar_senas_pendientes(
            ["CUANTOS", "PAGINA", *"CUANTO"], corr,
            "¿Cuánto dice la página?", {"cuanto": "CUÁNTOS"})
        self.assertEqual(salida, ["CUANTOS", "PAGINA"])

    def test_un_nombre_propio_no_se_cambia_por_otra_sena(self):
        salida = B.marcar_senas_pendientes(
            [*"REAL"], self.CORR[1:], "Necesito el Folio Real.", self.EQ)
        self.assertEqual(salida, ["SENA_PENDIENTE:REAL"])

    def test_solo_se_cargan_las_aprobadas(self):
        with tempfile.TemporaryDirectory() as d:
            ruta = os.path.join(d, "eq.json")
            with open(ruta, "w", encoding="utf-8") as f:
                json.dump({
                    "DOCUMENTO": {"sena": "PAPEL", "estado": "aprobada"},
                    "CASO": {"sena": "INVESTIGACIÓN", "estado": "propuesta"},
                    "ESTAR": {"sena": None, "estado": "sin_equivalente"},
                }, f)
            self.assertEqual(B.cargar_equivalencias(ruta), {"documento": "PAPEL"})


class HerramientaEquivalencias(unittest.TestCase):
    import rag_equivalencias as E  # noqa: E402

    CAT = {"PAPEL": ["Papel", "el documento"], "MÍO": ["Mío", "mi"],
           "AYUDAR": ["Ayudar", "ayudar"], "INVESTIGACIÓN": ["Investigación"]}

    def test_el_catalogo_escribe_la_palabra_tal_cual(self):
        self.assertEqual(self.E.por_catalogo("DOCUMENTO", self.CAT)["sena"],
                         "PAPEL")
        self.assertEqual(self.E.por_catalogo("MI", self.CAT)["sena"], "MÍO")
        self.assertIsNone(self.E.por_catalogo("CASO", self.CAT))

    def test_lo_que_propone_bedrock_siempre_se_revisa(self):
        ayuda = self.E.decidir("AYUDA", {"sena": "AYUDAR"}, self.CAT)
        caso = self.E.decidir("CASO", {"sena": "INVESTIGACIÓN"}, self.CAT)
        nada = self.E.decidir("ESTAR", {"sena": None}, self.CAT)
        self.assertEqual((ayuda["estado"], ayuda["misma_raiz"]),
                         ("propuesta", True))
        self.assertEqual((caso["estado"], caso["misma_raiz"]),
                         ("propuesta", False))
        self.assertEqual(nada["estado"], "sin_equivalente")


class Vocabulario(unittest.TestCase):
    def test_la_lista_ordena_por_uso_y_no_muestra_la_marca(self):
        corpus = {"escenarios": [{
            "id": "ESC-SERECI-02", "variantes": [],
            "turnos": [
                {"texto": "Sí. Perdimos la copia.", "glosas":
                 ["SI", "SENA_PENDIENTE:COPIA", "PERDER"]},
                {"texto": "¿Otra copia anterior?", "glosas":
                 ["SENA_PENDIENTE:COPIA", "SENA_PENDIENTE:ANTERIOR"]},
            ]}]}
        md = B.vocabulario_md(corpus)
        self.assertIn("**2 palabras · 3 usos.**", md)
        self.assertLess(md.index("| COPIA | 2 |"), md.index("| ANTERIOR | 1 |"))
        self.assertNotIn("SENA_PENDIENTE", md)


class ZonasDeTramite(unittest.TestCase):
    ZONAS = {"senas": {"papel": ("PAPEL", "Documentos"), "si": ("SÍ", "Respuesta"),
                       "casa": ("CASA", "Lugares")},
             "formas": {"papel": ["Papel", "el documento"], "casa": ["Casa"]},
             "palabras": {"BOLETA": "Documentos"}}
    ESC = {"turnos": [
        {"texto": "¿Qué trae?", "glosas": ["TRAER"]},
        {"texto": "Traje la boleta.", "glosas": ["TRAER", "SENA_PENDIENTE:BOLETA"]},
        {"texto": "Tengo el papel de la casa.", "glosas": ["PAPEL", "CASA"]},
    ], "variantes": []}

    def test_la_pregunta_abre_las_zonas_de_sus_respuestas(self):
        respuestas = [{"glosas": ["SI", "SENA_PENDIENTE:BOLETA"]}]
        tarjetas = B.tarjetas_de_zona(self.ESC, respuestas, self.ZONAS)
        # Documentos (por BOLETA), no Lugares ni Respuesta.
        self.assertEqual([(t["glosas"], t["frase"]) for t in tarjetas],
                         [(["SENA_PENDIENTE:BOLETA"], "boleta"),
                          (["PAPEL"], "papel")])

    def test_sin_zona_de_respuesta_no_hay_tarjetas(self):
        self.assertEqual(
            B.tarjetas_de_zona(self.ESC, [{"glosas": ["SI"]}], self.ZONAS), [])


class ConfirmacionAutomatica(unittest.TestCase):
    """Una equivalencia de Bedrock se decide sola con Titan y la vuelta."""

    def decidir(self, zona, faltan, sobran):
        import rag_equivalencias as E
        import rag_zonas as ZN
        import rag_indexar_embeddings as RI
        salida = {"BOLETA": {"sena": "FACTURA", "estado": "propuesta",
                             "origen": "bedrock",
                             "ejemplos": ["Tengo mi boleta."]}}
        with tempfile.TemporaryDirectory() as d:
            zonas = os.path.join(d, "zonas.json")
            with open(zonas, "w", encoding="utf-8") as f:
                json.dump({"BOLETA": {"zona": zona}}, f)
            respuesta = {"generated": True, "items": [
                {"faltan": faltan, "sobran": sobran}]}
            with mock.patch.object(ZN, "DESTINO", zonas),                     mock.patch.object(RI, "llamar", return_value=respuesta),                     mock.patch.object(E, "_frases_con_glosas", return_value={
                        "Tengo mi boleta.": ["TENER", "MÍO",
                                             "SENA_PENDIENTE:BOLETA"]}):
                E.confirmar("url", salida)
        return salida["BOLETA"]

    def test_con_las_tres_senales_se_aprueba_sola(self):
        e = self.decidir("Documentos", [], [])
        self.assertEqual((e["estado"], e["automatica"]), ("aprobada", True))

    def test_si_la_sena_es_de_otra_zona_se_rechaza(self):
        self.assertEqual(self.decidir("Lugares", [], [])["estado"], "rechazada")

    def test_si_la_vuelta_pierde_la_palabra_se_rechaza(self):
        e = self.decidir("Documentos", ["boleta"], [])
        self.assertEqual(e["estado"], "rechazada")

if __name__ == "__main__":
    unittest.main()


class IngestaDocumentos(unittest.TestCase):
    """Un documento nuevo produce un prompt con los siguientes IDs libres."""

    def setUp(self):
        import rag_ingestar_documentos as I
        self.I = I
        self.tmp = tempfile.TemporaryDirectory()
        rag = self.tmp.name
        self.guardado = (B.RAG, B.DOCUMENTOS, B.ESCENARIOS, I.EXTRAIDO, I.PENDIENTES)
        B.RAG = rag
        B.DOCUMENTOS = os.path.join(rag, "documentos")
        B.ESCENARIOS = os.path.join(rag, "escenarios")
        I.EXTRAIDO = os.path.join(B.DOCUMENTOS, "extraido")
        I.PENDIENTES = os.path.join(rag, "pendientes")
        os.makedirs(B.DOCUMENTOS)
        os.makedirs(B.ESCENARIOS)
        with open(os.path.join(B.ESCENARIOS, "a.md"), "w", encoding="utf-8") as f:
            f.write(documento(cuerpo=escenario("DDRR", 4)))

    def tearDown(self):
        (B.RAG, B.DOCUMENTOS, B.ESCENARIOS,
         self.I.EXTRAIDO, self.I.PENDIENTES) = self.guardado
        self.tmp.cleanup()

    def test_documento_md_genera_prompt_con_ids_libres_y_su_texto(self):
        with open(os.path.join(B.DOCUMENTOS, "Arancel Notarial 2025.md"),
                  "w", encoding="utf-8") as f:
            f.write("Certificación de firmas: Bs 50 por formulario.")
        salida = self.I.procesar(os.path.join(B.DOCUMENTOS, "Arancel Notarial 2025.md"),
                                 self.I.siguientes_ids())
        self.assertIn("procesado: Arancel Notarial 2025.md (1 páginas)", salida)
        with open(os.path.join(self.I.PENDIENTES, "arancel_notarial_2025_prompt.md"),
                  encoding="utf-8") as f:
            texto = f.read()
        self.assertIn("| DDRR | ESC-DDRR-05 |", texto)
        self.assertIn("documentos/Arancel Notarial 2025.md#p=<página>", texto)
        self.assertIn("Certificación de firmas: Bs 50 por formulario.", texto)
        self.assertIn("[VERIFICAR]", texto)  # reglas del prompt base
        # Sin cambios, no se vuelve a procesar.
        again = self.I.procesar(os.path.join(B.DOCUMENTOS, "Arancel Notarial 2025.md"),
                                self.I.siguientes_ids())
        self.assertEqual(["sin cambios: Arancel Notarial 2025.md"], again)

    def test_un_pdf_sin_texto_pide_ocr(self):
        from pypdf import PdfWriter
        pdf = PdfWriter()
        pdf.add_blank_page(width=100, height=100)
        ruta = os.path.join(B.DOCUMENTOS, "escaneado.pdf")
        with open(ruta, "wb") as f:
            pdf.write(f)
        salida = self.I.procesar(ruta, self.I.siguientes_ids())
        self.assertTrue(any("OCR" in s for s in salida), salida)
        self.assertFalse(os.path.exists(self.I.PENDIENTES))
