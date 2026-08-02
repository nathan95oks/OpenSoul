import 'semantic_message.dart';

/// Salidas multimodales generadas para un [SemanticMessage].
///
/// Nacen siempre de la representación semántica, nunca directamente de la
/// entrada cruda. Un turno de la persona sorda produce texto + audio; un
/// turno de la persona oyente produce la secuencia de animaciones del
/// avatar LSB. Los campos no aplicables quedan vacíos/nulos.
class GeneratedOutputs {
  /// Texto final en español (refinado por IA si estuvo disponible).
  final String text;

  /// Oración base del motor semántico local (fiel a las glosas).
  final String baseText;

  /// Audio neuronal remoto (Amazon Polly), si se generó.
  final String? audioUrl;

  /// Animaciones del avatar 3D, en orden de reproducción.
  final List<String> animationUrls;

  /// Glosa que rotula cada animación, alineada con [animationUrls]. Difiere
  /// de las glosas del mensaje cuando hay señas compuestas (varias
  /// animaciones para una sola glosa).
  final List<String> animationGlosses;

  /// Si el texto fue refinado por el modelo fundacional (Bedrock).
  final bool refinedByAi;

  const GeneratedOutputs({
    required this.text,
    this.baseText = '',
    this.audioUrl,
    this.animationUrls = const [],
    this.animationGlosses = const [],
    this.refinedByAi = false,
  });

  bool get hasRemoteAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasAvatar => animationUrls.isNotEmpty;
}

/// Un turno de la conversación: mensaje semántico + salidas generadas.
class ConversationTurn {
  final SemanticMessage message;
  final GeneratedOutputs outputs;

  const ConversationTurn({required this.message, required this.outputs});
}

/// Agregado raíz de la comunicación bidireccional.
///
/// La aplicación no tiene "módulos": tiene una conversación entre una
/// persona sorda y una oyente, compuesta por turnos alternados. Inmutable:
/// cada operación devuelve una nueva instancia (apto para Notifier).
class Conversation {
  final String id;
  final List<ConversationTurn> turns;
  final DateTime startedAt;

  const Conversation({
    required this.id,
    this.turns = const [],
    required this.startedAt,
  });

  factory Conversation.start() => Conversation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        startedAt: DateTime.now(),
      );

  bool get isEmpty => turns.isEmpty;

  ConversationTurn? get lastTurn => turns.isEmpty ? null : turns.last;

  /// Último contexto situacional declarado en la conversación. Permite que
  /// turnos posteriores hereden el contexto sin volver a seleccionarlo.
  String? get activeContextId {
    for (final turn in turns.reversed) {
      final ctx = turn.message.contextId;
      if (ctx != null && ctx.isNotEmpty) return ctx;
    }
    return null;
  }

  /// Último turno de la persona oyente, esté o no respondido.
  ConversationTurn? get lastHearingTurn {
    for (final turn in turns.reversed) {
      if (turn.message.speaker == SpeakerRole.hearing) return turn;
    }
    return null;
  }

  /// Turno del oyente que sigue esperando respuesta, si lo hay.
  ///
  /// Es la pregunta que la persona sorda está a punto de contestar: de ella
  /// salen el contexto sugerido y el enunciado que se le muestra como
  /// referencia mientras construye su respuesta.
  ConversationTurn? get pendingReply {
    final last = lastTurn;
    if (last == null) return null;
    return last.message.speaker == SpeakerRole.hearing ? last : null;
  }

  /// Contexto desde el que conviene abrir el flujo de tarjetas.
  ///
  /// Prioriza lo inferido del enunciado que se está respondiendo —es la
  /// información más fresca— y recurre al último contexto confirmado cuando
  /// no hay inferencia. Nulo si no hay ninguna de las dos cosas.
  String? get suggestedReplyContextId =>
      pendingReply?.message.contextSuggestion?.contextId ?? activeContextId;

  Conversation addTurn(ConversationTurn turn) => Conversation(
        id: id,
        turns: [...turns, turn],
        startedAt: startedAt,
      );
}
