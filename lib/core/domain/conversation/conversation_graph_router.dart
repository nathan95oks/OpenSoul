import 'dart:developer' as developer;

import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route_validator.dart';
import 'package:lsb_legal_app/core/domain/conversation/graph_matcher.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';

/// El modelo que rankea rutas candidatas (Bedrock de LSB→Texto/Audio,
/// acción `route`, con su caché S3).
///
/// Recibe solo rutas reales y devuelve la que elige, o `null`. Lo que
/// devuelva se valida después: el modelo no puede crear contextos,
/// preguntas, ranuras ni respuestas.
abstract class GraphRouteModel {
  Future<ConversationRoute?> rank({
    required SemanticTurn turn,
    required List<ConversationRoute> candidates,
    String? activeContextId,
  });
}

/// Decide qué parte del grafo de LSB→Texto/Audio abre la persona sorda para
/// responder a un turno del oyente.
///
/// Consume el [SemanticTurn] que entregó Audio/Texto→LSB: no traduce ni
/// relee el mensaje. Primero reglas deterministas sobre esa lectura y el
/// catálogo; si la ruta es inequívoca no se gasta el modelo. El modelo entra
/// solo cuando quedan varias rutas reales candidatas, y su propuesta pasa
/// por [ConversationRouteValidator]. Si nada es seguro, la ruta es
/// [ConversationRouteType.noSafeRoute]: no se inventa ninguna.
class ConversationGraphRouter {
  /// Versión de las reglas; viaja a la Lambda y forma parte de la clave de
  /// su caché de rutas.
  static const int version = 3;

  final ConversationGraphCatalog catalog;
  final ConversationRouteValidator validator;
  final GraphMatcher matcher;
  final GraphRouteModel? model;

  ConversationGraphRouter(
    this.catalog, {
    this.model,
    double minConfidence = 0.6,
  }) : validator = ConversationRouteValidator(
         catalog,
         minConfidence: minConfidence,
       ),
       matcher = GraphMatcher(catalog);

  /// Ruta con el modelo como desempate, si hace falta y está disponible.
  Future<ConversationRoute> route(
    SemanticTurn turn, {
    String? activeContextId,
    ContextSuggestion? suggestion,
  }) async {
    final fallback = routeDeterministic(
      turn,
      activeContextId: activeContextId,
      suggestion: suggestion,
    );
    final model = this.model;
    if (!fallback.needsModel || model == null || fallback.candidates.isEmpty) {
      return fallback;
    }
    ConversationRoute? proposed;
    try {
      proposed = await model.rank(
        turn: turn,
        candidates: fallback.candidates,
        activeContextId: activeContextId,
      );
    } catch (_) {
      proposed = null;
    }
    final chosen = acceptModelRoute(
      proposed,
      turn: turn,
      fallback: fallback,
      activeContextId: activeContextId,
    );
    _log(turn, chosen);
    return chosen;
  }

  /// Valida la propuesta del modelo. Si no pasa, queda [fallback] (que ya
  /// es seguro) sin volver a pedir el modelo.
  ConversationRoute acceptModelRoute(
    ConversationRoute? proposed, {
    required SemanticTurn turn,
    required ConversationRoute fallback,
    String? activeContextId,
  }) {
    final settled = fallback.copyWith(needsModel: false, candidates: const []);
    if (proposed == null) return settled;
    final validation = validator.validate(
      proposed,
      presupposed: _asked(turn, activeContextId),
    );
    if (!validation.isValid) {
      return settled.copyWith(
        reason: 'propuesta del modelo rechazada: ${validation.rejection}',
      );
    }
    if (!_withinCandidates(validation.route!, fallback.candidates)) {
      return settled.copyWith(
        reason: 'propuesta del modelo fuera de las rutas candidatas',
      );
    }
    final requested = GraphMatcher.requestedSlotsOf(turn);
    final targets = validation.route!.targetQuestionIds;
    final context = validation.route!.targetContextId ?? '';
    // Lo que abre una puerta de la ruta responde con ella.
    final opened = {for (final q in targets) ...catalog.openedBy(context, q)};
    if (!targets.every(
      (q) => catalog.answers(q, requested) || opened.contains(q),
    )) {
      return settled.copyWith(
        reason: 'propuesta del modelo que no responde a lo pedido',
      );
    }
    return validation.route!.copyWith(
      source: proposed.source == RouteSource.deterministic
          ? RouteSource.bedrock
          : proposed.source,
      needsModel: false,
    );
  }

  /// Preguntas que el oyente formuló tal cual: el grafo las reconoce con
  /// seguridad en su lectura.
  Set<String> _asked(SemanticTurn turn, String? activeContextId) => {
    for (final r in matcher.match(turn, activeContextId: activeContextId))
      if (r.score >= GraphMatcher.strongMatch) r.questionId,
  };

  /// Solo con identificadores que el determinista ofreció: el modelo puede
  /// combinar preguntas candidatas, no traer otras.
  bool _withinCandidates(
    ConversationRoute route,
    List<ConversationRoute> candidates,
  ) {
    final questions = {for (final c in candidates) ...c.targetQuestionIds};
    final contexts = {
      for (final c in candidates)
        if (c.targetContextId != null) c.targetContextId!,
    };
    final families = {
      for (final c in candidates)
        if (c.targetFamilyId != null) c.targetFamilyId!,
    };
    final types = {for (final c in candidates) c.type};
    if (!types.contains(route.type) &&
        !(route.type == ConversationRouteType.minimalGraphPath &&
            types.contains(ConversationRouteType.directQuestion))) {
      return false;
    }
    if (!route.targetQuestionIds.every(questions.contains)) return false;
    final context = route.targetContextId;
    if (context != null && !contexts.contains(context)) return false;
    final family = route.targetFamilyId;
    if (family != null &&
        !families.contains(family) &&
        catalog.familyOf(context ?? '') != family) {
      return false;
    }
    return true;
  }

  /// Ruta solo con reglas y datos del grafo.
  ConversationRoute routeDeterministic(
    SemanticTurn turn, {
    String? activeContextId,
    ContextSuggestion? suggestion,
  }) {
    final active =
        activeContextId != null && catalog.hasContext(activeContextId)
        ? activeContextId
        : null;
    // Lo que el oyente pregunta manda: solo cuentan las preguntas que
    // responden a las ranuras pedidas. El tema («robar»), el contexto y las
    // entidades («celular») sitúan o desempatan dentro de ellas; nunca
    // convierten una pregunta por el tiempo en otra por el hecho.
    final requested = GraphMatcher.requestedSlotsOf(turn);
    final matches = [
      for (final r in matcher.match(turn, activeContextId: active))
        if (catalog.answers(r.questionId, requested)) r,
    ];
    final (mentionedContexts, mentionedFamilies) = _mentions(turn);
    var strong = [
      for (final r in matches)
        if (r.score >= GraphMatcher.strongMatch) r,
    ];
    // En una conversación ya situada, lo que el recorrido activo pregunta
    // manda sobre preguntas parecidas de otros contextos («¿Qué tiene?» en
    // un robo no es el número de trámite de un seguimiento). Nombrar otro
    // contexto sí cambia de tema.
    if (active != null && mentionedContexts.every((c) => c == active)) {
      // Una pregunta que no es paso de ningún recorrido también es del
      // activo: se antepone en él.
      final inActive = [
        for (final r in strong)
          if (catalog.isStepOf(active, r.questionId) ||
              catalog.journeysOf(r.questionId).isEmpty)
            r,
      ];
      if (inActive.isNotEmpty) strong = inActive;
    }
    final weak = [
      for (final r in matches)
        if (r.score < GraphMatcher.strongMatch) r,
    ];

    ConversationRoute done(ConversationRoute r) {
      _log(turn, r);
      return r;
    }

    // 1. Preguntas concretas del grafo: esa pregunta o el mínimo recorrido.
    if (strong.isNotEmpty) {
      final place = _placement(
        strong,
        active: active,
        mentionedContexts: mentionedContexts,
        mentionedFamilies: mentionedFamilies,
        suggestion: suggestion,
      );
      if (place.ambiguous.isNotEmpty) {
        // La pregunta vale en varios contextos y nada —ni la conversación ni
        // el turno— dice cuál: no se elige uno a ciegas. Decide la persona
        // (o el modelo, entre esas rutas reales).
        final candidates = [
          for (final c in place.ambiguous)
            ?_questionRoute(strong, context: c, reason: 'candidata en $c'),
        ];
        if (candidates.isNotEmpty) {
          return done(
            _selector(
              'la pregunta vale en varios contextos: '
              '${place.ambiguous.join(', ')}',
            ).copyWith(
              needsModel: true,
              candidates: [
                ...candidates,
                _selector('selector como alternativa'),
              ],
            ),
          );
        }
      }
      final route = place.context == null
          ? null
          : _questionRoute(
              strong,
              context: place.context!,
              reason: 'preguntas del grafo',
            );
      if (route != null) return done(route);
    }

    // 2. Un contexto o una familia nombrados: se abren directamente, aunque
    //    la conversación viniera de otro contexto.
    if (mentionedContexts.isNotEmpty || mentionedFamilies.isNotEmpty) {
      final route = _mentionRoute(mentionedContexts, mentionedFamilies);
      if (route != null) return done(route);
      return done(
        ConversationRoute(
          type: ConversationRouteType.contextSelector,
          confidence: 0.6,
          reason: 'varios contextos nombrados',
          needsModel: true,
          candidates: [
            for (final c in mentionedContexts) _contextCandidate(c),
            for (final f in mentionedFamilies) _familyCandidate(f),
          ],
        ),
      );
    }

    // 3. Pregunta abierta por el motivo de la atención: elegir contexto. Va
    //    antes que las coincidencias débiles, que aquí serían solo ruido de
    //    verbos genéricos. Con la conversación ya situada, un «¿qué…?»
    //    («¿Qué ropa llevaba?») pregunta dentro del tema: siguen las rutas
    //    posibles del recorrido, que el modelo puede elegir.
    if (turn.intent == SemanticIntent.askPurpose && active == null) {
      return done(_selector('pregunta abierta por el motivo de la atención'));
    }

    // 4. Coincidencias débiles: rutas posibles, no seguras.
    if (weak.isNotEmpty) {
      return done(
        ConversationRoute.noSafeRoute(
          reason: 'coincidencia débil con el grafo',
          needsModel: true,
          candidates: [
            for (final r in weak)
              ?_candidate([r], active: active, suggestion: suggestion),
            _selector('selector como alternativa'),
          ],
        ),
      );
    }

    // 5. Lenguaje libre: solo el modelo puede decidir entre intenciones
    //    cercanas del grafo; sin él, no hay ruta segura.
    if (turn.isQuestion || turn.intent == SemanticIntent.askInformation) {
      final candidates = <ConversationRoute>[
        for (final (questionId, scope) in _nearby(turn))
          if (catalog.answers(questionId, requested))
            ?_candidate(
              [
                RequestedQuestion(
                  questionId: questionId,
                  nodeId: '',
                  scope: scope,
                  slots: const [],
                  score: 0,
                ),
              ],
              active: active,
              suggestion: null,
              reason: 'intención cercana',
            ),
      ];
      return done(
        ConversationRoute.noSafeRoute(
          reason: 'ningún nodo del grafo corresponde con seguridad',
          needsModel: candidates.isNotEmpty,
          candidates: candidates.isEmpty
              ? const []
              : [...candidates, _selector('selector como alternativa')],
        ),
      );
    }
    return done(
      const ConversationRoute.noSafeRoute(
        reason: 'el turno no pide una respuesta guiada',
      ),
    );
  }

  /// Contextos y familias nombrados, agrupados por familia. Varias
  /// situaciones de una familia nombradas con la misma pista («denunciar»
  /// vale para todas las denuncias) son la familia; si una tiene una pista
  /// propia dentro de ella («un robo»), manda esa. Nombres de familias
  /// distintas quedan como están: son rutas distintas.
  (Set<String>, Set<String>) _mentions(SemanticTurn turn) {
    final byContext = <String, Set<String>>{};
    final families = <String>{};
    for (final m in turn.mentionedContexts) {
      if (m.isFamily) {
        if (catalog.hasFamily(m.id)) families.add(m.id);
      } else if (catalog.hasContext(m.id)) {
        byContext.putIfAbsent(m.id, () => <String>{}).addAll(m.evidence);
      }
    }
    final byFamily = <String?, List<String>>{};
    for (final c in byContext.keys) {
      byFamily.putIfAbsent(catalog.familyOf(c), () => []).add(c);
    }
    final contexts = <String>{};
    for (final entry in byFamily.entries) {
      final group = entry.value;
      if (group.length == 1 || entry.key == null) {
        contexts.addAll(group);
        continue;
      }
      final specific = [
        for (final c in group)
          if (byContext[c]!.any(
            (cue) => group.every((o) => o == c || !byContext[o]!.contains(cue)),
          ))
            c,
      ];
      if (specific.length == 1) {
        contexts.add(specific.single);
      } else {
        families.add(entry.key!);
      }
    }
    return (contexts, families);
  }

  /// Preguntas cercanas cuando nada coincide con seguridad (para el modelo).
  List<(String, String)> _nearby(SemanticTurn turn) {
    if (turn.source == SemanticTurnSource.clientFallback) {
      return [
        for (final node in catalog.graph.candidates(
          turn.text,
          mode: CardsFlowPurpose.conversationReply,
        ))
          if (node.bankQuestion != null &&
              catalog.hasQuestion(node.bankQuestion!))
            (node.bankQuestion!, node.scope),
      ];
    }
    return matcher.nearby(turn);
  }

  /// La ruta que abre [requests] en [context], validada.
  ConversationRoute? _questionRoute(
    List<RequestedQuestion> requests, {
    required String context,
    required String reason,
    double? minConfidence,
  }) {
    final ids = [for (final r in requests) r.questionId];
    // Una puerta de control que el oyente preguntó («¿Puede describir a los
    // agresores?») se sustituye por las preguntas que abre: pedir la
    // descripción es pedir esos rasgos. La puerta no escribe nada, así que
    // saltarla no responde por la persona sorda; cada rasgo tiene su «No
    // sé».
    final opened = <String>{};
    final targets = <String>[];
    for (final id in ids) {
      final children = catalog.openedBy(context, id);
      if (children.isEmpty) {
        if (!targets.contains(id)) targets.add(id);
        continue;
      }
      for (final child in children) {
        if (opened.add(child) && !targets.contains(child)) targets.add(child);
      }
    }
    final confidence = requests
        .map((r) => r.score)
        .reduce((a, b) => a < b ? a : b);
    final route = ConversationRoute(
      type: targets.length == 1
          ? ConversationRouteType.directQuestion
          : ConversationRouteType.minimalGraphPath,
      targetFamilyId: catalog.familyOf(context),
      targetContextId: context,
      targetQuestionIds: targets,
      requestedSlots: {for (final r in requests) ...r.slots}.toList(),
      confidence: confidence,
      reason: '$reason: ${[for (final r in requests) r.nodeId].join(', ')}',
    );
    final validation =
        (minConfidence == null
                ? validator
                : ConversationRouteValidator(
                    catalog,
                    minConfidence: minConfidence,
                  ))
            .validate(route, presupposed: {...ids, ...opened});
    return validation.route;
  }

  /// Una ruta posible, no segura, para que el modelo elija entre reales.
  ConversationRoute? _candidate(
    List<RequestedQuestion> requests, {
    required String? active,
    required ContextSuggestion? suggestion,
    String reason = 'candidata débil',
  }) {
    final context = _placement(
      requests,
      active: active,
      mentionedContexts: const {},
      mentionedFamilies: const {},
      suggestion: suggestion,
    ).context;
    if (context == null) return null;
    return _questionRoute(
      requests,
      context: context,
      reason: reason,
      minConfidence: 0,
    );
  }

  /// El contexto donde se abren las preguntas pedidas.
  ///
  /// Manda el contexto activo de la conversación si las preguntas son suyas
  /// (o no son de ningún recorrido); después, un contexto nombrado (cambiar
  /// de tema es legítimo); después, otro contexto de la misma familia que el
  /// activo; después, la sugerencia o el único contexto donde valen todas.
  ///
  /// Si nada de eso lo ancla y las preguntas valen en varios contextos
  /// («¿Cuándo ocurrió?» sin conversación previa), [ambiguous] los trae: el
  /// ámbito del nodo del corpus no basta para decidir de qué se habla.
  ({String? context, List<String> ambiguous}) _placement(
    List<RequestedQuestion> requests, {
    required String? active,
    required Set<String> mentionedContexts,
    required Set<String> mentionedFamilies,
    required ContextSuggestion? suggestion,
  }) {
    ({String? context, List<String> ambiguous}) anchored(String? c) =>
        (context: c, ambiguous: const []);
    final ids = [for (final r in requests) r.questionId];
    bool fits(String context) =>
        ids.every((q) => catalog.isStepOf(context, q)) ||
        requests.any((r) => r.scope == context);

    final activeFits =
        active != null &&
        ids.every(
          (q) => catalog.isStepOf(active, q) || catalog.journeysOf(q).isEmpty,
        );
    // Un contexto nombrado explícitamente manda sobre el activo: cambiar de
    // tema («¿Dónde ocurrió el robo?» estando en violencia) es legítimo.
    if (activeFits && mentionedContexts.contains(active)) {
      return anchored(active);
    }
    for (final c in mentionedContexts) {
      if (fits(c)) return anchored(c);
    }
    for (final f in mentionedFamilies) {
      final contexts = catalog.contextsOfFamily(f);
      if (activeFits && contexts.contains(active)) return anchored(active);
      for (final c in contexts) {
        if (requests.any((r) => r.scope == c)) return anchored(c);
      }
      for (final c in contexts) {
        if (fits(c)) return anchored(c);
      }
    }
    if (activeFits) return anchored(active);
    final activeFamily = active == null ? null : catalog.familyOf(active);
    if (activeFamily != null) {
      for (final c in catalog.contextsOfFamily(activeFamily)) {
        if (ids.every((q) => catalog.isStepOf(c, q))) return anchored(c);
      }
    }

    final possible = _possibleContexts(requests);
    final suggested = suggestion?.contextId;
    if (suggested != null && possible.contains(suggested)) {
      return anchored(suggested);
    }
    if (possible.length == 1) return anchored(possible.single);
    final guess = _guessContext(requests, suggestion);
    return (
      context: guess,
      ambiguous: possible.length > 1 ? possible : const [],
    );
  }

  /// Contextos donde valen todas las preguntas: donde son paso del recorrido
  /// o, si no son paso de ninguno, donde las sitúa el corpus.
  List<String> _possibleContexts(List<RequestedQuestion> requests) {
    Set<String>? common;
    List<String> order = const [];
    final scopes = <String>{};
    for (final r in requests) {
      final journeys = catalog.journeysOf(r.questionId);
      if (journeys.isEmpty) {
        if (catalog.hasContext(r.scope)) scopes.add(r.scope);
        continue;
      }
      if (order.isEmpty) order = journeys;
      common = common == null
          ? journeys.toSet()
          : common.intersection(journeys.toSet());
    }
    if (common == null) return scopes.toList();
    final allowed = scopes.isEmpty ? common : common.intersection(scopes);
    return [
      for (final c in order)
        if (allowed.contains(c)) c,
    ];
  }

  /// La elección de siempre cuando nada ancla el contexto: sirve para
  /// ofrecer candidatas al modelo, no para decidir por la persona.
  String? _guessContext(
    List<RequestedQuestion> requests,
    ContextSuggestion? suggestion,
  ) {
    final ids = [for (final r in requests) r.questionId];
    bool isStepEverywhere(String context) => ids.every(
      (q) => catalog.isStepOf(context, q) || catalog.journeysOf(q).isEmpty,
    );
    for (final r in requests) {
      if (catalog.hasContext(r.scope) && isStepEverywhere(r.scope)) {
        return r.scope;
      }
    }
    final withSteps = [
      for (final q in ids) catalog.journeysOf(q),
    ].where((j) => j.isNotEmpty).toList();
    if (withSteps.isNotEmpty) {
      final common = withSteps
          .map((j) => j.toSet())
          .reduce((a, b) => a.intersection(b));
      for (final c in withSteps.first) {
        if (common.contains(c)) return c;
      }
    }
    for (final r in requests) {
      if (catalog.hasContext(r.scope)) return r.scope;
    }
    final suggested = suggestion?.contextId;
    if (suggested != null &&
        catalog.hasContext(suggested) &&
        (ids.every((q) => catalog.isStepOf(suggested, q)) ||
            requests.any((r) => r.scope == suggested))) {
      return suggested;
    }
    for (final q in ids) {
      final journeys = catalog.journeysOf(q);
      if (journeys.isNotEmpty) return journeys.first;
    }
    return null;
  }

  ConversationRoute? _mentionRoute(
    Set<String> mentionedContexts,
    Set<String> mentionedFamilies,
  ) {
    if (mentionedContexts.length == 1) {
      final context = mentionedContexts.single;
      final family = catalog.familyOf(context);
      if (mentionedFamilies.every((f) => f == family)) {
        return validator.validate(_contextCandidate(context)).route;
      }
      return null;
    }
    if (mentionedContexts.isEmpty && mentionedFamilies.length == 1) {
      return validator
          .validate(_familyCandidate(mentionedFamilies.single))
          .route;
    }
    return null;
  }

  ConversationRoute _contextCandidate(String context) => ConversationRoute(
    type: ConversationRouteType.directContext,
    targetFamilyId: catalog.familyOf(context),
    targetContextId: context,
    confidence: 0.8,
    reason: 'contexto nombrado: $context',
  );

  /// Una familia con un solo contexto abre ese contexto; con varios, abre la
  /// familia para que la persona elija dentro (sin pasar por el selector
  /// general).
  ConversationRoute _familyCandidate(String family) {
    final contexts = catalog.contextsOfFamily(family);
    return ConversationRoute(
      type: ConversationRouteType.directContext,
      targetFamilyId: family,
      targetContextId: contexts.length == 1 ? contexts.single : null,
      confidence: 0.75,
      reason: 'familia nombrada: $family',
    );
  }

  ConversationRoute _selector(String reason) => validator
      .validate(
        ConversationRoute(
          type: ConversationRouteType.contextSelector,
          confidence: 0.6,
          reason: reason,
        ),
      )
      .route!;

  /// Por qué gana una ruta: lo pedido, lo nombrado, las candidatas con el
  /// dato que responde cada una y la ruta elegida. Para trazas y pruebas.
  RouteTrace explain(
    SemanticTurn turn, {
    String? activeContextId,
    ContextSuggestion? suggestion,
  }) {
    final requested = GraphMatcher.requestedSlotsOf(turn);
    return RouteTrace(
      hearingText: turn.text,
      requestedSlots: requested.toList(),
      mentionedContexts: [for (final m in turn.mentionedContexts) m.id],
      mentionedEntities: turn.mentionedEntities,
      presupposed: matcher
          .presupposedOf(turn, activeContextId: activeContextId)
          .toList(),
      activeContextId: activeContextId,
      candidates: [
        for (final r in matcher.match(turn, activeContextId: activeContextId))
          RouteTraceCandidate(
            questionId: r.questionId,
            answerSlots: catalog.answerSlotsOf(r.questionId).toList(),
            score: r.score,
            answersRequest: catalog.answers(r.questionId, requested),
          ),
      ],
      route: routeDeterministic(
        turn,
        activeContextId: activeContextId,
        suggestion: suggestion,
      ),
    );
  }

  /// Traza técnica (nunca se muestra a la persona).
  static void _log(SemanticTurn turn, ConversationRoute route) => developer.log(
    'turn=${turn.turnId} semanticTurnSource=${turn.source.name} '
    'requestedSlots=${turn.requestedSlots.join('+')} '
    'routeSource=${route.sourceLabel} route=${route.type.wireName} '
    'context=${route.targetContextId ?? route.targetFamilyId ?? '-'} '
    'questions=${route.targetQuestionIds.join('+')} '
    'reason=${route.reason}',
    name: 'conversation.routing',
  );
}

/// La matriz de depuración de una ruta. Nunca se muestra en la interfaz.
class RouteTrace {
  final String hearingText;
  final List<String> requestedSlots;
  final List<String> mentionedContexts;
  final List<String> mentionedEntities;

  /// Lo que el oyente da por supuesto (una respuesta del recorrido de su
  /// contexto). Orienta; no es un hecho de la persona sorda.
  final List<String> presupposed;
  final String? activeContextId;
  final List<RouteTraceCandidate> candidates;
  final ConversationRoute route;

  const RouteTrace({
    required this.hearingText,
    required this.requestedSlots,
    required this.mentionedContexts,
    required this.mentionedEntities,
    required this.presupposed,
    required this.activeContextId,
    required this.candidates,
    required this.route,
  });

  Map<String, Object?> toJson() => {
    'hearingText': hearingText,
    'requestedSlots': requestedSlots,
    'mentionedContexts': mentionedContexts,
    'mentionedEntities': mentionedEntities,
    'presupposed': presupposed,
    'activeContext': activeContextId,
    'candidates': [for (final c in candidates) c.toJson()],
    'selectedRoute': {
      'type': route.type.wireName,
      'context': route.targetContextId ?? route.targetFamilyId,
      'questions': route.targetQuestionIds,
      'path': route.pathQuestionIds,
      'needsModel': route.needsModel,
    },
    'reason': route.reason,
    'source': route.sourceLabel,
  };

  @override
  String toString() => toJson().toString();
}

class RouteTraceCandidate {
  final String questionId;
  final List<String> answerSlots;
  final double score;
  final bool answersRequest;

  const RouteTraceCandidate({
    required this.questionId,
    required this.answerSlots,
    required this.score,
    required this.answersRequest,
  });

  Map<String, Object?> toJson() => {
    'questionId': questionId,
    'answerSlots': answerSlots,
    'score': double.parse(score.toStringAsFixed(3)),
    'answersRequest': answersRequest,
  };
}
