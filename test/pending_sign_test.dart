import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/features/conversation/presentation/widgets/gloss_line.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/semantic_node.dart';

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
      const MaterialApp(
        home: Scaffold(
          body: GlossLine(
            glosses: ['YO', 'NECESITAR', 'SENA_PENDIENTE:FOLIO_REAL'],
            style: TextStyle(color: Colors.black),
            pendingColor: azul,
          ),
        ),
      ),
    );
    final linea = tester.widget<RichText>(find.byType(RichText).first);
    final spans = <TextSpan>[];
    linea.text.visitChildren((s) {
      if (s is TextSpan && s.text != null) spans.add(s);
      return true;
    });
    final folio = spans.firstWhere((s) => s.text == 'FOLIO REAL');
    expect(folio.style?.color, azul);
    expect(spans.any((s) => s.text!.contains('SENA_PENDIENTE')), isFalse);
    expect(find.text('En azul: seña a incorporar'), findsOneWidget);
  });

  testWidgets('la tarjeta del trámite pinta en azul la palabra sin seña', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [signImagesEnabledProvider.overrideWith(_SinImagenes.new)],
        child: MaterialApp(
          home: Scaffold(
            body: SemanticNode(
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
              onTap: () {},
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
                of: find.byType(SemanticNode),
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
