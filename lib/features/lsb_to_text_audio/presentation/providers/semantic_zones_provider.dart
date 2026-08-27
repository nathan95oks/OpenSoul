import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_zone.dart';
import 'package:lsb_legal_app/core/domain/services/semantic_navigation_engine.dart';
import 'package:lsb_legal_app/core/domain/services/zone_inference_engine.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

class SemanticZonesState {
  final String? activeZoneId;
  final Set<String> visitedZoneIds;
  final List<String> visitedZoneOrder;
  final Map<String, List<String>> zoneAnswers;
  final NavigationSnapshot snapshot;
  final List<String> requestedZoneIds;

  const SemanticZonesState({
    required this.activeZoneId,
    required this.visitedZoneIds,
    required this.snapshot,
    this.visitedZoneOrder = const [],
    this.zoneAnswers = const {},
    this.requestedZoneIds = const [],
  });

  List<String> get pendingRequestedZones => [
        for (final id in requestedZoneIds)
          if (!visitedZoneIds.contains(id)) id,
      ];

  int get picksInActiveZone =>
      activeZoneId == null ? 0 : (zoneAnswers[activeZoneId]?.length ?? 0);

  SemanticZone? get activeZone {
    if (activeZoneId == null) return null;
    for (final p in snapshot.orderedZones) {
      if (p.zone.id == activeZoneId) return p.zone;
    }
    return null;
  }

  List<String> get activeAnswers =>
      activeZoneId == null ? const [] : (zoneAnswers[activeZoneId] ?? const []);

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

  bool get canGoBack {
    final id = activeZoneId;
    return id != null && visitedZoneOrder.indexOf(id) > 0;
  }

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
    List<String>? requestedZoneIds,
  }) {
    return SemanticZonesState(
      activeZoneId: clearActive ? null : (activeZoneId ?? this.activeZoneId),
      visitedZoneIds: visitedZoneIds ?? this.visitedZoneIds,
      visitedZoneOrder: visitedZoneOrder ?? this.visitedZoneOrder,
      zoneAnswers: zoneAnswers ?? this.zoneAnswers,
      snapshot: snapshot ?? this.snapshot,
      requestedZoneIds: requestedZoneIds ?? this.requestedZoneIds,
    );
  }
}

final _engineProvider =
    Provider<SemanticNavigationEngine>((_) => const SemanticNavigationEngine());

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
    } on Error catch (_) {}

    final pending = ref.watch(pendingReplyProvider);
    final requested = pending == null
        ? const <String>[]
        : const ZoneInferenceEngine()
            .zonesFor(context: ctx, text: pending.question);

    final activeId = previousActiveId ??
        (requested.isNotEmpty ? requested.first : ctx.entryZoneId);
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
      requestedZoneIds: requested,
    );
  }

  List<String> orderedGlosses() {
    final out = <String>[];
    for (final zoneId in state.visitedZoneOrder) {
      out.addAll(state.zoneAnswers[zoneId] ?? const []);
    }
    return out;
  }

  List<String> orderedGlossesMarked() {
    final ctx = ref.read(contextProvider);
    final out = <String>[];
    for (final zoneId in state.visitedZoneOrder) {
      final answers = state.zoneAnswers[zoneId] ?? const [];
      if (answers.isEmpty) continue;
      final lead = ctx?.zoneById(zoneId)?.leadGloss;
      if (lead != null) out.add(lead);
      out.addAll(answers);
    }
    return out;
  }

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
      return;
    }

    state = state.copyWith(
      zoneAnswers: {...state.zoneAnswers, zoneId: current},
    );
  }

  bool activeAnswersOf(String gloss) =>
      (state.zoneAnswers[state.activeZoneId] ?? const <String>[]).contains(gloss);

  String? unidadTemporalDe(String gloss) {
    final zona = ref.read(contextProvider)?.zoneById(state.activeZoneId ?? '');
    if (zona == null || !zona.chainTriggers.contains(gloss)) return null;
    const nombres = {
      'MINUTO': 'minutos', 'HORA': 'horas', 'DIA': 'días',
      'SEMANA': 'semanas', 'MES': 'meses', 'ANO': 'años',
    };
    return nombres[gloss];
  }

  void appendQualifiers(String gloss, List<String> qualifiers) {
    final zoneId = state.activeZoneId;
    if (zoneId == null || qualifiers.isEmpty) return;

    final current = [...(state.zoneAnswers[zoneId] ?? const <String>[])];
    final at = current.lastIndexOf(gloss);
    if (at < 0) return;

    final hasta = current.length;
    current.removeRange(at + 1, hasta);
    current.insertAll(at + 1, qualifiers);

    state = state.copyWith(
      zoneAnswers: {...state.zoneAnswers, zoneId: current},
    );
  }

  void activateZone(String zoneId) {
    final ctx = ref.read(contextProvider);
    if (ctx == null) return;
    if (ctx.zoneById(zoneId) == null) return;

    final visited = {...state.visitedZoneIds, zoneId};
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
      requestedZoneIds: state.requestedZoneIds,
    );
  }

  void goToNextZone() {
    final id = state.activeZoneId;
    if (id == null) return;

    final order = state.visitedZoneOrder;
    final idx = order.indexOf(id);
    if (idx >= 0 && idx < order.length - 1) {
      activateZone(order[idx + 1]);
      return;
    }
    final requested = state.pendingRequestedZones;
    if (requested.isNotEmpty) {
      activateZone(requested.first);
      return;
    }
    final soloPorCadena = _chainOnlyZoneIds();
    for (final p in state.snapshot.orderedZones) {
      if (p.zone.id == state.activeZoneId) continue;
      if (state.visitedZoneIds.contains(p.zone.id)) continue;
      if (soloPorCadena.contains(p.zone.id)) continue;
      activateZone(p.zone.id);
      return;
    }
  }

  Set<String> _chainOnlyZoneIds() {
    final context = ref.read(contextProvider);
    if (context == null) return const {};
    return {
      for (final z in context.zones)
        if (z.chainZoneId != null) z.chainZoneId!,
    };
  }

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
    final pending = ref.read(pendingReplyProvider);
    final requested = pending == null
        ? const <String>[]
        : const ZoneInferenceEngine()
            .zonesFor(context: ctx, text: pending.question);
    final entry = requested.isNotEmpty ? requested.first : ctx.entryZoneId;

    final snapshot = engine.compute(
      context: ctx,
      selectedGlosses: const [],
      selectedCards: const [],
      activeZoneId: entry,
      visitedZoneIds: {entry},
    );
    state = SemanticZonesState(
      activeZoneId: entry,
      visitedZoneIds: {entry},
      visitedZoneOrder: [entry],
      zoneAnswers: const {},
      snapshot: snapshot,
      requestedZoneIds: requested,
    );
  }
}

final semanticZonesProvider =
    NotifierProvider<SemanticZonesNotifier, SemanticZonesState>(
  SemanticZonesNotifier.new,
);
