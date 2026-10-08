import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'helpers/rag_ofrecidas.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn_builder.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/rag_suggestions_provider.dart';

void main() {
  late ConversationGraphCatalog catalog;
  late ConversationGraphRouter router;
  late SemanticTurnBuilder builder;
  late RagRetriever retriever;

  setUpAll(() {
    catalog = ConversationGraphCatalog(
      bank: QuestionBank.generated(),
      graph: DialogueGraph.fromJsonString(
        File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
      ),
    );
    router = ConversationGraphRouter(catalog);
    builder = SemanticTurnBuilder(catalog);
    retriever = RagRetriever(
      RagCorpus.fromJsonString(
        File('assets/rag/escenarios_cbba.json').readAsStringSync(),
      ),
    );
  });

  ({SemanticTurn semantic, ConversationRoute route}) evaluate(String text) {
    final semantic = builder.build(turnId: text, text: text);
    return (semantic: semantic, route: router.routeDeterministic(semantic));
  }

  Set<String> openedQuestions(ConversationRoute route) {
    final out = {...route.targetQuestionIds, ...route.pathQuestionIds};
    if (route.type == ConversationRouteType.directContext &&
        route.targetContextId != null) {
      final first = catalog.bank
          .journey(route.targetContextId!)
          ?.steps
          .firstOrNull
          ?.questionId;
      if (first != null) out.add(first);
    }
    return out;
  }

  Conversation conversationFor(String text, ConversationRoute route) =>
      Conversation(
        id: 'audit',
        startedAt: DateTime(2026, 9, 27),
        turns: [
          ConversationTurn(
            route: route,
            message: SemanticMessage(
              id: 'turno',
              speaker: SpeakerRole.hearing,
              source: MessageSource.text,
              glosses: const [],
              text: text,
            ),
            outputs: GeneratedOutputs(text: text),
          ),
        ],
      );

  group('el grafo conserva la pregunta exacta del oyente', () {
    final cases =
        <
          ({
            String text,
            List<String> slots,
            Set<String> expectedQuestions,
            Set<String> forbiddenQuestions,
          })
        >[
          (
            text: '¿Quién te robó?',
            slots: ['person'],
            expectedQuestions: {'Q.PER.CONOCE'},
            forbiddenQuestions: {'Q.HEC.QUE_OCURRIO'},
          ),
          (
            text: 'Hola, ¿cómo estás? ¿Quién te robó?',
            slots: ['person'],
            expectedQuestions: {'Q.PER.CONOCE'},
            forbiddenQuestions: {'Q.HEC.QUE_OCURRIO'},
          ),
          (
            text: '¿Cuándo te robaron el celular?',
            slots: ['time'],
            expectedQuestions: {'Q.TIE.CUANDO'},
            forbiddenQuestions: {
              'Q.HEC.QUE_OCURRIO',
              'Q.ROB.QUE',
              'Q.LUG.DONDE',
            },
          ),
          (
            text: '¿Dónde te robaron?',
            slots: ['place'],
            expectedQuestions: {'Q.LUG.DONDE'},
            forbiddenQuestions: {'Q.HEC.QUE_OCURRIO', 'Q.TIE.CUANDO'},
          ),
          (
            text: '¿Qué te robaron?',
            slots: ['object'],
            expectedQuestions: {'Q.ROB.QUE'},
            forbiddenQuestions: {'Q.HEC.QUE_OCURRIO'},
          ),
          (
            text: '¿A qué hora y dónde te robaron?',
            slots: ['time', 'place'],
            expectedQuestions: {'Q.TIE.HORA', 'Q.LUG.DONDE'},
            forbiddenQuestions: {'Q.HEC.QUE_OCURRIO', 'Q.ROB.QUE'},
          ),
          (
            text: 'Cuéntame cómo pasó el robo.',
            slots: const [],
            expectedQuestions: {'Q.HEC.QUE_OCURRIO'},
            forbiddenQuestions: {'Q.PER.CONOCE'},
          ),
        ];

    for (final c in cases) {
      test(c.text, () {
        final result = evaluate(c.text);
        expect(result.semantic.requestedSlots, c.slots);
        expect(result.route.targetContextId, 'denuncia_robo');
        final opened = openedQuestions(result.route);
        expect(opened, containsAll(c.expectedQuestions));
        for (final forbidden in c.forbiddenQuestions) {
          expect(opened, isNot(contains(forbidden)));
        }
      });
    }
  });

  test(
    'una ruta determinista segura nunca muestra tarjetas RAG competidoras',
    () {
      for (final text in [
        '¿Quién te robó?',
        'Hola, ¿cómo estás? ¿Quién te robó?',
        '¿Cuándo te robaron el celular?',
        '¿Dónde te robaron?',
        '¿Qué te robaron?',
        '¿A qué hora y dónde te robaron?',
        'Cuéntame cómo pasó el robo.',
        // Coincidencia literal existente en el corpus RAG.
        '¿Qué ocurrió?',
      ]) {
        final result = evaluate(text);
        expect(
          result.route.type,
          isNot(ConversationRouteType.noSafeRoute),
          reason: text,
        );
        expect(
          ragOfrecidas(conversationFor(text, result.route), retriever),
          isEmpty,
          reason: text,
        );
      }
    },
  );

  test('una pregunta segura del grafo siempre pesa más que el RAG', () {
    final route = ConversationRoute(
      type: ConversationRouteType.directQuestion,
      targetContextId: 'denuncia_robo',
      targetQuestionIds: const ['Q.HEC.QUE_OCURRIO'],
      confidence: 1,
    );
    expect(ragOutranksGraph(route, 1), isFalse);
  });

  group('continuidad del contexto', () {
    test('robo conserva LOCATION → TIME', () {
      final first = evaluate('¿Dónde te robaron?');
      expect(first.semantic.requestedSlots, ['place']);
      expect(openedQuestions(first.route), contains('Q.LUG.DONDE'));

      final semantic = builder.build(
        turnId: 'hora',
        text: '¿Y a qué hora?',
        activeContextId: 'denuncia_robo',
      );
      final route = router.routeDeterministic(
        semantic,
        activeContextId: 'denuncia_robo',
      );
      expect(semantic.requestedSlots, ['time']);
      expect(route.targetContextId, 'denuncia_robo');
      expect(openedQuestions(route), contains('Q.TIE.HORA'));
    });

    test('robo conserva PERSON → LOCATION', () {
      final first = evaluate('¿Quién te robó?');
      expect(first.semantic.requestedSlots, ['person']);
      expect(openedQuestions(first.route), contains('Q.PER.CONOCE'));

      final semantic = builder.build(
        turnId: 'lugar',
        text: '¿Dónde pasó?',
        activeContextId: 'denuncia_robo',
      );
      final route = router.routeDeterministic(
        semantic,
        activeContextId: 'denuncia_robo',
      );
      expect(semantic.requestedSlots, ['place']);
      expect(route.targetContextId, 'denuncia_robo');
      expect(openedQuestions(route), contains('Q.LUG.DONDE'));
    });

    test('Fiscalía continúa y una mención explícita cambia a SEGIP', () {
      final first = retriever.areaOf('¿Cómo sigo mi denuncia en Fiscalía?');
      expect(first, 'FIS');
      final followUp = retriever.areaOf('¿Y qué necesito?', preferArea: first);
      expect(followUp, 'FIS');
      final switched = retriever.areaOf(
        'Ahora necesito renovar mi cédula',
        preferArea: followUp,
      );
      expect(switched, 'SEGIP');
    });
  });
}
