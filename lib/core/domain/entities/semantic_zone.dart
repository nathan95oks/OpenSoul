enum UrgencyLevel {
  none,
  low,
  medium,
  high,
  critical,
}

class EmotionalTag {
  static const miedo = 'miedo';
  static const peligro = 'peligro';
  static const dolor = 'dolor';
  static const urgente = 'urgente';
  static const ayuda = 'ayuda';
  static const amenaza = 'amenaza';
  static const all = [miedo, peligro, dolor, urgente, ayuda, amenaza];
}

class SemanticZone {
  /// Qué campo de respuesta pide cada zona, por su id.
  ///
  /// Sirve para filtrar las opciones cuando no hay un turno del oyente al que
  /// responder —el modo A, o cuando el español libre no encaja con ningún
  /// nodo—. Sin esto, abrir el buscador o cambiar de categoría permitía meter
  /// una tarjeta que la pregunta activa no admite.
  ///
  /// Una zona que no esté aquí no filtra nada: es preferible ofrecer de más a
  /// esconder una respuesta correcta por una clasificación incompleta.
  static const Map<String, List<String>> answerFieldsByZoneId = {
    // Denuncia y relato
    'hecho': ['free_text'],
    'objetos': ['object'],
    'persona': ['person'],
    'persona_pregunta': ['person'],
    'conocimiento': ['polarity', 'person'],
    'lugar': ['place'],
    'lugar_pregunta': ['place'],
    'tiempo': ['time'],
    'tiempo_pregunta': ['time'],
    'testigos': ['polarity', 'person'],
    'evidencia': ['evidence'],
    'comprobante': ['evidence'],
    'cantidad': ['amount'],
    'cantidad_pregunta': ['amount'],
    'institucion': ['institution'],
    'institucion_autoridad': ['institution'],
    'medio_banco': ['institution', 'object'],
    'apoyo_legal': ['institution'],
    'denuncia': ['polarity', 'free_text'],
    // Identificación y acceso
    'identidad': ['person'],
    'contacto': ['object'],
    'acompanante': ['person'],
    'edad': ['person'],
    'acceso': ['polarity', 'free_text'],
    // Violencia y riesgo
    'salud_urgencia': ['polarity', 'free_text'],
    'emocion_riesgo': ['free_text'],
    'emergencia': ['polarity', 'free_text'],
    // Seguimiento
    'tramite': ['free_text'],
    'accion': ['free_text'],
    // Relato abierto y preguntas: no acotan el tipo de respuesta.
    'relato': ['free_text'],
    'interrogativa': ['free_text'],
    'tema_pregunta': ['free_text'],
  };

  final String id;
  final String label;
  final String hint;
  final String question;
  final String emoji;
  final double semanticWeight;
  final bool optional;
  final UrgencyLevel urgencyLevel;
  final List<String> relatedZones;
  final List<String> cardCategories;
  final List<String> cardSubcategories;
  final List<String> glossAllowlist;
  final List<String> chainTriggers;
  final String? chainZoneId;
  final bool strictContext;
  final int maxPicks;
  final List<String> contextTags;
  final String? leadGloss;

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
    this.cardCategories = const [],
    this.cardSubcategories = const [],
    this.glossAllowlist = const [],
    this.chainTriggers = const [],
    this.chainZoneId,
    this.strictContext = false,
    this.maxPicks = 1,
    this.contextTags = const [],
    this.leadGloss,
  });

  /// Campos de respuesta que admite esta zona. Vacío = no filtra.
  List<String> get answerFields => answerFieldsByZoneId[id] ?? const [];

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
      glossAllowlist: glossAllowlist,
      chainTriggers: chainTriggers,
      chainZoneId: chainZoneId,
      strictContext: strictContext,
      maxPicks: maxPicks,
      contextTags: contextTags,
      leadGloss: leadGloss,
    );
  }
}
