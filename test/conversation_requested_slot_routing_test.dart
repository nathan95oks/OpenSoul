import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn_builder.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

/// Conversation responde LA PREGUNTA del oyente.
///
/// El interrogativo (lo pedido: `requestedSlots`) decide qué dato da la
/// persona sorda; el tema («robar») y las entidades («celular») solo sitúan
/// el contexto. «¿Cuándo te robaron el celular?» lleva a responder CUÁNDO,
/// no a confirmar «me robaron el celular».
class _FakeModel implements GraphRouteModel {
  _FakeModel(this.answer);

  final ConversationRoute? Function(List<ConversationRoute> candidates) answer;
  int calls = 0;

  @override
  Future<ConversationRoute?> rank({
    required SemanticTurn turn,
    required List<ConversationRoute> candidates,
    String? activeContextId,
  }) async {
    calls++;
    return answer(candidates);
  }
}

/// Lecturas capturadas de `build_semantic_turn` (ver
/// `aws/tests/regenerar_casos_semantic_turn.py`).
final Map<String, Map<String, dynamic>> _casos = {
  for (final c
      in (jsonDecode(
                File('aws/tests/casos_semantic_turn.json').readAsStringSync(),
              )['casos']
              as List)
          .cast<Map<String, dynamic>>())
    c['id'] as String: c,
};

SemanticTurn backendTurn(String id) {
  final c = _casos[id]!;
  return SemanticTurn.fromBackend(
    turnId: id,
    text: c['texto'] as String,
    speechAct: classifySpeechAct(c['texto'] as String),
    backend: BackendSemanticTurn.fromJson(c['semanticTurn'])!,
    glosses: List<String>.from(c['glosas'] as List),
  );
}

void main() {
  late ConversationGraphCatalog catalog;
  late ConversationGraphRouter router;
  late SemanticTurnBuilder builder;

  setUpAll(() {
    catalog = ConversationGraphCatalog(
      bank: QuestionBank.generated(),
      graph: DialogueGraph.fromJsonString(
        File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
      ),
    );
    router = ConversationGraphRouter(catalog);
    builder = SemanticTurnBuilder(catalog);
  });

  /// La ruta y la matriz que explica por qué ganó (va en los mensajes de
  /// fallo; nunca en la interfaz).
  (ConversationRoute, String) route(SemanticTurn turn, {String? active}) {
    final trace = router.explain(turn, activeContextId: active);
    return (trace.route, trace.toString());
  }

  /// La invariante que impide volver al bug: cada pregunta abierta responde
  /// a lo pedido, y cada dato pedido lo responde alguna pregunta abierta.
  void answersWhatWasAsked(ConversationRoute r, SemanticTurn turn, String why) {
    if (!r.opensQuestions) return;
    final asked = turn.requestedSlots.toSet();
    for (final q in r.targetQuestionIds) {
      expect(
        catalog.answers(q, asked),
        isTrue,
        reason: '$q no responde $asked\n$why',
      );
    }
    for (final slot in asked) {
      expect(
        r.targetQuestionIds.any(
          (q) => slot == 'polarity'
              ? catalog.isPolarQuestion(q)
              : catalog.answerSlotsOf(q).contains(slot),
        ),
        isTrue,
        reason: 'nadie responde $slot\n$why',
      );
    }
  }

  group('lo pedido manda sobre el tema', () {
    test('1. «¿Cuándo te robaron el celular?» → TIEMPO en el robo', () {
      for (final id in [
        'cuando_te_robaron_celular',
        'cuando_te_robaron_sin_glosa',
      ]) {
        final turn = backendTurn(id);
        expect(turn.requestedSlots, ['time'], reason: id);
        expect(
          [for (final m in turn.mentionedContexts) m.id],
          ['denuncia_robo'],
        );
        expect(turn.mentionedEntities, ['CELULAR']);

        final (r, why) = route(turn);
        expect(r.type, ConversationRouteType.directQuestion, reason: why);
        expect(r.targetContextId, 'denuncia_robo', reason: why);
        expect(r.targetQuestionIds, ['Q.TIE.CUANDO'], reason: why);
        expect(r.pathQuestionIds, ['Q.TIE.CUANDO'], reason: why);
        expect(r.pathQuestionIds, isNot(contains('Q.ROB.CONFIRMA_OBJETO')));
        expect(r.needsModel, isFalse, reason: why);
        answersWhatWasAsked(r, turn, why);
      }
    });

    test('un objeto que el oyente da por supuesto no degrada la ruta', () {
      // MOCHILA aparece en otra pregunta del banco, pero en el robo es una
      // respuesta posible: el oyente la supone, no pregunta por ella.
      final turn = backendTurn('cuando_te_robaron_mochila');
      final (r, why) = route(turn);
      expect(r.targetQuestionIds, ['Q.TIE.CUANDO'], reason: why);
      expect(r.needsModel, isFalse, reason: why);
    });

    test('2. «¿Dónde te robaron el celular?» → LUGAR en el robo', () {
      final turn = backendTurn('donde_te_robaron_celular');
      final (r, why) = route(turn);
      expect(r.type, ConversationRouteType.directQuestion, reason: why);
      expect(r.targetQuestionIds, ['Q.LUG.DONDE'], reason: why);
      expect(r.targetContextId, 'denuncia_robo', reason: why);
      answersWhatWasAsked(r, turn, why);
    });

    test('3. «¿Quién te robó el celular?» no se convierte en el hecho', () {
      // El robo no tiene una pregunta del banco que pida QUIÉN robó (solo
      // «¿Quién escapó?»): se abre el robo, sin inventar la pregunta y sin
      // confirmar ROBAR · CELULAR.
      final turn = backendTurn('quien_te_robo_celular');
      expect(turn.requestedSlots, ['person']);
      final (r, why) = route(turn);
      expect(r.targetQuestionIds, isNot(contains('Q.ROB.CONFIRMA_OBJETO')));
      expect(r.targetQuestionIds, isNot(contains('Q.HEC.ESCAPE_ACTOR')));
      expect(r.type, ConversationRouteType.directContext, reason: why);
      expect(r.targetContextId, 'denuncia_robo', reason: why);
    });

    test('4. «¿Qué te robaron?» → el objeto robado', () {
      final turn = backendTurn('que_te_robaron');
      final (r, why) = route(turn);
      expect(r.targetQuestionIds, ['Q.ROB.QUE'], reason: why);
      expect(r.targetContextId, 'denuncia_robo', reason: why);
    });

    test('5. «¿Te robaron el celular?» sí es la pregunta de sí/no', () {
      final turn = backendTurn('te_robaron_celular');
      expect(turn.requestedSlots, isEmpty);
      final (r, why) = route(turn);
      expect(r.targetQuestionIds, ['Q.ROB.CONFIRMA_OBJETO'], reason: why);
      expect(catalog.isPolarQuestion('Q.ROB.CONFIRMA_OBJETO'), isTrue);
    });

    test('6. «¿Cuándo ocurrió?» con el robo activo → TIEMPO en el robo', () {
      final turn = backendTurn('cuando');
      final (r, why) = route(turn, active: 'denuncia_robo');
      expect(r.type, ConversationRouteType.directQuestion, reason: why);
      expect(r.targetQuestionIds, ['Q.TIE.CUANDO'], reason: why);
      expect(r.targetContextId, 'denuncia_robo', reason: why);
      // El contexto activo sitúa; no convierte la pregunta en otra.
      answersWhatWasAsked(r, turn, why);
    });

    test('7. «¿Cuándo ocurrió?» sin contexto: no se adivina uno', () {
      final turn = backendTurn('cuando');
      final (r, why) = route(turn);
      expect(r.type, ConversationRouteType.contextSelector, reason: why);
      expect(r.targetContextId, isNull, reason: why);
      expect(r.needsModel, isTrue, reason: why);
      expect(
        {for (final c in r.candidates) c.targetContextId},
        containsAll(['denuncia_robo', 'violencia', 'otro']),
        reason: why,
      );
      for (final c in r.candidates.where((c) => c.opensQuestions)) {
        expect(c.targetQuestionIds, ['Q.TIE.CUANDO'], reason: why);
      }
    });

    test('8. «¿Cuándo y dónde…?» → recorrido mínimo TIEMPO + LUGAR', () {
      final turn = backendTurn('cuando_y_donde_robo');
      expect(turn.requestedSlots, ['time', 'place']);
      final (r, why) = route(turn);
      expect(r.type, ConversationRouteType.minimalGraphPath, reason: why);
      expect(r.targetQuestionIds, ['Q.TIE.CUANDO', 'Q.LUG.DONDE'], reason: why);
      expect(r.pathQuestionIds, ['Q.TIE.CUANDO', 'Q.LUG.DONDE'], reason: why);
      expect(r.targetContextId, 'denuncia_robo', reason: why);
      answersWhatWasAsked(r, turn, why);
    });

    test('9. «¿Te robaron el celular y cuándo fue?» → sí/no + TIEMPO', () {
      final turn = backendTurn('robaron_celular_y_cuando');
      expect(turn.requestedSlots, ['time', 'polarity']);
      final (r, why) = route(turn);
      expect(r.type, ConversationRouteType.minimalGraphPath, reason: why);
      expect(r.targetQuestionIds, [
        'Q.ROB.CONFIRMA_OBJETO',
        'Q.TIE.CUANDO',
      ], reason: why);
      expect(
        r.targetQuestionIds,
        contains('Q.TIE.CUANDO'),
        reason: 'TIEMPO no se pierde',
      );
      answersWhatWasAsked(r, turn, why);
    });

    test('equivalentes temporales llegan a una pregunta de TIEMPO', () {
      for (final id in ['a_que_hora_fue', 'cuando']) {
        final turn = backendTurn(id);
        expect(turn.requestedSlots, ['time'], reason: id);
        final (r, why) = route(turn, active: 'denuncia_robo');
        expect(r.type, ConversationRouteType.directQuestion, reason: why);
        expect(
          catalog.answerSlotsOf(r.targetQuestionIds.single),
          contains('time'),
        );
        answersWhatWasAsked(r, turn, why);
      }
      expect(
        route(backendTurn('a_que_hora_fue')).$1.targetQuestionIds,
        ['Q.TIE.HORA'],
        reason: '«¿A qué hora?» es la hora, no la fecha',
      );
    });
  });

  group('respaldo del cliente (backend sin lectura)', () {
    test('las mismas preguntas llegan a lo pedido sin la Lambda', () {
      const esperado = {
        '¿Cuándo te robaron el celular?': ['Q.TIE.CUANDO'],
        '¿cuando te robaron el celular?': ['Q.TIE.CUANDO'],
        '¿Dónde te robaron el celular?': ['Q.LUG.DONDE'],
        '¿Cuándo y dónde te robaron el celular?': [
          'Q.TIE.CUANDO',
          'Q.LUG.DONDE',
        ],
        '¿Te robaron el celular y cuándo fue?': [
          'Q.ROB.CONFIRMA_OBJETO',
          'Q.TIE.CUANDO',
        ],
        '¿Te robaron el celular?': ['Q.ROB.CONFIRMA_OBJETO'],
      };
      for (final e in esperado.entries) {
        final turn = builder.build(turnId: 'f', text: e.key);
        expect(turn.source, SemanticTurnSource.clientFallback);
        final (r, why) = route(turn);
        expect(r.targetQuestionIds, e.value, reason: why);
        expect(r.targetContextId, 'denuncia_robo', reason: why);
        answersWhatWasAsked(r, turn, why);
      }
    });
  });

  group('invariante: la pregunta elegida responde lo pedido', () {
    test('en todos los casos compartidos, con y sin contexto activo', () {
      for (final id in _casos.keys) {
        for (final active in [null, 'denuncia_robo', 'violencia']) {
          final turn = backendTurn(id);
          final (r, why) = route(turn, active: active);
          answersWhatWasAsked(r, turn, why);
          for (final c in r.candidates.where((c) => c.opensQuestions)) {
            for (final q in c.targetQuestionIds) {
              expect(
                catalog.answers(q, turn.requestedSlots),
                isTrue,
                reason: 'candidata $q no responde ${turn.requestedSlots}\n$why',
              );
            }
          }
        }
      }
    });

    test('el modelo no puede cambiar TIEMPO por el hecho', () {
      final turn = backendTurn('cuando');
      final fallback = router.routeDeterministic(turn);
      final chosen = router.acceptModelRoute(
        const ConversationRoute(
          type: ConversationRouteType.directQuestion,
          targetContextId: 'denuncia_robo',
          targetQuestionIds: ['Q.ROB.CONFIRMA_OBJETO'],
          confidence: 0.95,
          source: RouteSource.bedrock,
        ),
        turn: turn,
        fallback: fallback,
      );
      expect(
        chosen.targetQuestionIds,
        isNot(contains('Q.ROB.CONFIRMA_OBJETO')),
      );
      expect(chosen.source, RouteSource.deterministic);
    });
  });

  group('Bedrock solo si quedan varias rutas reales', () {
    test(
      '0 llamadas cuando lo pedido y el contexto dan una sola ruta',
      () async {
        final model = _FakeModel((_) => null);
        final withModel = ConversationGraphRouter(catalog, model: model);
        for (final (id, active) in [
          ('cuando_te_robaron_celular', null),
          ('cuando_te_robaron_sin_glosa', null),
          ('donde_te_robaron_celular', null),
          ('cuando', 'denuncia_robo'),
          ('cuando_y_donde_robo', null),
          ('robaron_celular_y_cuando', null),
        ]) {
          final r = await withModel.route(
            backendTurn(id),
            activeContextId: active,
          );
          expect(r.source, RouteSource.deterministic, reason: id);
        }
        expect(model.calls, 0);
      },
    );

    test(
      'sin contexto, el modelo elige entre las rutas reales de TIEMPO',
      () async {
        final model = _FakeModel(
          (cands) => cands
              .firstWhere((c) => c.targetContextId == 'violencia')
              .copyWith(confidence: 0.8, source: RouteSource.bedrock),
        );
        final r = await ConversationGraphRouter(
          catalog,
          model: model,
        ).route(backendTurn('cuando'));
        expect(model.calls, 1);
        expect(r.source, RouteSource.bedrock);
        expect(r.targetContextId, 'violencia');
        expect(r.targetQuestionIds, ['Q.TIE.CUANDO']);
      },
    );

    test('sin modelo, el caso sin contexto queda en el selector', () async {
      final r = await router.route(backendTurn('cuando'));
      expect(r.type, ConversationRouteType.contextSelector);
      expect(r.targetContextId, isNull);
      expect(r.targetQuestionIds, isEmpty);
    });
  });

  group('lectura del turno', () {
    test('lo pedido, el contexto, las entidades y lo supuesto van aparte', () {
      final trace = router.explain(backendTurn('cuando_te_robaron_celular'));
      final json = trace.toJson();
      expect(json['hearingText'], '¿Cuándo te robaron el celular?');
      expect(json['requestedSlots'], ['time']);
      expect(json['mentionedContexts'], ['denuncia_robo']);
      expect(json['mentionedEntities'], ['CELULAR']);
      expect(json['presupposed'], contains('CELULAR'));
      expect(json['activeContext'], isNull);
      final candidates = json['candidates'] as List;
      expect(candidates, isNotEmpty);
      expect(
        candidates.every((c) => (c as Map)['answersRequest'] == true),
        isTrue,
      );
      expect((json['selectedRoute'] as Map)['questions'], ['Q.TIE.CUANDO']);
      expect(json['source'], 'deterministic');
    });

    test('la ranura de respuesta sale de la formulación del banco', () {
      expect(catalog.answerSlotsOf('Q.TIE.CUANDO'), {'time'});
      expect(catalog.answerSlotsOf('Q.LUG.DONDE'), {'place'});
      expect(catalog.answerSlotsOf('Q.ROB.CONFIRMA_OBJETO'), isEmpty);
      expect(catalog.isPolarQuestion('Q.ROB.CONFIRMA_OBJETO'), isTrue);
      expect(catalog.answers('Q.ROB.CONFIRMA_OBJETO', ['time']), isFalse);
      expect(catalog.answers('Q.TIE.CUANDO', ['time']), isTrue);
      expect(
        catalog.answers('Q.ROB.CONFIRMA_OBJETO', ['time', 'polarity']),
        isTrue,
      );
    });
  });
}
