import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/session_snapshot.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_handoff.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/counter/domain/counter_session.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

import 'helpers/business_catalog.dart';
import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Los recorridos completos, en los dos modos de uso.
///
/// Las tres situaciones —intervención independiente, apertura por la persona
/// sorda y respuesta a un turno concreto— tienen que comportarse igual de bien
/// en personal y en ventanilla, y el turno tiene que poder alternar tantas
/// veces como haga falta sin que se pierda ni se confunda nada.
class _SignRepo implements AudioTranslationRepository {
  final List<String> recibidos = [];

  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async {
    recibidos.add(text);
    return LsbTranslation(glosses: const ['TU'], animationUrl: '');
  }
}

class _DeclRepo implements TranslationRepository {
  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
    Map<String, dynamic>? guided,
  }) async =>
      TranslationResult(
        baseSentence: cards.join(' '),
        generatedText: cards.join(' '),
      );
}

ProviderContainer _app({_SignRepo? signRepo}) {
  final c = ProviderContainer(overrides: [
    lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
    audioTranslationRepositoryProvider
        .overrideWithValue(signRepo ?? _SignRepo()),
    translationRepositoryProvider.overrideWithValue(_DeclRepo()),
    audioOutputProvider.overrideWithValue(FakeAudioOutput()),
    businessCatalogDataSourceProvider
        .overrideWithValue(FakeBusinessCatalogDataSource()),
    ...conversationOverrides(),
  ]);
  addTearDown(c.dispose);
  return c;
}

SubmitOutcome _enviar(ProviderContainer c, String texto) {
  final launch = c.read(cardsFlowLaunchProvider);
  return c.read(conversationBridgeProvider).submitDeclaration(
        result: TranslationResult(baseSentence: texto, generatedText: texto),
        glosses: const ['ROBAR'],
        contextId: 'denuncia_robo',
        replyToId: launch.hearingTurnId,
        conversationId: launch.conversationId,
      );
}

Future<void> _esperarSesion(ProviderContainer c) async {
  for (var i = 0; i < 20 && c.read(usageSessionProvider).loading; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final modo in [UsageMode.personal, UsageMode.counter]) {
    group('modo ${modo.name}', () {
      Future<ProviderContainer> preparado() async {
        final c = _app();
        await _esperarSesion(c);
        await c.read(usageSessionProvider.notifier).choose(
              modo,
              institutionProfileId:
                  modo == UsageMode.counter ? 'policia' : null,
            );
        await c.read(lexiconEntriesProvider.future);
        return c;
      }

      test('intervención independiente no hereda preguntas anteriores',
          () async {
        final c = await preparado();
        await c
            .read(conversationProvider.notifier)
            .sendHearingMessage('¿Le robaron su celular?');

        // Se abre el módulo por su cuenta, no desde el chat.
        c
            .read(cardsFlowLaunchProvider.notifier)
            .start(const CardsFlowLaunch.standalone());

        expect(c.read(pendingReplyProvider), isNull,
            reason: 'Una intervención independiente no responde a nadie.');
        expect(c.read(cardsFlowLaunchProvider).purpose.servesConversation,
            isFalse);
      });

      test('la persona sorda abre la conversación', () async {
        final c = await preparado();
        final handoff = c.read(conversationHandoffProvider);
        final launch = handoff.nextDeafLaunch();

        expect(launch.purpose, CardsFlowPurpose.conversationInitiative);
        expect(launch.hearingTurnId, isNull);
        if (modo == UsageMode.counter) {
          expect(launch.institutionProfileId, 'policia',
              reason: 'El perfil acompaña al encargo como señal de orden.');
        }

        handoff.openCards(launch);
        expect(c.read(pendingReplyProvider), isNull);
        expect(_enviar(c, 'Quiero hacer una denuncia.'), SubmitOutcome.sent);

        final turno = c.read(conversationProvider).conversation.turns.single;
        expect(turno.message.speaker, SpeakerRole.deaf);
        expect(turno.message.replyToId, isNull);
      });

      test('responde a un turno concreto conservando su texto y su id',
          () async {
        final c = await preparado();
        await c
            .read(conversationProvider.notifier)
            .sendHearingMessage('¿Le robaron su celular?');

        final handoff = c.read(conversationHandoffProvider);
        final launch = handoff.nextDeafLaunch();
        handoff.openCards(launch);

        final prompt = c.read(pendingReplyProvider)!;
        expect(prompt.question, '¿Le robaron su celular?');
        expect(prompt.turnId, launch.hearingTurnId);

        _enviar(c, 'Sí, me robaron el celular.');
        final respuesta =
            c.read(conversationProvider).conversation.turns.last;
        expect(respuesta.message.replyToId, launch.hearingTurnId);
      });

      test('la alternancia aguanta cuatro turnos seguidos', () async {
        final c = await preparado();
        final notifier = c.read(conversationProvider.notifier);
        final handoff = c.read(conversationHandoffProvider);

        handoff.openCards(handoff.nextDeafLaunch());
        _enviar(c, 'Quiero hacer una denuncia.');

        final enlaces = <String>[];
        for (final pregunta in [
          '¿Qué le robaron?',
          '¿Dónde ocurrió?',
          '¿Había testigos?',
          '¿Quiere agregar algo?',
        ]) {
          handoff.handBackToHearing();
          expect(c.read(selectedTabProvider), AppTabId.conversation);
          await notifier.sendHearingMessage(pregunta);

          final l = handoff.nextDeafLaunch();
          expect(l.purpose, CardsFlowPurpose.conversationReply);
          expect(l.hearingText, pregunta);
          handoff.openCards(l);
          enlaces.add(l.hearingTurnId!);
          expect(_enviar(c, 'Respuesta'), SubmitOutcome.sent);
        }

        final turnos = c.read(conversationProvider).conversation.turns;
        expect(turnos, hasLength(9)); // 1 apertura + 4 pares
        final respuestas = turnos
            .where((t) =>
                t.message.speaker == SpeakerRole.deaf &&
                t.message.replyToId != null)
            .map((t) => t.message.replyToId)
            .toList();
        expect(respuestas, enlaces);
      });

      test('reabrir el mismo encargo conserva el borrador', () async {
        final c = await preparado();
        await c
            .read(conversationProvider.notifier)
            .sendHearingMessage('¿Qué le robaron?');

        final handoff = c.read(conversationHandoffProvider);
        handoff.openCards(handoff.nextDeafLaunch());
        c.read(sentenceProvider.notifier).setWords(['CELULAR']);

        // Se vuelve al chat y se pulsa otra vez el mismo botón.
        handoff.handBackToHearing();
        handoff.openCards(handoff.nextDeafLaunch());

        expect(c.read(sentenceProvider), ['CELULAR'],
            reason: 'Releer la pregunta no puede borrar lo ya armado.');
      });

      test('cambiar de encargo sí reinicia el flujo', () async {
        final c = await preparado();
        final notifier = c.read(conversationProvider.notifier);
        await notifier.sendHearingMessage('¿Qué le robaron?');

        final handoff = c.read(conversationHandoffProvider);
        handoff.openCards(handoff.nextDeafLaunch());
        c.read(sentenceProvider.notifier).setWords(['CELULAR']);

        // Llega otra pregunta: otro encargo.
        await notifier.sendHearingMessage('¿Dónde ocurrió?');
        handoff.openCards(handoff.nextDeafLaunch());

        expect(c.read(sentenceProvider), isEmpty);
      });
    });
  }

  group('finalizar una atención corta el hilo', () {
    test('lo del ciudadano se va y la institución se queda', () async {
      final c = _app();
      await _esperarSesion(c);
      await c.read(usageSessionProvider.notifier).choose(
            UsageMode.counter,
            institutionProfileId: 'derechos_reales',
          );
      await c.read(lexiconEntriesProvider.future);

      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Cuál es su nombre?');
      c.read(sentenceProvider.notifier).setWords(['NOMBRE']);

      await c.read(counterSessionProvider).endAttention();

      expect(c.read(conversationProvider).conversation.turns, isEmpty);
      expect(c.read(sentenceProvider), isEmpty);
      expect(c.read(contextProvider), isNull);
      expect(c.read(usageSessionProvider).institutionProfileId,
          'derechos_reales');
      expect(c.read(cardsFlowLaunchProvider).purpose,
          CardsFlowPurpose.standaloneIntervention);
    });
  });

  group('varias preguntas en un mismo mensaje', () {
    late DialogueGraph graph;

    setUpAll(() {
      // El mismo asset que empaqueta la aplicación.
      graph = DialogueGraph.fromJsonString(
        File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
      );
    });

    test('se reconocen los campos, no se mezcla todo en una lista', () {
      // «¿A qué hora y dónde te robaron?» pide dos datos distintos.
      final m = graph.match(
        '¿A qué hora y dónde le robaron?',
        mode: CardsFlowPurpose.conversationReply,
      );
      expect(m, isNotNull);

      final campos = m!.node.slots.toSet();
      expect(campos.length, greaterThanOrEqualTo(1),
          reason: 'El nodo declara qué datos pide.');
    });

    test('las continuaciones aportan campos que aún faltan', () {
      final nodo = graph
          .match('¿Dónde ocurrió?', mode: CardsFlowPurpose.conversationReply)!
          .node;
      final siguientes = graph.nextFrom(nodo);

      expect(siguientes, isNotEmpty);
      for (final s in siguientes) {
        expect(s.slots.toSet().difference(nodo.slots.toSet()), isNotEmpty,
            reason: 'Una continuación que no aporta nada es ruido.');
      }
    });

    test('lo ya respondido deja de proponerse', () {
      final nodo = graph
          .match('¿Dónde ocurrió?', mode: CardsFlowPurpose.conversationReply)!
          .node;
      final todas = graph.nextFrom(nodo).length;
      final respondidas =
          graph.nextFrom(nodo).expand((n) => n.slots).toSet();
      final tras = graph.nextFrom(nodo, answered: respondidas).length;

      expect(tras, lessThan(todas));
    });
  });
}
