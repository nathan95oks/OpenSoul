import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';

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
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.processing) return;

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

    try {
      final turn = await engine.translateHearingTurn(
        draft,
        activeContextId: conversation.activeContextId,
      );
      state = ConversationState(
        conversation: state.conversation.replaceTurn(turn),
      );
    } catch (_) {
      state = ConversationState(
        conversation:
            state.conversation.replaceTurn(draft.copyWith(pending: false)),
        error: 'No se pudo traducir el mensaje a señas. '
            'Revisa tu conexión e intenta de nuevo.',
      );
    }
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
    String? conversationId,
  }) {
    final conversation = state.conversation;
    if (conversationId != null && conversationId != conversation.id) {
      return SubmitOutcome.staleReply;
    }
    if (replyToId != null && !conversation.hasTurn(replyToId)) {
      return SubmitOutcome.staleReply;
    }

    final turn = ref.read(conversationEngineProvider).turnFromDeclaration(
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

final conversationProvider =
    NotifierProvider<ConversationNotifier, ConversationState>(
  ConversationNotifier.new,
);
