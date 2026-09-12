import 'package:lsb_legal_app/core/domain/entities/semantic_zone.dart';
import 'package:lsb_legal_app/core/domain/services/context_catalog.dart' show contextById;

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

class ContextFamily {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<String> contextIds;

  const ContextFamily({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.contextIds,
  });
}

const contextFamilies = <ContextFamily>[
  ContextFamily(
    id: 'denuncias',
    name: 'Denuncias',
    emoji: '🚨',
    description: 'Robo, violencia física, engaños, amenazas o testimonio',
    contextIds: ['denuncia_robo', 'violencia', 'amenaza_digital', 'engano_dinero', 'otro'],
  ),
  ContextFamily(
    id: 'consultas',
    name: 'Consultas',
    emoji: '📂',
    description: 'Estado de investigación, citaciones, resoluciones o citas judiciales',
    contextIds: ['seguimiento'],
  ),
  ContextFamily(
    id: 'tramites',
    name: 'Trámites',
    emoji: '🪪',
    description: 'Identificación, datos de contacto y recepción de avisos',
    contextIds: ['identificacion'],
  ),
  ContextFamily(
    id: 'preguntas',
    name: 'Preguntas',
    emoji: '❓',
    description: 'Preguntas directas del ciudadano sobre trámites o instituciones',
    contextIds: ['preguntas'],
  ),
];

List<SemanticContext> contextsOfFamily(ContextFamily family) {
  return [
    for (final id in family.contextIds)
      if (contextById(id) != null) contextById(id)!,
  ];
}



