import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/polar_question.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_handoff.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/conversation/presentation/screens/conversation_screen.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Las preguntas de sí o no («¿Quieres…?», «¿Tienes…?», «¿Puedes…?») que el
/// grafo y el RAG no tienen mapeadas se pueden contestar con «Sí», «No» o
/// «No sé» desde el chat, sin pasar por las tarjetas.

/// Audio/Texto→LSB de prueba: una glosa por palabra. No manda lectura
/// semántica, así que el cliente arma la suya (el respaldo de siempre).
class _SignRepo implements AudioTranslationRepository {
  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async => LsbTranslation(
    glosses: text
        .toUpperCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.isNotEmpty)
        .toList(),
    animationUrl: '',
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('isPolarQuestion', () {
    test('reconoce las preguntas que se contestan con sí o no', () {
      for (final t in [
        '¿Quieres un vaso de agua?',
        '¿Quiere un café?',
        '¿Tienes hijos?',
        '¿Tiene testigos?',
        '¿Puedes leer esto?',
        '¿Puede esperar un momento?',
        '¿Usted vive en Cochabamba?',
        '¿Está cansado?',
        'Y ¿tiene frío?',
        '¿Quiere que le ayude?',
        '¿Hay alguien con usted?',
        'Entiendo. ¿Tiene hijos?',
        '¿Por favor, puede esperar?',
        'tienes hijos?',
      ]) {
        expect(isPolarQuestion(t), isTrue, reason: t);
      }
    });

    test('no toma por polares las preguntas abiertas', () {
      for (final t in [
        '¿Qué le robaron?',
        '¿Cuándo pasó?',
        '¿Dónde fue?',
        '¿Quién le hizo esto?',
        '¿Cómo era?',
        '¿Cuánto dinero fue?',
        '¿Cuál es su nombre?',
        '¿Por qué vino?',
        '¿A qué hora ocurrió?',
        '¿De dónde viene?',
        'Usted vino ayer, ¿a qué hora?',
        '¿Donde fue?',
        '¿Cuantos años tiene?',
      ]) {
        expect(isPolarQuestion(t), isFalse, reason: t);
      }
    });

    test('ni las alternativas, ni lo que no es pregunta', () {
      for (final t in [
        '¿Quiere agua o café?',
        '¿Es hombre o mujer?',
        'Puede pasar.',
        'Tiene que firmar aquí',
        'Tome asiento',
        '',
        // Una pregunta cerrada y otra abierta: un sí o no no contesta la 2.ª.
        '¿Me puede describir a esa persona? ¿Cómo era?',
      ]) {
        expect(isPolarQuestion(t), isFalse, reason: t);
      }
    });
  });

  group('ofrecer y dar la respuesta', () {
    late FakeAudioOutput audio;

    Future<ProviderContainer> app() async {
      audio = FakeAudioOutput();
      final graph = DialogueGraph.fromJsonString(
        File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
      );
      final c = ProviderContainer(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioTranslationRepositoryProvider.overrideWithValue(_SignRepo()),
          audioOutputProvider.overrideWithValue(audio),
          dialogueGraphProvider.overrideWith((ref) async => graph),
          ...conversationOverrides(),
        ],
      );
      addTearDown(c.dispose);
      await c.read(lexiconEntriesProvider.future);
      await c.read(ragCorpusProvider.future);
      return c;
    }

    Future<bool> ofrece(ProviderContainer c, String texto) async {
      await c.read(conversationProvider.notifier).sendHearingMessage(texto);
      await pumpEventQueue();
      return c.read(polarAnswerOfferedProvider);
    }

    test('se ofrece donde el grafo no tiene la pregunta mapeada', () async {
      for (final t in [
        '¿Quieres un vaso de agua?',
        '¿Puedes leer esto?',
        '¿Quiere un café?',
        '¿Puede esperar un momento?',
      ]) {
        final c = await app();
        expect(await ofrece(c, t), isTrue, reason: t);
      }
    });

    test('no se ofrece si la pregunta no es de sí o no', () async {
      final c = await app();
      expect(await ofrece(c, '¿Cuántos años tiene?'), isFalse);
    });

    test('no se ofrece si el grafo tiene sus propias tarjetas', () async {
      // Q.EVI.FACTURA y Q.EVI.CAJA: ya traen su «Sí / No / No sé».
      final c = await app();
      expect(
        await ofrece(c, '¿Tiene la factura o la caja del celular?'),
        isFalse,
      );
      final route = c
          .read(conversationProvider)
          .conversation
          .pendingReply!
          .route!;
      expect(route.opensQuestions, isTrue);
    });

    test('no se ofrece si un trámite documentado (RAG) la responde', () async {
      // Preguntas que un escenario de Trámites documenta con sus tarjetas.
      for (final t in [
        '¿Perdió su cédula de identidad?',
        '¿Tienes hijos?',
        '¿Vive usted en Cochabamba?',
      ]) {
        final c = await app();
        expect(await ofrece(c, t), isFalse, reason: t);
        final conversation = c.read(conversationProvider).conversation;
        final route = c
            .read(conversationHandoffProvider)
            .replyRouteFor(conversation, conversation.pendingReply!);
        expect(route?.opensQuestions, isTrue, reason: t);
      }
    });

    test('no se ofrece mientras el turno del oyente aún se traduce', () async {
      final c = await app();
      final handoff = c.read(conversationHandoffProvider);
      final notifier = c.read(conversationProvider.notifier);
      final borrador = c
          .read(conversationEngineProvider)
          .draftHearingTurn(text: '¿Tienes hijos?');
      notifier.state = ConversationState(
        conversation: Conversation.start().addTurn(borrador),
        processing: true,
      );
      final conversation = c.read(conversationProvider).conversation;
      expect(handoff.offersPolarAnswer(conversation, borrador), isFalse);
    });

    for (final caso in [
      (PolarAnswer.yes, 'Sí.', 'SÍ'),
      (PolarAnswer.no, 'No.', 'NO'),
      (PolarAnswer.unknown, 'No sé.', 'NO_SABER'),
    ]) {
      test('«${caso.$2}» queda como respuesta de la persona sorda', () async {
        final c = await app();
        await c
            .read(conversationProvider.notifier)
            .sendHearingMessage('¿Tienes hijos?');
        await pumpEventQueue();
        final antes = c.read(conversationProvider).conversation;
        final pregunta = antes.pendingReply!;

        final resultado = c
            .read(conversationHandoffProvider)
            .answerPolar(caso.$1);

        expect(resultado, SubmitOutcome.sent);
        final conversation = c.read(conversationProvider).conversation;
        final respuesta = conversation.lastTurn!;
        expect(respuesta.message.speaker, SpeakerRole.deaf);
        expect(respuesta.message.text, caso.$2);
        expect(respuesta.outputs.text, caso.$2);
        expect(respuesta.message.glosses, [caso.$3]);
        expect(respuesta.message.replyToId, pregunta.message.id);
        // Ya no hay nada que responder: el turno quedó contestado.
        expect(conversation.pendingReply, isNull);
        expect(c.read(polarAnswerOfferedProvider), isFalse);
        // Suena con la voz del dispositivo, sin Lambda ni Polly.
        await pumpEventQueue();
        expect(audio.spoken, [caso.$2]);
        expect(audio.played, isEmpty);
      });
    }

    test('no cambia el tema de la conversación', () async {
      final c = await app();
      final notifier = c.read(conversationProvider.notifier);
      await notifier.sendHearingMessage('¿Qué le robaron?');
      await pumpEventQueue();
      final tema = c.read(conversationProvider).conversation.topicContextId;
      expect(tema, isNotNull);

      await notifier.sendHearingMessage('¿Quieres un vaso de agua?');
      await pumpEventQueue();
      c.read(conversationHandoffProvider).answerPolar(PolarAnswer.yes);

      expect(c.read(conversationProvider).conversation.topicContextId, tema);
    });

    test('sin pregunta esperando no se envía nada', () async {
      final c = await app();
      final resultado = c
          .read(conversationHandoffProvider)
          .answerPolar(PolarAnswer.yes);
      expect(resultado, SubmitOutcome.staleReply);
      expect(c.read(conversationProvider).conversation.isEmpty, isTrue);
    });

    test('responder dos veces seguidas no duplica la respuesta', () async {
      final c = await app();
      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Tienes hijos?');
      await pumpEventQueue();
      final handoff = c.read(conversationHandoffProvider);
      expect(handoff.answerPolar(PolarAnswer.yes), SubmitOutcome.sent);
      expect(handoff.answerPolar(PolarAnswer.no), SubmitOutcome.staleReply);
      final turnos = c.read(conversationProvider).conversation.turns;
      expect(
        turnos.where((t) => t.message.speaker == SpeakerRole.deaf),
        hasLength(1),
      );
    });
  });

  group('en la pantalla', () {
    Future<ProviderContainer> abrir(
      WidgetTester tester,
      String pregunta,
    ) async {
      final c = ProviderContainer(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
          ...conversationOverrides(),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(home: ConversationScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      c.read(conversationProvider.notifier).state = ConversationState(
        conversation: Conversation.start().addTurn(
          ConversationTurn(
            message: SemanticMessage(
              id: 'p1',
              speaker: SpeakerRole.hearing,
              source: MessageSource.text,
              text: pregunta,
              glosses: const ['TENER'],
            ),
            outputs: GeneratedOutputs(text: pregunta),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      return c;
    }

    testWidgets('una pregunta de sí o no ofrece Sí, No y No sé', (
      tester,
    ) async {
      await abrir(tester, '¿Tienes hijos?');
      expect(find.byKey(const Key('responder_si')), findsOneWidget);
      expect(find.byKey(const Key('responder_no')), findsOneWidget);
      expect(find.byKey(const Key('responder_no_se')), findsOneWidget);
      // Las tarjetas siguen ahí para quien quiera responder con más detalle.
      expect(find.text('Responder en LSB'), findsOneWidget);
    });

    testWidgets('tocar «No sé» deja la respuesta en el chat', (tester) async {
      final c = await abrir(tester, '¿Tienes hijos?');
      await tester.tap(find.byKey(const Key('responder_no_se')));
      await tester.pump(const Duration(milliseconds: 400));
      final ultimo = c.read(conversationProvider).conversation.lastTurn!;
      expect(ultimo.message.speaker, SpeakerRole.deaf);
      expect(ultimo.message.text, 'No sé.');
      expect(ultimo.message.glosses, ['NO_SABER']);
      // Contestada la pregunta, los botones se van.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('responder_si')), findsNothing);
    });

    testWidgets('una pregunta abierta no ofrece Sí / No', (tester) async {
      await abrir(tester, '¿Cuántos años tiene?');
      expect(find.byKey(const Key('responder_si')), findsNothing);
      expect(find.text('Responder en LSB'), findsOneWidget);
    });
  });
}
