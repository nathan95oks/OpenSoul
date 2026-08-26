import '../../engines/conversation_engine/speech_act.dart';
import 'context_suggestion.dart';

/// Decisión de desambiguación tomada sobre una palabra polisémica.
///
/// El motor de traducción resuelve ambigüedades del español al pasar a LSB
/// ("llama" → convocar / animal / fuego). Esa decisión es parte del
/// significado del mensaje, no un detalle de implementación: se conserva
/// para poder mostrarla y justificarla ante quien conversa.
class SemanticDisambiguation {
  /// Palabra ambigua tal como apareció en el enunciado.
  final String original;

  /// Sentido elegido.
  final String meaning;

  /// Justificación breve de la elección.
  final String reason;

  const SemanticDisambiguation({
    required this.original,
    required this.meaning,
    this.reason = '',
  });

  factory SemanticDisambiguation.fromJson(Map<String, dynamic> json) =>
      SemanticDisambiguation(
        original: (json['original'] ?? '').toString(),
        meaning: (json['meaning'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
      );
}

/// Quién produce el mensaje dentro de la conversación.
///
/// En el modo de un solo dispositivo, el teléfono se pasa entre ambas
/// personas: la persona sorda se expresa con tarjetas LSB; la persona
/// oyente con voz o texto.
enum SpeakerRole { deaf, hearing }

/// Canal de entrada con el que se construyó el mensaje.
enum MessageSource { cards, speech, text }

/// Representación semántica única de un enunciado dentro de la conversación.
///
/// Es la entidad central del sistema: todo canal de entrada (tarjetas,
/// voz, texto) se normaliza a un [SemanticMessage], y todo generador de
/// salida (texto, audio, avatar) trabaja exclusivamente sobre él. Ningún
/// generador debe producir salida desde la entrada cruda.
class SemanticMessage {
  final String id;
  final SpeakerRole speaker;
  final MessageSource source;

  /// Secuencia de glosas LSB del enunciado (p. ej. ['HOMBRE','ROBAR','CELULAR']).
  final List<String> glosses;

  /// Contexto situacional **confirmado** por quien emite el mensaje
  /// ('denuncia_robo', 'violencia'…). Nulo cuando el canal de entrada no lo
  /// determina (voz/texto libre). Nunca contiene una inferencia del sistema:
  /// para eso está [contextSuggestion].
  final String? contextId;

  /// Contexto **inferido** del enunciado, pendiente de confirmación.
  ///
  /// Es lo que permite que el turno de la persona oyente proponga a la
  /// persona sorda desde qué contexto responder, en lugar de obligarla a
  /// declararlo de nuevo desde cero.
  final ContextSuggestion? contextSuggestion;

  /// Id del mensaje al que responde este turno. Enlaza ambas direcciones de
  /// la conversación: sin él los turnos serían una lista, no un diálogo.
  final String? replyToId;

  /// Ambigüedades resueltas al interpretar el enunciado.
  final List<SemanticDisambiguation> disambiguations;

  /// Forma de superficie en español del enunciado.
  final String text;

  /// Representación intermedia con roles semánticos (sujeto, verbo, objeto…)
  /// producida por el motor de análisis, cuando está disponible.
  final Map<String, dynamic>? intermediateRepresentation;

  final DateTime createdAt;

  /// Qué hace el enunciado: preguntar, instruir o informar.
  ///
  /// Decide qué se le ofrece a la persona sorda debajo del turno. Solo tiene
  /// sentido en los del oyente; en los propios queda en [SpeechAct.statement].
  final SpeechAct speechAct;

  SemanticMessage({
    this.speechAct = SpeechAct.statement,
    required this.id,
    required this.speaker,
    required this.source,
    required this.glosses,
    required this.text,
    this.contextId,
    this.contextSuggestion,
    this.replyToId,
    this.disambiguations = const [],
    this.intermediateRepresentation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
