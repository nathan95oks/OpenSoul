import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';

/// Frases de cada trámite con las que la persona sorda abre el tema. Ya no
/// tienen botón propio en la conversación, pero clasifican la institución de
/// lo dicho (RagRetriever.rankAreas).
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
}
