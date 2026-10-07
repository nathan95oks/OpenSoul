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

    test('con una seña equivalente que el avatar tiene, se seña', () {
      final catalogo = PendingSignCatalog.fromJsonString(
        jsonEncode({
          'palabras': {
            'COMPROBANTE': {'descripcion': 'Papel de un pago.'},
          },
          'equivalencias': {
            'COMPROBANTE': ['FACTURA'],
            'TERRENO': ['TERRENO'],
          },
        }),
      );
      final t = DescribedWordSteps.apply(
        _traduccion(
          ['YO', ...'COMPROBANTE'.split(''), ...'TERRENO'.split('')],
          ['comprobante', 'terreno'],
        ),
        catalogo,
      );
      // FACTURA tiene clip: se seña. TERRENO existe en LSB pero el avatar no
      // la tiene: no se deletrea, se explica.
      expect(t.animationGlosses, ['YO', 'FACTURA', 'SENA_PENDIENTE:TERRENO']);
      expect(t.animationUrls[1], isNot(startsWith(_marca)));
      final terreno = t.stepDescriptions['SENA_PENDIENTE:TERRENO']!;
      expect(terreno.hasLsbSign, isTrue);
      expect(terreno.lsbDescription, ['TERRENO']);
    });

    test('«hola quiero realizar un tramite»: realizar existe (HACER) y se '
        'explica, no se deletrea', () {
      final catalogo = PendingSignCatalog.fromJsonString(
        jsonEncode({
          'palabras': const {},
          'equivalencias': {
            'REALIZAR': ['HACER'],
          },
        }),
      );
      // Lo que devuelve hoy la Lambda desplegada para esa frase.
      final t = DescribedWordSteps.apply(
        _traduccion(['HOLA', 'TRAMITE', ...'REALIZAR'.split('')], ['REALIZAR']),
        catalogo,
        signSources: const {'HACER': 'M3 · General I · p.111'},
      );
      expect(t.animationGlosses, [
        'HOLA',
        'TRAMITE',
        'SENA_PENDIENTE:REALIZAR',
      ]);
      final info = t.stepDescriptions['SENA_PENDIENTE:REALIZAR']!;
      expect(info.word, 'REALIZAR');
      expect(info.hasLsbSign, isTrue);
      expect(info.lsbDescription, ['HACER']);
      expect(info.source, 'M3 · General I · p.111');
    });

    test('una seña del catálogo sin animación no se deletrea: se explica', () {
      // «es verdad»: la Lambda deletrea VERDAD porque no hay clip.
      final t = DescribedWordSteps.apply(
        LsbTranslation(
          glosses: const ['VERDAD'],
          animationUrl: '',
          animationGlosses: 'VERDAD'.split(''),
          animationUrls: [for (final l in 'VERDAD'.split('')) '$_marca$l'],
          unanimatedSigns: const ['VERDAD'],
        ),
        _catalogo,
      );
      expect(t.animationGlosses, ['SENA_PENDIENTE:VERDAD']);
      expect(t.stepDescriptions['SENA_PENDIENTE:VERDAD']!.hasLsbSign, isTrue);
    });

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
