/// Contexto situacional **inferido** a partir de un enunciado, todavía sin
/// confirmar por una persona.
///
/// Se distingue deliberadamente de `SemanticMessage.contextId`, que solo
/// contiene el contexto que alguien eligió de forma explícita. Una suposición
/// del sistema nunca debe hacerse pasar por una declaración del usuario: la
/// sugerencia se ofrece, la persona sorda decide.
class ContextSuggestion {
  /// Id del contexto propuesto ('denuncia_robo', 'violencia'…).
  final String contextId;

  /// Confianza normalizada en [0,1]: proporción de la evidencia total que
  /// apunta a este contexto frente al resto.
  final double confidence;

  /// Glosas o palabras que motivaron la sugerencia, de mayor a menor peso.
  /// Se muestran al usuario para que la propuesta sea explicable y no un
  /// acto de fe ("Detectado: ROBAR, CELULAR").
  final List<String> evidence;

  const ContextSuggestion({
    required this.contextId,
    required this.confidence,
    this.evidence = const [],
  });

  @override
  String toString() =>
      'ContextSuggestion($contextId, ${(confidence * 100).round()}%, $evidence)';
}
