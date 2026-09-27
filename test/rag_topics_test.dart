import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/features/conversation/presentation/widgets/rag_topics_sheet.dart';

/// Caso 2 del RAG: la persona sorda abre la conversación preguntando por un
/// trámite, con frases de situaciones reales documentadas.
void main() {
  final corpus = RagCorpus.fromJsonString(
    File('assets/rag/escenarios_cbba.json').readAsStringSync(),
  );
  final topics = corpus.deafTopics;
  final phrases = [
    for (final t in topics)
      for (final p in t.procedures) ...p.phrases.map((f) => f.text),
  ];

  test('cada institución del corpus ofrece frases para iniciar', () {
    expect(topics.length, greaterThanOrEqualTo(15));
    for (final t in topics) {
      expect(t.procedures, isNotEmpty, reason: t.area);
    }
  });

  test('frases de apertura y preguntas del trámite, con sus glosas', () {
    expect(
      phrases,
      containsAll([
        'Necesito un Folio Real actualizado de mi casa.',
        'Quiero saber cuánto debo de mi moto.',
        '¿Cuánto cuesta la cédula física?',
        'Necesito un intérprete de Lengua de Señas Boliviana.',
      ]),
    );
    for (final t in topics) {
      for (final p in t.procedures) {
        for (final f in p.phrases) {
          expect(f.isOfferableReply, isTrue, reason: f.text);
          expect(RegExp(r'\d').hasMatch(f.text), isFalse, reason: f.text);
        }
      }
    }
    // Sin repetir una frase dentro de la misma institución.
    for (final t in topics) {
      final textos = [
        for (final p in t.procedures) ...p.phrases.map((f) => f.text),
      ];
      expect(textos.toSet(), hasLength(textos.length), reason: t.area);
    }
  });

  test('no se ofrece lo que solo se entiende a mitad del diálogo', () {
    expect(
      phrases,
      isNot(
        anyOf(
          contains('¿Entonces no pago el impuesto?'),
          contains('¿Eso incluye todo el contrato?'),
          contains('¿Después puedo volver hoy?'),
        ),
      ),
    );
  });

  testWidgets('institución → trámite → frase: devuelve la frase con su LSB', (
    tester,
  ) async {
    RagSuggestion? elegida;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  elegida = await RagTopicsSheet.show(context, topics),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Preguntar sobre un trámite'), findsOneWidget);
    final segip = topics.firstWhere((t) => t.area == 'SEGIP');
    final area = find.byKey(const ValueKey('rag_area_SEGIP'));
    await tester.scrollUntilVisible(
      area,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(area);
    await tester.pumpAndSettle();
    await tester.tap(area);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Otras instituciones'), findsOneWidget);
    expect(find.text(segip.institution), findsOneWidget);
    final frase = find.text('¿Cuánto cuesta la cédula física?');
    await tester.ensureVisible(frase);
    await tester.pumpAndSettle();
    await tester.tap(frase);
    await tester.pumpAndSettle();

    expect(elegida?.text, '¿Cuánto cuesta la cédula física?');
    expect(elegida?.glosses, isNotEmpty);
    expect(elegida?.scenarioId, startsWith('ESC-SEGIP-'));
  });
}
