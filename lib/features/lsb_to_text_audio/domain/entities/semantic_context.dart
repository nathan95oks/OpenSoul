/// Representa un contexto semántico situacional (ej: Robo, Violencia).
///
/// Cada contexto tiene un conjunto de [GuidedStep] que funcionan como
/// "zonas semánticas" explorables, NO como preguntas secuenciales rígidas.
class SemanticContext {
  final String id;
  final String name;
  final String icon;
  final String emoji;
  final String description;
  final List<GuidedStep> defaultSteps;

  const SemanticContext({
    required this.id,
    required this.name,
    required this.icon,
    required this.emoji,
    required this.description,
    required this.defaultSteps,
  });
}

/// Representa una zona semántica dentro del flujo guiado.
///
/// NO es una pregunta interrogativa. Es una etiqueta visual corta
/// que agrupa conceptos relacionados (ej: "Situación", "Personas").
/// El usuario puede seleccionar múltiples glosas dentro de una zona
/// y avanzar manualmente cuando lo desee.
class GuidedStep {
  /// Identificador único del paso.
  final String id;

  /// Etiqueta corta (1-2 palabras): "Situación", "Personas", "Objetos".
  final String label;

  /// Texto de apoyo breve y accesible.
  final String hint;

  /// Emoji visual para refuerzo rápido.
  final String emoji;

  /// Categorías de tarjetas a mostrar en esta zona.
  final List<String> targetCategories;

  /// Si es true, el usuario puede saltar esta zona.
  final bool isOptional;

  /// Mínimo de selecciones requeridas (0 = se puede saltar).
  final int minSelections;

  /// Máximo de selecciones permitidas (null = ilimitado).
  final int? maxSelections;

  const GuidedStep({
    required this.id,
    required this.label,
    required this.hint,
    this.emoji = '📌',
    required this.targetCategories,
    this.isOptional = false,
    this.minSelections = 0,
    this.maxSelections,
  });
}
