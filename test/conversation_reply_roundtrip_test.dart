import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_handoff.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_emission.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Lo que devolvería la Lambda de Audio/Texto→LSB para cada frase: las glosas
/// y la lectura capturadas de la Lambda real (`casos_semantic_turn.json`).
final Map<String, Map<String, dynamic>> _lambda = {
  for (final c
      in (jsonDecode(
                File('aws/tests/casos_semantic_turn.json').readAsStringSync(),
              )['casos']
              as List)
          .cast<Map<String, dynamic>>())
    c['texto'] as String: c,
};

/// Audio/Texto→LSB de prueba. Cuenta cuántas veces se traduce cada frase:
/// una intervención del oyente se interpreta una sola vez.
class _SignRepo implements AudioTranslationRepository {
  _SignRepo({required this.sendsSemanticTurn});

  final bool sendsSemanticTurn;
  final Map<String, int> calls = {};

  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async {
    calls[text] = (calls[text] ?? 0) + 1;
    final caso = _lambda[text]!;
    return LsbTranslation(
      glosses: List<String>.from(caso['glosas'] as List),
      animationUrl: '',
      semanticTurn: sendsSemanticTurn
          ? BackendSemanticTurn.fromJson(caso['semanticTurn'])
          : null,
    );
  }
}

/// Backend de declaraciones sin cobertura certificada: vale la redacción
/// local del banco, como en producción sin Bedrock.
class _DeclarationRepo implements TranslationRepository {
  int calls = 0;

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
    Map<String, dynamic>? guided,
  }) async {
    calls++;
    return TranslationResult(baseSentence: '', generatedText: '');
  }
}

/// El Bedrock de LSB→Texto/Audio (acción `route`) simulado.
class _RouteModel implements GraphRouteModel {
  _RouteModel(this.answer);

  final ConversationRoute? Function(List<ConversationRoute>) answer;
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _SignRepo signRepo;
  late _DeclarationRepo declarationRepo;

  ProviderContainer app({bool backend = true, GraphRouteModel? model}) {
    signRepo = _SignRepo(sendsSemanticTurn: backend);
    declarationRepo = _DeclarationRepo();
    final graph = DialogueGraph.fromJsonString(
      File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
    );
    final c = ProviderContainer(
      overrides: [
        lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
        audioTranslationRepositoryProvider.overrideWithValue(signRepo),
        translationRepositoryProvider.overrideWithValue(declarationRepo),
        audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        dialogueGraphProvider.overrideWith((ref) async => graph),
        graphRouteModelProvider.overrideWithValue(model),
        ...conversationOverrides(),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<ConversationTurn> oyente(ProviderContainer c, String texto) async {
    await c.read(conversationProvider.notifier).sendHearingMessage(texto);
    // El desempate con el modelo corre aparte del avatar.
    await pumpEventQueue();
    return c
        .read(conversationProvider)
        .conversation
        .turnById(
          c.read(conversationProvider).conversation.lastHearingTurn!.message.id,
        )!;
  }

  CardsFlowLaunch responder(ProviderContainer c) {
    final handoff = c.read(conversationHandoffProvider);
    final launch = handoff.nextDeafLaunch();
    handoff.openCards(launch);
    return launch;
  }

  Future<GuidedEmissionOutcome> emitir(ProviderContainer c) =>
      c.read(guidedEmissionProvider).emit();

  void vueltaAlMismoTurno(
    ProviderContainer c,
    ConversationTurn pregunta, {
    required String conversationId,
  }) {
    expect(c.read(selectedTabProvider), AppTabId.conversation);
    expect(c.read(resultVisibleProvider), isFalse);
    final conversation = c.read(conversationProvider).conversation;
    expect(conversation.id, conversationId);
    final respuesta = conversation.lastTurn!;
    expect(respuesta.message.speaker, SpeakerRole.deaf);
    expect(respuesta.message.replyToId, pregunta.message.id);
  }

  group('una intervención se interpreta una sola vez', () {
    test('1/4. Conversation usa la lectura del backend', () async {
      final c = app();
      final turno = await oyente(c, '¿Dónde ocurrió?');
      expect(turno.semantic!.source, SemanticTurnSource.backend);
      expect(turno.semantic!.requestedSlots, ['place']);
      expect(turno.semantic!.entities, ['DONDE']);
      expect(turno.route!.targetQuestionIds, ['Q.LUG.DONDE']);
    });

    test('3. con un backend antiguo sin lectura, vale el respaldo', () async {
      final c = app(backend: false);
      final turno = await oyente(c, '¿Dónde ocurrió?');
      expect(turno.semantic!.source, SemanticTurnSource.clientFallback);
      expect(turno.route!.targetQuestionIds, ['Q.LUG.DONDE']);
    });

    test('5. responder de punta a punta no vuelve a traducir', () async {
      final c = app();
      await oyente(c, '¿Dónde ocurrió?');
      responder(c);
      c.read(guidedFlowProvider.notifier).select('Q.LUG.DONDE', 'calle');
      // Releer la pregunta y volver a abrir las tarjetas tampoco traduce.
      c.read(conversationHandoffProvider).nextDeafLaunch();
      await emitir(c);

      expect(signRepo.calls, {'¿Dónde ocurrió?': 1});
      expect(declarationRepo.calls, 1, reason: 'Una sola redacción.');
    });

    test('6/7. solo el turno ambiguo pasa por Bedrock', () async {
      final model = _RouteModel(
        (cands) => cands
            .firstWhere((r) => r.targetFamilyId == 'denuncias')
            .copyWith(confidence: 0.8, source: RouteSource.bedrock),
      );
      final c = app(model: model);
      await oyente(c, '¿Dónde ocurrió?');
      await oyente(c, 'Hola, ¿cómo está? ¿Qué viene a realizar?');
      expect(model.calls, 0, reason: 'Lo determinista no gasta el modelo.');

      final ambiguo = await oyente(c, '¿Viene a consultar o a denunciar?');
      expect(model.calls, 1);
      expect(ambiguo.route!.sourceLabel, 'bedrock');
      expect(ambiguo.route!.targetFamilyId, 'denuncias');
    });
  });

  group('de punta a punta', () {
    test('A. motivo → selector → contexto → respuesta → mismo turno', () async {
      final c = app();
      final pregunta = await oyente(
        c,
        'Hola, ¿cómo está? ¿Qué viene a realizar?',
      );
      final conversationId = c.read(conversationProvider).conversation.id;
      final launch = responder(c);
      expect(launch.route!.type, ConversationRouteType.contextSelector);
      expect(c.read(contextProvider), isNull);

      // La persona sorda elige contexto: el recorrido es el de siempre.
      c
          .read(contextProvider.notifier)
          .setContext(contextById('denuncia_robo')!);
      final flow = c.read(guidedFlowProvider.notifier);
      expect(
        c.read(guidedFlowProvider).session!.currentQuestionId,
        'Q.HEC.QUE_OCURRIO',
      );
      expect(flow.select('Q.HEC.QUE_OCURRIO', 'robar').accepted, isTrue);

      final outcome = await emitir(c);
      expect(outcome.status, GuidedEmissionStatus.returnedToConversation);
      vueltaAlMismoTurno(c, pregunta, conversationId: conversationId);
      expect(
        c.read(conversationProvider).conversation.lastTurn!.outputs.text,
        'Me robaron algo.',
      );
    });

    test('B. «¿Quiere denunciar algo?» → Denuncias → respuesta → vuelta, '
        'y el contexto sigue para el siguiente turno', () async {
      final c = app();
      final pregunta = await oyente(c, '¿Quiere denunciar algo?');
      final conversationId = c.read(conversationProvider).conversation.id;
      final launch = responder(c);
      expect(launch.route!.type, ConversationRouteType.directContext);
      expect(launch.focusedFamilyId, 'denuncias');

      c.read(contextProvider.notifier).setContext(contextById('violencia')!);
      c.read(guidedFlowProvider.notifier).select('Q.VIO.TIPO', 'pegar');
      final outcome = await emitir(c);
      expect(outcome.status, GuidedEmissionStatus.returnedToConversation);
      vueltaAlMismoTurno(c, pregunta, conversationId: conversationId);
      expect(
        c.read(conversationProvider).conversation.activeContextId,
        'violencia',
      );

      // 11. El siguiente turno se queda en el contexto de la conversación.
      final siguiente = await oyente(c, '¿Dónde ocurrió?');
      expect(siguiente.route!.targetContextId, 'violencia');
      expect(siguiente.route!.targetQuestionIds, ['Q.LUG.DONDE']);

      // 12. Pero un cambio explícito de tema no se bloquea.
      final otro = await oyente(c, '¿Cuál es su nombre completo?');
      expect(otro.route!.targetContextId, 'identificacion');
    });

    test(
      'C. pregunta exacta del banco → solo esa respuesta → vuelta',
      () async {
        final c = app();
        final pregunta = await oyente(c, '¿Dónde ocurrió?');
        final conversationId = c.read(conversationProvider).conversation.id;
        responder(c);

        final session = c.read(guidedFlowProvider).session!;
        expect([for (final s in session.steps) s.questionId], ['Q.LUG.DONDE']);
        c.read(guidedFlowProvider.notifier).select('Q.LUG.DONDE', 'calle');

        await emitir(c);
        vueltaAlMismoTurno(c, pregunta, conversationId: conversationId);
        expect(
          c.read(conversationProvider).conversation.lastTurn!.outputs.text,
          'Ocurrió en la calle.',
        );
      },
    );

    test(
      'D. dos datos → recorrido mínimo → una sola respuesta → vuelta',
      () async {
        final c = app();
        final pregunta = await oyente(c, '¿A qué hora y dónde ocurrió?');
        final conversationId = c.read(conversationProvider).conversation.id;
        responder(c);

        final session = c.read(guidedFlowProvider).session!;
        expect(
          [for (final s in session.steps) s.questionId],
          ['Q.TIE.HORA', 'Q.LUG.DONDE'],
        );
        final flow = c.read(guidedFlowProvider.notifier);
        flow.select('Q.TIE.HORA', 'tarde');
        flow.goNext();
        flow.select('Q.LUG.DONDE', 'calle');

        await emitir(c);
        vueltaAlMismoTurno(c, pregunta, conversationId: conversationId);
        final turnos = c.read(conversationProvider).conversation.turns;
        expect(turnos, hasLength(2), reason: 'Una pregunta, una respuesta.');
        expect(
          turnos.last.outputs.text,
          'Ocurrió en la calle. Fue por la tarde.',
        );
      },
    );

    test('E. ambiguo → Bedrock elige entre candidatas reales', () async {
      final model = _RouteModel(
        (cands) => cands
            .firstWhere((r) => r.targetContextId == 'seguimiento')
            .copyWith(confidence: 0.85, source: RouteSource.bedrock),
      );
      final c = app(model: model);
      await oyente(c, '¿Viene a consultar o a denunciar?');
      final launch = responder(c);
      expect(launch.route!.sourceLabel, 'bedrock');
      expect(c.read(contextProvider)?.id, 'seguimiento');
    });

    test(
      'F. confianza baja → NO_SAFE_ROUTE: selector, nada inventado',
      () async {
        final model = _RouteModel(
          (cands) => cands
              .firstWhere((r) => r.opensQuestions)
              .copyWith(confidence: 0.3, source: RouteSource.bedrock),
        );
        final c = app(model: model);
        final turno = await oyente(c, '¿Y a esa persona la vio bien?');
        expect(model.calls, 1);
        expect(turno.route!.type, ConversationRouteType.noSafeRoute);
        responder(c);
        expect(c.read(contextProvider), isNull);
      },
    );

    test('G. ruta inválida de Bedrock → rechazada', () async {
      final model = _RouteModel(
        (_) => const ConversationRoute(
          type: ConversationRouteType.directQuestion,
          targetContextId: 'denuncia_robo',
          targetQuestionIds: ['Q.INVENTADA'],
          confidence: 0.99,
          source: RouteSource.bedrock,
        ),
      );
      final c = app(model: model);
      final turno = await oyente(c, '¿Y a esa persona la vio bien?');
      expect(turno.route!.type, ConversationRouteType.noSafeRoute);
      expect(turno.route!.targetQuestionIds, isEmpty);
    });

    test('H. conversación reiniciada mientras responde: no se envía', () async {
      final c = app();
      await oyente(c, '¿Dónde ocurrió?');
      responder(c);
      c.read(guidedFlowProvider.notifier).select('Q.LUG.DONDE', 'calle');

      c.read(conversationProvider.notifier).startNew();
      final outcome = await emitir(c);

      expect(outcome.status, GuidedEmissionStatus.staleConversation);
      expect(c.read(conversationProvider).conversation.turns, isEmpty);
      expect(c.read(resultVisibleProvider), isTrue);
    });

    test(
      '14. si entra otro turno, la respuesta va al que se tenía delante',
      () async {
        final c = app();
        final primera = await oyente(c, '¿Dónde ocurrió?');
        responder(c);
        c.read(guidedFlowProvider.notifier).select('Q.LUG.DONDE', 'calle');

        await oyente(c, '¿Cuándo ocurrió?');
        await emitir(c);

        final respuesta = c.read(conversationProvider).conversation.lastTurn!;
        expect(respuesta.message.speaker, SpeakerRole.deaf);
        expect(respuesta.message.replyToId, primera.message.id);
      },
    );
  });

  group('fuera de Conversation nada cambia', () {
    test(
      '16. LSB→Texto/Audio abierto por su cuenta se queda en su resultado',
      () async {
        final c = app();
        c
            .read(cardsFlowLaunchProvider.notifier)
            .start(const CardsFlowLaunch.standalone());
        c
            .read(contextProvider.notifier)
            .setContext(contextById('denuncia_robo')!);

        final session = c.read(guidedFlowProvider).session!;
        expect(
          session.steps.length,
          c.read(questionBankProvider).journey('denuncia_robo')!.steps.length,
        );
        c
            .read(guidedFlowProvider.notifier)
            .select('Q.HEC.QUE_OCURRIO', 'robar');

        final outcome = await emitir(c);
        expect(outcome.status, GuidedEmissionStatus.shownResult);
        expect(c.read(resultVisibleProvider), isTrue);
        expect(c.read(conversationProvider).conversation.turns, isEmpty);
      },
    );
  });
}
