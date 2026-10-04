"""Léxico LSB de M1–M4 y los diccionarios (tool/build_lexico_lsb.py).

    python -m pytest tool/tests/test_lexico_lsb.py -q

Las pruebas del índice usan texto como el que da pypdf de los módulos. La
última comprueba los PDF reales y que `aws/lexico_lsb.json` esté al día.
"""

import json
import os
import sys
import tempfile
import unittest

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))

import build_lexico_lsb as L  # noqa: E402
import extraer_diccionario_lsb as X  # noqa: E402
from unittest import mock  # noqa: E402

# Una página del índice, como la extrae pypdf: número de página arriba,
# títulos en dos líneas, «Y o» partido y una palabra que sigue en otra línea.
INDICE = """54
Pronombres ...................................Pág. 113
1 . Y o
2. Tú
3. Ver/mirar
Salud sexual y
reproductiva
...........................................Pág. 91
1 . Bonito/a
2. Salario / Sueldo
3. Inicial (educación en familia
 comunitaria)
4. Prestar (opción 1 y 2)
Índice de palabras y señas"""


class Indice(unittest.TestCase):
    def test_lee_temas_con_su_pagina_y_sus_palabras(self):
        temas, errores, avisos = L.leer_indice("M1", [(54, INDICE)])
        self.assertEqual(errores, [])
        self.assertEqual([(t["titulo"], t["pagina"]) for t in temas],
                         [("Pronombres", 113),
                          ("Salud sexual y reproductiva", 91)])
        self.assertEqual([t for _, t, _ in temas[1]["palabras"]][2],
                         "Inicial (educación en familia comunitaria)")

    def test_un_numero_que_falta_detiene_el_lexico(self):
        roto = INDICE.replace("2. Tú\n", "")
        _, errores, _ = L.leer_indice("M1", [(54, roto)])
        self.assertTrue(any("faltan [2]" in e for e in errores), errores)

    def test_un_caracter_danado_detiene_el_lexico(self):
        _, errores, _ = L.leer_indice("M1", [(54, INDICE.replace("Tú", "T�"))])
        self.assertTrue(any("reemplazo" in e for e in errores), errores)

    def test_solo_el_primer_bloque_de_paginas_de_indice(self):
        paginas = [(1, "Portada"), (54, INDICE), (55, INDICE), (90, INDICE)]
        self.assertEqual([n for n, _ in L.paginas_de_indice(paginas)], [54, 55])


class Formas(unittest.TestCase):
    def test_variantes_de_una_palabra(self):
        self.assertEqual(L.formas_de("Y o"), (["Yo"], ""))
        self.assertEqual(L.formas_de("Bonito/a")[0], ["Bonito", "Bonita"])
        self.assertEqual(L.formas_de("Secretaria/o")[0],
                         ["Secretaria", "Secretario"])
        self.assertEqual(L.formas_de("Coordinador/a")[0],
                         ["Coordinador", "Coordinadora"])
        self.assertEqual(L.formas_de("Salario / Sueldo")[0], ["Salario", "Sueldo"])
        self.assertEqual(L.formas_de("Delgado/da")[0], ["Delgado", "Delgada"])
        self.assertEqual(L.formas_de("Autor/ra")[0], ["Autor", "Autora"])
        self.assertEqual(L.formas_de("Castellano/na")[0],
                         ["Castellano", "Castellana"])
        self.assertEqual(L.formas_de("Embajador / ra")[0],
                         ["Embajador", "Embajadora"])
        self.assertEqual(L.formas_de("Conocido - Conocer")[0],
                         ["Conocido", "Conocer"])
        self.assertEqual(L.formas_de("Prestar (opción 1 y 2)"),
                         (["Prestar"], "opción 1 y 2"))

    def test_un_articulo_suelto_no_es_una_sena_pero_el_pronombre_si(self):
        self.assertEqual(L.formas_de("El / al lado")[0], ["al lado"])
        self.assertEqual(L.formas_de("Él")[0], ["Él"])

    def test_glosa_de_una_forma(self):
        self.assertEqual(L.glosa_de("Buenos días"), "BUENOS_DÍAS")
        self.assertEqual(L.glosa_de("¿Cómo estás?"), "CÓMO_ESTÁS")


class Union(unittest.TestCase):
    CATALOGO = {"VER": ["ver", "vi"], "MIRAR": ["mirar", "ver"],
                "PAPEL": ["Papel", "el documento"]}

    def entrada(self, texto, fuente="M1"):
        formas, nota = L.formas_de(texto)
        return {"formas": formas, "nota": nota,
                "fuente": {"fuente": fuente, "pagina": 10, "tema": "T", "n": 1}}

    def test_una_palabra_del_catalogo_suma_su_fuente_a_esa_sena(self):
        lexico, _, _ = L.unir(self.CATALOGO, [self.entrada("Papel")], set())
        self.assertEqual([f["fuente"] for f in lexico["PAPEL"]["fuentes"]],
                         ["catalogo", "M1"])
        self.assertTrue(lexico["PAPEL"]["catalogo"])

    def test_si_varias_senas_coinciden_manda_la_de_su_nombre(self):
        lexico, ambiguas, _ = L.unir(self.CATALOGO,
                                     [self.entrada("Ver/mirar")], set())
        self.assertEqual(lexico["VER"]["fuentes"][-1]["fuente"], "M1")
        self.assertEqual(ambiguas["ver"], ["MIRAR", "VER"])

    def test_una_palabra_nueva_es_una_sena_nueva_con_su_tema(self):
        lexico, _, _ = L.unir({}, [self.entrada("Yerno", "M2")], {"yerno"})
        self.assertEqual(lexico["YERNO"]["formas"], ["Yerno"])
        self.assertFalse(lexico["YERNO"]["catalogo"])
        self.assertTrue(lexico["YERNO"]["animacion"])


class Diccionarios(unittest.TestCase):
    def escribir(self, d, nombre, texto):
        ruta = os.path.join(d, nombre)
        with open(ruta, "w", encoding="utf-8") as f:
            f.write(texto)
        return ruta

    def test_un_csv_con_palabra_y_pagina(self):
        with tempfile.TemporaryDirectory() as d:
            ruta = self.escribir(d, "D2024.csv",
                                 "palabra,pagina,glosa\nRobar,499,\n"
                                 "Testigo,557,TESTIGO\n")
            entradas, errores = L.entradas_de_diccionario(ruta)
        self.assertEqual(errores, [])
        self.assertEqual([(e["formas"], e["glosa"], e["fuente"]) for e in entradas],
                         [(["Robar"], None, {"fuente": "D2024", "pagina": "499"}),
                          (["Testigo"], "TESTIGO",
                           {"fuente": "D2024", "pagina": "557"})])

    def test_filas_incompletas_o_glosas_mal_escritas_se_rechazan(self):
        with tempfile.TemporaryDirectory() as d:
            ruta = self.escribir(d, "D1.csv", "palabra,pagina,glosa\nRobar,,\n"
                                              "Testigo,3,el testigo\n")
            _, errores = L.entradas_de_diccionario(ruta)
        self.assertEqual(len(errores), 2, errores)

    def test_un_diccionario_en_pdf_pide_su_extractor(self):
        with tempfile.TemporaryDirectory() as d:
            ruta = self.escribir(d, "D1.pdf", "%PDF-1.4")
            _, errores = L.entradas_de_diccionario(ruta)
        self.assertIn("sin extractor", errores[0])


# Dos páginas como las da pypdf del II Diccionario 2024.
PAGINA_A = """3
Diccionario Bilingüe de
Lengua de Señas Boliviana / Castellano
A a
1.Abreviatura: f. Palabra reducida. La abreviatura de doctor es Dr.
2.Abusar: v. Aprovecharse de alguien. No se debe abusar de nadie."""
PAGINA_T = """208 209
T t
3.Tapir: sin. Anta. m. Animal amazónico. El tapir vive en la selva.
4.Tanque de guerra: m. Carro de combate. Ese tanque de guerra es grande."""


class DiccionarioPdf(unittest.TestCase):
    def test_lee_entradas_con_su_numero_pagina_sinonimo_y_definicion(self):
        lista, errores = X.entradas([(23, PAGINA_A), (228, PAGINA_T)])
        self.assertEqual(errores, [])
        self.assertEqual([(e["n"], e["formas"], e["pagina"]) for e in lista],
                         [(1, ["Abreviatura"], "3"), (2, ["Abusar"], "3"),
                          (3, ["Tapir", "Anta"], "208"),
                          (4, ["Tanque de guerra"], "208")])
        self.assertEqual(lista[2]["categoria"], "m.")
        self.assertEqual(lista[2]["definicion"], "Animal amazónico.")

    def test_una_entrada_perdida_detiene_la_extraccion(self):
        _, errores = X.entradas([(23, PAGINA_A.replace("2.Abusar", "Abusar")),
                                 (228, PAGINA_T)])
        self.assertTrue(any("faltan 1 entradas: [2]" in e for e in errores),
                        errores)

    def test_dentro_de_una_pagina_el_orden_no_cuenta_pero_entre_paginas_si(self):
        invertida = PAGINA_A.replace("1.Abreviatura", "X").replace(
            "2.Abusar", "1.Abreviatura").replace("X", "2.Abusar")
        _, errores = X.entradas([(23, invertida), (228, PAGINA_T)])
        self.assertEqual(errores, [])
        _, errores = X.entradas([(23, PAGINA_T.replace("208 209", "3")),
                                 (228, PAGINA_A)])
        self.assertTrue(any("el orden se perdió" in e for e in errores), errores)

    def test_la_errata_del_punto_en_lugar_de_dos_puntos(self):
        lista, errores = X.entradas([(23, PAGINA_A.replace(
            "2.Abusar: v.", "2.Buque de guerra. m."))])
        self.assertEqual(errores, [])
        self.assertEqual(lista[1]["palabra"], "Buque de guerra")
        # Sin categoría detrás no es una entrada: es una frase cualquiera.
        lista, _ = X.entradas([(23, PAGINA_A + "\n3.Se ve. Otra cosa.")])
        self.assertEqual(len(lista), 2)

    def test_una_repeticion_solo_vale_si_es_una_errata_comprobada(self):
        doble = PAGINA_A + "\n2.Auxilio: m. Pedir ayuda."
        _, errores = X.entradas([(23, doble)], "OTRO")
        self.assertTrue(any("entrada 2 repetida" in e for e in errores), errores)
        with mock.patch.dict(X.ERRATAS, {"D9": {"repetidas": {
                2: ["Abusar", "Auxilio"]}}}):
            _, errores = X.entradas([(23, doble)], "D9")
        self.assertEqual(errores, [])

    def test_otra_maquetacion_no_se_adivina(self):
        _, errores = X.entradas([(1, "Una página sin entradas")])
        self.assertIn("no se reconoció ninguna entrada", errores[0])

    def test_el_catalogo_contrasta_lo_que_cita(self):
        lista, _ = X.entradas([(23, PAGINA_A), (228, PAGINA_T)])
        with mock.patch.object(X, "citas_del_catalogo",
                               return_value={2: "ABUSAR", 3: "ROBAR"}):
            errores = X.contrastar("D2024", lista)
        self.assertEqual(len(errores), 1)
        self.assertIn("D2024-3 como ROBAR pero el PDF tiene «Tapir»", errores[0])

    def test_el_csv_de_un_pdf_vale_solo_con_la_huella_de_ese_pdf(self):
        with tempfile.TemporaryDirectory() as d:
            pdf = os.path.join(d, "D2024.pdf")
            with open(pdf, "wb") as f:
                f.write(b"%PDF-1.4 uno")
            self.assertIn("no tiene su CSV", L.pdf_al_dia(pdf)[0])
            for ext, texto in ((".csv", "palabra,pagina\nRobar,1\n"),
                               (".huella", L.huella(pdf))):
                with open(os.path.join(d, "D2024" + ext), "w") as f:
                    f.write(texto)
            self.assertEqual(L.pdf_al_dia(pdf), [])
            with open(pdf, "wb") as f:
                f.write(b"%PDF-1.4 otro")
            self.assertIn("cambió", L.pdf_al_dia(pdf)[0])

    def test_el_csv_lleva_entrada_y_definicion_a_la_fuente(self):
        with tempfile.TemporaryDirectory() as d:
            ruta = os.path.join(d, "D2024.csv")
            with open(ruta, "w", encoding="utf-8") as f:
                lista, _ = X.entradas([(228, PAGINA_T.replace("3.", "1.")
                                        .replace("4.", "2."))])
                f.write(X.a_csv(lista))
            entradas, errores = L.entradas_de_diccionario(ruta)
        self.assertEqual(errores, [])
        self.assertEqual(entradas[0]["formas"], ["Tapir", "Anta"])
        self.assertEqual(entradas[0]["fuente"],
                         {"fuente": "D2024", "pagina": "208", "entrada": 1,
                          "definicion": "Animal amazónico."})


@unittest.skipUnless(
    all(os.path.exists(os.path.join(L.MODULOS, f"M{i}.pdf")) for i in range(1, 5)),
    "faltan los módulos en docs/lsb_fuentes/modulos")
class ModulosReales(unittest.TestCase):
    def test_los_cuatro_modulos_se_leen_y_el_lexico_esta_al_dia(self):
        try:
            import pypdf  # noqa: F401
        except ImportError:
            self.skipTest("falta pypdf")
        datos, errores, _ = L.construir()
        self.assertEqual(errores, [])
        self.assertEqual(sorted(k for k in datos["fuentes"] if k.startswith("M")),
                         ["M1", "M2", "M3", "M4"])
        if os.path.exists(os.path.join(L.DICCIONARIOS, "D2024.pdf")):
            # El II Diccionario 2024 entra por su CSV, con número de entrada
            # y definición (lo que distingue homónimos).
            robar = [f for f in datos["glosas"]["ROBAR"]["fuentes"]
                     if f["fuente"] == "D2024"]
            self.assertEqual(robar[0]["entrada"], 499)
        glosas = datos["glosas"]
        self.assertIn("M3 ", " ".join(f"{f['fuente']} {f.get('tema')}"
                                      for f in glosas["FISCAL"]["fuentes"]))
        with open(L.SALIDA, encoding="utf-8") as f:
            self.assertEqual(json.load(f), datos,
                             "aws/lexico_lsb.json desactualizado: ejecuta "
                             "python tool/build_lexico_lsb.py")


if __name__ == "__main__":
    unittest.main()
