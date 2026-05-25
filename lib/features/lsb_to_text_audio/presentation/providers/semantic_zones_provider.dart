import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/lsb_card.dart';
import '../../domain/entities/semantic_zone.dart';
import '../../domain/services/semantic_navigation_engine.dart';
import 'context_provider.dart';
import 'sentence_provider.dart';

/// Estado reactivo de navegación semántica.
///
/// Sustituye por completo a `GuidedFlowState`: ya no hay índice secuencial.
/// Cualquier zona puede activarse en cualquier momento; el motor decide
/// cuáles son sugeridas / prioritarias según el contexto activo y las
/// tarjetas que el usuario ya seleccionó.
class SemanticZonesState {
  /// Zona actualmente seleccionada (manualmente o por sugerencia inicial).
  final String? activeZoneId;

  /// Zonas que el usuario ya activó al menos una vez.
  final Set<String> visitedZoneIds;

  /// Snapshot inmutable producido por el motor.
  final NavigationSnapshot snapshot;

  /// Cuántas cards lleva seleccionadas el usuario en la zona activa
  /// desde la última vez que se activó. Se usa para permitir múltiples
  /// respuestas (ej: CHOMPA+NEGRO) y para detectar fin de flujo.
  final int picksInActiveZone;

  const SemanticZonesState({
    required this.activeZoneId,
    required this.visitedZoneIds,
    required this.snapshot,
    this.picksInActiveZone = 0,
  });

  /// Acceso conveniente a la zona activa como entidad.
  SemanticZone? get activeZone {
    if (activeZoneId == null) return null;
    for (final p in snapshot.orderedZones) {
      if (p.zone.id == activeZoneId) return p.zone;
    }
    return null;
  }

  /// `true` si no hay ninguna zona pendiente además de la activa.
  bool get _noPendingQuestion {
    for (final p in snapshot.orderedZones) {
      if (p.zone.id == activeZoneId) continue;
      if (!visitedZoneIds.contains(p.zone.id)) return false;
    }
    return true;
  }

  /// `true` cuando el usuario ya respondió todas las preguntas y agotó
  /// los picks permitidos en la zona activa. Sirve para bloquear la
  /// selección de más cards y forzar al usuario a "Terminé y traducir"
  /// o a regresar manualmente a una pregunta anterior.
  bool get isFlowComplete {
    final zone = activeZone;
    if (zone == null) return false;
    if (!_noPendingQuestion) return false;
    return picksInActiveZone >= zone.maxPicks;
  }

  SemanticZonesState copyWith({
    String? activeZoneId,
    bool clearActive = false,
    Set<String>? visitedZoneIds,
    NavigationSnapshot? snapshot,
    int? picksInActiveZone,
  }) {
    return SemanticZonesState(
      activeZoneId: clearActive ? null : (activeZoneId ?? this.activeZoneId),
      visitedZoneIds: visitedZoneIds ?? this.visitedZoneIds,
      snapshot: snapshot ?? this.snapshot,
      picksInActiveZone: picksInActiveZone ?? this.picksInActiveZone,
    );
  }
}

final _engineProvider =
    Provider<SemanticNavigationEngine>((_) => const SemanticNavigationEngine());

/// Estado base — no depende de [allCardsProvider] (que es async) para evitar
/// loops circulares. Los boosts por categoría se aplican en
/// [dynamicCardsProvider]; aquí solo necesitamos las glosas seleccionadas.
class SemanticZonesNotifier extends Notifier<SemanticZonesState> {
  static const _emptyState = SemanticZonesState(
    activeZoneId: null,
    visitedZoneIds: {},
    snapshot: NavigationSnapshot(
      orderedZones: [],
      activeTags: {},
      dominantUrgency: UrgencyLevel.none,
      suggestedZoneIds: [],
    ),
  );

  @override
  SemanticZonesState build() {
    final ctx = ref.watch(contextProvider);
    final sentence = ref.watch(sentenceProvider);
    final engine = ref.watch(_engineProvider);

    if (ctx == null) return _emptyState;

    // En el primer build de un Notifier, `state` aún no está inicializado
    // y leerlo lanza LateError. Lo envolvemos para que el primer ingreso
    // al módulo no rompa la pantalla con "provider in error state".
    String? previousActiveId;
    Set<String> previousVisited = const {};
    try {
      final s = state;
      previousActiveId = s.activeZoneId;
      previousVisited = s.visitedZoneIds;
    } on Error {
      // First build — state aún no existe. Continuamos con valores por defecto.
    }

    final activeId = previousActiveId ?? ctx.entryZoneId;
    final visited = {...previousVisited, activeId};

    final snapshot = engine.compute(
      context: ctx,
      selectedGlosses: sentence,
      selectedCards: const <LsbCard>[],
      activeZoneId: activeId,
      visitedZoneIds: visited,
    );

    return SemanticZonesState(
      activeZoneId: activeId,
      visitedZoneIds: visited,
      snapshot: snapshot,
    );
  }

  /// Activa una zona libremente — no hay orden obligatorio.
  /// Al cambiar de zona se reinicia el contador de picks para que la
  /// nueva pregunta vuelva a aceptar respuestas.
  void activateZone(String zoneId) {
    final ctx = ref.read(contextProvider);
    if (ctx == null) return;
    if (ctx.zoneById(zoneId) == null) return;

    final visited = {...state.visitedZoneIds, zoneId};
    final engine = ref.read(_engineProvider);
    final sentence = ref.read(sentenceProvider);

    final snapshot = engine.compute(
      context: ctx,
      selectedGlosses: sentence,
      selectedCards: const <LsbCard>[],
      activeZoneId: zoneId,
      visitedZoneIds: visited,
    );

    state = SemanticZonesState(
      activeZoneId: zoneId,
      visitedZoneIds: visited,
      snapshot: snapshot,
      picksInActiveZone: 0,
    );
  }

  /// Avanza automáticamente a la siguiente pregunta después de que el
  /// usuario respondió tocando una tarjeta.
  ///
  /// Estrategia de decisión:
  /// 0. Incrementa el contador de picks de la zona activa. Si la zona
  ///    permite varias respuestas (`maxPicks > 1`) y todavía no se llegó
  ///    al máximo, se mantiene en la misma pregunta para que el usuario
  ///    pueda agregar otra card (ej: CHOMPA + NEGRO).
  /// 1. Si la tarjeta seleccionada tiene `suggestedNextCardIds`, busca
  ///    la categoría de esas tarjetas y activa la zona que las contiene
  ///    (siempre que no haya sido visitada todavía).
  /// 2. Si no hay sugerencia o ya fue visitada, salta a la siguiente
  ///    zona no visitada según la prioridad del motor.
  /// 3. Si todas las zonas están visitadas, mantiene la zona actual —
  ///    el usuario debería pulsar "Terminé y traducir".
  ///
  /// Esto es lo que materializa el flujo encadenado pregunta → respuesta
  /// → siguiente pregunta sin obligar al usuario a navegar manualmente.
  void advanceFromCard(LsbCard card, List<LsbCard> allCards) {
    final ctx = ref.read(contextProvider);
    if (ctx == null) return;

    final activeZone = state.activeZone;
    final newPickCount = state.picksInActiveZone + 1;

    // Si la zona acepta más respuestas, registramos el pick y nos quedamos.
    if (activeZone != null && newPickCount < activeZone.maxPicks) {
      state = state.copyWith(picksInActiveZone: newPickCount);
      return;
    }

    // 1. Intentar avanzar a la zona donde viven las tarjetas sugeridas.
    String? nextZoneId;
    if (card.suggestedNextCardIds.isNotEmpty) {
      final suggestedCategories = <String>{};
      for (final id in card.suggestedNextCardIds) {
        for (final c in allCards) {
          if (c.id == id) {
            suggestedCategories.add(c.categoryId);
            break;
          }
        }
      }
      for (final zone in ctx.zones) {
        if (zone.id == state.activeZoneId) continue;
        if (state.visitedZoneIds.contains(zone.id)) continue;
        if (zone.cardCategories.any(suggestedCategories.contains)) {
          nextZoneId = zone.id;
          break;
        }
      }
    }

    // 2. Fallback: siguiente zona no visitada según prioridad del motor.
    if (nextZoneId == null) {
      for (final p in state.snapshot.orderedZones) {
        if (p.zone.id == state.activeZoneId) continue;
        if (state.visitedZoneIds.contains(p.zone.id)) continue;
        nextZoneId = p.zone.id;
        break;
      }
    }

    // 3. Si no hay siguiente, dejamos el contador actualizado para que
    //    `isFlowComplete` bloquee la selección. La frase actualizada ya
    //    disparó un rebuild vía sentenceProvider.
    if (nextZoneId == null) {
      state = state.copyWith(picksInActiveZone: newPickCount);
      return;
    }

    activateZone(nextZoneId);
  }

  /// Marca la pregunta actual como visitada y salta a la siguiente.
  void skipCurrentQuestion() {
    final visited = {...state.visitedZoneIds};
    if (state.activeZoneId != null) visited.add(state.activeZoneId!);

    for (final p in state.snapshot.orderedZones) {
      if (p.zone.id == state.activeZoneId) continue;
      if (visited.contains(p.zone.id)) continue;
      activateZone(p.zone.id);
      return;
    }
  }

  void reset() {
    final ctx = ref.read(contextProvider);
    final engine = ref.read(_engineProvider);
    if (ctx == null) {
      state = const SemanticZonesState(
        activeZoneId: null,
        visitedZoneIds: {},
        snapshot: NavigationSnapshot(
          orderedZones: [],
          activeTags: {},
          dominantUrgency: UrgencyLevel.none,
          suggestedZoneIds: [],
        ),
      );
      return;
    }
    final snapshot = engine.compute(
      context: ctx,
      selectedGlosses: const [],
      selectedCards: const [],
      activeZoneId: ctx.entryZoneId,
      visitedZoneIds: {ctx.entryZoneId},
    );
    state = SemanticZonesState(
      activeZoneId: ctx.entryZoneId,
      visitedZoneIds: {ctx.entryZoneId},
      snapshot: snapshot,
      picksInActiveZone: 0,
    );
  }
}

final semanticZonesProvider =
    NotifierProvider<SemanticZonesNotifier, SemanticZonesState>(
  SemanticZonesNotifier.new,
);
