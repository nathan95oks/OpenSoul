"""Paridad del ensamblador Python con el motor local en Dart.

El cliente descarta la respuesta del servidor cuando pierde una glosa
(`isBackendDegenerate`): si el backend no compone el tiempo o suelta una
institución, su trabajo se tira y el usuario recibe la frase del motor local.
La paridad no es estética — es la diferencia entre usar el servidor o no.

Estas pruebas fijan las reglas que deben coincidir con
`lib/core/engines/semantic_engine/local_sentence_assembler.dart`:

  · unidad de tiempo + dígito → "hace dos semanas" / "dentro de dos semanas"
  · la dirección la decide el contexto, no una glosa (no existe PASADO)
  · un dígito solo es cantidad detrás de una unidad; fuera de ahí, dactilología
  · ninguna glosa institucional o de lugar puede desaparecer de la oración

    python3 -m unittest discover -s aws/tests -v
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()

import lambda_function as L  # noqa: E402


def frase(context_type, cards):
    analysis = L.analyze_glosses(cards)
    ir = L.build_intermediate_representation(cards, analysis, context_type)
    return L.generate_base_sentence(ir, analysis, context_type)


class ComposicionTemporal(unittest.TestCase):
    """Unidad + cantidad, con la dirección que dicta el contexto."""

    def test_denuncia_compone_en_pasado(self):
        self.assertIn("hace dos semanas",
                      frase("denuncia_robo", ["ROBAR", "SEMANA", "2"]).lower())

    def test_tramite_compone_en_futuro(self):
        self.assertIn("dentro de dos semanas",
                      frase("tramite", ["PEDIR", "CERTIFICADO", "SEMANA", "2"]).lower())

    def test_consulta_compone_en_futuro(self):
        self.assertIn("dentro de tres dias",
                      _sin_tildes(frase("consulta", ["PEDIR", "CARNET", "DIA", "3"])))

    def test_una_perdida_es_pasado_aunque_llegue_como_tramite(self):
        # El cliente manda el id de UI ('tramite') pero su motor local usa el
        # contexto ya resuelto ('perdida'), que es pasado. Sin replicar ese
        # reparto, el servidor diría "dentro de" y el cliente "hace".
        texto = frase("tramite", ["PERDER", "CARNET", "SEMANA", "2"]).lower()
        self.assertIn("hace dos semanas", texto)
        self.assertNotIn("dentro de", texto)

    def test_concordancia_de_genero_en_la_cantidad_uno(self):
        self.assertIn("hace una hora",
                      frase("denuncia_robo", ["ROBAR", "HORA", "1"]).lower())
        self.assertIn("hace un dia",
                      _sin_tildes(frase("denuncia_robo", ["ROBAR", "DIA", "1"])))

    def test_unidad_sin_cantidad_conserva_su_forma_deictica(self):
        self.assertIn("esta semana",
                      frase("denuncia_robo", ["ROBAR", "SEMANA"]).lower())

    def test_un_digito_suelto_no_es_cantidad(self):
        # Fuera de una cadena temporal un dígito sigue siendo dactilología —el
        # número de un NUREJ, un teléfono— y no debe inventar un complemento.
        texto = frase("consulta", ["PEDIR", "NUREJ", "1", "2", "3"]).lower()
        self.assertNotIn("hace", texto)
        self.assertNotIn("dentro de", texto)


class NingunaGlosaSeQuedaFuera(unittest.TestCase):
    """Lo que la persona eligió tiene que aparecer en la oración."""

    def test_dos_instituciones_se_enlazan_con_conjuncion(self):
        texto = frase("denuncia_robo", ["ROBAR", "MOCHILA", "POLICIA", "FISCAL"]).lower()
        self.assertIn("polic", texto)
        self.assertIn("fiscal", texto)

    def test_la_institucion_del_relato_no_desaparece(self):
        texto = _sin_tildes(frase("violencia", ["DISCRIMINACION", "OFICIAL", "AYER"]))
        self.assertIn("oficial", texto)

    def test_acudir_rige_a_y_no_en(self):
        texto = frase("denuncia_robo", ["ROBAR", "POLICIA"]).lower()
        self.assertIn("a la policía", texto)
        self.assertNotIn("acudir en", texto)

    def test_dos_lugares_no_pierden_el_segundo(self):
        texto = frase("denuncia_robo", ["ROBAR", "CALLE", "PLAZA"]).lower()
        self.assertIn("calle", texto)
        self.assertIn("plaza", texto)

    def test_una_agresion_conserva_agresor_y_lugar(self):
        # Antes MALTRATAR no figuraba en la lista de verbos de agresión —24 de
        # las 32 glosas que enumeraba esa función ya no existían— y el relato
        # caía al generador genérico, que ignora descriptores y lugares.
        texto = frase("violencia", ["MALTRATAR", "MUJER", "CASA", "MES", "6"]).lower()
        self.assertIn("mujer", texto)
        self.assertIn("casa", texto)
        self.assertIn("maltrat", texto)


class NingunEstadoSePierde(unittest.TestCase):
    """En un accidente, el estado es el núcleo del parte, no un adorno.

    Solo 2 de los 13 generadores leían `estados`. Con [MAL, DOCTOR, AHORA] la
    heurística elegía la plantilla de SOLICITUD —el servicio se evaluaba antes
    que el estado— y salía "Solicito un doctor ahora mismo": un trámite. La
    urgencia vital desaparecía de la declaración.
    """

    def test_un_accidente_declara_primero_el_estado(self):
        texto = frase("accidente", ["MAL", "DOCTOR", "AHORA"])
        self.assertTrue(texto.lower().startswith("me siento mal"), texto)
        self.assertIn("doctor", texto.lower())
        self.assertIn("ahora mismo", texto.lower())

    def test_el_contexto_manda_sobre_la_heuristica(self):
        # Paridad: el cliente enruta 'accidente' a _composeEmergency sin
        # deducir nada. Aquí se deducía y ganaba la rama equivocada.
        analysis = L.analyze_glosses(["MAL", "DOCTOR", "AHORA"])
        self.assertEqual(
            L._detect_event_type(analysis, "accidente"), "EMERGENCIA")
        self.assertEqual(
            L._detect_event_type(analysis, "orientacion"), "SOLICITUD",
            "fuera de una urgencia la heurística sigue mandando")

    def test_el_estado_sobrevive_a_cualquier_plantilla(self):
        # _gen_solicitud ignora los estados; la red de seguridad los recupera.
        texto = frase("orientacion", ["PEDIR", "CARNET", "MAL"]).lower()
        self.assertIn("carnet", texto)
        self.assertIn("me siento mal", texto)

    def test_un_motivo_se_adjunta_y_no_abre_oracion(self):
        # "por un problema" no es una oración: se pega a la anterior.
        texto = frase("tramite", ["PEDIR", "CERTIFICADO", "PROBLEMA"])
        self.assertIn("por un problema", texto.lower())
        self.assertNotIn("Por un problema", texto)

    def test_no_se_duplica_el_estado_que_la_plantilla_ya_integro(self):
        texto = frase("violencia", ["MALTRATAR", "PAREJA", "MIEDO"]).lower()
        self.assertEqual(texto.count("tengo miedo"), 1, texto)


class SinArticulosDuplicados(unittest.TestCase):
    """El lexema ya trae su determinante; anteponerle otro lo duplicaba."""

    def test_sin_preposicion_repetida(self):
        texto = frase("consulta", ["NO_SABER", "FISCAL", "DESPACHO"]).lower()
        self.assertNotIn("en en", texto)

    def test_sin_articulo_repetido(self):
        texto = frase("tramite", ["PEDIR", "CERTIFICADO"]).lower()
        self.assertNotIn("el un ", texto)
        self.assertNotIn("el mi ", texto)

    def test_la_oracion_empieza_en_mayuscula(self):
        texto = frase("tramite", ["PEDIR", "CARNET"])
        self.assertTrue(texto[:1].isupper(), texto)


def _sin_tildes(texto):
    tabla = str.maketrans("áéíóúÁÉÍÓÚñÑ", "aeiouAEIOUnN")
    return texto.translate(tabla).lower()


if __name__ == "__main__":
    unittest.main()
