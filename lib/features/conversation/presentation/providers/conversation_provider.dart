import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/core_providers.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';

/// Estado de la conversación bidireccional activa.
class ConversationState {
  final Conversation conversation;

  /// Hay un turno en generación (voz/texto → señas).
  final bool processing;

  final String? error;

  const ConversationState({
    required this.conversation,
    this.processing = false,
    this.error,
  });
}

/// Orquesta la conversación entre la persona oyente y la persona sorda.
///
/// Toda generación pasa por el [ConversationEngine] del núcleo: aquí solo
/// se mantiene el agregado [Conversation] y el estado de la UI.
class ConversationNotifier extends Notifier<ConversationState> {
  @override
  ConversationState build() =>
      ConversationState(conversation: Conversation.start());

  /// Turno de la persona oyente: voz o texto → glosas + avatar.
  ///
  /// El turno entra en el hilo **antes** de traducirse. El enunciado y el
  /// contexto inferido en local están disponibles de inmediato, así que la
  /// persona sorda puede abrir las tarjetas y empezar a responder mientras el
  /// motor remoto todavía trabaja; las señas se incorporan al mismo turno
  /// cuando llegan. Antes ese ida y vuelta —uno o dos segundos— era tiempo
  /// muerto en el que la conversación no avanzaba.
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
        // El contexto ya declarado en la conversación acota el vocabulario
        // del motor remoto en este turno.
        activeContextId: conversation.activeContextId,
      );
      state = ConversationState(
        conversation: state.conversation.replaceTurn(turn),
      );
    } catch (_) {
      // El turno se queda: lo dicho se dijo, y con el contexto inferido en
      // local la persona sorda todavía puede responderlo. Solo se retira el
      // indicador de que faltan señas por llegar.
      state = ConversationState(
        conversation:
            state.conversation.replaceTurn(draft.copyWith(pending: false)),
        error: 'No se pudo traducir el mensaje a señas. '
            'Revisa tu conexión e intenta de nuevo.',
      );
    }
  }

  /// Turno de la persona sorda, generado por el flujo guiado de tarjetas.
  /// El resultado ya pasó por el motor híbrido; aquí solo se incorpora
  /// como turno semántico de la conversación.
  void addDeafDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
  }) {
    final turn = ref.read(conversationEngineProvider).turnFromDeclaration(
          result: result,
          glosses: glosses,
          contextId: contextId,
          // Queda enlazada con la pregunta que estaba respondiendo.
          replyToId: state.conversation.pendingReply?.message.id,
        );
    state = ConversationState(conversation: state.conversation.addTurn(turn));
  }

  void startNew() =>
      state = ConversationState(conversation: Conversation.start());
}

final conversationProvider =
    NotifierProvider<ConversationNotifier, ConversationState>(
  ConversationNotifier.new,
);
