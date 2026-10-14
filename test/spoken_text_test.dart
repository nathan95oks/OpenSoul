import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/services/spoken_text.dart';

/// Los mismos casos que `aws/tests/test_texto_para_voz.py`.
void main() {
  test('un celular se dice cifra por cifra', () {
    expect(
      SpokenText.forSpeech('Mi celular es 72726841.'),
      'Mi celular es 7 2 7 2 6 8 4 1.',
    );
  });

  test('con guion', () {
    expect(
      SpokenText.forSpeech('Llámeme al 7272-6841.'),
      'Llámeme al 7 2 7 2 6 8 4 1.',
    );
  });

  test('una cédula', () {
    expect(
      SpokenText.forSpeech('Mi cédula es 6543210.'),
      'Mi cédula es 6 5 4 3 2 1 0.',
    );
  });

  test('los números cortos se dicen como números', () {
    for (final t in [
      'Tengo 25 años.',
      'Fue en 2024.',
      'Perdí 500 bolivianos.',
      'Son 12500 bolivianos.',
      'Fue a las 3:30.',
    ]) {
      expect(SpokenText.forSpeech(t), t);
    }
  });

  test('varios números en una frase', () {
    expect(
      SpokenText.forSpeech('Mi celular es 72726841 y el de mi mamá 61234567.'),
      'Mi celular es 7 2 7 2 6 8 4 1 y el de mi mamá 6 1 2 3 4 5 6 7.',
    );
  });

  test('sin números no cambia', () {
    expect(
      SpokenText.forSpeech('Me robaron el celular.'),
      'Me robaron el celular.',
    );
  });
}
