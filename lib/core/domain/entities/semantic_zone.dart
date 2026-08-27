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
