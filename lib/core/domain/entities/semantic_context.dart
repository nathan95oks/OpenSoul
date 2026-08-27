import 'package:lsb_legal_app/core/domain/entities/semantic_zone.dart';

class SemanticContext {
  final String id;
  final String name;
  final String icon;
  final String emoji;
  final String description;
  final List<SemanticZone> zones;
  final String entryZoneId;
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
