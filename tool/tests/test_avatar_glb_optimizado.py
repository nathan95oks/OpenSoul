"""El modelo del avatar que viaja con la app está optimizado.

Si alguien vuelve a exportar el .glb desde Blender y lo copia tal cual, el
visor vuelve a tardar en cargarlo (decenas de miles de pistas que no mueven
nada). Estas pruebas lo detectan: hay que pasarlo por
`tool/optimizar_avatar_glb.py`.
"""

import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tool"))

import optimizar_avatar_glb as O  # noqa: E402

MODELO = O.Glb.abrir(O.MODELO)


class ModeloOptimizado(unittest.TestCase):
    def test_ninguna_pista_quieta_en_su_reposo(self):
        sobran = [
            (a.get("name"), c["target"]["node"], c["target"]["path"])
            for a in MODELO.json["animations"]
            for c in a["channels"]
            if O._quieta_en_reposo(MODELO, c["target"]["node"], c["target"]["path"],
                                   a["samplers"][c["sampler"]]["output"])
        ]
        self.assertEqual([], sobran[:5], f"{len(sobran)} pistas sin movimiento: "
                         "ejecuta python tool/optimizar_avatar_glb.py")

    def test_los_datos_de_animacion_van_en_un_bloque(self):
        # Una vista por acceso (lo que exporta Blender) eran ~35 000.
        self.assertLess(len(MODELO.json["bufferViews"]), 1000)

    def test_las_rotaciones_son_enteros_normalizados(self):
        for a in MODELO.json["animations"]:
            for c in a["channels"]:
                if c["target"]["path"] != "rotation":
                    continue
                acceso = MODELO.json["accessors"][a["samplers"][c["sampler"]]["output"]]
                self.assertEqual(5122, acceso["componentType"])
                self.assertTrue(acceso.get("normalized"))

    def test_las_texturas_no_pasan_del_lado_maximo(self):
        import io as _io
        from PIL import Image
        for i, im in enumerate(MODELO.json.get("images", [])):
            lado = max(Image.open(_io.BytesIO(MODELO.vista(im["bufferView"]))).size)
            self.assertLessEqual(lado, O.TEXTURA_MAXIMA, f"textura {i}")

    def test_el_json_es_ligero(self):
        self.assertLess(O.contar(MODELO)["json"], 3_000_000)


if __name__ == "__main__":
    unittest.main()
