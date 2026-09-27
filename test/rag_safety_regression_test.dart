import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn_builder.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';

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

  group('las presuposiciones de una pregunta no se confirman', () {
    for (final c in const [
      ('¿El ladrón escapó en moto?', 'denuncia_robo'),
      ('¿Tu pareja te golpeó ayer?', 'violencia'),
      ('¿Te robaron dos celulares?', 'denuncia_robo'),
    ]) {
      test(c.$1, () {
        final semantic = builder.build(
          turnId: c.$1,
          text: c.$1,
          activeContextId: c.$2,
        );
        final route = router.routeDeterministic(
          semantic,
          activeContextId: c.$2,
        );
        expect(semantic.speechAct, SpeechAct.question);

        final flow = GuidedFlow(catalog.bank);
        final session = flow.startJourney(
          route.targetContextId ?? c.$2,
          purpose: GuidedPurpose.reply,
          requestedQuestionIds: route.presupposedQuestionIds,
          onlySteps: route.pathQuestionIds,
        );
        final composer = GuidedComposer(catalog.bank);
        expect(session.answers, isEmpty);
        expect(composer.confirmedFacts(session.toIntervention()), isEmpty);
        expect(composer.compose(session.toIntervention()), isEmpty);
      });
    }
  });

  group('las negaciones sobreviven a la salida local', () {
    const assembler = LocalSentenceAssembler();
    const cases = <(List<String>, List<String>)>[
      (['NO', 'CONOCER', 'LADRON'], ['no conozco']),
      (['NO', 'VER', 'CARA'], ['no vi', 'cara']),
      (['NO', 'NOCHE'], ['no fue de noche']),
      (['NO', 'CASA'], ['no ocurrió en mi casa']),
      (['NO', 'ROBAR', 'BILLETES'], ['no me robaron', 'dinero']),
    ];

    for (final c in cases) {
      test(c.$1.join(' '), () {
        final output = assembler
            .assemble(contextId: 'denuncia_robo', glosses: c.$1)
            .toLowerCase();
        for (final fragment in c.$2) {
          expect(output, contains(fragment), reason: output);
        }
      });
    }
  });
}
