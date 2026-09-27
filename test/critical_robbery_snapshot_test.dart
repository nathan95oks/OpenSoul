import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn_builder.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

void main() {
  test('instantánea comparable de los casos críticos de robo', () {
    final catalog = ConversationGraphCatalog(
      bank: QuestionBank.generated(),
      graph: DialogueGraph.fromJsonString(
        File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
      ),
    );
    final router = ConversationGraphRouter(catalog);
    final builder = SemanticTurnBuilder(catalog);
    final output = <String, Object?>{};
    for (final text in const [
      '¿Quién te robó?',
      'Hola, ¿cómo estás? ¿Quién te robó?',
      '¿Cuándo te robaron el celular?',
      '¿Dónde te robaron?',
      '¿Qué te robaron?',
      '¿A qué hora y dónde te robaron?',
      'Cuéntame cómo pasó el robo.',
    ]) {
      final semantic = builder.build(turnId: text, text: text);
      final route = router.routeDeterministic(semantic);
      output[text] = {
        'context': route.targetContextId,
        'requestedSlots': semantic.requestedSlots,
        'route': route.type.wireName,
        'questions': <String>{
          ...route.targetQuestionIds,
          ...route.pathQuestionIds,
          if (route.type == ConversationRouteType.directContext &&
              route.targetContextId != null)
            ?catalog.bank
                .journey(route.targetContextId!)
                ?.steps
                .firstOrNull
                ?.questionId,
        }.toList(),
      };
    }
    // ignore: avoid_print
    print('CRITICAL_SNAPSHOT ${jsonEncode(output)}');
  });
}
