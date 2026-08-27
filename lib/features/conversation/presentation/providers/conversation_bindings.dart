import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/presentation/session/flow_surface.dart';

import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

class _ConversationBridge implements ConversationBridge {
  final Ref ref;

  const _ConversationBridge(this.ref);

  @override
  void submitDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
  }) {
    ref.read(conversationProvider.notifier).addDeafDeclaration(
          result: result,
          glosses: glosses,
          contextId: contextId,
        );
  }
}

List<Override> conversationOverrides() => [
      pendingReplyProvider.overrideWith((ref) {
        if (!ref.watch(flowSurfaceProvider).isConversation) return null;

        final pending = ref.watch(conversationProvider).conversation.pendingReply;
        if (pending == null) return null;
        return ReplyPrompt(
          question: pending.outputs.text,
          suggestion: pending.message.contextSuggestion,
          activeContextId:
              ref.watch(conversationProvider).conversation.activeContextId,
        );
      }),
      conversationBridgeProvider.overrideWith((ref) => _ConversationBridge(ref)),
    ];
