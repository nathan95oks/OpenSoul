/// Nivel de urgencia semántica de una zona o etiqueta.
///
/// Permite que el motor de navegación priorice automáticamente
/// zonas críticas (Emergencia, Amenaza, Ayuda) cuando el usuario
/// selecciona glosas que disparan miedo / peligro / dolor.
enum UrgencyLevel {
  none,
  low,
  medium,
  high,
  critical,
}

/// Etiquetas emocionales / situacionales que el motor puede activar
/// dinámicamente a partir de las glosas seleccionadas.
///
/// No son zonas — son banderas que reorganizan las prioridades de las
/// zonas existentes. Ej: detectar "CUCHILLO" activa [amenaza] y [peligro],
/// lo cual sube la prioridad de la zona `emergencia` / `ayuda`.
class EmotionalTag {
  static const miedo = 'miedo';
  static const peligro = 'peligro';
  static const dolor = 'dolor';
  static const urgente = 'urgente';
  static const ayuda = 'ayuda';
  static const amenaza = 'amenaza';

  static const all = [miedo, peligro, dolor, urgente, ayuda, amenaza];
}

/// Representa una zona semántica navegable libremente dentro de un contexto.
///
/// A diferencia del antiguo [GuidedStep] (secuencial e indexado), una
/// [SemanticZone] es un **espacio conceptual** que el usuario puede
/// activar en cualquier orden. El motor de navegación se encarga de
/// sugerir, priorizar y resaltar zonas según el contexto activo, las
/// tarjetas seleccionadas y las etiquetas emocionales detectadas.
class SemanticZone {
  /// Identificador único dentro del contexto (ej: 'situacion', 'personas').
  final String id;

  /// Etiqueta corta para la UI (ej: 'Situación', 'Personas', 'Lugar').
  final String label;

  /// Texto de apoyo breve y accesible. Sin tono interrogativo.
  final String hint;

  /// Emoji de refuerzo visual.
  final String emoji;

  /// Peso semántico base [0..1]. Zonas con mayor peso aparecen primero
  /// cuando ninguna selección las ha desbalanceado todavía.
  final double semanticWeight;

  /// Si es true, la zona puede omitirse sin afectar la coherencia narrativa.
  final bool optional;

  /// Nivel de urgencia intrínseco de la zona (ej: 'emergencia' = high).
  final UrgencyLevel urgencyLevel;

  /// IDs de otras zonas semánticamente relacionadas. Al activar esta zona
  /// el motor también sugerirá las relacionadas.
  final List<String> relatedZones;

  /// Categorías de tarjetas (del datasource) que esta zona expone.
  final List<String> cardCategories;

  /// Etiquetas emocionales que esta zona "absorbe" o representa
  /// (ej: la zona `emergencia` lleva [urgente, ayuda]).
  final List<String> contextTags;

  const SemanticZone({
    required this.id,
    required this.label,
    required this.hint,
    this.emoji = '📌',
    this.semanticWeight = 0.5,
    this.optional = false,
    this.urgencyLevel = UrgencyLevel.none,
    this.relatedZones = const [],
    required this.cardCategories,
    this.contextTags = const [],
  });

  SemanticZone copyWith({
    double? semanticWeight,
    UrgencyLevel? urgencyLevel,
  }) {
    return SemanticZone(
      id: id,
      label: label,
      hint: hint,
      emoji: emoji,
      semanticWeight: semanticWeight ?? this.semanticWeight,
      optional: optional,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      relatedZones: relatedZones,
      cardCategories: cardCategories,
      contextTags: contextTags,
    );
  }
}
