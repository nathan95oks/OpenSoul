/// Representa una tarjeta de glosa LSB (Lengua de Señas Boliviana).
///
/// Cada tarjeta contiene la glosa, su representación visual mediante
/// ícono semántico, categoría, y metadatos para trámites y consultas
/// ciudadanas en entidades públicas judiciales.
class LsbCard {
  final String id;
  final String gloss;
  final String displayText;
  final String iconUrl;
  final String categoryId;
  final String subcategoryId;
  final List<String> contexts;
  final int priority;
  final List<String> suggestedNextCardIds;
  final bool isFrequent;
  final bool isEmergency;

  /// Nombre del ícono semántico de Material Icons (ej: 'person', 'gavel').
  final String semanticIcon;

  /// Dialecto LSB al que pertenece la glosa.
  /// Por defecto 'cochabamba' (alcance del proyecto).
  final String dialect;

  LsbCard({
    required this.id,
    required this.gloss,
    required this.displayText,
    required this.iconUrl,
    required this.categoryId,
    required this.subcategoryId,
    required this.contexts,
    required this.priority,
    required this.suggestedNextCardIds,
    required this.isFrequent,
    required this.isEmergency,
    this.semanticIcon = 'credit_card',
    this.dialect = 'cochabamba',
  });
}
