import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/local_audio_translator.dart';
import 'package:lsb_legal_app/core/domain/services/verb_forms.dart';

const _modelo = 'https://x/avatar_test.glb';

LsbTranslation _traduccion(List<String> pasos) => LsbTranslation(
  glosses: pasos,
  animationUrl: _modelo,
  animationGlosses: pasos,
  animationUrls: [for (final _ in pasos) _modelo],
);

List<String> _letras(String w) => w.split('');

void main() {
  group('formas conjugadas con seña (va, tiene, da…)', () {
    test('«va» dictada sola salía V-A: es IR', () {
      final t = VerbForms.apply('va', _traduccion(['V', 'A']));
      expect(t.glosses, ['IR']);
      expect(t.animationGlosses, ['IR']);
      expect(t.animationUrls, hasLength(1));
    });

    test('«van», «tiene», «da» y «venga» vuelven a su verbo', () {
      for (final (forma, verbo) in [
        ('van', 'IR'),
        ('tiene', 'TENER'),
        ('da', 'DAR'),
        ('venga', 'VENIR'),
      ]) {
        final t = VerbForms.apply(
          forma,
          _traduccion(_letras(forma.toUpperCase())),
        );
        expect(t.animationGlosses, [verbo], reason: forma);
        expect(
          AnimationUrlResolver.available3DGlosses,
          contains(verbo),
          reason: '$verbo tiene clip',
        );
      }
    });

    test('dentro de una frase: «ya va» → YA IR', () {
      final t = VerbForms.apply('ya va', _traduccion(['Y', 'A', 'V', 'A']));
      expect(t.animationGlosses, ['Y', 'A', 'IR']);
    });

    test('si no la dijo, no cambia nada (misma instancia)', () {
      final t = _traduccion(['V', 'A', 'CASA']);
      expect(VerbForms.apply('la casa', t), same(t));
    });

    test('lo que ya tiene seña no se toca', () {
      final t = _traduccion(['EL', 'IR', 'CASA']);
      expect(VerbForms.apply('él va a la casa', t), same(t));
    });

    test('«voy a denunciar» es futuro: sin IR y con FUTURO al inicio', () {
      final t = VerbForms.apply(
        'voy a denunciar',
        _traduccion([..._letras('DENUNCIAR'), 'IR']),
      );
      expect(t.animationGlosses.first, 'FUTURO');
      expect(t.animationGlosses, isNot(contains('IR')));
      expect(t.animationUrls, hasLength(t.animationGlosses.length));
    });

    test('«voy a un bar» no es futuro', () {
      expect(VerbForms.diceFuturoProximo('voy a un bar'), isFalse);
      expect(VerbForms.diceFuturoProximo('va a la casa'), isFalse);
      expect(VerbForms.diceFuturoProximo('¿Va a venir mañana?'), isTrue);
    });

    test('sin conexión: «va», «van», «voy a denunciar»', () {
      const local = LocalAudioTranslator();
      expect(local.translate('va').glosses, ['IR']);
      expect(local.translate('van').animationGlosses, ['IR']);
      expect(local.translate('voy a denunciar').glosses, [
        'FUTURO',
        'DENUNCIAR',
      ]);
      expect(local.translate('él va a la casa').glosses, ['EL', 'IR', 'CASA']);
    });

    test('toda forma lleva a un verbo con clip del avatar', () {
      for (final MapEntry(key: forma, value: verbo)
          in VerbForms.lemmas.entries) {
        expect(
          AnimationUrlResolver.available3DGlosses,
          contains(AnimationUrlResolver.canonicalFor(verbo)),
          reason: '$forma → $verbo',
        );
      }
    });

    test('la tabla del cliente y la de la Lambda son la misma', () {
      final py = File('aws/lambda_text_to_lsb.py').readAsStringSync();
      final bloque = RegExp(
        r'_FORMAS_VERBALES = \{(.*?)\n\}',
        dotAll: true,
      ).firstMatch(py)!.group(1)!;
      final servidor = <String, String>{};
      for (final m in RegExp(
        r'"([A-Z]+)":\s*((?:"[^"]*"\s*)+),',
      ).allMatches(bloque)) {
        for (final tramo in RegExp('"([^"]*)"').allMatches(m.group(2)!)) {
          for (final f
              in tramo.group(1)!.split(' ').where((f) => f.isNotEmpty)) {
            servidor[f] = m.group(1)!;
          }
        }
      }
      expect(servidor, isNotEmpty);
      expect(VerbForms.lemmas, servidor);
    });
  });
}
