import '../entities/context_suggestion.dart';
import '../repositories/translation_repository.dart';

/// Pregunta de la persona oyente que está esperando respuesta.
///
/// Es todo lo que el flujo de tarjetas necesita saber de una conversación en
/// curso: qué se preguntó y desde qué contexto conviene responder. No expone
/// la conversación entera —turnos, historial, audio— porque el módulo de
/// traducción no tiene por qué conocerla.
class ReplyPrompt {
  /// Enunciado al que se responde, tal como lo dijo la persona oyente.
  final String question;

  /// Contexto inferido de ese enunciado, sin confirmar. Nulo si la frase no
  /// daba evidencia suficiente.
  final ContextSuggestion? suggestion;

  /// Último contexto confirmado en la conversación, si lo hubo.
  final String? activeContextId;

  const ReplyPrompt({
    required this.question,
    this.suggestion,
    this.activeContextId,
  });

  /// Contexto desde el que abrir el flujo guiado: lo inferido de esta
  /// pregunta manda sobre lo heredado de turnos anteriores.
  String? get proposedContextId => suggestion?.contextId ?? activeContextId;
}

/// Puerto por el que el flujo de tarjetas entrega una declaración terminada.
///
/// Invierte la dependencia entre módulos: `lsb_to_text_audio` declara **qué**
/// necesita de una conversación, y es el módulo de conversación quien lo
/// implementa. Así el módulo de traducción no conoce al de conversación y
/// sigue funcionando por sí solo — con la implementación inerte de abajo, el
/// flujo de tarjetas se comporta como una aplicación independiente.
abstract class ConversationBridge {
  /// Incorpora la declaración a la conversación como turno.
  void submitDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
  });
}

/// Implementación por defecto: no hay conversación que alimentar.
///
/// Es la que rige cuando el flujo de tarjetas se usa de forma autónoma. La
/// declaración se genera, se escucha y se copia igual; simplemente no viaja
/// a ningún hilo de conversación.
class NoConversationBridge implements ConversationBridge {
  const NoConversationBridge();

  @override
  void submitDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
  }) {}
}
