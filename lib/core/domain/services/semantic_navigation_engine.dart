import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_zone.dart';

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
  final List<ZonePriority> orderedZones;
  final Set<String> activeTags;
  final UrgencyLevel dominantUrgency;
  final List<String> suggestedZoneIds;

  const NavigationSnapshot({
    required this.orderedZones,
    required this.activeTags,
    required this.dominantUrgency,
    required this.suggestedZoneIds,
  });
}

class SemanticNavigationEngine {
  const SemanticNavigationEngine();

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

    final tagOverlap = zone.contextTags.where(activeTags.contains).length;
    score += tagOverlap * 0.35;

    if (activeTags.contains(EmotionalTag.urgente) ||
        activeTags.contains(EmotionalTag.peligro)) {
      score += zone.urgencyLevel.index * 0.15;
    }

    if (activeZoneId != null) {
      final activeZone = context.zoneById(activeZoneId);
      if (activeZone != null && activeZone.relatedZones.contains(zone.id)) {
        score += 0.25;
      }
    }

    final categoryHits = selectedCards
        .where((c) => zone.cardCategories.contains(c.categoryId))
        .length;
    score += categoryHits * 0.05;

    if (visitedZoneIds.contains(zone.id) && zone.id != activeZoneId) {
      score -= 0.15;
    }

    if (zone.optional && tagOverlap == 0 && categoryHits == 0) {
      score -= 0.1;
    }

    return score;
  }
}
