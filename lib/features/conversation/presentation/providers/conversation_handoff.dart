import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
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

    if (pending == null) {
      return CardsFlowLaunch.initiative(
        conversationId: conversation.id,
        activeContextId: conversation.activeContextId,
      );
    }

    return CardsFlowLaunch.reply(
      conversationId: conversation.id,
      hearingTurnId: pending.message.id,
      hearingText: pending.outputs.text,
      hearingSpeechAct: pending.message.speechAct,
      suggestion: pending.message.contextSuggestion,
      activeContextId: conversation.activeContextId,
    );
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
    }

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

final conversationHandoffProvider =
    Provider<ConversationHandoff>(ConversationHandoff.new);
