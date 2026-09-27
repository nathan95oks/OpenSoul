"""Pruebas del constructor del corpus RAG con archivos temporales.

    python -m pytest tool/tests -q
"""

import os
import sys
import tempfile
import unittest

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
