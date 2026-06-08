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

  /// Orden de activación de zonas (preserva inserción) — necesario para
  /// construir el árbol conceptual en el orden que el usuario navegó.
  final List<String> visitedZoneOrder;

  /// Respuestas por zona: zoneId → lista de glosas seleccionadas.
  /// Permite mostrar qué respondió el usuario en cada pregunta del árbol.
  final Map<String, List<String>> zoneAnswers;

  /// Snapshot inmutable producido por el motor.
  final NavigationSnapshot snapshot;

  const SemanticZonesState({
    required this.activeZoneId,
    required this.visitedZoneIds,
    required this.snapshot,
    this.visitedZoneOrder = const [],
    this.zoneAnswers = const {},
  });

  /// Cuántas glosas lleva seleccionadas el usuario en la zona activa.
  /// Derivado de [zoneAnswers] — fuente única de verdad, sin contador
  /// paralelo que pueda desincronizarse al editar/deseleccionar.
  int get picksInActiveZone =>
      activeZoneId == null ? 0 : (zoneAnswers[activeZoneId]?.length ?? 0);

  /// Acceso conveniente a la zona activa como entidad.
  SemanticZone? get activeZone {
    if (activeZoneId == null) return null;
    for (final p in snapshot.orderedZones) {
      if (p.zone.id == activeZoneId) return p.zone;
    }
    return null;
  }

  /// Glosas seleccionadas en la zona actualmente activa.
  List<String> get activeAnswers =>
      activeZoneId == null ? const [] : (zoneAnswers[activeZoneId] ?? const []);

  /// `true` si existe una pregunta a la que avanzar con "Continuar":
  /// bien una zona posterior ya navegada (cuando el usuario retrocedió),
  /// bien una zona aún no visitada que el motor sugiere.
  bool get hasNextQuestion {
    final id = activeZoneId;
    if (id == null) return false;
    final idx = visitedZoneOrder.indexOf(id);
    if (idx >= 0 && idx < visitedZoneOrder.length - 1) return true;
    for (final p in snapshot.orderedZones) {
      if (p.zone.id == id) continue;
      if (!visitedZoneIds.contains(p.zone.id)) return true;
    }
    return false;
  }

  /// `true` si hay una pregunta anterior a la que volver.
  bool get canGoBack {
    final id = activeZoneId;
    return id != null && visitedZoneOrder.indexOf(id) > 0;
  }

  /// `true` cuando ya no quedan más preguntas por delante. La traducción
  /// siempre está disponible desde el panel inferior; esto solo sirve para
  /// mostrar el indicador de "relato completo".
  bool get isFlowComplete {
    if (activeZone == null) return false;
    return !hasNextQuestion;
  }

  SemanticZonesState copyWith({
    String? activeZoneId,
    bool clearActive = false,
    Set<String>? visitedZoneIds,
    List<String>? visitedZoneOrder,
    Map<String, List<String>>? zoneAnswers,
    NavigationSnapshot? snapshot,
  }) {
    return SemanticZonesState(
      activeZoneId: clearActive ? null : (activeZoneId ?? this.activeZoneId),
      visitedZoneIds: visitedZoneIds ?? this.visitedZoneIds,
      visitedZoneOrder: visitedZoneOrder ?? this.visitedZoneOrder,
      zoneAnswers: zoneAnswers ?? this.zoneAnswers,
      snapshot: snapshot ?? this.snapshot,
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
    //
    // IMPORTANTE: `build` se re-ejecuta cada vez que cambia `sentenceProvider`
    // (al seleccionar/deseleccionar glosas). Por eso preservamos también
    // `visitedZoneOrder` y `zoneAnswers`: de lo contrario el árbol conceptual
    // y las respuestas se borrarían en cada selección y sería imposible
    // editar respuestas anteriores.
    String? previousActiveId;
    Set<String> previousVisited = const {};
    List<String> previousOrder = const [];
    Map<String, List<String>> previousAnswers = const {};
    try {
      final s = state;
      previousActiveId = s.activeZoneId;
      previousVisited = s.visitedZoneIds;
      previousOrder = s.visitedZoneOrder;
      previousAnswers = s.zoneAnswers;
    } on Error {
      // First build — state aún no existe. Continuamos con valores por defecto.
    }

    final activeId = previousActiveId ?? ctx.entryZoneId;
    final visited = {...previousVisited, activeId};
    final order = [...previousOrder];
    if (!order.contains(activeId)) order.add(activeId);

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
      visitedZoneOrder: order,
      zoneAnswers: previousAnswers,
      snapshot: snapshot,
    );
  }

  /// Secuencia plana de glosas en orden narrativo (zona por zona, según
  /// el orden en que el usuario navegó). Es lo que se envía al motor de
  /// traducción a través de [sentenceProvider].
  List<String> orderedGlosses() {
    final out = <String>[];
    for (final zoneId in state.visitedZoneOrder) {
      out.addAll(state.zoneAnswers[zoneId] ?? const []);
    }
    return out;
  }

  /// Selecciona / deselecciona una glosa en la zona activa.
  ///
  /// - Si la glosa ya estaba elegida → se quita (deseleccionar).
  /// - Si la zona admite una sola respuesta (`maxPicks == 1`) → la nueva
  ///   glosa reemplaza a la anterior (comportamiento tipo radio).
  /// - Si admite varias y aún no se llegó al tope → se añade.
  /// - Si ya se alcanzó el tope → se ignora.
  ///
  /// NO avanza de pregunta: el cambio de pregunta es explícito vía
  /// [goToNextZone] ("Continuar").
  void toggleAnswer(String gloss) {
    final zoneId = state.activeZoneId;
    if (zoneId == null) return;
    final ctx = ref.read(contextProvider);
    final maxPicks = ctx?.zoneById(zoneId)?.maxPicks ?? 1;

    final current = [...(state.zoneAnswers[zoneId] ?? const <String>[])];
    if (current.contains(gloss)) {
      current.remove(gloss);
    } else if (maxPicks <= 1) {
      current
        ..clear()
        ..add(gloss);
    } else if (current.length < maxPicks) {
      current.add(gloss);
    } else {
      return; // tope alcanzado
    }

    state = state.copyWith(
      zoneAnswers: {...state.zoneAnswers, zoneId: current},
    );
  }

  /// Activa una zona libremente — no hay orden obligatorio.
  void activateZone(String zoneId) {
    final ctx = ref.read(contextProvider);
    if (ctx == null) return;
    if (ctx.zoneById(zoneId) == null) return;

    final visited = {...state.visitedZoneIds, zoneId};
    // Preservar orden de inserción para el árbol conceptual
    final order = [...state.visitedZoneOrder];
    if (!order.contains(zoneId)) order.add(zoneId);

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
      visitedZoneOrder: order,
      zoneAnswers: state.zoneAnswers,
      snapshot: snapshot,
    );
  }

  /// Avanza a la siguiente pregunta de forma **explícita** (botón "Continuar").
  ///
  /// Reemplaza al antiguo auto-avance: el usuario decide cuándo cambiar de
  /// pregunta, tras seleccionar todas las glosas que necesite.
  ///
  /// 1. Si el usuario había retrocedido, avanza a la zona posterior ya
  ///    navegada (conserva el recorrido).
  /// 2. Si está en la última zona navegada, salta a la siguiente zona no
  ///    visitada según la prioridad del motor.
  /// 3. Si no quedan zonas, no hace nada (`hasNextQuestion` será `false`).
  void goToNextZone() {
    final id = state.activeZoneId;
    if (id == null) return;
    final order = state.visitedZoneOrder;
    final idx = order.indexOf(id);
    if (idx >= 0 && idx < order.length - 1) {
      activateZone(order[idx + 1]);
      return;
    }
    for (final p in state.snapshot.orderedZones) {
      if (p.zone.id == state.activeZoneId) continue;
      if (state.visitedZoneIds.contains(p.zone.id)) continue;
      activateZone(p.zone.id);
      return;
    }
  }

  /// Vuelve a la pregunta anterior del recorrido, conservando todas las
  /// respuestas para que el usuario pueda corregirlas o deseleccionarlas.
  void goToPreviousZone() {
    final id = state.activeZoneId;
    if (id == null) return;
    final order = state.visitedZoneOrder;
    final idx = order.indexOf(id);
    if (idx <= 0) return;
    activateZone(order[idx - 1]);
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
      visitedZoneOrder: [ctx.entryZoneId],
      zoneAnswers: const {},
      snapshot: snapshot,
    );
  }
}

final semanticZonesProvider =
    NotifierProvider<SemanticZonesNotifier, SemanticZonesState>(
  SemanticZonesNotifier.new,
);
