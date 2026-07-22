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
  Future<void> sendHearingMessage(
    String text, {
    MessageSource source = MessageSource.text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.processing) return;

    state = ConversationState(
      conversation: state.conversation,
      processing: true,
    );
    try {
      final turn = await ref
          .read(conversationEngineProvider)
          .composeHearingTurn(text: trimmed, source: source);
      state = ConversationState(conversation: state.conversation.addTurn(turn));
    } catch (_) {
      state = ConversationState(
        conversation: state.conversation,
        error:
            'No se pudo traducir el mensaje a señas. Revisa tu conexión e intenta de nuevo.',
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
