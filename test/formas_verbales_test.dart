import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/local_audio_translator.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';
import 'package:lsb_legal_app/core/domain/services/verb_forms_data.g.dart';
import 'package:lsb_legal_app/core/domain/services/word_forms.dart';
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
  group('plurales y femeninos de una seña', () {
    test('sin conexión: «abogadas», «papeles», «testigos»', () {
      const local = LocalAudioTranslator();
      expect(local.translate('abogadas').glosses, ['ABOGADO']);
      expect(local.translate('papeles').glosses, ['PAPEL']);
      expect(local.translate('los testigos').glosses, ['TESTIGO']);
      expect(local.translate('juezas').glosses, ['JUEZ']);
    });

    test('la misma regla que la Lambda', () {
      bool known(String c) =>
          {'ABOGADO', 'PAPEL', 'JUEZ', 'DOCTOR'}.contains(c);
      expect(WordForms.baseOf('ABOGADAS', known), 'ABOGADO');
      expect(WordForms.baseOf('JUEZAS', known), 'JUEZ');
      expect(WordForms.baseOf('DOCTORAS', known), 'DOCTOR');
      expect(WordForms.baseOf('PAPELES', known), 'PAPEL');
      expect(WordForms.baseOf('XYZS', known), isNull);
      expect(WordForms.baseOf('ASAS', known), isNull);
    });
  });

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

    test('toda forma lleva a un verbo del léxico LSB', () {
      final lexico =
          (jsonDecode(File('aws/lexico_lsb.json').readAsStringSync())
                  as Map<String, dynamic>)['glosas']
              as Map<String, dynamic>;
      for (final MapEntry(key: forma, value: verbo)
          in VerbForms.lemmas.entries) {
        expect(lexico, contains(verbo), reason: '$forma → $verbo');
      }
    });

    test('verbos con seña: una forma de cada tiempo', () {
      const casos = {
        'ESCUCHARON': 'ESCUCHAR',
        'BUSQUE': 'BUSCAR',
        'PIDIO': 'PEDIR',
        'VUELVO': 'VOLVER',
        'RECIBIRA': 'RECIBIR',
        'PERDIO': 'PERDER',
        'CONOZCO': 'CONOCER',
        'ACOMPAÑARON': 'ACOMPAÑAR',
        'MURIO': 'MORIR',
        'VOY': 'IR',
        'TUVO': 'TENER',
      };
      for (final MapEntry(key: f, value: v) in casos.entries) {
        expect(VerbForms.lemmas[f], v, reason: f);
      }
    });

    test('las formas ambiguas no se llevan a un verbo', () {
      for (final f in [
        'FUE', 'FUERON', 'IRA', 'DE', 'PASO', 'ENVIO', 'HACE', 'PARA', 'TRATA',
        'PRUEBA', 'CITA', 'DENUNCIA', //
      ]) {
        expect(VerbForms.lemmas, isNot(contains(f)), reason: f);
        expect(describedVerbFormsData, isNot(contains(f)), reason: f);
      }
    });

    test('la tabla de la app y la de la Lambda son la misma', () {
      final json =
          jsonDecode(File('aws/formas_verbales.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(VerbForms.lemmas, json['formas']);
      expect(describedVerbFormsData, json['descritas']);
    });

    test('«denunció» se explica como «denunciar»', () {
      final catalogo = PendingSignCatalog.fromJsonString(
        File('assets/dictionary/senas_sin_sena.json').readAsStringSync(),
      );
      for (final f in ['denunció', 'denunciaron']) {
        expect(catalogo.describedGloss(f), isNotNull, reason: f);
      }
      // Plural y femenino de una palabra descrita.
      for (final f in ['mensajes', 'inmuebles', 'propietarias', 'herederos']) {
        expect(catalogo.describedGloss(f), isNotNull, reason: f);
      }
      // «solicitar» y «realizar» no tienen descripción pero sí equivalencia.
      expect(catalogo.equivalentSigns('solicitaron'), ['PEDIR']);
      expect(catalogo.equivalentSigns('realizó'), ['HACER']);
      expect(
        catalogo
            .infoOf(
              catalogo.describedGloss('pasaron')!,
              sentence: 'Pasaron adelante',
            )
            .lsbDescription,
        ['VENIR', 'AQUÍ'],
      );
    });
  });
}
