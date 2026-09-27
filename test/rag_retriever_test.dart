import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/rag_suggestions_provider.dart';
import 'package:lsb_legal_app/features/conversation/presentation/widgets/rag_suggestions_bar.dart';

void main() {
  final corpus = RagCorpus.fromJsonString(
    File('assets/rag/escenarios_cbba.json').readAsStringSync(),
  );
  final retriever = RagRetriever(corpus);

  group('recupera la situación documentada', () {
    test('cada pregunta del funcionario encuentra su propio escenario', () {
      final fallas = <String>[];
      for (final s in corpus.scenarios) {
        for (final t in s.turns) {
          if (t.speaker != RagSpeaker.official) continue;
          final next = s.turn(t.n + 1);
          final hasReply =
              (next != null && next.isOfferableReply) ||
              s.variants.any(
                (v) =>
                    v.turn == t.n && v.replies.any((r) => r.isOfferableReply),
              );
          if (!hasReply) continue;
          final found = retriever.suggest(t.text, limit: 12);
          // Otra situación con la misma pregunta literal empata: vale igual.
          if (found.isEmpty || found.first.score < 0.99) {
            fallas.add('${s.id} turno ${t.n}: «${t.text}»');
          }
        }
      }
      expect(fallas, isEmpty, reason: fallas.join('\n'));
    });

    test('las otras formas de preguntar también encuentran respuestas', () {
      final fallas = <String>[];
      for (final s in corpus.scenarios) {
        for (final v in s.variants) {
          if (!v.replies.any((r) => r.isOfferableReply)) continue;
          for (final q in v.questions) {
            if (retriever.suggest(q).isEmpty) fallas.add('${s.id}: «$q»');
          }
        }
      }
      expect(fallas, isEmpty, reason: fallas.join('\n'));
    });

    test('las preguntas de ventanilla de las capturas encuentran su trámite', () {
      const casos = {
        '¿Trae el número de Matrícula de la casa o el Folio Real antiguo?':
            'DDRR',
        'Por favor, dígame el número de la placa del vehículo.': 'IMP',
        '¿Usted está en peligro ahorita? ¿El agresor está afuera o en su casa?':
            'FELCV',
        '¿Tiene el número de NUREJ o el nombre completo del denunciante?': 'OJ',
        '¿Qué número de Juzgado de Familia es y cuál es el apellido del '
                'demandado?':
            'OJ',
        '¿Usted es el denunciado o acusado en el caso?': 'SEPDEP',
        '¿Traen el contrato impreso, sus carnets vigentes y están presentes '
                'el dueño y el inquilino?':
            'NOT',
      };
      casos.forEach((texto, area) {
        final found = retriever.suggest(texto);
        expect(found, isNotEmpty, reason: texto);
        expect(found.first.scenarioId, startsWith('ESC-$area-'), reason: texto);
      });
    });

    test('lo que no se parece a ninguna situación no sugiere nada', () {
      for (final texto in [
        '¿Le gusta el fútbol?',
        'Buenos días',
        'Vamos a llenar su ficha',
        '',
      ]) {
        expect(retriever.suggest(texto), isEmpty, reason: texto);
      }
    });
  });

  group('lo dicho de verdad en ventanilla', () {
    const nurej = '¿Tiene el número de NUREJ y el WebID?';

    test('un saludo antes de la pregunta no la diluye', () {
      final sola = retriever.suggest(nurej);
      final saludo = retriever.suggest(
        'Buenos días señor, bienvenido a la oficina. $nurej',
      );
      expect(saludo.first.scenarioId, sola.first.scenarioId);
      expect(saludo.first.score, sola.first.score);
    });

    test('dos preguntas en un mensaje: respuestas para cada una', () {
      final found = retriever.suggest(
        '¿Ya tiene abogado particular? ¿Y trajo su cédula de identidad?',
        limit: 12,
      );
      final areas = {for (final s in found) s.scenarioId.split('-')[1]};
      expect(areas, contains('SEPDEP'));
      expect(areas.length, greaterThan(1), reason: '$areas');
    });

    test('una pregunta genérica sigue el trámite del que se habla', () {
      final found = retriever.suggest(
        '¿Trae también su cédula de identidad?',
        preferArea: 'DDRR',
      );
      expect(found.first.scenarioId, startsWith('ESC-DDRR-'));
    });

    test('el tema no se impone a una coincidencia claramente mejor', () {
      final found = retriever.suggest(nurej, preferArea: 'DDRR');
      expect(found.first.scenarioId, startsWith('ESC-OJ-'));
    });
  });

  test('solo se ofrecen tarjetas aprobadas, con glosas y sin datos de '
      'ejemplo', () {
    for (final s in corpus.scenarios) {
      for (final t in s.turns.where((t) => t.speaker == RagSpeaker.official)) {
        for (final r in retriever.suggest(t.text, limit: 12)) {
          expect(r.glosses, isNotEmpty, reason: r.text);
          expect(RegExp(r'\d').hasMatch(r.text), isFalse, reason: r.text);
          expect(r.text, isNot(contains('[VERIFICAR]')));
        }
      }
    }
  });

  group('solo se consulta cuando el grafo no reconoce la pregunta', () {
    Conversation withHearing(
      String text, {
      ConversationRoute? route,
      bool pending = false,
    }) => Conversation(
      id: 'c',
      startedAt: DateTime(2026, 9, 27),
      turns: [
        ConversationTurn(
          pending: pending,
          route: route,
          message: SemanticMessage(
            id: 't1',
            speaker: SpeakerRole.hearing,
            source: MessageSource.text,
            glosses: const [],
            text: text,
          ),
          outputs: GeneratedOutputs(text: text),
        ),
      ],
    );

    const pregunta = '¿Usted es el denunciado o acusado en el caso?';

    test('sin ruta segura: situaciones parecidas', () {
      final found = ragSuggestionsFor(
        withHearing(pregunta, route: const ConversationRoute.noSafeRoute()),
        retriever,
      );
      expect(found.map((s) => s.text), contains('Soy denunciado.'));
    });

    test('el grafo solo reconoció el tema: el RAG entra', () {
      // «denunciado» nombra Denuncias y el grafo abre ese contexto, pero la
      // pregunta es de SEPDEP.
      final found = ragSuggestionsFor(
        withHearing(
          pregunta,
          route: const ConversationRoute(
            type: ConversationRouteType.directContext,
            targetFamilyId: 'denuncias',
            confidence: 0.75,
          ),
        ),
        retriever,
      );
      expect(found.map((s) => s.text), contains('Soy denunciado.'));
    });

    test('el grafo eligió una pregunta con seguridad: manda el grafo', () {
      // Parecido alto pero no literal (0.84) contra un grafo seguro.
      const nurej = '¿Tiene el número de NUREJ y el WebID?';
      ConversationRoute graph(double confidence) => ConversationRoute(
        type: ConversationRouteType.directQuestion,
        targetContextId: 'seguimiento',
        targetQuestionIds: const ['Q.SEG.NUM_REFERENCIA'],
        confidence: confidence,
      );
      expect(
        ragSuggestionsFor(withHearing(nurej, route: graph(0.95)), retriever),
        isEmpty,
      );
      // Con un grafo que dudaba, el RAG se ofrece junto a sus tarjetas.
      expect(
        ragSuggestionsFor(withHearing(nurej, route: graph(0.6)), retriever),
        isNotEmpty,
      );
    });

    test('el chat recuerda de qué trámite venía hablando el funcionario', () {
      final conversation = Conversation(
        id: 'c',
        startedAt: DateTime(2026, 9, 27),
        turns: [
          for (final (id, text) in [
            ('t0', '¿Trae el número de matrícula o el Folio Real antiguo?'),
            ('t1', '¿Trae también su cédula de identidad?'),
          ])
            ConversationTurn(
              route: const ConversationRoute.noSafeRoute(),
              message: SemanticMessage(
                id: id,
                speaker: SpeakerRole.hearing,
                source: MessageSource.text,
                glosses: const [],
                text: text,
              ),
              outputs: GeneratedOutputs(text: text),
            ),
        ],
      );
      final found = ragSuggestionsFor(conversation, retriever);
      expect(found.first.scenarioId, startsWith('ESC-DDRR-'));
    });

    test('mientras se traduce, sin ruta todavía o sin corpus: nada', () {
      expect(
        ragSuggestionsFor(
          withHearing(
            pregunta,
            route: const ConversationRoute.noSafeRoute(),
            pending: true,
          ),
          retriever,
        ),
        isEmpty,
      );
      expect(ragSuggestionsFor(withHearing(pregunta), retriever), isEmpty);
      expect(
        ragSuggestionsFor(
          withHearing(pregunta, route: const ConversationRoute.noSafeRoute()),
          null,
        ),
        isEmpty,
      );
    });
  });

  test('cuándo pesa más el RAG que el grafo', () {
    const noSafe = ConversationRoute.noSafeRoute();
    const topic = ConversationRoute(
      type: ConversationRouteType.contextSelector,
      confidence: 0.6,
    );
    ConversationRoute question(double c) => ConversationRoute(
      type: ConversationRouteType.directQuestion,
      targetContextId: 'denuncia_robo',
      targetQuestionIds: const ['Q.LUG.DONDE'],
      confidence: c,
    );
    // El grafo no sabe: basta un parecido suficiente.
    expect(ragOutranksGraph(noSafe, RagRetriever.minScore), isTrue);
    expect(ragOutranksGraph(noSafe, RagRetriever.minScore - 0.01), isFalse);
    // Solo reconoció el tema: hace falta un parecido bueno.
    expect(ragOutranksGraph(topic, 0.6), isTrue);
    expect(ragOutranksGraph(topic, 0.59), isFalse);
    // Eligió preguntas: casi literal y bastante más seguro que el grafo…
    expect(ragOutranksGraph(question(0.6), 0.8), isTrue);
    expect(ragOutranksGraph(question(0.6), 0.79), isFalse);
    expect(ragOutranksGraph(question(0.9), 0.95), isFalse);
    // …o la pregunta documentada tal cual, aunque el grafo esté seguro.
    expect(ragOutranksGraph(question(1.0), 1.0), isTrue);
  });

  testWidgets('la barra muestra la frase y su LSB, y envía lo elegido', (
    tester,
  ) async {
    final found = retriever.suggest(
      '¿Usted es el denunciado o acusado en el caso?',
    );
    RagSuggestion? elegida;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RagSuggestionsBar(
            suggestions: found,
            onReply: (s) => elegida = s,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final primera = found.first;
    expect(find.textContaining('Situaciones parecidas'), findsOneWidget);
    expect(find.text(primera.text), findsOneWidget);
    expect(find.text(primera.glosses.join(' · ')), findsWidgets);

    await tester.tap(find.text(primera.text));
    expect(elegida?.text, primera.text);
  });
}
