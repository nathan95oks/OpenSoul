import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/app/surface_session.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/graph_matcher.dart';
import 'package:lsb_legal_app/core/domain/conversation/polar_question.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/rag_suggestions_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

/// El paso del turno entre los dos participantes.
///
/// Vive fuera del widget porque es la regla del producto, no una decisión de
/// pantalla: quién habla ahora, con qué encargo se abre el módulo de tarjetas
/// y a qué turno queda enlazado lo que se escriba. Tenerlo aquí permite
/// probar el ciclo completo sin montar la interfaz, y que la pantalla se
/// quede solo con la confirmación de descartar un borrador.
class ConversationHandoff {
  final Ref ref;

  const ConversationHandoff(this.ref);

  Conversation get _conversation => ref.read(conversationProvider).conversation;

  /// El encargo que corresponde ahora mismo: responder si hay un turno del
  /// oyente esperando, abrir el turno si no lo hay.
  CardsFlowLaunch nextDeafLaunch() {
    final conversation = _conversation;
    final pending = conversation.pendingReply;

    // El perfil de la institución y la necesidad activa acompañan al
    // encargo para ordenar las opciones. Son señales de prioridad, nunca
    // contenido: el generador no puede escribir el nombre de la institución
    // en la declaración porque venga aquí.
    final perfil = ref.read(activeProfileIdProvider);
    final necesidad = ref.read(activeNeedProvider);

    if (pending == null) {
      return CardsFlowLaunch.initiative(
        conversationId: conversation.id,
        activeContextId: conversation.activeContextId,
        need: necesidad,
        institutionProfileId: perfil,
      );
    }

    final route = replyRouteFor(conversation, pending);

    return CardsFlowLaunch.reply(
      conversationId: conversation.id,
      hearingTurnId: pending.message.id,
      hearingText: pending.outputs.text,
      hearingSpeechAct: pending.message.speechAct,
      suggestion: pending.message.contextSuggestion,
      activeContextId: conversation.activeContextId,
      need: necesidad,
      institutionProfileId: perfil,
      route: route,
    );
  }

  /// Con qué parte del grafo (o del trámite documentado) se responde a
  /// [pending]; `null` si nada lo reconoce.
  ConversationRoute? replyRouteFor(
    Conversation conversation,
    ConversationTurn pending,
  ) {
    // La parte del grafo con la que se responde. Una conversación restaurada
    // no guarda rutas (son derivadas): se recalculan aquí.
    final graphRoute =
        pending.route ??
        routeForTurn(
          ref,
          pending,
          activeContextId: conversation.activeContextId,
        )?.route;
    // Donde el grafo no tiene ruta segura, la pregunta del trámite
    // documentado que se le parece (Trámites, RAG). La consulta por
    // significado se lanzó al llegar el turno: aquí solo se usa si ya volvió.
    final retriever = ref.read(ragRetrieverProvider);
    final router = ref.read(conversationGraphRouterProvider);
    final graphText =
        router?.matcher.textScores(pending.message.text) ?? const {};
    final topic = topicBeforePending(conversation, pending);
    final graphSupportsActiveContext =
        topic != null &&
        router?.catalog.hasContext(topic) == true &&
        graphText.entries.any(
          (entry) =>
              entry.value >= GraphMatcher.weakMatch &&
              (router!.catalog.isStepOf(topic, entry.key) ||
                  router.catalog.journeysOf(entry.key).isEmpty),
        );
    final route = graphRoute == null
        ? null
        : ragTramiteRoute(
                conversation,
                pending,
                graphRoute,
                retriever,
                graphText: graphText,
                graphSupportsActiveContext: graphSupportsActiveContext,
                remote:
                    ref
                        .read(
                          remoteRagSuggestionsProvider(
                            ragRemoteQueryFor(conversation, pending, retriever),
                          ),
                        )
                        .asData
                        ?.value ??
                    const [],
              ) ??
              graphRoute;
    return route;
  }

  /// Si a [pending] se le puede contestar con «Sí», «No» o «No sé» sin pasar
  /// por las tarjetas: es una pregunta de sí o no ([isPolarQuestion]) y el
  /// grafo y el RAG no tienen pregunta propia con sus opciones. Cuando sí la
  /// tienen, esas tarjetas ya ofrecen su sí / no / no sé con la frase
  /// completa, y esta respuesta genérica sobraría.
  bool offersPolarAnswer(Conversation conversation, ConversationTurn pending) {
    if (pending.pending || !isPolarQuestion(pending.message.text)) return false;
    final route = replyRouteFor(conversation, pending);
    return route == null ||
        (!route.opensQuestions && route.targetContextId == null);
  }

  /// Deja en el chat la respuesta [answer] al turno del oyente que espera.
  ///
  /// No abre las tarjetas ni llama a la Lambda: «Sí.», «No.» o «No sé.» con
  /// su seña, y suena con la voz del dispositivo. No cambia el tema de la
  /// conversación (no lleva contexto).
  SubmitOutcome answerPolar(PolarAnswer answer) {
    final conversation = _conversation;
    final pending = conversation.pendingReply;
    if (pending == null) return SubmitOutcome.staleReply;

    final outcome = ref
        .read(conversationProvider.notifier)
        .addDeafDeclaration(
          result: TranslationResult(
            baseSentence: answer.text,
            generatedText: answer.text,
          ),
          glosses: [answer.gloss],
          replyToId: pending.message.id,
          expectedReplyText: pending.message.text,
          conversationId: conversation.id,
        );
    if (outcome == SubmitOutcome.sent) {
      // Un fallo del audio no deshace la respuesta: el turno conserva su
      // botón de escuchar.
      unawaited(
        ref.read(audioOutputProvider).speak(answer.text).catchError((_) {}),
      );
    }
    return outcome;
  }

  /// Abre el módulo de tarjetas con [launch].
  ///
  /// Reabrir el **mismo** encargo continúa donde se dejó: no se toca el
  /// borrador, ni el contexto, ni las zonas. Antes se limpiaba siempre, así
  /// que volver al chat a releer la pregunta y pulsar otra vez «Responder»
  /// borraba en silencio lo que ya se había armado —justo lo que la pantalla
  /// había prometido conservar al no preguntar nada.
  ///
  /// Cambiar de encargo sí reinicia el flujo. La confirmación de descartar la
  /// pide quien llama, porque es una decisión de la persona, no del servicio.
  ///
  /// El contexto propuesto solo se aplica en B y C; en A no se propone
  /// ninguno, porque ahí lo elige la persona sin que el chat opine.
  void openCards(CardsFlowLaunch launch) {
    final anterior = ref.read(cardsFlowLaunchProvider);
    final mismoEncargo = anterior.sameErrand(launch);

    ref.read(cardsFlowLaunchProvider.notifier).start(launch);

    if (!mismoEncargo) {
      // Un encargo nuevo no hereda nada de Tarjetas LSB ni de Voz a LSB: ni
      // la última oración formal, ni un recorrido a medias, ni una voz ya
      // traducida. Se limpia primero, para que lo que se propone a
      // continuación (el contexto y la pregunta recomendada) sea lo único
      // que la persona encuentre.
      ref.read(surfaceSessionProvider).resetStandaloneModules();

      final proposedId = launch.proposedContextId;
      final proposed = proposedId == null ? null : contextById(proposedId);
      final contexts = ref.read(contextProvider.notifier);
      if (proposed != null) {
        contexts.setContext(proposed);
      } else {
        contexts.clearContext();
      }

      ref.read(sentenceProvider.notifier).clearSentence();
      ref.read(semanticZonesProvider.notifier).reset();
      // Con el contexto ya puesto, el recorrido arranca por la pregunta que
      // la ruta recomienda (o por la primera) aunque el contexto sea el
      // mismo de antes y no haya cambiado.
      ref.read(guidedFlowProvider.notifier).reset();
    }

    // El acto comunicativo llega al borrador, que es quien lo manda al
    // backend. `setSpeechAct` existía y no lo llamaba nadie, así que todo
    // salía como afirmación: una consulta se redactaba «Declaro…» aunque
    // fuera una pregunta.
    ref
        .read(declarationDraftProvider.notifier)
        .setSpeechAct(launch.intendedAct.wireName);

    ref.read(selectedTabProvider.notifier).select(AppTabId.cards);
  }

  /// Devuelve el control al oyente: vuelve al chat, donde la pantalla pone el
  /// cursor en su campo de texto. No enciende el micrófono — eso lo pulsa él.
  ///
  /// El lanzamiento no se toca: si la persona sorda vuelve a las tarjetas sin
  /// que el oyente haya escrito nada, sigue siendo el mismo encargo.
  void handBackToHearing() =>
      ref.read(selectedTabProvider.notifier).select(AppTabId.conversation);
}

final conversationHandoffProvider = Provider<ConversationHandoff>(
  ConversationHandoff.new,
);

/// Si ahora mismo se ofrece contestar con «Sí», «No» o «No sé» al último
/// turno del oyente ([ConversationHandoff.offersPolarAnswer]).
///
/// Se recalcula cuando llega la consulta por significado: si el RAG encuentra
/// el trámite de la pregunta, las respuestas genéricas dejan paso a sus
/// tarjetas.
final polarAnswerOfferedProvider = Provider<bool>((ref) {
  final conversation = ref.watch(
    conversationProvider.select((state) => state.conversation),
  );
  final pending = conversation.pendingReply;
  if (pending == null || !isPolarQuestion(pending.message.text)) return false;

  final route = pending.route;
  if (route != null &&
      ragMayAskRemote(route) &&
      ref.watch(remoteRagProvider) != null) {
    final retriever = ref.watch(ragRetrieverProvider);
    ref.watch(
      remoteRagSuggestionsProvider(
        ragRemoteQueryFor(conversation, pending, retriever),
      ),
    );
  }
  return ref
      .read(conversationHandoffProvider)
      .offersPolarAnswer(conversation, pending);
});
