import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/di/injection.dart'
    show remoteAudioDataSourceProvider;
import 'package:lsb_legal_app/features/audio_to_lsb/domain/services/audio_input_validator.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/fake_webview_platform.dart';

AudioInputIssue? _v(String t) => AudioInputValidator.validate(t);

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  testWidgets('la pantalla avisa por qué no se tradujo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final llamadas = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteAudioDataSourceProvider.overrideWithValue(
            RemoteAudioDataSourceImpl(
              apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
              client: MockClient((req) async {
                llamadas.add(req.body);
                return http.Response('{}', 200);
              }),
            ),
          ),
        ],
        child: const MaterialApp(home: AudioToLsbScreen()),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byType(TextField),
      'ljalskalksjlakj(*\$)\$#()#)',
    );
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(AudioInputIssue.gibberish.message), findsOneWidget);
    expect(llamadas, isEmpty);
  });

  group('lo que no debe pasar', () {
    test('vacío o solo espacios (un audio sin voz)', () {
      for (final t in ['', '   ', '\n\t ', '​​']) {
        expect(_v(t), AudioInputIssue.empty, reason: '«$t»');
      }
    });

    test('muchos caracteres juntos y símbolos', () {
      expect(_v('ljalskalksjlakj(*\$)\$#()#)'), isNotNull);
      for (final t in [
        'ljalskalksjlakj',
        'asdfghjklñ',
        'qwertyuiop',
        'aaaaaaaaaaaa',
        'zxcvbnm lkjhgfd',
        'hola ljalskalksjlakj',
        'kjhgfdsapoiuytrewq',
      ]) {
        expect(_v(t), AudioInputIssue.gibberish, reason: t);
      }
      for (final t in [
        '(*\$)\$#()#)',
        '!!!???...',
        '@#%^&*',
        '--- ---',
        '😀😀😀',
      ]) {
        expect(_v(t), AudioInputIssue.noWords, reason: t);
      }
    });

    test('demasiado largo', () {
      expect(_v('hola ' * 80), AudioInputIssue.tooLong);
      expect(_v('a' * 301), AudioInputIssue.tooLong);
    });

    test('otro idioma o otro alfabeto', () {
      for (final t in [
        'hello, I need help with the police',
        'the house is big',
        'thank you very much',
        'where is the court',
        'hello',
        'não tenho documento',
        'obrigado pela ajuda',
        'bonjour, je voudrais de l’aide',
        'ich brauche hilfe',
        'ciao, voglio una denuncia',
        'привет, мне нужна помощь',
        '你好我需要帮助',
        'مرحبا أحتاج مساعدة',
        'γεια σου',
      ]) {
        expect(_v(t), AudioInputIssue.otherLanguage, reason: t);
      }
    });
  });

  group('lo que sí debe pasar', () {
    test('frases normales', () {
      for (final t in [
        'hola quiero realizar un tramite',
        'quiere realizar un tramite en la felcc?',
        '¿Quiere realizar un trámite en la FELCC?',
        'Necesito ayuda, me robaron el celular',
        'Mi nombre es Ñusta Quispe Mamani',
        'Tengo 25 años',
        'mi carnet es 1234567',
        'FELCC',
        'hola',
        'no',
        'sí',
        'voy a la SEPDAVI y al SERECI',
        'necesito el NUREJ de mi caso',
        'tengo el CRPVA de mi auto',
        'vergüenza y güero',
        'Cochabamba, 12 de octubre de 2026.',
        'jajaja qué gracioso',
        'estoy en la oficina de transplantes',
        'construcción de obstrucciones',
        'Quiero denunciar a Schwarzenegger',
        'help',
      ]) {
        // «help» es una palabra suelta en otro idioma: debe rechazarse.
        if (t == 'help') {
          expect(_v(t), AudioInputIssue.otherLanguage);
        } else {
          expect(_v(t), isNull, reason: t);
        }
      }
    });

    test('todas las frases del corpus de trámites', () {
      final corpus =
          jsonDecode(File('assets/rag/escenarios_cbba.json').readAsStringSync())
              as Map<String, dynamic>;
      final rechazadas = <String>[];
      var total = 0;
      for (final e in (corpus['escenarios'] as List).cast<Map>()) {
        for (final t in (e['turnos'] as List).cast<Map>()) {
          final texto = '${t['texto']}';
          if (texto.length > AudioInputValidator.maxLength) continue;
          total++;
          final problema = _v(texto);
          if (problema != null) rechazadas.add('$problema «$texto»');
        }
      }
      expect(total, greaterThan(1000));
      expect(rechazadas, isEmpty);
    });

    test('una frase de más de una oración se limpia pero pasa', () {
      expect(
        AudioInputValidator.clean('  hola \n  quiero\tayuda  '),
        'hola quiero ayuda',
      );
      expect(_v('  hola \n  quiero\tayuda  '), isNull);
    });
  });

  group('en el módulo', () {
    ProviderContainer app(List<String> llamadas) {
      final c = ProviderContainer(
        overrides: [
          remoteAudioDataSourceProvider.overrideWithValue(
            RemoteAudioDataSourceImpl(
              apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
              client: MockClient((req) async {
                llamadas.add(req.body);
                return http.Response(
                  jsonEncode({
                    'glosses': ['HOLA'],
                    'animationSequence': [
                      {'gloss': 'HOLA', 'animationFile': 'avatar_test.glb'},
                    ],
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<AudioTranslationState> enviar(
      ProviderContainer c,
      String texto,
    ) async {
      c.read(audioTranslationControllerProvider.notifier).processText(texto);
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (c.read(audioTranslationControllerProvider).status !=
            AudioTranslationStatus.processing) {
          break;
        }
      }
      return c.read(audioTranslationControllerProvider);
    }

    test('un texto sin sentido no llega al traductor y dice por qué', () async {
      final llamadas = <String>[];
      final c = app(llamadas);
      for (final (texto, motivo) in [
        ('ljalskalksjlakj(*\$)\$#()#)', AudioInputIssue.gibberish),
        ('hello I need help', AudioInputIssue.otherLanguage),
        ('   ', AudioInputIssue.empty),
        ('???', AudioInputIssue.noWords),
      ]) {
        final estado = await enviar(c, texto);
        expect(estado.status, AudioTranslationStatus.error, reason: texto);
        expect(estado.errorMessage, motivo.message, reason: texto);
        expect(estado.translationResult, isNull);
      }
      expect(llamadas, isEmpty, reason: 'nada de eso se manda al modelo');
    });

    test('un audio vacío vuelve al inicio sin llamar al traductor', () async {
      final llamadas = <String>[];
      final c = app(llamadas);
      c
          .read(audioTranslationControllerProvider.notifier)
          .processAudioAsText('  ');
      expect(
        c.read(audioTranslationControllerProvider).status,
        AudioTranslationStatus.idle,
      );
      expect(llamadas, isEmpty);
    });

    test('después de un rechazo, un texto bueno se traduce', () async {
      final llamadas = <String>[];
      final c = app(llamadas);
      await enviar(c, 'asdfghjkl');
      final estado = await enviar(c, 'hola');
      expect(estado.status, AudioTranslationStatus.success);
      expect(estado.errorMessage, isNull);
      expect(llamadas, hasLength(1));
    });
  });
}
