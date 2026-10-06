import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/data/models/lsb_translation_model.dart';
import 'package:lsb_legal_app/core/di/injection.dart'
    show pendingSignCatalogProvider;
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/domain/services/described_word_steps.dart';

import 'support/fake_webview_platform.dart';

const _modelo = 'https://x/avatar_test.glb';
const _marca = AnimationUrlResolver.placeholderScheme;

/// Un catálogo de descripciones pequeño, con la forma del asset.
final _catalogo = PendingSignCatalog.fromJsonString(
  jsonEncode({
    'palabras': {
      'HIPOTECA': {
        'descripcion': 'El banco presta dinero y la casa queda como garantía.',
        'descripcionLsb': [
          'BANCO',
          'PRESTAR',
          'CASA',
          'SENA_PENDIENTE:GARANTIA',
        ],
        'tipo': 'concepto',
      },
      'FOLIO_REAL': {
        'descripcion': 'Papel del registro de una casa.',
        'descripcionLsb': ['PAPEL', 'CASA'],
        'tipo': 'concepto',
      },
      'TAMAÑO': {
        'descripcion': 'Qué tan grande es algo.',
        'descripcionLsb': const [],
        'tipo': 'concepto',
      },
      'ANTEZANA': {
        'descripcion': 'Apellido.',
        'descripcionLsb': ['A', 'N', 'T', 'E', 'Z', 'A', 'N', 'A'],
        'tipo': 'nombre_propio',
      },
    },
  }),
);

/// Una traducción con [pasos] (señas con clip y letras) y las palabras que
/// el backend informó deletreadas.
LsbTranslation _traduccion(List<String> pasos, List<String> deletreadas) {
  final urls = [for (final p in pasos) p.length == 1 ? '$_marca$p' : _modelo];
  return LsbTranslation(
    glosses: pasos,
    animationUrl: urls.first,
    animationUrls: urls,
    animationGlosses: pasos,
    spelledWords: deletreadas,
  );
}

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  group('una palabra que no existe en LSB', () {
    test('con descripción se explica en vez de deletrearse', () {
      final t = DescribedWordSteps.apply(
        _traduccion(['YO', ...'HIPOTECA'.split(''), 'TENER'], ['HIPOTECA']),
        _catalogo,
      );
      expect(t.animationGlosses, ['YO', 'SENA_PENDIENTE:HIPOTECA', 'TENER']);
      expect(t.animationUrls, [
        _modelo,
        '${_marca}SENA_PENDIENTE:HIPOTECA',
        _modelo,
      ]);
    });

    test('sin descripción (o sin avatar) se deletrea', () {
      final pasos = ['YO', ...'ACOSO'.split('')];
      final t = DescribedWordSteps.apply(
        _traduccion(pasos, ['ACOSO']),
        _catalogo,
      );
      expect(t.animationGlosses, pasos);
    });

    test('un nombre propio se deletrea aunque tenga entrada', () {
      final pasos = ['SEÑOR', ...'ANTEZANA'.split('')];
      final t = DescribedWordSteps.apply(
        _traduccion(pasos, ['Antezana']),
        _catalogo,
      );
      expect(t.animationGlosses, pasos);
    });

    test('se reconoce con tildes, Ñ, minúsculas y varias palabras', () {
      final t = DescribedWordSteps.apply(
        _traduccion(
          [...'FOLIOREAL'.split(''), 'Y', ...'TAMAÑO'.split('')],
          ['Folio Real', 'y', 'tamaño'],
        ),
        _catalogo,
      );
      expect(t.animationGlosses, [
        'SENA_PENDIENTE:FOLIO_REAL',
        'Y',
        'SENA_PENDIENTE:TAMAÑO',
      ]);
    });

    test('la respuesta del backend trae las palabras deletreadas', () {
      final m = LsbTranslationModel.fromJson({
        'glosses': ['YO'],
        'animationUrl': '',
        'spelledWords': ['HIPOTECA'],
      });
      expect(m.spelledWords, ['HIPOTECA']);
      expect(LsbTranslationModel.fromJson(m.toJson()).spelledWords, [
        'HIPOTECA',
      ]);
    });

    test(
      'de la respuesta de la Lambda a la descripción delante del avatar',
      () async {
        final fuente = RemoteAudioDataSourceImpl(
          apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'glosses': ['YO', ...'HIPOTECA'.split('')],
                'animationSequence': [
                  {'gloss': 'YO', 'animationFile': 'YO'},
                  for (final l in 'HIPOTECA'.split(''))
                    {'gloss': l, 'animationFile': l},
                ],
                'fidelityFixes': [
                  {'palabra': 'HIPOTECA', 'accion': 'concepto_sin_catalogo'},
                  {'palabra': 'tengo', 'accion': 'palabra_recuperada'},
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          animationResolver: const AnimationUrlResolver(baseUrl: 'https://x/'),
        );
        final t = await fuente.translateText('Tengo una hipoteca');
        expect(t.spelledWords, ['HIPOTECA']);
        expect(DescribedWordSteps.apply(t, _catalogo).animationGlosses, [
          'YO',
          'SENA_PENDIENTE:HIPOTECA',
        ]);
      },
    );

    test('la descripción se queda lo que tarda en leerse', () {
      final corta = Avatar3DViewer.readingTimeFor(
        _catalogo.infoOf('SENA_PENDIENTE:FOLIO_REAL'),
      );
      final larga = Avatar3DViewer.readingTimeFor(
        const PendingSignInfo(
          word: 'X',
          description: 'x',
          lsbDescription: [
            'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
            'N', 'O', 'P', 'Q', 'R', 'S', 'T',
          ],
        ),
      );
      expect(corta, const Duration(seconds: 5));
      expect(larga, const Duration(seconds: 15));
    });

    test('toda palabra del catálogo de la app se puede explicar', () {
      final catalogo = PendingSignCatalog.fromJsonString(
        File('assets/dictionary/senas_sin_sena.json').readAsStringSync(),
      );
      expect(catalogo.describedGloss('hipoteca'), 'SENA_PENDIENTE:HIPOTECA');
      expect(catalogo.describedGloss('PALABRA_QUE_NO_ESTA'), isNull);
    });
  });

  group('delante del avatar', () {
    Future<void> reproducir(
      WidgetTester tester, {
      required bool describir,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSignCatalogProvider.overrideWith((ref) async => _catalogo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Avatar3DViewer(
                isProcessing: false,
                describePendingSigns: describir,
                animationDuration: const Duration(milliseconds: 10),
                glosses: const ['SENA_PENDIENTE:HIPOTECA', 'HOLA'],
                animationUrls: const [
                  '${_marca}SENA_PENDIENTE:HIPOTECA',
                  '${_marca}HOLA',
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('se desliza la descripción, se lee y vuelve el avatar', (
      tester,
    ) async {
      await reproducir(tester, describir: true);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('avatar_descripcion')), findsOneWidget);
      // Se ve delante del avatar (no colapsa la capa de la seña).
      final bloque = tester.getRect(
        find.byKey(const Key('avatar_descripcion')),
      );
      expect(bloque.height, greaterThan(100));
      expect(bloque.width, greaterThan(600));
      expect(find.text('No tiene seña en LSB. ¿Qué es?'), findsOneWidget);
      expect(find.byKey(const Key('descripcion_lsb')), findsOneWidget);
      // La esquina rotula la palabra, sin la marca interna.
      expect(find.text('HIPOTECA'), findsWidgets);
      expect(find.textContaining('SENA_PENDIENTE'), findsNothing);

      // Sigue ahí mientras se lee…
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('avatar_descripcion')), findsOneWidget);

      // …y al terminar se va y el avatar sigue con la seña siguiente.
      final lectura = Avatar3DViewer.readingTimeFor(
        _catalogo.infoOf('SENA_PENDIENTE:HIPOTECA'),
      );
      await tester.pump(lectura);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('avatar_descripcion')), findsNothing);
    });

    testWidgets('«Seguir» la cierra antes', (tester) async {
      await reproducir(tester, describir: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('avatar_descripcion')), findsNothing);
    });

    testWidgets('las demás vistas siguen con el aviso de seña a incorporar', (
      tester,
    ) async {
      await reproducir(tester, describir: false);
      expect(find.byKey(const Key('avatar_descripcion')), findsNothing);
      expect(find.byKey(const Key('avatar_sena_a_incorporar')), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
