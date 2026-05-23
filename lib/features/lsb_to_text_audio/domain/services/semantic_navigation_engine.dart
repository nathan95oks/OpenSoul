import '../entities/lsb_card.dart';
import '../entities/semantic_context.dart';
import '../entities/semantic_zone.dart';

/// Resultado inmutable de un cálculo de prioridades por el motor.
class ZonePriority {
  final SemanticZone zone;
  final double score;
  final UrgencyLevel urgency;
  final bool isSuggested;

  const ZonePriority({
    required this.zone,
    required this.score,
    required this.urgency,
    required this.isSuggested,
  });
}

class NavigationSnapshot {
  /// Zonas ordenadas por prioridad descendente.
  final List<ZonePriority> orderedZones;

  /// Etiquetas emocionales activas detectadas en las glosas seleccionadas.
  final Set<String> activeTags;

  /// Nivel de urgencia global combinado (max entre baseUrgency y tags).
  final UrgencyLevel dominantUrgency;

  /// IDs de zonas que el motor sugiere explorar a continuación.
  final List<String> suggestedZoneIds;

  const NavigationSnapshot({
    required this.orderedZones,
    required this.activeTags,
    required this.dominantUrgency,
    required this.suggestedZoneIds,
  });
}

/// Motor de navegación semántica — **stateless / puro**.
///
/// Recibe: contexto activo, glosas seleccionadas, zona actualmente activada
/// y zonas visitadas. Devuelve una vista priorizada de las zonas y las
/// etiquetas emocionales detectadas. No mantiene estado propio — los
/// providers Riverpod son responsables del estado.
class SemanticNavigationEngine {
  const SemanticNavigationEngine();

  /// Diccionario de glosas/keywords que disparan etiquetas emocionales.
  /// Se compara contra el `displayText` y la `gloss` en mayúsculas.
  ///
  /// La lista es deliberadamente corta — son disparadores semánticos
  /// concretos, no un análisis lingüístico exhaustivo (eso lo hace el NLP
  /// del backend). Si una glosa no aparece aquí pero la tarjeta tiene
  /// `isEmergency = true`, también activa [EmotionalTag.urgente].
  static const Map<String, List<String>> _glossTagTriggers = {
    'CUCHILLO': [EmotionalTag.amenaza, EmotionalTag.peligro],
    'ARMA': [EmotionalTag.amenaza, EmotionalTag.peligro],
    'PISTOLA': [EmotionalTag.amenaza, EmotionalTag.peligro],
    'GOLPE': [EmotionalTag.dolor, EmotionalTag.amenaza],
    'GOLPEAR': [EmotionalTag.dolor, EmotionalTag.amenaza],
    'SANGRE': [EmotionalTag.dolor, EmotionalTag.urgente],
    'HERIDO': [EmotionalTag.dolor, EmotionalTag.urgente],
    'DOLOR': [EmotionalTag.dolor],
    'MIEDO': [EmotionalTag.miedo],
    'AMENAZA': [EmotionalTag.amenaza, EmotionalTag.peligro],
    'AMENAZAR': [EmotionalTag.amenaza, EmotionalTag.peligro],
    'AYUDA': [EmotionalTag.ayuda, EmotionalTag.urgente],
    'AYUDAR': [EmotionalTag.ayuda],
    'URGENTE': [EmotionalTag.urgente],
    'EMERGENCIA': [EmotionalTag.urgente, EmotionalTag.ayuda],
    'AMBULANCIA': [EmotionalTag.urgente, EmotionalTag.ayuda],
    'POLICIA': [EmotionalTag.ayuda],
    'PELIGRO': [EmotionalTag.peligro],
    'LLORAR': [EmotionalTag.dolor, EmotionalTag.miedo],
    'TRISTE': [EmotionalTag.dolor],
  };

  NavigationSnapshot compute({
    required SemanticContext context,
    required List<String> selectedGlosses,
    required List<LsbCard> selectedCards,
    String? activeZoneId,
    Set<String> visitedZoneIds = const {},
  }) {
    final activeTags = _detectTags(selectedGlosses, selectedCards);
    final dominantUrgency = _combineUrgency(context.baseUrgency, activeTags);

    final scored = <ZonePriority>[];
    for (final zone in context.zones) {
      final score = _scoreZone(
        zone: zone,
        context: context,
        activeTags: activeTags,
        activeZoneId: activeZoneId,
        visitedZoneIds: visitedZoneIds,
        selectedCards: selectedCards,
      );
      scored.add(ZonePriority(
        zone: zone,
        score: score,
        urgency: _zoneUrgency(zone, activeTags),
        isSuggested: false,
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Las top-3 zonas no visitadas y distintas de la activa son las "sugeridas".
    final suggested = <String>[];
    for (final p in scored) {
      if (suggested.length >= 3) break;
      if (p.zone.id == activeZoneId) continue;
      if (visitedZoneIds.contains(p.zone.id)) continue;
      suggested.add(p.zone.id);
    }

    final marked = scored
        .map((p) => ZonePriority(
              zone: p.zone,
              score: p.score,
              urgency: p.urgency,
              isSuggested: suggested.contains(p.zone.id),
            ))
        .toList();

    return NavigationSnapshot(
      orderedZones: marked,
      activeTags: activeTags,
      dominantUrgency: dominantUrgency,
      suggestedZoneIds: suggested,
    );
  }

  Set<String> _detectTags(List<String> glosses, List<LsbCard> cards) {
    final tags = <String>{};
    for (final g in glosses) {
      final key = g.toUpperCase().trim();
      final hit = _glossTagTriggers[key];
      if (hit != null) tags.addAll(hit);
    }
    for (final c in cards) {
      if (c.isEmergency) {
        tags.add(EmotionalTag.urgente);
      }
      final key = c.gloss.toUpperCase().trim();
      final hit = _glossTagTriggers[key];
      if (hit != null) tags.addAll(hit);
    }
    return tags;
  }

  UrgencyLevel _combineUrgency(UrgencyLevel base, Set<String> tags) {
    var level = base;
    if (tags.contains(EmotionalTag.peligro) || tags.contains(EmotionalTag.amenaza)) {
      level = _max(level, UrgencyLevel.high);
    }
    if (tags.contains(EmotionalTag.urgente)) {
      level = _max(level, UrgencyLevel.critical);
    }
    if (tags.contains(EmotionalTag.dolor)) {
      level = _max(level, UrgencyLevel.high);
    }
    if (tags.contains(EmotionalTag.miedo)) {
      level = _max(level, UrgencyLevel.medium);
    }
    return level;
  }

  UrgencyLevel _zoneUrgency(SemanticZone zone, Set<String> tags) {
    if (zone.contextTags.any(tags.contains)) {
      return _max(zone.urgencyLevel, UrgencyLevel.high);
    }
    return zone.urgencyLevel;
  }

  UrgencyLevel _max(UrgencyLevel a, UrgencyLevel b) =>
      a.index >= b.index ? a : b;

  double _scoreZone({
    required SemanticZone zone,
    required SemanticContext context,
    required Set<String> activeTags,
    required String? activeZoneId,
    required Set<String> visitedZoneIds,
    required List<LsbCard> selectedCards,
  }) {
    var score = zone.semanticWeight;

    // Boost por overlap de etiquetas emocionales activas.
    final tagOverlap = zone.contextTags.where(activeTags.contains).length;
    score += tagOverlap * 0.35;

    // Boost por urgencia intrínseca alta cuando hay urgencia activa.
    if (activeTags.contains(EmotionalTag.urgente) ||
        activeTags.contains(EmotionalTag.peligro)) {
      score += zone.urgencyLevel.index * 0.15;
    }

    // Boost si la zona es "related" desde la zona activa.
    if (activeZoneId != null) {
      final activeZone = context.zoneById(activeZoneId);
      if (activeZone != null && activeZone.relatedZones.contains(zone.id)) {
        score += 0.25;
      }
    }

    // Boost si las tarjetas ya seleccionadas comparten categoría con la zona.
    final categoryHits = selectedCards
        .where((c) => zone.cardCategories.contains(c.categoryId))
        .length;
    score += categoryHits * 0.05;

    // Penalización suave si ya fue visitada (para invitar a explorar otras).
    if (visitedZoneIds.contains(zone.id) && zone.id != activeZoneId) {
      score -= 0.15;
    }

    // Penalización si es opcional y no hay nada que la dispare.
    if (zone.optional && tagOverlap == 0 && categoryHits == 0) {
      score -= 0.1;
    }

    return score;
  }
}
