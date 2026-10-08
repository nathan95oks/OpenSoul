import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/text/spanish_text.dart';

void main() {
  test('quita tildes y diéresis sin cambiar mayúsculas ni minúsculas', () {
    expect(SpanishText.stripAccents('Cédula de IDENTIDAD, pingüino'),
        'Cedula de IDENTIDAD, pinguino');
    expect(SpanishText.stripAccents('ÁÉÍÓÚÜ áéíóúü àâ'), 'AEIOUU aeiouu aa');
  });

  test('la ñ se conserva salvo que se pida', () {
    expect(SpanishText.stripAccents('Niño ÑANDÚ'), 'Niño ÑANDU');
    expect(SpanishText.stripAccents('Niño ÑANDÚ', foldEnye: true), 'Nino NANDU');
  });
}
