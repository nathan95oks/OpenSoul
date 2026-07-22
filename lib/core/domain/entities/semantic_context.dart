import 'semantic_zone.dart';

/// Contexto situacional humano (ej: "Me robaron", "Tengo miedo").
///
/// Mantiene los IDs originales para no romper el datasource de tarjetas
/// (que referencia 'denuncia_robo', 'violencia', etc.), pero los labels
/// y descripciones ahora son cognitivamente más naturales —- centrados
/// en lo que la persona vive, no en categorías institucionales.
///
/// Cada contexto expone un conjunto de [SemanticZone] **navegables
/// libremente**, no una secuencia obligatoria. El [SemanticNavigationEngine]
/// decide qué zonas priorizar según las glosas seleccionadas.
class SemanticContext {
  final String id;
  final String name;
  final String icon;
  final String emoji;

  /// Descripción humana en primera persona ("Me quitaron algo").
  final String description;

  /// Zonas semánticas navegables.
  final List<SemanticZone> zones;

  /// ID de la zona inicial sugerida (no obligatoria — el usuario puede
  /// entrar por donde quiera). El motor la usa solo como punto de partida
  /// visual si el usuario aún no seleccionó nada.
  final String entryZoneId;

  /// Nivel base de urgencia del contexto en general. 'emergencia' arranca
  /// con [UrgencyLevel.high]; trámites con [UrgencyLevel.none].
  final UrgencyLevel baseUrgency;

  const SemanticContext({
    required this.id,
    required this.name,
    required this.icon,
    required this.emoji,
    required this.description,
    required this.zones,
    required this.entryZoneId,
    this.baseUrgency = UrgencyLevel.none,
  });

  SemanticZone? zoneById(String zoneId) {
    for (final z in zones) {
      if (z.id == zoneId) return z;
    }
    return null;
  }
}
