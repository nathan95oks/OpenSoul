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

  /// Pregunta guiada en primera persona que se le muestra al usuario sordo
  /// cuando esta zona está activa (ej: "¿Qué pasó?", "¿Quién estuvo?").
  /// Convierte la navegación por zonas en un cuestionario asistido sin
  /// reemplazar las tarjetas: el usuario responde tocando glosas.
  final String question;

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

  /// Subcategorías permitidas dentro de [cardCategories]. Si está vacío,
  /// se aceptan todas las subcategorías de las categorías declaradas.
  /// Permite que dos zonas que comparten categoría muestren cards
  /// diferentes (ej: "Personas" → Descripción[Género,Edad] vs
  /// "Apariencia" → Descripción[Físico,Cabello]).
  final List<String> cardSubcategories;

  /// Si es true, sólo se muestran cards cuyo `contexts` incluye el id
  /// del contexto activo — no se rellena con cards `general`. Útil para
  /// zonas donde los fillers genéricos (YO, FAMILIA, HIJO) carecen de
  /// sentido (ej: "¿Quién te robó?" no debe sugerir "MI HIJO").
  final bool strictContext;

  /// Cantidad máxima de cards que el usuario puede elegir antes de que
  /// el motor avance automáticamente a la siguiente pregunta. Default 1
  /// (una sola respuesta por pregunta). Zonas descriptivas pueden usar
  /// 2 para permitir combinaciones tipo "CHOMPA + NEGRO" o
  /// "ALTO + DELGADO".
  final int maxPicks;

  /// Etiquetas emocionales que esta zona "absorbe" o representa
  /// (ej: la zona `emergencia` lleva [urgente, ayuda]).
  final List<String> contextTags;

  const SemanticZone({
    required this.id,
    required this.label,
    required this.hint,
    this.question = '',
    this.emoji = '📌',
    this.semanticWeight = 0.5,
    this.optional = false,
    this.urgencyLevel = UrgencyLevel.none,
    this.relatedZones = const [],
    required this.cardCategories,
    this.cardSubcategories = const [],
    this.strictContext = false,
    this.maxPicks = 1,
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
      question: question,
      emoji: emoji,
      semanticWeight: semanticWeight ?? this.semanticWeight,
      optional: optional,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      relatedZones: relatedZones,
      cardCategories: cardCategories,
      cardSubcategories: cardSubcategories,
      strictContext: strictContext,
      maxPicks: maxPicks,
      contextTags: contextTags,
    );
  }
}
