"""Un número de celular se dice cifra por cifra (Polly)."""
import unittest

import lambda_function as L


class TextoParaVoz(unittest.TestCase):
    def test_un_celular_se_dice_cifra_por_cifra(self):
        self.assertEqual(L.texto_para_voz("Mi celular es 72726841."),
                         "Mi celular es 7 2 7 2 6 8 4 1.")

    def test_con_guion(self):
        self.assertEqual(L.texto_para_voz("Llámeme al 7272-6841."),
                         "Llámeme al 7 2 7 2 6 8 4 1.")

    def test_una_cedula(self):
        self.assertEqual(L.texto_para_voz("Mi cédula es 6543210."),
                         "Mi cédula es 6 5 4 3 2 1 0.")

    def test_los_numeros_cortos_se_dicen_como_numeros(self):
        for texto in ("Tengo 25 años.", "Fue en 2024.", "Perdí 500 bolivianos.",
                      "Son 12500 bolivianos.", "Fue a las 3:30."):
            self.assertEqual(L.texto_para_voz(texto), texto)

    def test_varios_numeros_en_una_frase(self):
        self.assertEqual(
            L.texto_para_voz("Mi celular es 72726841 y el de mi mamá 61234567."),
            "Mi celular es 7 2 7 2 6 8 4 1 y el de mi mamá 6 1 2 3 4 5 6 7.")

    def test_sin_numeros_no_cambia(self):
        self.assertEqual(L.texto_para_voz("Me robaron el celular."),
                         "Me robaron el celular.")

    def test_polly_recibe_el_texto_ya_dicho(self):
        recibido = {}

        class Voz:
            def synthesize_speech(self, **kw):
                recibido.update(kw)

                class S:
                    def read(self):
                        return b"mp3"
                return {"AudioStream": S()}

        original = L.polly_client
        L.polly_client = Voz()
        try:
            L.synthesize_audio("Mi celular es 72726841.")
        finally:
            L.polly_client = original
        self.assertEqual(recibido["Text"], "Mi celular es 7 2 7 2 6 8 4 1.")


if __name__ == "__main__":
    unittest.main()
