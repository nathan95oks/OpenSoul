import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn_builder.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/rag_suggestions_provider.dart';

/// Lo que el QA de Conversación (2026-10-08) encontró incoherente, con
/// frases reales del funcionario. Ver docs/QA_CONVERSACION_2026-10-08.md.
void main() {
  final catalog = ConversationGraphCatalog(
    bank: QuestionBank.generated(),
    graph: DialogueGraph.fromJsonString(
      File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
    ),
  );
  final router = ConversationGraphRouter(catalog);
  final builder = SemanticTurnBuilder(catalog);

  ConversationRoute route(
    String text,
    List<String> glosses, {
    String? active,
  }) => router.routeDeterministic(
    builder.build(turnId: text, text: text, glosses: glosses),
    activeContextId: active,
  );

  // Como llega de la Lambda Texto→LSB: glosas reales y su lectura.
  ConversationRoute fromBackend(
    String text,
    List<String> glosses, {
    String? active,
  }) => router.routeDeterministic(
    SemanticTurn.fromBackend(
      turnId: text,
      text: text,
      speechAct: SpeechAct.question,
      glosses: glosses,
      backend: const BackendSemanticTurn(
        version: 1,
        intent: SemanticIntent.askInformation,
        confidence: 0.5,
      ),
    ),
    activeContextId: active,
  );

  group('lo que el oyente pregunta, y no otra cosa', () {
    test('una palabra que nadie entendió no se ignora', () {
      // BURLAR no está en ninguna pregunta del banco: «¿Usted es una
      // persona sorda?» no responde a «¿Se burlan de usted…?».
      final r = fromBackend('¿Se burlan de usted por ser sorda?', const [
        'SORDO',
        'BURLAR',
        'TU',
      ]);
      expect(r.targetQuestionIds, isNot(contains('Q.ACC.SORDO')));
    });

    test('una deletreada tampoco («maestro»)', () {
      final r = fromBackend('¿Habló con el maestro?', const [
        'HABLAR', 'M', 'A', 'E', 'S', 'T', 'R', 'O', 'C', 'O', 'N', 'TU', //
      ], active: 'violencia');
      expect(r.targetQuestionIds, isNot(contains('Q.SEG.HABLAR_FISCAL')));
    });

    test('una pregunta abierta no abre una de sí o no', () {
      final r = fromBackend('¿Qué vio exactamente?', const [
        'VER', 'E', 'X', 'A', 'C', 'T', 'A', 'M', 'E', 'N', 'T', 'E', //
        'QUE',
      ], active: 'otro');
      expect(r.targetQuestionIds, isNot(contains('Q.ROB.VIO_LADRON')));
      expect(r.targetQuestionIds, contains('Q.TES.QUE_VIO'));
    });

    test('las variantes del banco son formas reales de la pregunta', () {
      final r = fromBackend('¿Esto ya le pasó antes?', const [
        'A', 'N', 'T', 'E', 'S', 'PASAR', 'Y', 'A', 'TU', //
      ], active: 'violencia');
      expect(r.targetQuestionIds, ['Q.VIO.FRECUENCIA']);
    });
  });

  group('afirmaciones e indicaciones de un trámite', () {
    final retriever = RagRetriever(
      RagCorpus.fromJsonString(
        File('assets/rag/escenarios_cbba.json').readAsStringSync(),
      ),
    );
    ConversationRoute? tramite(String text) {
      final turn = ConversationTurn(
        route: const ConversationRoute.noSafeRoute(reason: 'prueba'),
        message: SemanticMessage(
          id: text,
          speaker: SpeakerRole.hearing,
          source: MessageSource.text,
          glosses: const [],
          text: text,
        ),
        outputs: GeneratedOutputs(text: text),
      );
      return ragTramiteRoute(
        Conversation(id: 'qa', startedAt: DateTime(2026, 10, 8), turns: [turn]),
        turn,
        turn.route!,
        retriever,
      );
    }

    test('una afirmación solo abre una indicación documentada', () {
      final r = tramite(
        'Aquí atendemos robos. Para violencia tiene que ir a la FELCV.',
      );
      expect(r, isNotNull);
      {
        final q = RagTramites.bankWithTramites().question(
          r!.targetQuestionIds.single,
        )!;
        expect(q.isIndication, isTrue, reason: q.formulation);
      }
    });

    test('una pregunta no abre una indicación («Entendido»)', () {
      final r = tramite('¿Fue con violencia?');
      if (r != null) {
        final q = RagTramites.bankWithTramites().question(
          r.targetQuestionIds.single,
        )!;
        expect(q.isIndication, isFalse, reason: q.formulation);
      }
    });
  });

  group('la hora es su propia pregunta', () {
    test('«¿Cuándo y a qué hora pasó?» abre CUÁNDO y HORA', () {
      final r = route('¿Cuándo y a qué hora pasó?', const [
        'CUANDO',
        'HORA',
        'QUE',
        'PASAR',
      ], active: 'denuncia_robo');
      expect(r.targetQuestionIds, containsAll(['Q.TIE.CUANDO', 'Q.TIE.HORA']));
    });

    test('«¿A qué hora fue?» abre solo la hora', () {
      final r = route('¿A qué hora fue?', const [
        'HORA',
        'QUE',
      ], active: 'denuncia_robo');
      expect(r.targetQuestionIds, ['Q.TIE.HORA']);
    });

    test('también en un contexto cuyo recorrido no tiene la hora', () {
      final r = route('¿Cuándo y a qué hora fue?', const [
        'CUANDO',
        'HORA',
        'QUE',
      ], active: 'violencia');
      expect(r.targetContextId, 'violencia');
      expect(r.targetQuestionIds, containsAll(['Q.TIE.CUANDO', 'Q.TIE.HORA']));
    });
  });

  group('apertura de ventanilla', () {
    test('«¿Qué le pasó?» sin caso abierto: la persona elige el motivo', () {
      final r = route('¿Qué le pasó?', const ['QUE', 'PASAR']);
      expect(r.type, ConversationRouteType.contextSelector);
      expect(
        r.confidence,
        greaterThanOrEqualTo(ConversationGraphRouter.askedMotiveConfidence),
      );
    });

    test('«lo que pasó» es una relativa, no pide el relato', () {
      final r = route('¿Usted fue testigo de lo que pasó?', const [
        'TU',
        'TESTIGO',
        'PASAR',
      ]);
      expect(r.reason, isNot(contains('apertura')));
    });

    test('un trámite del RAG no reemplaza al motivo pedido', () {
      final retriever = RagRetriever(
        RagCorpus.fromJsonString(
          File('assets/rag/escenarios_cbba.json').readAsStringSync(),
        ),
      );
      const text = '¿Qué ocurrió?';
      final r = route(text, const ['QUE', 'PASAR']);
      final conversation = Conversation(
        id: 'qa',
        startedAt: DateTime(2026, 10, 8),
        turns: [
          ConversationTurn(
            route: r,
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
      expect(ragSuggestionsFor(conversation, retriever), isEmpty);
    });

    test('un dictado sin puntuación no es una indicación', () {
      final r = route('vino a consultar el estado de su caso', const [
        'VENIR',
        'CONSULTAR',
        'ESTADO',
        'CASO',
      ]);
      expect(r.type, isNot(ConversationRouteType.noSafeRoute));
    });
  });

  group('trámites con indicaciones', () {
    final bank = RagTramites.bankWithTramites();
    final flow = GuidedFlow(bank);

    test('armando el trámite a solas no se contesta «Entendido»', () {
      final s = flow.startJourney('tramite_felcv_201');
      final ids = [for (final p in s.steps) p.questionId];
      expect(ids, isNot(contains('R.ESC-FELCV-201.12')));
      expect(ids, contains('R.ESC-FELCV-201.4'));
    });

    test('si el funcionario dice la indicación, sí se contesta', () {
      final s = flow.startJourney(
        'tramite_felcv_201',
        requestedQuestionIds: const ['R.ESC-FELCV-201.12'],
      );
      expect([
        for (final p in s.steps) p.questionId,
      ], contains('R.ESC-FELCV-201.12'));
    });

    test('SÍ no pone datos que nadie dijo en boca de la persona', () {
      for (final id in ['R.ESC-FELCV-201.4', 'R.ESC-FELCC-202.2']) {
        final si = bank.question(id)!.options.firstWhere((o) => o.id == 'si');
        expect(si.phrase, 'Sí.', reason: id);
      }
    });
  });
}
