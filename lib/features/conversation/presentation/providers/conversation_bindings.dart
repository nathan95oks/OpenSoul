import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:lsb_legal_app/core/di/core_providers.dart';
import 'package:lsb_legal_app/core/domain/ports/conversation_bridge.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/session/flow_surface.dart';

import 'conversation_provider.dart';

/// Conecta el módulo de conversación a los puertos que el núcleo declara.
///
/// La dirección de la dependencia es deliberada: el módulo de conversación
/// conoce a los de traducción —es quien los integra—, pero ellos no lo
/// conocen a él. Sin estas conexiones, el flujo de tarjetas sigue
/// funcionando por su cuenta; con ellas, se convierte en el turno de una
/// conversación.

/// Implementación real del puente: entrega la declaración al hilo.
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

/// Sobrescrituras que activan la integración. Se aplican en `AppScope`.
List<Override> conversationOverrides() => [
      pendingReplyProvider.overrideWith((ref) {
        // Fuera de la conversación el flujo de tarjetas no le responde a
        // nadie: en la pestaña autónoma es una herramienta suelta. Heredar
        // allí la pregunta del oyente enrutaría el recorrido —y mostraría la
        // franja «respondiendo a…»— por una conversación que el usuario dejó
        // atrás.
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
