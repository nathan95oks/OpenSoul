import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';

/// Lo que LSB→Texto/Audio devuelve a Conversation al terminar una respuesta.
///
/// La ida es el [CardsFlowLaunch] con propósito de conversación (su
/// `conversationId`, `hearingTurnId` y la ruta); esto es la vuelta. Enlaza la
/// respuesta con el mismo hilo y el mismo turno del oyente que se tenía
/// delante al abrir.
class ConversationReplyResult {
  final String? conversationId;

  /// El turno del oyente al que responde; `null` si la persona sorda abrió
  /// el turno ella misma.
  final String? replyToTurnId;

  /// Texto congelado del turno al abrir las tarjetas. Permite rechazar una
  /// entrega si una restauración reemplazó el turno conservando su id.
  final String? replyToTurnText;
  final String? contextId;

  /// Los hechos confirmados con las tarjetas (respuestas del banco).
  final GuidedIntervention? intervention;
  final List<String> glosses;

  /// Español generado y audio (Polly o, si no llegó, la voz local).
  final TranslationResult result;

  const ConversationReplyResult({
    required this.conversationId,
    required this.replyToTurnId,
    this.replyToTurnText,
    required this.contextId,
    required this.result,
    this.intervention,
    this.glosses = const [],
  });

  String get spanishText => result.generatedText;

  String? get audioRef => result.audioUrl;

  List<GuidedAnswer> get selectedFacts =>
      intervention?.answers ?? const <GuidedAnswer>[];
}

extension ConversationReplySubmission on ConversationBridge {
  /// Deja [reply] en el hilo al que pertenece.
  SubmitOutcome submitReply(ConversationReplyResult reply) => submitDeclaration(
    result: reply.result,
    glosses: reply.glosses,
    contextId: reply.contextId,
    replyToId: reply.replyToTurnId,
    expectedReplyText: reply.replyToTurnText,
    conversationId: reply.conversationId,
  );
}
