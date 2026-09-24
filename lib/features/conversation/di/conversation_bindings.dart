import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';

import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

class _ConversationBridge implements ConversationBridge {
  final Ref ref;

  const _ConversationBridge(this.ref);

  @override
  SubmitOutcome submitDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
    String? replyToId,
    String? conversationId,
  }) {
    return ref.read(conversationProvider.notifier).addDeafDeclaration(
          result: result,
          glosses: glosses,
          contextId: contextId,
          replyToId: replyToId,
          conversationId: conversationId,
        );
  }
}

List<Override> conversationOverrides() => [
      // La pregunta a la que se responde sale del lanzamiento, no del último
      // turno del chat. Así el modo A no hereda la charla guardada, el modo B
      // no finge responder a nadie, y en el modo C la frase y el turno quedan
      // fijos aunque entre otro mensaje mientras se está respondiendo.
      pendingReplyProvider.overrideWith((ref) {
        final launch = ref.watch(cardsFlowLaunchProvider);
        if (!launch.purpose.linksToHearingTurn) return null;

        final turnId = launch.hearingTurnId;
        final conversationId = launch.conversationId;
        if (turnId == null || conversationId == null) return null;

        return ReplyPrompt(
          turnId: turnId,
          conversationId: conversationId,
          question: launch.hearingText ?? '',
          speechAct: launch.hearingSpeechAct,
          suggestion: launch.suggestion,
          activeContextId: launch.activeContextId,
        );
      }),
      conversationBridgeProvider.overrideWith((ref) => _ConversationBridge(ref)),
    ];
