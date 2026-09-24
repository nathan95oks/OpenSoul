import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

/// El turno del oyente al que se está respondiendo, tal como se le mostró a la
/// persona sorda al abrir el módulo de tarjetas.
///
/// [turnId] es lo que convierte esto en una respuesta trazable: sin él, el
/// enlace se calculaba al enviar mirando el último turno del chat, así que un
/// mensaje que entrara durante la edición se llevaba la respuesta ajena.
class ReplyPrompt {
  final String turnId;
  final String conversationId;
  final String question;
  final SpeechAct speechAct;
  final ContextSuggestion? suggestion;
  final String? activeContextId;

  const ReplyPrompt({
    required this.turnId,
    required this.conversationId,
    required this.question,
    this.speechAct = SpeechAct.statement,
    this.suggestion,
    this.activeContextId,
  });

  String? get proposedContextId => suggestion?.contextId ?? activeContextId;

  /// Si el acto comunicativo entrante admite de suyo una respuesta de sí/no.
  /// Una afirmación o una instrucción no: convertirlas en pregunta cerrada es
  /// poner en boca de la persona sorda algo que nadie le preguntó.
  bool get invitesPolarAnswer => speechAct == SpeechAct.question;
}

/// Qué pasó al intentar dejar la declaración en el chat.
enum SubmitOutcome {
  /// Se añadió como turno nuevo, con el enlace que correspondía.
  sent,

  /// El turno al que respondía ya no existe (chat nuevo, historial reiniciado
  /// o sesión restaurada): no se envía nada y quien llama decide.
  staleReply,

  /// No hay conversación a la que enviar (modo A).
  noConversation,
}

abstract class ConversationBridge {
  /// Deja [result] en el chat.
  ///
  /// [replyToId] viene del lanzamiento, no del estado vivo del chat: es el
  /// turno que la persona sorda tenía delante cuando empezó a responder.
  SubmitOutcome submitDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
    String? replyToId,
    String? conversationId,
  });
}

class NoConversationBridge implements ConversationBridge {
  const NoConversationBridge();

  @override
  SubmitOutcome submitDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
    String? replyToId,
    String? conversationId,
  }) =>
      SubmitOutcome.noConversation;
}
