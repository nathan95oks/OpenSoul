import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_handoff.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_emission.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Glosas y lectura de la Lambda real para las frases capturadas; una frase
/// nueva llega sin lectura, como con un backend que no la reconoce.
final Map<String, Map<String, dynamic>> _lambda = {
  for (final c
      in (jsonDecode(
                File('aws/tests/casos_semantic_turn.json').readAsStringSync(),
              )['casos']
              as List)
          .cast<Map<String, dynamic>>())
    c['texto'] as String: c,
};

class _SignRepo implements AudioTranslationRepository {
  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async {
    final caso = _lambda[text];
    return LsbTranslation(
      glosses: caso == null
          ? const ['CERTIFICADO', 'NECESITAR']
          : List<String>.from(caso['glosas'] as List),
      animationUrl: '',
      semanticTurn: caso == null
          ? null
          : BackendSemanticTurn.fromJson(caso['semanticTurn']),
    );
  }
}

/// Sin cobertura certificada: vale la redacción local, la frase documentada.
class _DeclarationRepo implements TranslationRepository {
  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
    Map<String, dynamic>? guided,
  }) async => TranslationResult(baseSentence: '', generatedText: '');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const matrimonio = '¿Necesita un duplicado del certificado de matrimonio?';
  const pregunta = 'R.ESC-SERECI-02.1';

  ProviderContainer app() {
    final corpus = RagCorpus.fromJsonString(
      File('assets/rag/escenarios_cbba.json').readAsStringSync(),
    );
    final graph = DialogueGraph.fromJsonString(
      File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
    );
    final c = ProviderContainer(
      overrides: [
        lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
        audioTranslationRepositoryProvider.overrideWithValue(_SignRepo()),
        translationRepositoryProvider.overrideWithValue(_DeclarationRepo()),
        audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        dialogueGraphProvider.overrideWith((ref) async => graph),
        graphRouteModelProvider.overrideWithValue(null),
        ragCorpusProvider.overrideWith((ref) async => corpus),
        remoteRagProvider.overrideWithValue(null),
        ...conversationOverrides(),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> oyente(ProviderContainer c, String texto) async {
    await c.read(ragCorpusProvider.future);
    await c.read(conversationProvider.notifier).sendHearingMessage(texto);
    await pumpEventQueue();
  }

  group('Trámites en el módulo de tarjetas', () {
    final tramites = contextFamilies.firstWhere((f) => f.id == 'tramites');

    test('se abre como Denuncias: una lista con los trámites', () {
      final lista = contextsOfFamily(tramites).map((c) => c.id).toList();
      expect(lista.first, 'identificacion');
      expect(lista, contains('tramite_sereci_02'));
      expect(lista.length, greaterThan(1));
    });

    test('el grafo sigue enrutando con la misma familia', () {
      expect(tramites.contextIds, ['identificacion']);
    });

    test('cada paso: la pregunta en LSB y las respuestas documentadas', () {
      final q = RagTramites.bankWithTramites().question(pregunta)!;
      expect(q.formulation, '¿Necesita certificado de matrimonio duplicado?');
      expect(q.lsb.glosses, contains('CERTIFICADO'));
      expect(q.lsb.glosses.where(PendingSign.isPending), isNotEmpty);
      expect(
        {for (final o in q.options) o.label: o.glosses},
        containsPair('Sí. Perdimos la copia anterior.', [
          'SÍ',
          'SENA_PENDIENTE:COPIA',
          'SENA_PENDIENTE:ANTERIOR',
          'PERDER',
        ]),
      );
      // Una pregunta de sí o no se contesta con sus frases documentadas,
      // una sola a la vez: no con tarjetas sueltas de todo el escenario.
      expect(q.isMultiple, isFalse);
      // Primero las unidades SÍ, NO y NO SÉ (las documentó el escenario);
      // después las respuestas documentadas que dicen algo más.
      expect(q.isPolar, isTrue);
      expect(q.options.map((o) => '${o.id}:${o.label}:${o.state.wireName}'), [
        'si:Sí:afirmado',
        'no:No:negado',
        'no_se:No sé:desconocido',
        'r1:Sí. Perdimos la copia anterior.:afirmado',
        'r4:No sé cuál certificado.:desconocido',
      ]);
    });

    test('elegir otra respuesta reemplaza la anterior', () {
      final bank = RagTramites.bankWithTramites();
      final rules = GuidedFlow(bank);
      var s = rules.startJourney('tramite_sereci_02');
      s = rules.select(s, pregunta, 'r1').session;
      s = rules.select(s, pregunta, 'no').session;
      expect(s.answers[pregunta]!.optionIds, ['no']);
      expect(GuidedComposer(bank).compose(s.toIntervention()), 'No.');
    });
  });

  group('la pregunta que el grafo no reconoce abre su trámite', () {
    test('responder con tarjetas abre SERECI en esa pregunta', () async {
      final c = app();
      await oyente(c, matrimonio);
      final launch = c.read(conversationHandoffProvider).nextDeafLaunch();
      expect(launch.route?.type, ConversationRouteType.directQuestion);
      expect(launch.route?.targetContextId, 'tramite_sereci_02');
      expect(launch.route?.pathQuestionIds, [pregunta]);

      c.read(conversationHandoffProvider).openCards(launch);
      final session = c.read(guidedFlowProvider).session!;
      expect(session.currentQuestionId, pregunta);

      c.read(guidedFlowProvider.notifier).select(pregunta, 'r1');
      await c.read(guidedEmissionProvider).emit();
      final respuesta = c.read(conversationProvider).conversation.lastTurn!;
      expect(respuesta.message.speaker, SpeakerRole.deaf);
      expect(respuesta.message.text, 'Sí. Perdimos la copia anterior.');
      expect(respuesta.message.replyToId, launch.hearingTurnId);
    });

    test('responder con la unidad NO: lo elegido, el avatar y lo enviado '
        'coinciden', () async {
      final c = app();
      await oyente(c, matrimonio);
      final launch = c.read(conversationHandoffProvider).nextDeafLaunch();
      c.read(conversationHandoffProvider).openCards(launch);
      final rules = c.read(guidedFlowRulesProvider);
      c.read(guidedFlowProvider.notifier).select(pregunta, 'no');
      final inter = c.read(guidedFlowProvider.notifier).intervention!;
      expect(rules.glossesOf(inter), ['NO']);
      expect(c.read(guidedComposerProvider).compose(inter), 'No.');
      await c.read(guidedEmissionProvider).emit();
      final respuesta = c.read(conversationProvider).conversation.lastTurn!;
      expect(respuesta.message.text, 'No.');
      expect(respuesta.message.replyToId, launch.hearingTurnId);
    });

    test('en Derechos Reales, «¿Trajo su cédula?» no abre otra '
        'institución', () async {
      // Auditoría H1: antes abría «Solicitar patrocinio como víctima de
      // delito» (SEPDAVI).
      final c = app();
      await oyente(c, '¿Usted figura como titular del inmueble?');
      await oyente(c, '¿Trajo su cédula de identidad?');
      final launch = c.read(conversationHandoffProvider).nextDeafLaunch();
      expect(launch.route?.targetContextId, isNot('tramite_sepdavi_01'));
      expect(launch.route?.reason ?? '', isNot(contains('SEPDAVI')));
    });

    test('una pregunta negativa no se responde como la afirmativa', () async {
      // Auditoría H2: «¿No trajo su cédula?» abría «¿Tiene su cédula de
      // identidad?», donde «Sí.» significa otra cosa.
      final c = app();
      await oyente(c, '¿No trajo su cédula?');
      final launch = c.read(conversationHandoffProvider).nextDeafLaunch();
      expect(launch.route?.reason ?? '', isNot(startsWith('rag:')));
    });

    test(
      'lo que el grafo reconoce se sigue respondiendo con el grafo',
      () async {
        final c = app();
        await oyente(c, '¿Dónde ocurrió el robo?');
        final launch = c.read(conversationHandoffProvider).nextDeafLaunch();
        expect(launch.route?.targetContextId, 'denuncia_robo');
        expect(launch.route?.targetQuestionIds, ['Q.LUG.DONDE']);
      },
    );
  });
}
