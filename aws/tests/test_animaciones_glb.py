"""Seña si existe el clip en el .glb de S3; deletreo si no.

La lambda decidía qué señas tenía el avatar con una lista escrita a mano, y
esa lista declaraba ~146 señas cuando el .glb trae muchas menos: la glosa
salía como disponible, el visor pedía un clip inexistente y la seña no
aparecía. Ahora la lista sale del propio .glb.

    python3 -m unittest discover -s aws/tests -v
"""

import json
import os
import struct
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from boto3_stub import install as _install_boto3_stub  # noqa: E402

_install_boto3_stub()
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import lambda_text_to_lsb as m  # noqa: E402


def _glb(clip_names):
    """Un .glb mínimo: cabecera, chunk JSON con las animaciones y un binario."""
    doc = json.dumps({"asset": {"version": "2.0"},
                      "animations": [{"name": n} for n in clip_names]}).encode()
    doc += b" " * (-len(doc) % 4)
    binario = b"\x00" * 64
    cuerpo = (struct.pack("<II", len(doc), 0x4E4F534A) + doc
              + struct.pack("<II", len(binario), 0x004E4942) + binario)
    return struct.pack("<4sII", b"glTF", 2, 12 + len(cuerpo)) + cuerpo


class _Body:
    def __init__(self, data):
        self._data = data

    def read(self):
        return self._data


class _FakeS3:
    """S3 que sirve un solo objeto respetando la cabecera Range."""

    def __init__(self, data):
        self.data = data
        self.rangos = []

    def get_object(self, Bucket, Key, Range=None):
        self.rangos.append(Range)
        if Range is None:
            return {"Body": _Body(self.data)}
        inicio, fin = Range.removeprefix("bytes=").split("-")
        return {"Body": _Body(self.data[int(inicio):int(fin) + 1])}


class _ConGlb(unittest.TestCase):
    CLIPS = ["HOLA", "GRACIAS", "COMO_ESTAS", "NO", "A", "B", "C", "E", "O", "R", "S", "ENE",
             "CERO", "UNO", "DOS", "CINCO", "PRIMERA_VEZ", "ACOMPANAR"]

    def setUp(self):
        self._s3, self._bucket = m.s3, m.ANIMATIONS_BUCKET
        self.s3 = _FakeS3(_glb(self.CLIPS))
        m.s3 = self.s3
        m.ANIMATIONS_BUCKET = "bucket-animaciones"
        m._clips_cache.update(clips=None, expires=0.0)

    def tearDown(self):
        m.s3, m.ANIMATIONS_BUCKET = self._s3, self._bucket
        m._clips_cache.update(clips=None, expires=0.0)


class LecturaDelGlb(_ConGlb):

    def test_lee_los_nombres_de_los_clips(self):
        self.assertEqual(m.read_glb_clip_names("b", "k"), self.CLIPS)

    def test_no_descarga_el_binario(self):
        m.read_glb_clip_names("b", "k")
        self.assertTrue(all(r is not None for r in self.s3.rangos))
        self.assertEqual(self.s3.rangos[0], "bytes=0-19")

    def test_rechaza_un_archivo_que_no_es_glb(self):
        m.s3 = _FakeS3(b"no soy un glb" + b"\x00" * 20)
        with self.assertRaises(ValueError):
            m.read_glb_clip_names("b", "k")

    def test_la_lista_se_cachea_en_memoria(self):
        m.get_baked_clips()
        m.get_baked_clips()
        self.assertEqual(len(self.s3.rangos), 2)  # una sola lectura (2 rangos)


class SenaODeletreo(_ConGlb):

    def test_glosa_con_clip_se_muestra_como_sena(self):
        r = m.post_process_glosses({"glosses": ["HOLA"]}, "Hola")
        d = r["glossDetails"][0]
        self.assertTrue(d["available"])
        self.assertEqual(d["animationName"], "HOLA")
        self.assertEqual([p["gloss"] for p in r["animationSequence"]], ["HOLA"])
        self.assertEqual(r["representationStatus"], "complete")

    def test_glosa_del_catalogo_sin_clip_se_deletrea(self):
        # ABOGADO figura en la lista estática como "3D disponible", pero este
        # .glb no la trae: antes salía available=true y el avatar no mostraba
        # nada.
        r = m.post_process_glosses({"glosses": ["ABOGADO"]}, "abogado")
        d = r["glossDetails"][0]
        self.assertFalse(d["available"])
        self.assertEqual(d["spelledLetters"], list("ABOGADO"))
        self.assertEqual([p["gloss"] for p in r["animationSequence"]],
                         list("ABOGADO"))
        self.assertEqual(r["representationStatus"], "partial")

    def test_letra_sin_clip_queda_como_placeholder_sin_perderse(self):
        r = m.post_process_glosses({"glosses": ["ABOGADO"]}, "abogado")
        por_letra = {p["gloss"]: p["animationFile"] for p in r["animationSequence"]}
        self.assertEqual(por_letra["A"], m.ANIMATIONS_KEY)
        self.assertIsNone(por_letra["G"])  # G no está en este .glb
        self.assertIsNone(por_letra["D"])

    def test_mezcla_sena_y_deletreo_en_orden(self):
        r = m.post_process_glosses({"glosses": ["HOLA", "ABOGADO"]}, "hola abogado")
        pasos = [p["gloss"] for p in r["animationSequence"]]
        self.assertEqual(pasos, ["HOLA"] + list("ABOGADO"))
        self.assertEqual(r["glosses"], ["HOLA", "ABOGADO"])

    def test_ene_usa_su_clip_propio(self):
        plan, pasos = m.plan_gloss_animation("Ñ", m.get_baked_clips())
        self.assertTrue(plan["available"])
        self.assertEqual(pasos[0]["animationName"], "ENE")

    def test_digito_usa_el_clip_del_numeral(self):
        plan, _ = m.plan_gloss_animation("5", m.get_baked_clips())
        self.assertEqual(plan["animationName"], "CINCO")

    def test_cifra_de_varios_digitos_se_muestra_digito_a_digito(self):
        _, pasos = m.plan_gloss_animation("25", m.get_baked_clips())
        self.assertEqual([p["gloss"] for p in pasos], ["2", "5"])
        self.assertEqual([p["animationName"] for p in pasos], ["DOS", "CINCO"])

    def test_primera_vez_con_clip_en_s3(self):
        plan, pasos = m.plan_gloss_animation("PRIMERA_VEZ", m.get_baked_clips())
        self.assertTrue(plan["available"])
        self.assertEqual(plan["animationName"], "PRIMERA_VEZ")
        self.assertEqual(pasos[0]["animationName"], "PRIMERA_VEZ")

    def test_acompaniar_encuentra_clip_con_n_en_s3(self):
        plan, pasos = m.plan_gloss_animation("ACOMPAÑAR", m.get_baked_clips())
        self.assertTrue(plan["available"])
        self.assertEqual(plan["animationName"], "ACOMPANAR")
        self.assertEqual(pasos[0]["animationName"], "ACOMPANAR")

    def test_fusion_primera_vez_en_post_process(self):
        r = m.post_process_glosses({"glosses": ["PRIMERA", "VEZ"]}, "primera vez")
        self.assertIn("PRIMERA_VEZ", r["glosses"])
        self.assertEqual(r["representationStatus"], "complete")

    def test_como_estas_prioriza_el_clip_compuesto(self):
        r = m.post_process_glosses(
            {"glosses": ["COMO", "ESTAS"]}, "como estas",
        )
        self.assertEqual(r["glosses"], ["COMO_ESTAS"])
        self.assertEqual(r["glossDetails"][0]["animationName"], "COMO_ESTAS")
        self.assertEqual(
            [paso["animationName"] for paso in r["animationSequence"]],
            ["COMO_ESTAS"],
        )
        self.assertEqual(r["representationStatus"], "complete")

    def test_como_estas_corrige_incluso_una_salida_incompleta_del_modelo(self):
        r = m.post_process_glosses(
            {"glosses": ["COMO"]}, "¿Cómo estás?",
        )
        self.assertEqual(r["glosses"], ["COMO_ESTAS"])
        self.assertEqual(
            [paso["animationName"] for paso in r["animationSequence"]],
            ["COMO_ESTAS"],
        )

    def test_no_fuerza_la_compuesta_si_el_glb_no_tiene_el_clip(self):
        self.s3 = _FakeS3(_glb([c for c in self.CLIPS if c != "COMO_ESTAS"]))
        m.s3 = self.s3
        m._clips_cache.update(clips=None, expires=0.0)

        r = m.post_process_glosses(
            {"glosses": ["COMO", "ESTAS"]}, "como estas",
        )
        self.assertNotIn("COMO_ESTAS", r["glosses"])
        self.assertEqual(r["representationStatus"], "partial")


class FallosYCache(_ConGlb):

    def test_si_s3_falla_se_usa_la_lista_estatica(self):
        class _Roto:
            def get_object(self, **k):
                raise RuntimeError("sin permisos")
        m.s3 = _Roto()
        self.assertIs(m.get_baked_clips(), m._STATIC_CLIPS)

    def test_respuesta_de_cache_se_recalcula_con_el_glb_actual(self):
        # Guardado cuando ABOGADO "estaba disponible" según la lista vieja.
        cacheado = {"glosses": ["ABOGADO"], "fidelityFixes": [],
                    "glossDetails": [{"gloss": "ABOGADO", "available": True}]}
        r = m.attach_animation_plan(cacheado)
        self.assertFalse(r["glossDetails"][0]["available"])
        self.assertEqual(len(r["animationSequence"]), 7)


if __name__ == "__main__":
    unittest.main()
