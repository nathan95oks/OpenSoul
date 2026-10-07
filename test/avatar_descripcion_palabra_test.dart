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
    show pendingSignCatalogProvider, remoteAudioDataSourceProvider;
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';

import 'support/fake_webview_platform.dart';

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

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  group('datos de la traducción', () {
    test('la Lambda informa las señas sin animación', () async {
      final fuente = RemoteAudioDataSourceImpl(
        apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'glosses': ['VERDAD'],
              'glossDetails': [
                {
                  'gloss': 'VERDAD',
                  'available': false,
                  'spelledLetters': 'VERDAD'.split(''),
                },
              ],
              'animationSequence': [
                for (final l in 'VERDAD'.split(''))
                  {'gloss': l, 'animationFile': l},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        animationResolver: const AnimationUrlResolver(baseUrl: 'https://x/'),
      );
      final t = await fuente.translateText('es verdad');
      expect(t.unanimatedSigns, ['VERDAD']);
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

  test('Voz a LSB: «hola quiero realizar un tramite» termina sin error y '
      'deletrea REALIZAR', () async {
    // La respuesta real de la Lambda desplegada para esa frase.
    final respuesta = {
      'glosses': ['HOLA', 'TRAMITE', ...'REALIZAR'.split('')],
      'animationSequence': [
        {'gloss': 'HOLA', 'animationFile': 'avatar_test.glb'},
        {'gloss': 'TRAMITE', 'animationFile': 'avatar_test.glb'},
        for (final l in 'REALIZAR'.split(''))
          {'gloss': l, 'animationFile': 'avatar_test.glb'},
      ],
      'glossDetails': [
        {'gloss': 'HOLA', 'available': true},
        {'gloss': 'TRAMITE', 'available': true},
      ],
      'fidelityFixes': [
        {'palabra': 'REALIZAR', 'accion': 'concepto_sin_catalogo'},
      ],
      'semanticStatus': 'resolved',
      'representationStatus': 'complete',
    };
    final c = ProviderContainer(
      overrides: [
        remoteAudioDataSourceProvider.overrideWithValue(
          RemoteAudioDataSourceImpl(
            apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
            client: MockClient(
              (_) async => http.Response(
                jsonEncode(respuesta),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
            ),
          ),
        ),
        pendingSignCatalogProvider.overrideWith(
          (ref) async => PendingSignCatalog.fromJsonString(
            File('assets/dictionary/senas_sin_sena.json').readAsStringSync(),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    final controlador = c.read(audioTranslationControllerProvider.notifier);
    // Dos veces: la segunda sale de la caché de traducciones.
    for (var vez = 0; vez < 2; vez++) {
      controlador.processText('hola quiero realizar un tramite');
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (c.read(audioTranslationControllerProvider).status !=
            AudioTranslationStatus.processing) {
          break;
        }
      }
      final estado = c.read(audioTranslationControllerProvider);
      expect(estado.errorMessage, isNull);
      expect(estado.status, AudioTranslationStatus.success);
      final t = estado.translationResult!;
      // Sin la pantalla de descripción: como antes, lo que el avatar no
      // tiene se deletrea.
      expect(t.animationGlosses, ['HOLA', 'TRAMITE', ...'REALIZAR'.split('')]);
    }
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
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(const Key('avatar_descripcion')), findsOneWidget);
      // Se ve delante del avatar (no colapsa la capa de la seña).
      final bloque = tester.getRect(
        find.byKey(const Key('avatar_descripcion')),
      );
      expect(bloque.height, greaterThan(100));
      expect(bloque.width, greaterThan(600));
      // La misma tarjeta de la hoja «¿Qué es?», sobre la pantalla amarilla.
      expect(
        find.text('No tiene seña propia en los módulos M1–M4.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('avatar_descripcion_lectura')), findsOne);
      // Tapa todo el avatar.
      expect(bloque, tester.getRect(find.byType(Avatar3DViewer)).deflate(1));
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

    testWidgets('«Entendido» la cierra antes', (tester) async {
      await reproducir(tester, describir: true);
      // Solo la entrada: la barra de lectura sigue corriendo.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('avatar_descripcion')), findsNothing);
    });

    testWidgets('dos palabras seguidas: la pantalla se queda y cambia la '
        'tarjeta', (tester) async {
      const a = PendingSignInfo(
        word: 'REALIZAR',
        description: 'HACER',
        lsbDescription: ['HACER'],
        hasLsbSign: true,
      );
      const b = PendingSignInfo(
        word: 'VERDAD',
        description: 'VERDAD',
        lsbDescription: ['VERDAD'],
        hasLsbSign: true,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSignCatalogProvider.overrideWith((ref) async => _catalogo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Avatar3DViewer(
                isProcessing: false,
                describePendingSigns: true,
                animationDuration: Duration(milliseconds: 10),
                stepDescriptions: {
                  'SENA_PENDIENTE:REALIZAR': a,
                  'SENA_PENDIENTE:VERDAD': b,
                },
                glosses: [
                  'SENA_PENDIENTE:REALIZAR',
                  'SENA_PENDIENTE:VERDAD',
                  'HOLA',
                ],
                animationUrls: [
                  '${_marca}SENA_PENDIENTE:REALIZAR',
                  '${_marca}SENA_PENDIENTE:VERDAD',
                  '${_marca}HOLA',
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        find.text(
          'Existe en LSB, pero el avatar todavía no tiene esta '
          'seña.',
        ),
        findsOneWidget,
      );
      expect(find.text('En LSB se seña:'), findsOneWidget);
      final pantalla = tester.element(
        find.byKey(const Key('avatar_descripcion')),
      );

      await tester.tap(find.text('Entendido'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // La misma pantalla amarilla, con la tarjeta de VERDAD.
      expect(find.byKey(const Key('avatar_descripcion')), findsOneWidget);
      expect(
        tester.element(find.byKey(const Key('avatar_descripcion'))),
        same(pantalla),
      );
      expect(find.text('VERDAD'), findsWidgets);

      await tester.tap(find.text('Entendido'));
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
