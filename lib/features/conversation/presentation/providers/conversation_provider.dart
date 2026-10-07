import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/conversation/presentation/providers/rag_suggestions_provider.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/domain/services/input_validator.dart';

class ConversationState {
  final Conversation conversation;
  final bool processing;
  final String? error;

  const ConversationState({
    required this.conversation,
    this.processing = false,
    this.error,
  });
}

class ConversationNotifier extends Notifier<ConversationState> {
  @override
  ConversationState build() =>
      ConversationState(conversation: Conversation.start());

  Future<void> sendHearingMessage(
    String text, {
    MessageSource source = MessageSource.text,
  }) async {
    final trimmed = InputValidator.clean(text);
    if (trimmed.isEmpty || state.processing) return;
    // El mismo control de calidad que Voz a LSB: un texto sin sentido, solo
    // símbolos o en otro idioma no entra en la conversación ni se traduce.
    final problema = InputValidator.validate(trimmed);
    if (problema != null) {
      state = ConversationState(
        conversation: state.conversation,
        error: problema.message,
      );
      return;
    }

    final engine = ref.read(conversationEngineProvider);
    final conversation = state.conversation;
    final draft = engine.draftHearingTurn(
      text: trimmed,
      source: source,
      replyToId: conversation.lastTurn?.message.id,
    );

    state = ConversationState(
      conversation: conversation.addTurn(draft),
      processing: true,
    );

    final activeContextId = conversation.topicContextId;
    try {
      final translated = await engine.translateHearingTurn(
        draft,
        activeContextId: activeContextId,
      );
      final turn = await _withRoute(translated, activeContextId);
      state = ConversationState(
        conversation: state.conversation.replaceTurn(turn),
      );
      _anticiparTramite(turn);
      if (turn.route?.needsModel ?? false) {
        unawaited(_refineRoute(turn, activeContextId));
      }
    } catch (_) {
      state = ConversationState(
        conversation: state.conversation.replaceTurn(
          draft.copyWith(pending: false, failed: true),
        ),
        error:
            'No se pudo traducir el mensaje a señas. '
            'Revisa tu conexión e intenta de nuevo.',
      );
    }
  }

  /// Lee el turno ya traducido contra el grafo y decide con qué parte de
  /// LSB→Texto/Audio se responde. Usa lo que devolvió Audio/Texto→LSB: no
  /// hay otra traducción. Sin catálogo (aún cargando) el turno queda sin
  /// ruta y las tarjetas se abren como siempre.
  Future<ConversationTurn> _withRoute(
    ConversationTurn turn,
    String? activeContextId,
  ) async {
    try {
      await ref.read(conversationGraphCatalogProvider.future);
    } catch (_) {
      return turn;
    }
    final routed = routeForTurn(ref, turn, activeContextId: activeContextId);
    return routed ?? turn;
  }

  /// Si el grafo no tiene ruta segura y la búsqueda por palabras no encuentra
  /// un trámite, se pregunta ya a la Lambda por significado: cuando la
  /// persona sorda toque «Responder con tarjetas LSB» la respuesta estará.
  void _anticiparTramite(ConversationTurn turn) {
    final route = turn.route;
    if (route == null || !ragMayAskRemote(route)) return;
    if (ref.read(remoteRagProvider) == null) return;
    final retriever = ref.read(ragRetrieverProvider);
    final conversation = state.conversation;
    if (ragTramiteRoute(conversation, turn, route, retriever) != null) return;
    unawaited(
      ref
          .read(
            remoteRagSuggestionsProvider(
              ragRemoteQueryFor(conversation, turn, retriever),
            ).future,
          )
          .then((_) {}, onError: (_) {}),
    );
  }

  /// Desempate con el modelo cuando el determinista dejó varias rutas
  /// reales. Corre aparte: el avatar no espera por él.
  Future<void> _refineRoute(
    ConversationTurn turn,
    String? activeContextId,
  ) async {
    final router = ref.read(conversationGraphRouterProvider);
    final semantic = turn.semantic;
    if (router == null || semantic == null) return;
    final route = await router.route(
      semantic,
      activeContextId: activeContextId,
      suggestion: turn.message.contextSuggestion,
    );
    final current = state.conversation.turnById(turn.message.id);
    if (current == null) return;
    state = ConversationState(
      conversation: state.conversation.replaceTurn(
        current.copyWith(route: route),
      ),
      processing: state.processing,
      error: state.error,
    );
  }

  /// Añade el turno de la persona sorda enlazado a [replyToId].
  ///
  /// El enlace llega desde fuera —lo congela el lanzamiento del módulo de
  /// tarjetas— en vez de calcularse aquí mirando el último turno. Calcularlo
  /// al enviar hacía que una respuesta escrita durante la edición se colgara
  /// de la pregunta equivocada, y que un turno de apertura de la persona sorda
  /// se enlazara a lo que hubiera quedado de la charla anterior.
  ///
  /// Si [replyToId] ya no existe en el chat (historial reiniciado, sesión
  /// restaurada, otro chat) no se inventa un enlace ni se envía a ciegas:
  /// se devuelve [SubmitOutcome.staleReply] y quien llama decide.
  SubmitOutcome addDeafDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
    String? replyToId,
    String? expectedReplyText,
    String? conversationId,
  }) {
    final conversation = state.conversation;
    if (conversationId != null && conversationId != conversation.id) {
      return SubmitOutcome.staleReply;
    }
    if (replyToId != null) {
      final original = conversation.turnById(replyToId);
      if (original == null ||
          original.message.speaker != SpeakerRole.hearing ||
          (expectedReplyText != null &&
              original.message.text != expectedReplyText)) {
        return SubmitOutcome.staleReply;
      }
    }

    final turn = ref
        .read(conversationEngineProvider)
        .turnFromDeclaration(
          result: result,
          glosses: glosses,
          contextId: contextId,
          replyToId: replyToId,
        );
    state = ConversationState(conversation: conversation.addTurn(turn));
    return SubmitOutcome.sent;
  }

  void startNew() =>
      state = ConversationState(conversation: Conversation.start());

  /// Repone una conversación recuperada del almacenamiento.
  ///
  /// Es distinto de [startNew]: no crea una charla, continúa la que quedó a
  /// medias cuando el sistema cerró la aplicación.
  void replaceConversation(Conversation conversation) =>
      state = ConversationState(conversation: conversation);
}

/// El turno con su [SemanticTurn] y su ruta determinista, o `null` si el
/// router aún no está disponible.
///
/// La lectura preferida es la que Audio/Texto→LSB entregó con la traducción
/// (ya está en el turno). Solo si no llegó —backend anterior al contrato— se
/// arma con el respaldo del cliente, sin traducir de nuevo.
ConversationTurn? routeForTurn(
  Ref ref,
  ConversationTurn turn, {
  String? activeContextId,
}) {
  final router = ref.read(conversationGraphRouterProvider);
  if (router == null) return null;
  var semantic = turn.semantic;
  if (semantic == null) {
    final builder = ref.read(semanticTurnBuilderProvider);
    if (builder == null) return null;
    semantic = builder.build(
      turnId: turn.message.id,
      text: turn.message.text,
      glosses: turn.message.glosses,
      speechAct: turn.message.speechAct,
      disambiguations: turn.message.disambiguations,
      activeContextId: activeContextId,
    );
  }
  developer.log(
    'turn=${turn.message.id} semanticTurnSource=${semantic.source.name}',
    name: 'conversation.semantics',
  );
  return turn.copyWith(
    semantic: semantic,
    route: router.routeDeterministic(
      semantic,
      activeContextId: activeContextId,
      suggestion: turn.message.contextSuggestion,
    ),
  );
}

final conversationProvider =
    NotifierProvider<ConversationNotifier, ConversationState>(
      ConversationNotifier.new,
    );
