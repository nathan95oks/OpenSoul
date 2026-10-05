"""Ingesta de documentos, glosas separadas y ramificaciones del corpus RAG.

    python -m pytest tool/tests/test_rag_ingesta_y_ramas.py -q

Sin red: la Lambda Texto→LSB no se llama nunca; las glosas salen de una
caché de prueba. Para regenerar el banco que lee
`test/rag_ramificaciones_test.dart`:

    REGENERAR_FIXTURES=1 python -m pytest tool/tests/test_rag_ingesta_y_ramas.py -q
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
import rag_documento_escenarios as D  # noqa: E402
import rag_ingestar_documentos as I  # noqa: E402
import rag_texto as T  # noqa: E402

FIXTURE_MD = os.path.join(AQUI, "fixtures", "escenario_ramificado.md")
FIXTURE_DART = os.path.join(B.ROOT, "test", "fixtures", "rag_tramite_ramificado.json")

# Lo que habría devuelto la Lambda para cada frase del escenario de prueba,
# con señas del catálogo.
GLOSAS_DE_PRUEBA = {
    "¿Trajo su cédula de identidad?": ["IDENTIDAD", "TRAER"],
    "Sí, traje mi cédula.": ["SÍ", "IDENTIDAD", "TRAER"],
    "No, no traje mi cédula.": ["IDENTIDAD", "TRAER", "NO"],
    "No sé si la traje.": ["NO_SABER", "TRAER"],
    "¿Qué documentos trajo?": ["PAPEL", "TRAER", "QUÉ"],
    "Traje el certificado y la fotocopia.": ["CERTIFICADO", "FOTOCOPIA", "TRAER"],
    "Traje la factura.": ["FACTURA", "TRAER"],
    "No traje documentos.": ["PAPEL", "TRAER", "NO"],
    "¿Tiene una fotocopia de la cédula?": ["FOTOCOPIA", "IDENTIDAD", "TENER"],
    "No, no tengo fotocopia.": ["FOTOCOPIA", "TENER", "NO"],
    "Sí, tengo fotocopia.": ["SÍ", "FOTOCOPIA", "TENER"],
    "¿Sabe dónde está su cédula?": ["IDENTIDAD", "DÓNDE"],
    "No sé dónde está.": ["NO_SABER", "DÓNDE"],
    "Sí, está en mi casa.": ["SÍ", "CASA"],
}


def pdf_con_texto(paginas: list) -> bytes:
    """Un PDF mínimo y válido con una línea de texto por línea de cada
    página (Helvetica, WinAnsiEncoding: admite tildes, ñ y ¿)."""
    objetos = {1: "<< /Type /Catalog /Pages 2 0 R >>",
               3: "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
                  "/Encoding /WinAnsiEncoding >>"}
    hijos = []
    for i, texto in enumerate(paginas):
        pagina, contenido = 4 + 2 * i, 5 + 2 * i
        hijos.append(f"{pagina} 0 R")
        lineas = []
        for k, linea in enumerate(texto.split("\n")):
            crudo = linea.encode("cp1252")
            escapado = "".join(
                f"\\{b:03o}" if b > 126 or chr(b) in "()\\" else chr(b)
                for b in crudo)
            lineas.append(f"BT /F1 11 Tf 40 {760 - 16 * k} Td ({escapado}) Tj ET")
        flujo = "\n".join(lineas)
        objetos[pagina] = (f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
                           f"/Resources << /Font << /F1 3 0 R >> >> "
                           f"/Contents {contenido} 0 R >>")
        objetos[contenido] = (f"<< /Length {len(flujo.encode('latin-1'))} >>\n"
                              f"stream\n{flujo}\nendstream")
    objetos[2] = (f"<< /Type /Pages /Kids [{' '.join(hijos)}] "
                  f"/Count {len(hijos)} >>")
    salida = b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n"
    posiciones = {}
    for n in sorted(objetos):
        posiciones[n] = len(salida)
        salida += f"{n} 0 obj\n{objetos[n]}\nendobj\n".encode("latin-1")
    xref = len(salida)
    salida += f"xref\n0 {len(objetos) + 1}\n0000000000 65535 f \n".encode()
    for n in sorted(objetos):
        salida += f"{posiciones[n]:010d} 00000 n \n".encode()
    salida += (f"trailer\n<< /Size {len(objetos) + 1} /Root 1 0 R >>\n"
               f"startxref\n{xref}\n%%EOF\n").encode()
    return salida


# Lo que queda al abrir un PDF como texto y guardarlo como .md: la sintaxis
# del PDF y «�» donde iban los flujos comprimidos.
COPIA_TEXTUAL = (
    "%PDF-1.4\n%���� ReportLab Generated PDF document "
    "http://www.reportlab.com\n1 0 obj\n<<\n/F1 2 0 R /F2 3 0 R\n>>\nendobj\n"
    "2 0 obj\n<<\n/BaseFont /Helvetica /Encoding /WinAnsiEncoding /Name /F1 "
    "/Subtype /Type1 /Type /Font\n>>\nendobj\n4 0 obj\n<<\n/Contents 55 0 R "
    "/MediaBox [ 0 0 595.2756 841.8898 ] /Parent 54 0 R\n>>\nendobj\n"
    "55 0 obj\n<<\n/Filter [ /ASCII85Decode /FlateDecode ] /Length 1702\n>>\n"
    "stream\nGat=k��9�Q�\nendstream\nendobj\n")


class CarpetasTemporales(unittest.TestCase):
    """documentos/, escenarios/, extraido/ y pendientes/ en un temporal."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        rag = self.tmp.name
        self.guardado = (B.RAG, B.DOCUMENTOS, B.ESCENARIOS, I.EXTRAIDO,
                         I.PENDIENTES, B.GLOSAS)
        B.RAG = rag
        B.DOCUMENTOS = os.path.join(rag, "documentos")
        B.ESCENARIOS = os.path.join(rag, "escenarios")
        B.GLOSAS = os.path.join(rag, "glosas_cache.json")
        I.EXTRAIDO = os.path.join(B.DOCUMENTOS, "extraido")
        I.PENDIENTES = os.path.join(rag, "pendientes")
        os.makedirs(B.DOCUMENTOS)
        os.makedirs(B.ESCENARIOS)
        with open(FIXTURE_MD, encoding="utf-8") as f:
            self.escribir(B.ESCENARIOS, "a.md", f.read())

    def tearDown(self):
        (B.RAG, B.DOCUMENTOS, B.ESCENARIOS, I.EXTRAIDO, I.PENDIENTES,
         B.GLOSAS) = self.guardado
        self.tmp.cleanup()

    @staticmethod
    def escribir(carpeta, nombre, contenido):
        ruta = os.path.join(carpeta, nombre)
        modo = "wb" if isinstance(contenido, bytes) else "w"
        with open(ruta, modo, **({} if modo == "wb" else
                                 {"encoding": "utf-8", "newline": ""})) as f:
            f.write(contenido)
        return ruta

    def procesar(self, nombre):
        return I.procesar(os.path.join(B.DOCUMENTOS, nombre), I.siguientes_ids())


class FormatoYTexto(unittest.TestCase):
    def test_un_pdf_se_reconoce_por_su_firma_y_no_por_la_extension(self):
        with tempfile.TemporaryDirectory() as d:
            ruta = os.path.join(d, "requisitos.md")
            with open(ruta, "wb") as f:
                f.write(pdf_con_texto(["Hola"]))
            formato = T.detectar_formato(ruta)
        self.assertEqual(formato["formato"], "pdf")
        self.assertFalse(formato["coincide"])

    def test_la_copia_textual_de_un_pdf_no_es_texto(self):
        with tempfile.TemporaryDirectory() as d:
            ruta = os.path.join(d, "Derechos_Reales.md")
            with open(ruta, "w", encoding="utf-8") as f:
                f.write(COPIA_TEXTUAL)
            formato = T.detectar_formato(ruta)
        self.assertEqual(formato["formato"], "copia_pdf")
        self.assertIn("%PDF-1", formato["detalle"])

    def test_normalizar_conserva_tildes_ene_signos_y_cifras(self):
        crudo = ("¿Trajo   la cédula? Señor Ñandú, Bs 50.\r\n"
                 "Certiﬁcado de grava­men​ — «No».\n\n\n\nFin")
        texto, cambios = T.normalizar(crudo)
        self.assertEqual(texto, "¿Trajo la cédula? Señor Ñandú, Bs 50.\n"
                                "Certificado de gravamen — «No».\n\nFin")
        self.assertIn("ligaduras", cambios)
        # Una «e» con tilde combinada pasa a su forma compuesta, no pierde
        # la tilde.
        self.assertEqual(T.normalizar("cédula")[0], "cédula")

    def test_los_caracteres_sospechosos_se_ubican(self):
        texto = "Línea correcta\nCertificaci�n\x07 y trÃ¡mite"
        tipos = {(p["linea"], p["columna"], p["tipo"].split(" ")[0])
                 for p in T.problemas(texto)}
        self.assertIn((2, 12, "carácter"), tipos)
        self.assertEqual(len(T.problemas(texto)), 4)
        resumen = "\n".join(T.resumir(T.problemas(texto), "doc.md: "))
        self.assertIn("U+FFFD", resumen)
        self.assertIn("U+0007", resumen)
        self.assertIn("mojibake «Ã¡»", resumen)
        self.assertIn("uso privado U+E000", resumen)
        self.assertIn("línea 2, columna 12", resumen)

    def test_el_espanol_correcto_no_tiene_problemas(self):
        self.assertEqual(T.problemas(
            "¿Dónde está el Folio Real? Señora Muñoz: «no sé», 3 años."), [])


class Ingesta(CarpetasTemporales):
    def test_un_pdf_valido_se_extrae_con_sus_tildes_y_su_pagina(self):
        self.escribir(B.DOCUMENTOS, "Arancel.pdf", pdf_con_texto([
            "Certificación de firmas",
            "¿Qué trámite? Señor Muñoz, Bs 50"]))
        salida = self.procesar("Arancel.pdf")
        self.assertIn("procesado: Arancel.pdf (2 páginas)", salida)
        with open(os.path.join(I.EXTRAIDO, "arancel.md"), encoding="utf-8") as f:
            texto = f.read()
        self.assertIn("formato: pdf", texto)
        self.assertIn("no es un archivo de escenarios", texto)
        self.assertIn("## Página 2\n\n¿Qué trámite? Señor Muñoz, Bs 50", texto)
        self.assertEqual(T.problemas(texto), [])
        self.assertTrue(os.path.exists(
            os.path.join(I.PENDIENTES, "arancel_prompt.md")))

    def test_un_pdf_con_extension_md_se_lee_como_pdf(self):
        self.escribir(B.DOCUMENTOS, "requisitos.md",
                      pdf_con_texto(["Requisitos del trámite"]))
        salida = self.procesar("requisitos.md")
        self.assertTrue(any("se lee como PDF" in s for s in salida), salida)
        with open(os.path.join(I.EXTRAIDO, "requisitos.md"), encoding="utf-8") as f:
            self.assertIn("Requisitos del trámite", f.read())

    def test_la_copia_textual_de_un_pdf_pide_el_original_y_no_escribe_nada(self):
        self.escribir(B.DOCUMENTOS, "Derechos_Reales.md", COPIA_TEXTUAL)
        salida = self.procesar("Derechos_Reales.md")
        self.assertTrue(salida[0].startswith("ERROR"), salida)
        self.assertIn("Hace falta el PDF original", salida[0])
        self.assertIn("«�» en lugar de datos binarios", salida[0])
        self.assertFalse(os.path.exists(I.EXTRAIDO))
        self.assertFalse(os.path.exists(I.PENDIENTES))

    def test_un_texto_con_caracteres_perdidos_se_detiene_con_su_ubicacion(self):
        self.escribir(B.DOCUMENTOS, "nota.txt",
                      "Primera línea bien.\nInscripci�n de hipoteca.")
        salida = self.procesar("nota.txt")
        errores = [s for s in salida if s.startswith("ERROR")]
        self.assertTrue(any("línea 2, columna 10" in e for e in errores), salida)
        self.assertTrue(any("no se reconstruye" in e for e in errores))
        self.assertFalse(os.path.exists(I.EXTRAIDO))

    def test_un_texto_no_utf8_no_se_adivina(self):
        self.escribir(B.DOCUMENTOS, "viejo.txt", "Cédula".encode("cp1252"))
        salida = self.procesar("viejo.txt")
        self.assertIn("UTF-8", salida[0])
        self.assertTrue(salida[0].startswith("ERROR"))

    def test_un_documento_de_escenarios_da_un_borrador_validado(self):
        paginas = [
            "ESC-DDRR-91 / CERTIFICADOS\nFolio Real de prueba\n"
            "Situación: La persona pide un Folio Real.\n"
            "PREGUNTAS EN UNA SECUENCIA POSIBLE\n"
            "01\nFuncionario\n¿Trajo su cédula de\nidentidad?\n"
            "02\nPersona\nusuaria\nSí, traje mi cédula.\n"
            "VARIANTES Y RESPUESTAS POSIBLES\n"
            "P1. ¿Trajo su cédula de identidad?\n"
            "Variantes: ¿Tiene su cédula? / ¿Puede mostrar\nsu cédula?\n"
            "Respuestas: Sí, traje mi cédula. / No, no traje mi cédula. / No\n"
            "sé si la traje.\n"
            "ESCENARIOS POSIBLES\n"
            "Sin cédula: pasar a ESC-DDRR-06.\n"
            "Referencia temática: F-DDRR-91 · Tipo: mixto · Diálogo propuesto.",
            "Fuentes y trazabilidad\nConsultadas el 2026-10-01.\n"
            "F-DDRR-91 · Folio Real - requisitos\n"
            "https://cm.organojudicial.gob.bo/consejo/requisitosddrr/42.html",
        ]
        self.escribir(B.DOCUMENTOS, "Escenarios DDRR.pdf", pdf_con_texto(paginas))
        salida = self.procesar("Escenarios DDRR.pdf")
        self.assertFalse([s for s in salida if s.startswith("ERROR")], salida)
        self.assertTrue(any("validado junto al corpus activo: sin errores" in s
                            for s in salida), salida)
        ruta = os.path.join(I.PENDIENTES, "escenarios_ddrr_escenarios.md")
        fuentes, _, escenarios, errores, _ = B.leer(ruta)
        self.assertEqual(errores, [])
        self.assertEqual(fuentes["F-DDRR-91"]["consultado"], "2026-10-01")
        e = escenarios[0]
        self.assertEqual(e["meta"]["documento"],
                         "documentos/Escenarios DDRR.pdf#p=1")
        self.assertEqual([t["texto"] for t in e["turnos"]],
                         ["¿Trajo su cédula de identidad?", "Sí, traje mi cédula."])
        self.assertEqual(e["variantes"][1][1],
                         "«Sí, traje mi cédula.» · «No, no traje mi cédula.» · "
                         "«No sé si la traje.»")
        # «Escenarios posibles» es una nota: no crea ramificaciones.
        self.assertEqual(e["ramificaciones"], [])
        # El corpus activo no cambió: el borrador espera revisión.
        self.assertEqual(os.listdir(B.ESCENARIOS), ["a.md"])

    def documento_de_escenarios(self, nombre="Escenarios DDRR.pdf", eid="91"):
        paginas = [
            f"ESC-DDRR-{eid} / CERTIFICADOS\nFolio Real de prueba\n"
            "Situación: La persona pide un Folio Real.\n"
            "PREGUNTAS EN UNA SECUENCIA POSIBLE\n"
            "01\nFuncionario\n¿Trajo su cédula?\n"
            "02\nPersona\nusuaria\nSí, traje mi cédula.\n"
            "VARIANTES Y RESPUESTAS POSIBLES\n"
            "P1. ¿Trajo su cédula?\n"
            "Variantes: ¿Tiene su cédula?\n"
            "Respuestas: Sí, traje mi cédula. / No sé.\n",
            "Fuentes y trazabilidad\nConsultadas el 2026-10-01.\n"
            f"F-DDRR-{eid} · Folio Real - requisitos\n"
            "https://cm.organojudicial.gob.bo/consejo/requisitosddrr/42.html",
        ]
        self.escribir(B.DOCUMENTOS, nombre, pdf_con_texto(paginas))

    def test_el_borrador_de_un_documento_pide_el_lexico_estricto(self):
        self.documento_de_escenarios()
        self.procesar("Escenarios DDRR.pdf")
        ruta = os.path.join(I.PENDIENTES, "escenarios_ddrr_escenarios.md")
        with open(ruta, encoding="utf-8") as f:
            self.assertEqual(f.readline().strip(), B.MARCA_ESTRICTA)

    def test_un_borrador_que_fallo_no_se_esconde_al_repetir(self):
        # Antes: el texto extraído quedaba escrito, el borrador fallaba y la
        # siguiente ejecución decía «sin cambios» y terminaba bien.
        # ESC-DDRR-90 ya está en el corpus de prueba (a.md): el borrador no
        # pasa la validación.
        self.documento_de_escenarios(eid="90")
        primera = self.procesar("Escenarios DDRR.pdf")
        self.assertTrue(any(s.startswith("ERROR") for s in primera), primera)
        segunda = self.procesar("Escenarios DDRR.pdf")
        self.assertNotIn("sin cambios: Escenarios DDRR.pdf", segunda)
        self.assertEqual([s.startswith("ERROR") for s in primera],
                         [s.startswith("ERROR") for s in segunda])

    def test_un_documento_ya_movido_a_escenarios_no_se_vuelve_a_proponer(self):
        self.documento_de_escenarios()
        self.procesar("Escenarios DDRR.pdf")
        borrador = os.path.join(I.PENDIENTES, "escenarios_ddrr_escenarios.md")
        os.replace(borrador, os.path.join(B.ESCENARIOS, "ddrr.md"))
        salida = self.procesar("Escenarios DDRR.pdf")
        self.assertEqual(len(salida), 1)
        self.assertTrue(salida[0].startswith("ya incorporado:"), salida)

    def test_sin_pypdf_un_pdf_da_un_mensaje_y_no_una_traza(self):
        self.documento_de_escenarios()
        with mock.patch.dict(sys.modules, {"pypdf": None}):
            salida = self.procesar("Escenarios DDRR.pdf")
        self.assertTrue(any("falta pypdf" in s for s in salida), salida)

    def test_el_corpus_rechaza_un_pdf_o_su_copia_en_escenarios(self):
        self.escribir(B.ESCENARIOS, "Derechos_Reales.pdf", pdf_con_texto(["x"]))
        self.escribir(B.ESCENARIOS, "copia.md", COPIA_TEXTUAL)
        *_, errores, _, _ = B.leer_todos(B.ESCENARIOS)
        texto = "\n".join(errores)
        self.assertIn("Derechos_Reales.pdf: en", texto)
        self.assertIn("solo van escenarios .md", texto)
        self.assertIn("copia.md es la copia como texto de un PDF", texto)


def construir_fixture(cache: dict = GLOSAS_DE_PRUEBA) -> tuple:
    """(corpus, banco, errores, avisos) del escenario de prueba."""
    fuentes, hechos, escenarios, errores, avisos = B.leer(FIXTURE_MD)
    corpus = B.construir(fuentes, hechos, escenarios, errores, avisos,
                         hoy="2026-10-01", archivos=[B._rel(FIXTURE_MD)])
    with tempfile.TemporaryDirectory() as d:
        ruta = os.path.join(d, "cache.json")
        with open(ruta, "w", encoding="utf-8") as f:
            json.dump({k: {"glosas": v} for k, v in cache.items()}, f)
        nada = os.path.join(d, "no_existe.json")
        with mock.patch.multiple(B, GLOSAS=ruta, CORRECCIONES=nada,
                                 EQUIVALENCIAS=nada):
            B.poner_glosas(corpus, avisos)
    banco = B.banco_tramites(corpus, avisos)
    return corpus, banco, errores, avisos


class Glosas(unittest.TestCase):
    def test_solo_son_glosas_las_del_catalogo_compuestos_letras_y_pendientes(self):
        self.assertEqual(B.glosas_invalidas([
            "IDENTIDAD", "SI", "SÍ", "COMO_ESTAS", "NO_SABER", "POR_QUE", "A",
            "7", "SENA_PENDIENTE:FOLIO_REAL"]), [])
        self.assertEqual(B.glosas_invalidas(
            ["SÍ, LA TRAJE", "si", "TRAJE MI CÉDULA", "SEÑA_INVENTADA",
             "SENA_PENDIENTE:folio real"]),
            ["SÍ, LA TRAJE", "si", "TRAJE MI CÉDULA", "SEÑA_INVENTADA",
             "SENA_PENDIENTE:folio real"])

    def test_una_frase_guardada_como_glosa_no_llega_a_ninguna_tarjeta(self):
        cache = {**GLOSAS_DE_PRUEBA, "Sí, traje mi cédula.": ["SÍ, TRAJE MI CÉDULA"]}
        _, banco, _, avisos = construir_fixture(cache)
        glosas = [g for q in banco["preguntas"] for o in q["opciones"]
                  for g in o["glosas"]]
        self.assertEqual(B.glosas_invalidas(glosas), [])
        self.assertTrue(any("no son glosas (SÍ, TRAJE MI CÉDULA)" in a
                            for a in avisos), avisos)

    def test_cada_tarjeta_es_una_sena_y_su_espanol_va_aparte(self):
        _, banco, _, _ = construir_fixture()
        q = next(q for q in banco["preguntas"] if q["id"] == "R.ESC-DDRR-90.3")
        self.assertEqual(q["control"], "seleccion_multiple")
        self.assertEqual(q["plantilla"], "Traje {items}.")
        # PAPEL no: ya es lo que pregunta («¿Qué documentos…?»).
        self.assertEqual([(o["glosas"], o["frase"]) for o in q["opciones"]],
                         [(["CERTIFICADO"], "un certificado"),
                          (["FOTOCOPIA"], "una fotocopia"),
                          (["FACTURA"], "la factura")])
        todas = [o for q in banco["preguntas"] for o in q["opciones"]]
        self.assertTrue(all(len(o["glosas"]) == 1 for o in todas))

    def test_las_preguntas_nuevas_se_traducen_en_la_misma_pasada(self):
        corpus, _, _, _ = construir_fixture(cache={})
        textos = [t["texto"] for t in B.frases_a_traducir(corpus["escenarios"][0])]
        # Sin ninguna glosa aún, también las preguntas del funcionario.
        self.assertIn("¿Trajo su cédula de identidad?", textos)
        self.assertIn("No sé si la traje.", textos)
        self.assertEqual(len(textos), len(GLOSAS_DE_PRUEBA))


class Ramificaciones(unittest.TestCase):
    def setUp(self):
        self.corpus, self.banco, self.errores, self.avisos = construir_fixture()

    def pregunta(self, n):
        return next(q for q in self.banco["preguntas"]
                    if q["id"] == f"R.ESC-DDRR-90.{n}")

    def test_los_pasos_dependen_solo_de_lo_declarado(self):
        self.assertEqual(self.errores, [])
        pasos = self.banco["recorridos"]["tramite_ddrr_90"]["pasos"]
        q1 = "R.ESC-DDRR-90.1"
        self.assertEqual(pasos, [
            {"pregunta": q1},
            {"pregunta": "R.ESC-DDRR-90.3", "padre": q1,
             "cuando": [{"pregunta": q1, "estados": ["afirmado"]}]},
            {"pregunta": "R.ESC-DDRR-90.5", "padre": q1,
             "cuando": [{"pregunta": q1, "estados": ["negado"]}]},
            # «si Turno 1 = «No sé si la traje.»»: las respuestas ya no son
            # frases que se eligen; cuenta su estado.
            {"pregunta": "R.ESC-DDRR-90.7", "padre": q1,
             "cuando": [{"pregunta": q1, "estados": ["desconocido"]}]},
        ])

    def test_la_pregunta_polar_se_responde_con_si_no_y_no_se(self):
        q = self.pregunta(1)
        self.assertEqual(q["control"], "polar3")
        self.assertEqual(
            [(o["id"], o["frase"], o["estado"], o["glosas"]) for o in q["opciones"]],
            [
                # Una seña por tarjeta; al elegirla se dice la respuesta
                # documentada de ese estado, una frase completa.
                ("si", "Sí, traje mi cédula.", "afirmado", ["SÍ"]),
                ("no", "No, no traje mi cédula.", "negado", ["NO"]),
                ("no_se", "No sé si la traje.", "desconocido", ["NO_SABER"]),
            ])
        self.assertTrue(all(o["polar"] for o in q["opciones"]))

    def test_siempre_si_no_y_no_se_y_sin_respuesta_la_particula(self):
        # «¿Tiene una fotocopia de la cédula?»: no hay respuesta «No sé»
        # documentada; NO SÉ se ofrece igual y dice solo «No sé.».
        q = self.pregunta(5)
        self.assertEqual(q["control"], "polar3")
        self.assertEqual([(o["id"], o["frase"]) for o in q["opciones"]],
                         [("si", "Sí, tengo fotocopia."),
                          ("no", "No, no tengo fotocopia."),
                          ("no_se", "No sé.")])

    def test_una_disyuntiva_no_se_responde_con_si_o_no(self):
        self.assertFalse(B.es_pregunta_polar("¿Es víctima o persona denunciada?"))
        self.assertFalse(B.es_pregunta_polar("¿Qué documentos trajo?"))
        self.assertTrue(B.es_pregunta_polar("¿Trajo su cédula de identidad?"))

    def test_las_tarjetas_salen_solo_de_las_respuestas_afirmativas(self):
        q = self.pregunta(3)
        self.assertEqual(q["control"], "seleccion_multiple")
        self.assertEqual(q["plantilla"], "Traje {items}.")
        tarjetas = [o for o in q["opciones"] if o.get("zona")]
        # Ni IDENTIDAD (de otra pregunta) ni PAPEL (de «No traje documentos»)
        # ni TRAER (una acción).
        self.assertEqual([(t["glosas"], t["frase"]) for t in tarjetas], [
            (["CERTIFICADO"], "un certificado"),
            (["FOTOCOPIA"], "una fotocopia"),
            (["FACTURA"], "la factura")])
        self.assertEqual(q["maximo"], 3)
        self.assertTrue(all(o["salida"] for o in q["opciones"] if not o.get("zona")))

    def test_una_pregunta_de_si_o_no_no_abre_tarjetas(self):
        for n in (5, 7):
            self.assertFalse(any(o.get("zona") for o in self.pregunta(n)["opciones"]))

    def test_cada_pregunta_cita_su_escenario_turno_y_archivo(self):
        self.assertEqual(self.pregunta(3)["origen"], {
            "escenario": "ESC-DDRR-90", "turno": 3,
            "archivo": "tool/tests/fixtures/escenario_ramificado.md",
            "fuentes": []})

    def test_si_falta_la_pregunta_padre_el_hijo_no_aparece_siempre(self):
        # Ninguna respuesta al turno 1 tiene glosas: no es una pregunta.
        sin = {"Sí, traje mi cédula.", "No, no traje mi cédula.",
               "No sé si la traje."}
        cache = {k: v for k, v in GLOSAS_DE_PRUEBA.items() if k not in sin}
        _, banco, _, avisos = construir_fixture(cache)
        self.assertEqual(banco["recorridos"], {})
        self.assertTrue(any("depende del turno 1, que no se ofrece" in a
                            for a in avisos), avisos)

    def test_el_banco_de_la_app_esta_al_dia_con_el_escenario(self):
        datos = json.dumps(self.banco, ensure_ascii=False, indent=1,
                           sort_keys=True) + "\n"
        if os.environ.get("REGENERAR_FIXTURES"):
            os.makedirs(os.path.dirname(FIXTURE_DART), exist_ok=True)
            with open(FIXTURE_DART, "w", encoding="utf-8", newline="") as f:
                f.write(datos)
        with open(FIXTURE_DART, encoding="utf-8") as f:
            self.assertEqual(f.read(), datos,
                             "Regenera con REGENERAR_FIXTURES=1")


class RamificacionesInvalidas(unittest.TestCase):
    def errores_con(self, ramas: str) -> list:
        with open(FIXTURE_MD, encoding="utf-8") as f:
            texto = f.read()
        inicio = texto.index("### Ramificaciones")
        fin = texto.index("### Composición")
        with tempfile.TemporaryDirectory() as d:
            ruta = os.path.join(d, "x.md")
            with open(ruta, "w", encoding="utf-8") as f:
                f.write(texto[:inicio] + "### Ramificaciones\n\n" + ramas
                        + "\n\n" + texto[fin:])
            fuentes, hechos, escenarios, errores, avisos = B.leer(ruta)
            B.construir(fuentes, hechos, escenarios, errores, avisos,
                        hoy="2026-10-01")
        return errores

    def test_depender_de_un_turno_posterior_seria_un_ciclo(self):
        errores = self.errores_con("- **Turno 3:** si Turno 5 es negado")
        self.assertTrue(any("evita ciclos" in e for e in errores), errores)

    def test_una_respuesta_que_no_esta_documentada(self):
        errores = self.errores_con("- **Turno 5:** si Turno 1 = «Quizás.»")
        self.assertTrue(any("«Quizás.» no es una respuesta documentada" in e
                            for e in errores), errores)

    def test_un_estado_que_ninguna_respuesta_tiene(self):
        errores = self.errores_con("- **Turno 7:** si Turno 5 es desconocido")
        self.assertTrue(any("ninguna respuesta documentada del turno 5 es "
                            "«desconocido»" in e for e in errores), errores)

    def test_una_condicion_sobre_una_respuesta_del_usuario(self):
        errores = self.errores_con("- **Turno 3:** si Turno 2 es afirmado")
        self.assertTrue(any("el turno 2 no es una pregunta del funcionario" in e
                            for e in errores), errores)


class CorpusActual(unittest.TestCase):
    """Los escenarios que ya están en el repositorio siguen valiendo."""

    def test_construye_sin_errores_y_sin_ramas_que_no_declaro(self):
        fuentes, hechos, escenarios, errores, avisos, archivos = B.leer_todos()
        corpus = B.construir(fuentes, hechos, escenarios, errores, avisos,
                             archivos=archivos)
        B.poner_glosas(corpus, avisos)
        banco = B.banco_tramites(corpus, avisos)
        self.assertEqual(errores, [])
        self.assertGreater(len(banco["recorridos"]), 40)
        for recorrido in banco["recorridos"].values():
            for paso in recorrido["pasos"]:
                self.assertNotIn("cuando", paso)
        for q in banco["preguntas"]:
            for o in q["opciones"]:
                self.assertEqual(B.glosas_invalidas(o["glosas"]), [], o)
            # Una pregunta de sí o no no se contesta juntando tarjetas.
            if q["control"] == "seleccion_multiple":
                self.assertTrue(B.es_pregunta_abierta(q["formulacion"]), q["id"])


if __name__ == "__main__":
    unittest.main()


class DescripcionesEnLsb(unittest.TestCase):
    """Una descripción solo se muestra en LSB si su traducción dice lo mismo."""

    def test_una_traduccion_fiel_se_acepta(self):
        self.assertEqual(B.descripcion_fundada(
            "Ahora, en este momento.", ["AHORA", "MOMENTO"]), [])
        self.assertEqual(B.descripcion_fundada(
            "Otro papel igual al original.",
            ["PAPEL", "IGUAL", "SENA_PENDIENTE:ORIGINAL"]), [])

    def test_casos_reales_que_cambiaban_el_sentido(self):
        # «no se puede mover» no es «no sé».
        self.assertIn("NO_SABER", B.descripcion_fundada(
            "Casa, departamento o terreno: propiedad que no se puede mover.",
            ["SENA_PENDIENTE:PROPIEDAD", "NO_SABER", "SENA_PENDIENTE:MOVER",
             "CASA"]))
        # «todas las personas» no es «todos los días».
        self.assertIn("TODOS_LOS_DÍAS", B.descripcion_fundada(
            "Que todas las personas pueden usar algo.",
            ["TODOS_LOS_DÍAS", "USAR"]))
        # «cuando» sin tilde no pregunta.
        self.assertIn("CUÁNDO", B.descripcion_fundada(
            "Hacer un papel nuevo cuando el anterior vence.",
            ["NUEVO", "PAPEL", "HACER", "CUÁNDO"]))

    def test_negacion_perdida_o_sin_senas(self):
        self.assertIn("(negación perdida)", B.descripcion_fundada(
            "Guardar algo y no perderlo.", ["GUARDAR", "PERDER"]))
        self.assertIn("(ninguna seña)", B.descripcion_fundada(
            "Nombre de una calle.", list("CALLE")))
        self.assertIn("(usa CANCELAR)", B.descripcion_fundada(
            "Terminar algo. «Cancelar una deuda».",
            ["TERMINAR", "SENA_PENDIENTE:CANCELAR", "DEUDA"], "CANCELAR"))
