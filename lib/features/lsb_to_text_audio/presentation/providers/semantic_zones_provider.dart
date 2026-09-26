import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_zone.dart';
import 'package:lsb_legal_app/core/domain/services/semantic_navigation_engine.dart';
import 'package:lsb_legal_app/core/domain/services/zone_inference_engine.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

class SemanticZonesState {
  final String? activeZoneId;
  final Set<String> visitedZoneIds;
  final List<String> visitedZoneOrder;
  final Map<String, List<String>> zoneAnswers;

  /// Calificadores (cantidad, deletreo, etc.) asociados a cada glosa
  /// respondida, indexados por zona y luego por glosa. Se guardan aparte de
  /// [zoneAnswers] para que agregar o corregir el detalle de una respuesta no
  /// borre las demás respuestas ya confirmadas de la misma zona, y para que
  /// esos detalles no consuman cupos de `maxPicks`.
  final Map<String, Map<String, List<String>>> zoneQualifiers;
  final NavigationSnapshot snapshot;
  final List<String> requestedZoneIds;

  const SemanticZonesState({
    required this.activeZoneId,
    required this.visitedZoneIds,
    required this.snapshot,
    this.visitedZoneOrder = const [],
    this.zoneAnswers = const {},
    this.zoneQualifiers = const {},
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
    Map<String, Map<String, List<String>>>? zoneQualifiers,
    NavigationSnapshot? snapshot,
    List<String>? requestedZoneIds,
  }) {
    return SemanticZonesState(
      activeZoneId: clearActive ? null : (activeZoneId ?? this.activeZoneId),
      visitedZoneIds: visitedZoneIds ?? this.visitedZoneIds,
      visitedZoneOrder: visitedZoneOrder ?? this.visitedZoneOrder,
      zoneAnswers: zoneAnswers ?? this.zoneAnswers,
      zoneQualifiers: zoneQualifiers ?? this.zoneQualifiers,
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
    Map<String, Map<String, List<String>>> previousQualifiers = const {};
    try {
      final s = state;
      previousActiveId = s.activeZoneId;
      previousVisited = s.visitedZoneIds;
      previousOrder = s.visitedZoneOrder;
      previousAnswers = s.zoneAnswers;
      previousQualifiers = s.zoneQualifiers;
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
      zoneQualifiers: previousQualifiers,
      snapshot: snapshot,
      requestedZoneIds: requested,
    );
  }

  /// Respuestas de [zoneId] intercaladas con los calificadores propios de
  /// cada glosa (p. ej. `PLAZA` seguido de las letras de su nombre escrito).
  List<String> _answersWithQualifiers(String zoneId) {
    final answers = state.zoneAnswers[zoneId] ?? const <String>[];
    if (answers.isEmpty) return const [];
    final qualifiers = state.zoneQualifiers[zoneId] ?? const {};
    final out = <String>[];
    for (final gloss in answers) {
      out.add(gloss);
      out.addAll(qualifiers[gloss] ?? const []);
    }
    return out;
  }

  List<String> orderedGlosses() {
    final out = <String>[];
    for (final zoneId in state.visitedZoneOrder) {
      out.addAll(_answersWithQualifiers(zoneId));
    }
    return out;
  }

  List<String> orderedGlossesMarked() {
    final ctx = ref.read(contextProvider);
    final out = <String>[];
    for (final zoneId in state.visitedZoneOrder) {
      final answers = _answersWithQualifiers(zoneId);
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

    final current = [...(state.zoneAnswers[zoneId] ?? const <String>[])];
    var removedGlosses = const <String>[];
    if (current.contains(gloss)) {
      current.remove(gloss);
      removedGlosses = [gloss];
    } else {
      current.add(gloss);
    }

    var qualifiers = state.zoneQualifiers;
    if (removedGlosses.isNotEmpty) {
      final zoneQualifiers = {...(qualifiers[zoneId] ?? const {})};
      var changed = false;
      for (final g in removedGlosses) {
        if (zoneQualifiers.remove(g) != null) changed = true;
      }
      if (changed) qualifiers = {...qualifiers, zoneId: zoneQualifiers};
    }

    final order = state.visitedZoneOrder;
    final idx = order.indexOf(zoneId);
    List<String> newOrder = order;
    Set<String> newVisited = state.visitedZoneIds;
    Map<String, List<String>> newAnswers = {...state.zoneAnswers, zoneId: current};

    // Solo la familia de preguntas interrogativas (dónde/quién/qué/cuándo)
    // reenruta qué zona sigue según la respuesta: ahí sí tiene sentido
    // invalidar las zonas ya respondidas más adelante si se cambia de
    // pregunta. Aplicar esto a cualquier zona (p. ej. "evidencia" u "hecho"
    // en una denuncia) borraba respuestas ya dadas en zonas sin ninguna
    // relación solo por haber sido visitadas después en el recorrido.
    final esFamiliaInterrogativa =
        ctx?.id == 'preguntas' || zoneId == 'interrogativa';

    if (esFamiliaInterrogativa && idx >= 0 && idx < order.length - 1) {
      final abandoned = order.sublist(idx + 1);
      newOrder = order.sublist(0, idx + 1);
      newVisited = state.visitedZoneIds.difference(abandoned.toSet()).union({zoneId});
      for (final abandonedZone in abandoned) {
        newAnswers.remove(abandonedZone);
      }
    }

    state = state.copyWith(
      visitedZoneOrder: newOrder,
      visitedZoneIds: newVisited,
      zoneAnswers: newAnswers,
      zoneQualifiers: qualifiers,
    );
  }

  bool activeAnswersOf(String gloss) =>
      (state.zoneAnswers[state.activeZoneId] ?? const <String>[]).contains(gloss);

  String? unidadTemporalDe(String gloss) {
    final zona = ref.read(contextProvider)?.zoneById(state.activeZoneId ?? '');
    if (zona == null || !zona.chainTriggers.contains(gloss)) return null;
    // La glosa real del catálogo es "DÍA" (con tilde); la clave sin tilde
    // nunca calzaba y tocar esa tarjeta no abría ningún selector de
    // cantidad, sin aviso alguno (auditoría 2026-09).
    const nombres = {
      'MINUTO': 'minutos', 'HORA': 'horas', 'DÍA': 'días', 'DIA': 'días',
      'SEMANA': 'semanas', 'MES': 'meses', 'ANO': 'años',
    };
    return nombres[gloss];
  }

  /// Asocia [qualifiers] (cantidad, deletreo, color, etc.) a la respuesta
  /// [gloss] de la zona activa, sin tocar ninguna otra respuesta ni detalle
  /// de la misma zona. Reemplaza los calificadores previos de esa glosa en
  /// concreto, si los tenía (p. ej. corregir la cantidad ya elegida).
  void appendQualifiers(String gloss, List<String> qualifiers) {
    final zoneId = state.activeZoneId;
    if (zoneId == null) return;
    final current = state.zoneAnswers[zoneId] ?? const <String>[];
    if (!current.contains(gloss)) return;

    final zoneQualifiers = {...(state.zoneQualifiers[zoneId] ?? const {})};
    if (qualifiers.isEmpty) {
      zoneQualifiers.remove(gloss);
    } else {
      zoneQualifiers[gloss] = qualifiers;
    }

    state = state.copyWith(
      zoneQualifiers: {...state.zoneQualifiers, zoneId: zoneQualifiers},
    );
  }

  /// Calificadores actualmente guardados para [gloss] en la zona activa,
  /// para poder mostrarlos u ofrecer corregirlos.
  List<String> qualifiersOf(String gloss) {
    final zoneId = state.activeZoneId;
    if (zoneId == null) return const [];
    return state.zoneQualifiers[zoneId]?[gloss] ?? const [];
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
      zoneQualifiers: state.zoneQualifiers,
      snapshot: snapshot,
      requestedZoneIds: state.requestedZoneIds,
    );
  }

  void goToNextZone() {
    final id = state.activeZoneId;
    if (id == null) return;

    final requested = state.pendingRequestedZones;
    if (requested.isNotEmpty) {
      activateZone(requested.first);
      return;
    }

    final soloPorCadena = _chainOnlyZoneIds();
    final candidatos = state.snapshot.orderedZones
        .where((p) =>
            p.zone.id != id &&
            !soloPorCadena.contains(p.zone.id))
        .toList();

    final order = state.visitedZoneOrder;
    final idx = order.indexOf(id);

    final topCandidate = candidatos.firstOrNull?.zone.id;
    if (idx >= 0 && idx < order.length - 1) {
      final nextInOrder = order[idx + 1];
      if (topCandidate == null || topCandidate == nextInOrder || state.visitedZoneIds.contains(topCandidate)) {
        activateZone(nextInOrder);
        return;
      }
    }

    for (final p in candidatos) {
      if (state.visitedZoneIds.contains(p.zone.id)) continue;
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

  /// Reinicia el flujo de preguntas del módulo.
  ///
  /// La semántica vive en el flujo guiado ([guidedFlowProvider]); quien
  /// llama aquí (p. ej. la conversación al abrir un encargo nuevo) espera
  /// que el armado empiece limpio, así que se reinicia también.
  void reset() {
    ref.read(guidedFlowProvider.notifier).reset();
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
