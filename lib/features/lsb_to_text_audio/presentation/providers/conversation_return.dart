import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_reply.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_flow_session.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

/// La vuelta de LSB→Texto/Audio a Conversation.
///
/// Solo actúa si el encargo vino de Conversation
/// ([CardsFlowLaunch.returnToConversation]): entrega la respuesta al mismo
/// hilo y al mismo turno que se tenía delante al abrir, y devuelve la
/// pestaña al chat. Abierto por su cuenta, el módulo no cambia: se queda en
/// su pantalla de resultado.
///
/// El audio se reproduce solo al volver al chat, para seguir la conversación;
/// queda además en el turno para repetirlo con un toque.
class ConversationReturn {
  final Ref ref;

  const ConversationReturn(this.ref);

  /// `null` si el encargo no sirve a Conversation.
  Future<SubmitOutcome?> deliver(
    TranslationResult result, {
    GuidedIntervention? intervention,
  }) async {
    final launch = ref.read(cardsFlowLaunchProvider);
    if (!launch.returnToConversation) return null;

    final reply = ConversationReplyResult(
      conversationId: launch.conversationId,
      replyToTurnId: launch.hearingTurnId,
      replyToTurnText: launch.hearingText,
      contextId: intervention?.journeyId ?? ref.read(contextProvider)?.id,
      intervention: intervention,
      glosses: ref.read(sentenceProvider),
      result: result,
    );
    final outcome = ref.read(conversationBridgeProvider).submitReply(reply);
    if (outcome != SubmitOutcome.sent) return outcome;

    final session = ref.read(cardsFlowSessionProvider);
    ref.read(selectedTabProvider.notifier).select(AppTabId.conversation);
    ref.read(resultVisibleProvider.notifier).hide();
    await session.reset();
    _reproducir(result);
    return outcome;
  }

  /// Suena en Conversación la declaración que se acaba de entregar. Un fallo
  /// del audio no deshace el envío: el turno conserva su botón de reproducir.
  void _reproducir(TranslationResult result) {
    final audio = ref.read(audioOutputProvider);
    final url = result.audioUrl;
    Future<void> hablar() async {
      if (url != null && url.isNotEmpty) {
        try {
          await audio.playUrl(url);
          return;
        } catch (_) {}
      }
      if (result.generatedText.isNotEmpty) {
        await audio.speak(result.generatedText);
      }
    }

    unawaited(hablar().catchError((_) {}));
  }
}

final conversationReturnProvider = Provider<ConversationReturn>(
  ConversationReturn.new,
);
