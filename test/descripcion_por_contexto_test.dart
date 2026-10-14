import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/services/spelling_help.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';

final _catalogo = PendingSignCatalog.fromJsonString(
  File('assets/dictionary/senas_sin_sena.json').readAsStringSync(),
);

PendingSignInfo _pasar(String? frase) =>
    _catalogo.infoOf('SENA_PENDIENTE:PASAR', sentence: frase);

void main() {
  group('«pasar» se explica con el sentido de la frase', () {
    test('«¿qué está pasando?»: ocurrir ahora', () {
      expect(_pasar('¿Qué está pasando?').lsbDescription, ['AHORA', 'QUÉ']);
    });

    test('«¿qué pasó?»: ocurrir antes', () {
      expect(_pasar('¿Qué pasó?').lsbDescription, ['PASADO', 'QUÉ']);
    });

    test('«puede pasar adelante» / «pase»: entrar o avanzar', () {
      for (final f in ['Puede pasar adelante', 'Pase, por favor', 'pasen ya']) {
        expect(_pasar(f).lsbDescription, ['VENIR', 'AQUÍ'], reason: f);
      }
    });

    test('«quiero pasarlo a mi nombre»: cambiar de dueño', () {
      expect(_pasar('Quiero pasarlo a mi nombre').lsbDescription, [
        'CAMBIAR',
        'NOMBRE',
      ]);
    });

    test('«páseme su cédula»: dar', () {
      expect(_pasar('Páseme su cédula').lsbDescription, ['DAR']);
    });

    test('sin frase, o sin pista: la general, que nombra los sentidos', () {
      for (final f in [null, '', 'pasar']) {
        final info = _pasar(f);
        expect(info.description, contains('cambia de sentido'), reason: '$f');
        expect(info.lsbDescription, isEmpty);
      }
    });

    test('lo que no tiene sentidos no cambia', () {
      final info = _catalogo.infoOf('SENA_PENDIENTE:PASO', sentence: 'pase');
      expect(info.description, 'Cada parte de un trámite.');
    });

    test('la ayuda del deletreo usa la frase', () {
      List<String> letras(String w) => w.split('');
      final ayuda = SpellingHelp.forSteps(
        ['QUE', ...letras('PASAR')],
        ['PASAR'],
        _catalogo,
        sentence: '¿Qué está pasando?',
      ).single;
      expect(ayuda.description!.description, contains('qué ocurre'));
    });
  });

  group('otras palabras con varios sentidos', () {
    test('«poner una denuncia» es presentar, «ponerla a mi nombre» no', () {
      final denuncia = _catalogo.infoOf(
        'SENA_PENDIENTE:PONER',
        sentence: 'Quiero poner una denuncia',
      );
      expect(denuncia.lsbDescription, ['PRESENTAR']);
      final nombre = _catalogo.infoOf(
        'SENA_PENDIENTE:PONER',
        sentence: 'Quiero ponerla a mi nombre',
      );
      expect(nombre.lsbDescription, ['DEJAR']);
    });

    test('«cancelar la multa» es pagar; «cancelar una hipoteca», no', () {
      expect(
        _catalogo
            .infoOf('SENA_PENDIENTE:CANCELAR', sentence: 'Cancelar la multa')
            .lsbDescription,
        ['DAR', 'BILLETES'],
      );
      expect(
        _catalogo
            .infoOf(
              'SENA_PENDIENTE:CANCELAR',
              sentence: 'Cancelar una hipoteca',
            )
            .lsbDescription,
        ['TERMINAR', 'DEUDA'],
      );
    });

    test('«seguir las instrucciones» no es continuar', () {
      expect(
        _catalogo
            .infoOf('SENA_PENDIENTE:SEGUIR', sentence: 'Siga las instrucciones')
            .lsbDescription,
        ['HACER', 'EXPLICAR'],
      );
    });

    test('«ingresar a la oficina» es entrar; «ingresar el trámite» no', () {
      expect(
        _catalogo
            .infoOf('SENA_PENDIENTE:INGRESAR', sentence: 'Ingrese a la oficina')
            .lsbDescription,
        ['IR', 'DENTRO'],
      );
      expect(
        _catalogo
            .infoOf('SENA_PENDIENTE:INGRESAR', sentence: 'Ingresar un trámite')
            .lsbDescription,
        ['PRESENTAR', 'TRÁMITE'],
      );
    });
  });
}
