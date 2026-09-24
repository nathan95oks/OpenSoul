import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/app/surface_session.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/flow_surface.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_handoff.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Los tres modos del módulo LSB → texto/audio, y el ciclo entre ellos.
///
/// El mismo módulo sirve a tres situaciones que antes se confundían: declarar
/// por cuenta propia fuera del chat (A), abrir el turno dentro del chat (B) y
/// responder a un turno concreto del oyente (C). La diferencia no puede
/// deducirse de la pestaña abierta ni de si quedó algo pendiente en la charla
/// anterior: va en el lanzamiento, y es lo que decide qué se muestra y a qué
/// turno queda enlazado lo que se envía.
class _SignRepo implements AudioTranslationRepository {
  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async =>
      LsbTranslation(
        glosses: const ['TU', 'CELULAR', 'ROBAR'],
        animationUrl: '',
        animationUrls: const [],
      );
}

class _DeclarationRepo implements TranslationRepository {
  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
  }) async =>
      TranslationResult(
        baseSentence: cards.join(' '),
        generatedText: cards.join(' '),
      );
}

ProviderContainer _app() {
  final container = ProviderContainer(overrides: [
    lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
    audioTranslationRepositoryProvider.overrideWithValue(_SignRepo()),
    translationRepositoryProvider.overrideWithValue(_DeclarationRepo()),
    audioOutputProvider.overrideWithValue(FakeAudioOutput()),
    ...conversationOverrides(),
  ]);
  addTearDown(container.dispose);
  return container;
}

TranslationResult _result(String text) =>
    TranslationResult(baseSentence: text, generatedText: text);

/// Lo que hace la pantalla de resultado al pulsar "Enviar al chat": toma el
/// enlace del lanzamiento, no del último turno de ahora.
SubmitOutcome _enviarAlChat(
  ProviderContainer c, {
  required String texto,
  List<String> glosas = const ['ROBAR'],
  String? contextId = 'denuncia_robo',
}) {
  final launch = c.read(cardsFlowLaunchProvider);
  return c.read(conversationBridgeProvider).submitDeclaration(
        result: _result(texto),
        glosses: glosas,
        contextId: contextId,
        replyToId: launch.hearingTurnId,
        conversationId: launch.conversationId,
      );
}

void main() {
  group('modo A — declaración independiente', () {
    test('no muestra la frase del oyente aunque haya un chat guardado',
        () async {
      final c = _app();
      await c.read(lexiconEntriesProvider.future);
      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');

      await c.read(surfaceSessionProvider).enter(FlowSurface.standaloneCards);

      expect(c.read(cardsFlowLaunchProvider).purpose,
          CardsFlowPurpose.standaloneIntervention);
      expect(c.read(pendingReplyProvider), isNull,
          reason: 'En A no se responde a nadie: la pregunta del chat no '
              'puede encabezar esta pantalla.');
      expect(c.read(contextProvider), isNull,
          reason: 'El contexto lo elige la persona, no lo hereda del chat.');
      // Y el chat sigue esperando su respuesta, intacto.
      expect(c.read(conversationProvider).conversation.pendingReply, isNotNull);
    });

    test('el resultado de A no se añade al chat por su cuenta', () async {
      final c = _app();
      await c.read(lexiconEntriesProvider.future);
      await c.read(surfaceSessionProvider).enter(FlowSurface.standaloneCards);

      expect(c.read(cardsFlowLaunchProvider).purpose.servesConversation, isFalse,
          reason: 'A no ofrece enviar al chat: no hay turno que servir.');
      expect(c.read(conversationProvider).conversation.turns, isEmpty);
    });
  });

  group('modo B — la persona sorda abre el turno', () {
    test('sin turno oyente el encargo es iniciativa, no respuesta', () {
      final c = _app();
      final handoff = c.read(conversationHandoffProvider);

      final launch = handoff.nextDeafLaunch();
      expect(launch.purpose, CardsFlowPurpose.conversationInitiative);
      expect(launch.hearingTurnId, isNull);

      handoff.openCards(launch);
      expect(c.read(pendingReplyProvider), isNull,
          reason: 'No hay pregunta entrante que desambiguar: nadie preguntó.');
      expect(c.read(selectedTabProvider), AppTabId.cards);
    });

    test('el turno de apertura queda sin enlace y es el primero', () {
      final c = _app();
      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());

      final outcome =
          _enviarAlChat(c, texto: 'Quiero hacer una denuncia.', glosas: const [
        'YO',
        'QUERER',
      ]);

      expect(outcome, SubmitOutcome.sent);
      final turns = c.read(conversationProvider).conversation.turns;
      expect(turns, hasLength(1));
      expect(turns.single.message.speaker, SpeakerRole.deaf);
      expect(turns.single.message.replyToId, isNull);
    });

    test('tras enviar B le toca al oyente', () {
      final c = _app();
      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());
      _enviarAlChat(c, texto: 'Quiero hacer una denuncia.');

      final conversation = c.read(conversationProvider).conversation;
      expect(conversation.lastTurn!.message.speaker, SpeakerRole.deaf,
          reason: 'El botón "Continuar como persona oyente" se muestra '
              'justo cuando el último turno es de la persona sorda.');
      expect(conversation.pendingReply, isNull,
          reason: 'Su propio turno no es una pregunta que responder.');
    });
  });

  group('modo C — respuesta a un turno concreto', () {
    test('encabeza con la frase exacta del oyente', () async {
      final c = _app();
      await c.read(lexiconEntriesProvider.future);
      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');

      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());

      final prompt = c.read(pendingReplyProvider);
      expect(prompt, isNotNull);
      expect(prompt!.question, '¿Le robaron su celular?',
          reason: 'Literal, con su puntuación: no una paráfrasis.');
      expect(prompt.turnId,
          c.read(conversationProvider).conversation.lastHearingTurn!.message.id);
    });

    test('una afirmación del oyente no se convierte en pregunta de sí/no',
        () async {
      final c = _app();
      await c.read(lexiconEntriesProvider.future);
      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('Su denuncia quedó registrada.');

      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());

      final prompt = c.read(pendingReplyProvider)!;
      expect(prompt.speechAct, SpeechAct.statement);
      expect(prompt.invitesPolarAnswer, isFalse);
    });

    test('el enlace es el turno que se tenía delante, no el último de ahora',
        () async {
      final c = _app();
      await c.read(lexiconEntriesProvider.future);
      final notifier = c.read(conversationProvider.notifier);

      await notifier.sendHearingMessage('¿Le robaron su celular?');
      final primeraPregunta =
          c.read(conversationProvider).conversation.lastHearingTurn!.message.id;

      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());

      // El oyente se impacienta y escribe otra cosa mientras ella responde.
      await notifier.sendHearingMessage('¿Y dónde fue?');
      final segundaPregunta =
          c.read(conversationProvider).conversation.lastHearingTurn!.message.id;
      expect(segundaPregunta, isNot(primeraPregunta));

      _enviarAlChat(c, texto: 'Sí, me robaron el celular.');

      final respuesta = c.read(conversationProvider).conversation.turns.last;
      expect(respuesta.message.replyToId, primeraPregunta,
          reason: 'Respondió a lo que estaba leyendo, no a lo que entró '
              'después.');
    });

    test('si el turno respondido desaparece, no se envía a ciegas', () async {
      final c = _app();
      await c.read(lexiconEntriesProvider.future);
      final notifier = c.read(conversationProvider.notifier);
      await notifier.sendHearingMessage('¿Le robaron su celular?');

      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());

      // El chat se reinicia mientras ella arma la respuesta.
      notifier.startNew();

      final outcome = _enviarAlChat(c, texto: 'Sí, me robaron el celular.');
      expect(outcome, SubmitOutcome.staleReply);
      expect(c.read(conversationProvider).conversation.turns, isEmpty,
          reason: 'No se cuelga de otra pregunta ni se inventa un enlace.');
    });
  });

  group('el ciclo completo se repite', () {
    test('B seguido de tres ciclos C mantiene los enlaces', () async {
      final c = _app();
      await c.read(lexiconEntriesProvider.future);
      final notifier = c.read(conversationProvider.notifier);
      final handoff = c.read(conversationHandoffProvider);

      // B: abre la persona sorda.
      handoff.openCards(handoff.nextDeafLaunch());
      expect(handoff.nextDeafLaunch().purpose,
          CardsFlowPurpose.conversationInitiative);
      expect(_enviarAlChat(c, texto: 'Quiero hacer una denuncia.'),
          SubmitOutcome.sent);

      final preguntas = <String>[
        '¿Qué le robaron?',
        '¿Dónde ocurrió?',
        '¿Había testigos?',
      ];
      final esperados = <String>[];

      for (final pregunta in preguntas) {
        // El oyente recupera el turno y escribe.
        handoff.handBackToHearing();
        expect(c.read(selectedTabProvider), AppTabId.conversation);
        await notifier.sendHearingMessage(pregunta);

        // C: la persona sorda responde a ese turno.
        final launch = handoff.nextDeafLaunch();
        expect(launch.purpose, CardsFlowPurpose.conversationReply);
        expect(launch.hearingText, pregunta);
        handoff.openCards(launch);
        expect(c.read(pendingReplyProvider)!.question, pregunta);

        esperados.add(launch.hearingTurnId!);
        expect(_enviarAlChat(c, texto: 'Respuesta a $pregunta'),
            SubmitOutcome.sent);
      }

      final turns = c.read(conversationProvider).conversation.turns;
      // 1 apertura sorda + 3 pares pregunta/respuesta.
      expect(turns, hasLength(7));

      final respuestas = turns
          .where((t) =>
              t.message.speaker == SpeakerRole.deaf &&
              t.message.replyToId != null)
          .map((t) => t.message.replyToId)
          .toList();
      expect(respuestas, esperados);
    });

    test('cambiar de modo no deja residuos del encargo anterior', () async {
      final c = _app();
      await c.read(lexiconEntriesProvider.future);
      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');

      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());
      c.read(sentenceProvider.notifier).setWords(['CELULAR', 'ROBAR']);

      // Se va al módulo autónomo: otro encargo, otra sesión.
      await c.read(surfaceSessionProvider).enter(FlowSurface.standaloneCards);

      expect(c.read(sentenceProvider), isEmpty);
      expect(c.read(pendingReplyProvider), isNull);
      expect(c.read(cardsFlowLaunchProvider).hearingTurnId, isNull);
    });
  });

  group('los turnos no se pisan entre sí', () {
    test('turnos seguidos reciben identificadores distintos', () async {
      final c = _app();
      await c.read(lexiconEntriesProvider.future);
      final notifier = c.read(conversationProvider.notifier);
      final handoff = c.read(conversationHandoffProvider);

      // Alternancia rápida: es donde el reloj en microsegundos empataba y un
      // turno reemplazaba al anterior en vez de añadirse.
      for (var i = 0; i < 6; i++) {
        await notifier.sendHearingMessage('Pregunta $i');
        handoff.openCards(handoff.nextDeafLaunch());
        expect(_enviarAlChat(c, texto: 'Respuesta $i'), SubmitOutcome.sent);
      }

      final turns = c.read(conversationProvider).conversation.turns;
      expect(turns, hasLength(12),
          reason: 'Ningún turno puede desaparecer al llegar el siguiente.');
      final ids = turns.map((t) => t.message.id).toList();
      expect(ids.toSet(), hasLength(ids.length),
          reason: 'Dos turnos con el mismo id hacen que replaceTurn borre la '
              'intervención equivocada.');
      expect(
        turns.map((t) => t.outputs.text).toList(),
        [
          for (var i = 0; i < 6; i++) ...['Pregunta $i', 'Respuesta $i'],
        ],
      );
    });
  });
}
