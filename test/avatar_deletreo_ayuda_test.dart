import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';
import 'package:lsb_legal_app/core/domain/services/spelling_help.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';

import 'support/fake_webview_platform.dart';

const _marca = AnimationUrlResolver.placeholderScheme;

final _catalogo = PendingSignCatalog.fromJsonString(
  jsonEncode({
    'palabras': {
      'HIPOTECA': {
        'descripcion': 'El banco presta dinero y la casa queda como garantía.',
        'descripcionLsb': ['BANCO', 'PRESTAR', 'CASA', 'DEUDA'],
        'tipo': 'concepto',
      },
    },
    'equivalencias': {
      'REALIZAR': ['HACER'],
      'CONTRATO': ['CONTRATO'],
    },
  }),
);

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  group('qué ayuda tiene cada palabra deletreada', () {
    final pasos = [
      'HOLA',
      'TRAMITE',
      ...'REALIZAR'.split(''),
      ...'HIPOTECA'.split(''),
      ...'ACOSO'.split(''),
    ];
    final ayudas = SpellingHelp.forSteps(pasos, [
      'REALIZAR',
      'HIPOTECA',
      'ACOSO',
    ], _catalogo);

    test('con sinónimo en LSB', () {
      final h = ayudas[0];
      expect((h.start, h.end, h.word), (2, 9, 'REALIZAR'));
      expect(h.synonyms, ['HACER']);
      expect(h.description, isNull);
    });

    test('sin sinónimo, la descripción de las tarjetas LSB', () {
      final h = ayudas[1];
      expect((h.start, h.end), (10, 17));
      expect(h.synonyms, isEmpty);
      expect(h.description!.lsbDescription, [
        'BANCO',
        'PRESTAR',
        'CASA',
        'DEUDA',
      ]);
    });

    test('sin ninguno de los dos, solo la palabra', () {
      final h = ayudas[2];
      expect((h.start, h.end, h.word), (18, 22, 'ACOSO'));
      expect(h.synonyms, isEmpty);
      expect(h.description, isNull);
    });

    test('una equivalencia consigo misma no es un sinónimo', () {
      final h = SpellingHelp.forSteps('CONTRATO'.split(''), [
        'contrato',
      ], _catalogo).single;
      expect(h.synonyms, isEmpty);
    });

    test('con el catálogo de la app: «realizar» tiene sinónimo HACER', () {
      final catalogo = PendingSignCatalog.fromJsonString(
        File('assets/dictionary/senas_sin_sena.json').readAsStringSync(),
      );
      final h = SpellingHelp.forSteps(
        ['HOLA', 'TRAMITE', ...'REALIZAR'.split('')],
        ['REALIZAR'],
        catalogo,
      ).single;
      expect(h.synonyms, ['HACER']);
    });
  });

  group('abajo, mientras el avatar deletrea', () {
    Future<void> reproducir(
      WidgetTester tester,
      List<String> pasos,
      List<SpellingHelp> ayudas,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 700,
                child: Avatar3DViewer(
                  isProcessing: false,
                  expandToFit: true,
                  animationDuration: const Duration(seconds: 2),
                  glosses: pasos,
                  animationUrls: [for (final p in pasos) '$_marca$p'],
                  spellingHelp: ayudas,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('aparece el sinónimo y «Siguiente» salta el deletreo', (
      tester,
    ) async {
      final pasos = ['HOLA', ...'REALIZAR'.split(''), 'TRAMITE'];
      await reproducir(
        tester,
        pasos,
        SpellingHelp.forSteps(pasos, ['REALIZAR'], _catalogo),
      );
      // Durante HOLA no hay ayuda.
      expect(find.byKey(const Key('avatar_deletreo_ayuda')), findsNothing);

      // Empieza el deletreo de REALIZAR: abajo, su sinónimo.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('avatar_deletreo_ayuda')), findsOneWidget);
      expect(find.text('Sinónimo en LSB:'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('avatar_deletreo_sinonimo')))
            .data,
        'HACER',
      );

      // Siguiente: no espera las 8 letras, pasa a TRAMITE.
      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('avatar_deletreo_ayuda')), findsNothing);
      expect(find.text('TRAMITE'), findsWidgets);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('sin sinónimo muestra la descripción como en las tarjetas', (
      tester,
    ) async {
      final pasos = [...'HIPOTECA'.split('')];
      await reproducir(
        tester,
        pasos,
        SpellingHelp.forSteps(pasos, ['HIPOTECA'], _catalogo),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('avatar_deletreo_ayuda')), findsOneWidget);
      expect(find.text('¿Qué es?'), findsOneWidget);
      // Junto al avatar no se dice por qué no tiene seña: solo qué es, con
      // «¿Qué es?» en grande.
      expect(find.textContaining('No tiene seña propia'), findsNothing);
      expect(
        tester.widget<Text>(find.text('¿Qué es?')).style!.fontSize,
        greaterThanOrEqualTo(20),
      );
      expect(find.byKey(const Key('descripcion_lsb')), findsOneWidget);

      // En la última letra, «Siguiente» termina la seña.
      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('avatar_deletreo_ayuda')), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });
}
