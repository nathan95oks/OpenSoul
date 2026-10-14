/// El texto como se dice en voz alta.
///
/// Un número de celular escrito «72726841» lo lee la voz como un número
/// («setenta y dos millones…»). Un celular, una cédula o un número de caso se
/// dicen cifra por cifra: «7 2 7 2 6 8 4 1». Solo cambia lo que se dice; el
/// texto que se ve en el chat no se toca.
///
/// Misma regla que `texto_para_voz` de `aws/lambda_function.py`, que es la
/// voz de Polly: `test/spoken_text_test.dart` y `aws/tests/test_texto_para_voz.py`
/// prueban los mismos casos.
class SpokenText {
  const SpokenText._();

  /// Siete cifras o más seguidas (celular, cédula, número de caso).
  static final RegExp _longNumber = RegExp(r'(?<![\d.,])\d{7,}(?![\d])');

  /// Un celular con guion: «7272-6841», «727-26841».
  static final RegExp _hyphenated = RegExp(
    r'(?<![\d-])\d{3,4}-\d{4,5}(?![\d-])',
  );

  static String forSpeech(String text) {
    String spaced(Match m) => m[0]!.replaceAll('-', '').split('').join(' ');
    return text
        .replaceAllMapped(_longNumber, spaced)
        .replaceAllMapped(_hyphenated, spaced);
  }
}
