import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/di/injection.dart'
    show pendingSignCatalogProvider;
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';
import 'package:lsb_legal_app/core/presentation/widgets/pending_sign_info_sheet.dart';
import 'package:lsb_legal_app/features/conversation/presentation/widgets/gloss_line.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/sign_preview_planner.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_preview_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/gloss_row.dart';

class _SinImagenes extends SignImagesNotifier {
  @override
  bool build() => false;
}

void main() {
  test('la palabra sin seña se lee en español', () {
    expect(PendingSign.isPending('SENA_PENDIENTE:FOLIO_REAL'), isTrue);
    expect(PendingSign.isPending('CASA'), isFalse);
    expect(PendingSign.wordOf('SENA_PENDIENTE:FOLIO_REAL'), 'FOLIO REAL');
  });

  test('el avatar no la deletrea: un solo paso con el aviso', () {
    const resolver = AnimationUrlResolver(baseUrl: 'https://x/');
    expect(resolver.resolveAll(gloss: 'SENA_PENDIENTE:HIPOTECA'), [
      '${AnimationUrlResolver.placeholderScheme}SENA_PENDIENTE:HIPOTECA',
    ]);
  });

  test('en el corpus solo quedan deletreadas las siglas', () {
    final corpus = RagCorpus.fromJsonString(
      File('assets/rag/escenarios_cbba.json').readAsStringSync(),
    );
    // Un deletreo solo puede ser siglas o cifras escritas así en la frase
    // (NUREJ, WebID, 2025), una tras otra.
    bool soloSiglas(String letras, String texto) {
      final siglas = [
        for (final w in RegExp(r'[\wÁÉÍÓÚÑáéíóúñ]+').allMatches(texto))
          if (RegExp(r'^\d+$').hasMatch(w[0]!) ||
              w[0]!.replaceAll(RegExp(r'[^A-ZÁÉÍÓÚÑ]'), '').length >= 2)
            w[0]!.toUpperCase(),
      ];
      var resto = letras;
      while (resto.isNotEmpty) {
        final s = siglas.where(resto.startsWith).firstOrNull;
        if (s == null) return false;
        resto = resto.substring(s.length);
      }
      return true;
    }

    final comunes = <String>[];
    var pendientes = 0;
    for (final s in corpus.scenarios) {
      for (final t in [...s.turns, for (final v in s.variants) ...v.replies]) {
        var letras = '';
        for (final g in [...t.glosses, '']) {
          // Una letra suelta es deletreo; una cifra es la seña del número.
          if (RegExp(r'^[A-ZÁÉÍÓÚÑ]$').hasMatch(g)) {
            letras += g;
            continue;
          }
          if (letras.isNotEmpty && !soloSiglas(letras, t.text)) {
            comunes.add('$letras «${t.text}»');
          }
          letras = '';
          if (PendingSign.isPending(g)) pendientes++;
        }
      }
    }
    expect(comunes, isEmpty);
    expect(pendientes, greaterThan(100));
  });

  testWidgets('se pinta con otro color y dice que es una seña a incorporar', (
    tester,
  ) async {
    const azul = Color(0xFF2563EB);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GlossLine(
              glosses: ['YO', 'NECESITAR', 'SENA_PENDIENTE:FOLIO_REAL'],
              style: TextStyle(color: Colors.black),
              pendingColor: azul,
            ),
          ),
        ),
      ),
    );
    final folio = tester.widget<Text>(find.text('FOLIO REAL'));
    expect(folio.style?.color, azul);
    expect(find.textContaining('SENA_PENDIENTE'), findsNothing);
    expect(
      find.text('En azul: seña a incorporar (tóquela para ver qué es)'),
      findsOneWidget,
    );
  });

  group('qué es una palabra sin seña', () {
    final catalog = PendingSignCatalog.fromJsonString(
      File('assets/dictionary/senas_sin_sena.json').readAsStringSync(),
    );

    testWidgets('tocarla abre su descripción LSB en lugar de una seña', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSignCatalogProvider.overrideWith((ref) async => catalog),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: GlossLine(
                glosses: ['YO', 'SENA_PENDIENTE:INMUEBLE', 'TENER'],
                style: TextStyle(color: Colors.black),
                pendingColor: Colors.blue,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('INMUEBLE'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('info_sin_sena')), findsOneWidget);
      expect(
        find.textContaining('No tiene seña propia en los módulos M1–M4'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('descripcion_lsb')), findsOneWidget);
      expect(
        find.text(
          'Casa, departamento o terreno: propiedad que no se puede mover.',
        ),
        findsNothing,
      );
      expect(
        find.text('Descripción provisional, por revisar.'),
        findsOneWidget,
      );
    });

    testWidgets('con el tema oscuro se lee: texto oscuro sobre la hoja '
        'blanca, y la descripción va en LSB', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            backgroundColor: AppTheme.pageBg,
            body: PendingSignInfoSheet(
              infos: [
                PendingSignInfo(
                  word: 'INMUEBLE',
                  description: 'Casa o terreno que no se puede mover.',
                  lsbDescription: [
                    'CASA',
                    'SENA_PENDIENTE:TERRENO',
                    'MOVER',
                    'NO_PUEDO',
                  ],
                  example: '¿Tiene la matrícula del inmueble?',
                ),
              ],
            ),
          ),
        ),
      );
      final lsb = tester.widget<Text>(find.byKey(const Key('descripcion_lsb')));
      expect(lsb.textSpan!.toPlainText(), 'CASA · TERRENO · MOVER · NO PUEDO');
      expect(lsb.style!.color, AppTheme.lightText);
      final spans = <TextSpan>[];
      lsb.textSpan!.visitChildren((s) {
        if (s is TextSpan && s.text == 'TERRENO') spans.add(s);
        return true;
      });
      expect(spans.single.style!.color, AppTheme.pendingSign);
      // El español formal ya no se muestra cuando hay LSB.
      expect(find.text('Casa o terreno que no se puede mover.'), findsNothing);
      // Lo demás de la hoja tampoco queda en blanco sobre blanco.
      final titulo = tester.widget<Text>(find.text('¿Qué es?'));
      expect(titulo.style!.color, AppTheme.lightText);
      // La frase de ejemplo del trámite ya no se muestra: la descripción va
      // directa.
      expect(find.textContaining('matrícula del inmueble'), findsNothing);
      expect(find.text('En el trámite'), findsNothing);
    });

    test('una errata de la traducción remite a su palabra', () {
      expect(
        catalog.infoOf('SENA_PENDIENTE:CATARSTRAL').description,
        catalog.infoOf('SENA_PENDIENTE:CATASTRAL').description,
      );
      expect(catalog.infoOf('SENA_PENDIENTE:ANTEZANA').isProperName, isTrue);
    });

    test('sin descripción, al menos su nombre', () {
      final info = catalog.infoOf('SENA_PENDIENTE:PALABRA_NUEVA');
      expect(info.word, 'PALABRA NUEVA');
      expect(info.description, isEmpty);
    });

    Future<List<SignPreviewPlan>> deslizar(
      WidgetTester tester,
      List<String> glosas,
    ) async {
      final planes = <SignPreviewPlan>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSignCatalogProvider.overrideWith((ref) async => catalog),
            signPreviewPlayerProvider.overrideWithValue((_, plan, _) {
              if (plan.glosses.isNotEmpty) planes.add(plan);
              return const SizedBox.shrink();
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  // Lo que hace la fila al deslizarse más allá del umbral.
                  onPressed: () => ref
                      .read(signPreviewControllerProvider)
                      .show(context, glosas),
                  child: const Text('deslizar'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('deslizar'));
      await tester.pumpAndSettle();
      return planes;
    }

    testWidgets('deslizar una glosa sin seña propia explica qué es', (
      tester,
    ) async {
      final planes = await deslizar(tester, ['SENA_PENDIENTE:HIPOTECA']);
      expect(planes, isEmpty, reason: 'no se inventa una seña');
      expect(find.byKey(const Key('info_sin_sena')), findsOneWidget);
      expect(find.text('HIPOTECA'), findsOneWidget);
    });

    testWidgets('deslizar una glosa con seña la hace en el avatar', (
      tester,
    ) async {
      final planes = await deslizar(tester, ['ROBAR']);
      expect(planes.single.glosses, ['ROBAR']);
      expect(find.byKey(const Key('info_sin_sena')), findsNothing);
    });

    test('toda palabra sin seña del corpus tiene descripción en LSB', () {
      final corpus = RagCorpus.fromJsonString(
        File('assets/rag/escenarios_cbba.json').readAsStringSync(),
      );
      final sinDescripcion = <String>{};
      final sinDescripcionLsb = <String>{};
      for (final s in corpus.scenarios) {
        for (final t in [
          ...s.turns,
          for (final v in s.variants) ...v.replies,
        ]) {
          for (final g in t.glosses.where(PendingSign.isPending)) {
            final info = catalog.infoOf(g);
            if (info.description.isEmpty) sinDescripcion.add(g);
            if (info.lsbDescription.isEmpty) sinDescripcionLsb.add(g);
          }
        }
      }
      expect(sinDescripcion, isEmpty);
      expect(sinDescripcionLsb, isEmpty);
    });

    test('ninguna descripción tiene palabras en azul: va directa en señas', () {
      final datos =
          jsonDecode(
                File(
                  'assets/dictionary/senas_sin_sena.json',
                ).readAsStringSync(),
              )['palabras']
              as Map<String, dynamic>;
      final conAzul = <String>{
        for (final MapEntry(key: palabra, value: v) in datos.entries)
          if ((v['descripcionLsb'] as List).cast<String>().any(
            PendingSign.isPending,
          ))
            palabra,
      };
      expect(conAzul, isEmpty);
    });

    test('una palabra simple con seña no queda en azul', () {
      final corpus = RagCorpus.fromJsonString(
        File('assets/rag/escenarios_cbba.json').readAsStringSync(),
      );
      final azules = <String>{
        for (final s in corpus.scenarios)
          for (final t in [
            ...s.turns,
            for (final v in s.variants) ...v.replies,
          ])
            for (final g in t.glosses.where(PendingSign.isPending))
              PendingSign.wordOf(g),
      };
      for (final simple in [
        'NUMERO',
        'PERSONA',
        'AYUDA',
        'ENTENDER',
        'COMPROBANTE',
        'ATENCION',
        'OTRO',
        'TODAVIA',
      ]) {
        expect(azules, isNot(contains(simple)), reason: simple);
      }
    });

    testWidgets('tocar una palabra en azul de la descripción abre la suya', (
      tester,
    ) async {
      // Hoy ninguna descripción lleva azul; si una volviera a tenerlo, la
      // palabra se sigue pudiendo tocar.
      final catalog = PendingSignCatalog.fromJsonString(
        jsonEncode({
          'palabras': {
            'INMUEBLE': {
              'descripcion': 'Casa o terreno.',
              'descripcionLsb': ['CASA', 'SENA_PENDIENTE:PROPIEDAD'],
            },
            'PROPIEDAD': {
              'descripcion': 'Lo que es suyo.',
              'descripcionLsb': ['SUYO'],
            },
          },
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPendingSignInfo(context, catalog, [
                  'SENA_PENDIENTE:INMUEBLE',
                ]),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('info_sin_sena')), findsOneWidget);
      expect(
        find.text('Toque una palabra en azul para ver qué es.'),
        findsOneWidget,
      );
      await tester.tapOnText(find.textRange.ofSubstring('PROPIEDAD'));
      await tester.pumpAndSettle();
      // Se abre encima: la de INMUEBLE sigue debajo.
      expect(find.byKey(const Key('info_sin_sena')), findsNWidgets(2));
      expect(find.text('PROPIEDAD'), findsOneWidget);
      await tester.tap(find.text('Entendido').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('info_sin_sena')), findsOneWidget);
    });
  });

  testWidgets('la tarjeta del trámite pinta en azul la palabra sin seña', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [signImagesEnabledProvider.overrideWith(_SinImagenes.new)],
        child: MaterialApp(
          home: Scaffold(
            body: GlossRow(
              card: LsbCard(
                id: 'r1',
                gloss: 'SI',
                displayText:
                    'SI · SENA_PENDIENTE:COPIA · SENA_PENDIENTE:ANTERIOR · PERDER',
                iconUrl: '',
                categoryId: '',
                subcategoryId: '',
                contexts: const [],
                priority: 0,
                suggestedNextCardIds: const [],
                isFrequent: false,
                isEmergency: false,
              ),
              onToggle: () async => false,
            ),
          ),
        ),
      ),
    );
    expect(find.text('SI · COPIA · ANTERIOR · PERDER'), findsOneWidget);
    expect(find.textContaining(PendingSign.prefix), findsNothing);
    final spans = <TextSpan>[];
    tester
        .widget<RichText>(
          find
              .descendant(
                of: find.byType(GlossRow),
                matching: find.byType(RichText),
              )
              .first,
        )
        .text
        .visitChildren((s) {
          if (s is TextSpan && s.text != null) spans.add(s);
          return true;
        });
    expect(
      spans.firstWhere((s) => s.text == 'COPIA').style?.color,
      AppTheme.pendingSign,
    );
  });
}
