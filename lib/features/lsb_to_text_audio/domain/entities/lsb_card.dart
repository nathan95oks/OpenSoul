/// Representa una tarjeta de glosa LSB (Lengua de Señas Boliviana).
///
/// Cada tarjeta contiene la glosa, su traducción visual, categoría,
/// y metadatos para trámites y consultas ciudadanas en entidades públicas.
class LsbCard {
  final String id;
  final String gloss;
  final String displayText;
  final String iconUrl;
  final String videoUrl;
  final String categoryId;
  final String subcategoryId;
  final List<String> contexts;
  final int priority;
  final List<String> suggestedNextCardIds;
  final bool isFrequent;
  final bool isEmergency;

  /// Nombre del ícono semántico de Material Icons (ej: 'person', 'gavel').
  final String semanticIcon;

  /// Clave de animación 3D asociada en el modelo GLB del avatar.
  final String? animationKey;

  LsbCard({
    required this.id,
    required this.gloss,
    required this.displayText,
    required this.iconUrl,
    required this.videoUrl,
    required this.categoryId,
    required this.subcategoryId,
    required this.contexts,
    required this.priority,
    required this.suggestedNextCardIds,
    required this.isFrequent,
    required this.isEmergency,
    this.semanticIcon = 'credit_card',
    this.animationKey,
  });
}
