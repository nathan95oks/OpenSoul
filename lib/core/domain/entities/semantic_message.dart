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

  /// Contexto situacional en el que se emitió ('denuncia_robo', 'violencia'…).
  /// Nulo cuando el canal de entrada no lo determina (voz/texto libre).
  final String? contextId;

  /// Forma de superficie en español del enunciado.
  final String text;

  /// Representación intermedia con roles semánticos (sujeto, verbo, objeto…)
  /// producida por el motor de análisis, cuando está disponible.
  final Map<String, dynamic>? intermediateRepresentation;

  final DateTime createdAt;

  SemanticMessage({
    required this.id,
    required this.speaker,
    required this.source,
    required this.glosses,
    required this.text,
    this.contextId,
    this.intermediateRepresentation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
