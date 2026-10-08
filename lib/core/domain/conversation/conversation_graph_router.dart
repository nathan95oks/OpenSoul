import 'dart:developer' as developer;

import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route_validator.dart';
import 'package:lsb_legal_app/core/domain/conversation/graph_matcher.dart';
import 'package:lsb_legal_app/core/domain/conversation/lsb_gloss_semantics.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';
import 'package:lsb_legal_app/core/domain/services/context_inference_engine.dart';
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
  static const int version = 4;

  /// Una pregunta que ya pertenece al recorrido activo necesita menos
  /// evidencia que una pregunta que abriría un contexto nuevo. Solo se usa
  /// cuando queda una única coincidencia dentro de ese recorrido.
  static const double contextualQuestionConfidence = 0.5;

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
        if (r.score >= GraphMatcher.exactMatch ||
            catalog.answers(r.questionId, requested))
          r,
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

    // Apertura de ventanilla («¿En qué le puedo ayudar?», «Cuénteme qué le
    // pasó»): sin un caso abierto, la persona elige el motivo. No se adivina
    // un trámite por «ayudar» o «pasó».
    if (active == null &&
        turn.mentionedContexts.isEmpty &&
        requested.difference(const {'polarity'}).isEmpty &&
        _opensService(turn.text)) {
      return done(
        _selector(
          'apertura de ventanilla: elegir motivo',
          confidence: askedMotiveConfidence,
        ),
      );
    }

    // Una instrucción puede tener palabras parecidas a una pregunta del
    // banco («Firme aquí» se parecía a «¿La tiene aquí?»). El grafo no debe
    // convertirla en pregunta. Queda disponible el RAG para instrucciones
    // documentadas que sí esperan una respuesta («pase a otra oficina»).
    if (!_expectsAnswer(turn)) {
      return done(
        const ConversationRoute.noSafeRoute(
          reason: 'el turno es una indicación, no una pregunta',
        ),
      );
    }

    // 0. El oyente pregunta por la clase de atención o nombra el papel de la
    //    persona en un contexto, sin pedir un dato.
    if (requested.difference(const {'polarity'}).isEmpty) {
      // «¿Qué trámite desea realizar?», «¿Qué denuncia quiere presentar?»:
      // la respuesta es elegir el contexto.
      if (_asksWhichKind(turn.text)) {
        return done(
          _selector(
            'pregunta qué clase de atención',
            confidence: askedMotiveConfidence,
          ),
        );
      }
      // «¿Usted fue testigo de un crimen?»: ser testigo es el contexto
      // «Declaración y testimonio».
      final role = _roleContext(turn.text);
      if (role != null) {
        final route = validator.validate(_contextCandidate(role)).route;
        if (route != null) return done(route);
      }
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
            ?_questionRoute(
              strong,
              context: c,
              reason: 'candidata en $c',
              text: turn.text,
            ),
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
              text: turn.text,
            );
      if (route != null) return done(route);
    }

    // El contexto ya confirmado también desambigua una coincidencia apenas
    // por debajo del umbral global. No sirve para cambiar de tema y exige una
    // sola pregunta del recorrido activo, para no elegir entre alternativas.
    if (active != null &&
        mentionedContexts.isEmpty &&
        mentionedFamilies.isEmpty) {
      final contextual = [
        for (final r in weak)
          if (catalog.isStepOf(active, r.questionId)) r,
      ];
      if (contextual.length == 1 &&
          contextual.single.score >= contextualQuestionConfidence) {
        final route = _questionRoute(
          contextual,
          context: active,
          reason: 'pregunta respaldada por el contexto activo',
          minConfidence: contextualQuestionConfidence,
          text: turn.text,
        );
        if (route != null) return done(route);
      }
    }

    // 2. Un contexto o una familia nombrados: se abren directamente, aunque
    //    la conversación viniera de otro contexto.
    if (mentionedContexts.isNotEmpty || mentionedFamilies.isNotEmpty) {
      final route = _mentionRoute(mentionedContexts, mentionedFamilies);
      if (route != null) {
        // «¿Las amenazas le llegaron por algún medio?» nombra el contexto,
        // pero pregunta algo dentro de él: las preguntas que el turno sugiere
        // en ese contexto quedan como candidatas para el modelo. Sin modelo
        // se abre el contexto desde el principio, como siempre.
        final context = route.targetContextId;
        final inside = context == null
            ? const <ConversationRoute>[]
            : [
                for (final r in weak)
                  if (catalog.isStepOf(context, r.questionId))
                    ?_questionRoute(
                      [r],
                      context: context,
                      reason: 'candidata en el contexto nombrado',
                      minConfidence: 0,
                      text: turn.text,
                    ),
              ];
        if (turn.isQuestion && inside.isNotEmpty) {
          return done(
            route.copyWith(needsModel: true, candidates: [...inside, route]),
          );
        }
        return done(route);
      }
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
    //    verbos genéricos.
    if (turn.intent == SemanticIntent.askPurpose) {
      return done(
        _selector(
          'pregunta abierta por el motivo de la atención',
          confidence: askedMotiveConfidence,
        ),
      );
    }

    // 4. Coincidencias débiles: rutas posibles, no seguras.
    if (weak.isNotEmpty) {
      return done(
        ConversationRoute.noSafeRoute(
          reason: 'coincidencia débil con el grafo',
          needsModel: true,
          candidates: [
            for (final r in weak)
              ?_candidate(
                [r],
                active: active,
                suggestion: suggestion,
                text: turn.text,
              ),
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
      if (_negatesMention(turn.text, m.evidence)) continue;
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

  /// Una mención usada para descartar un tema no lo activa. Se limita a
  /// verbos de discurso para no confundir «No sabe quién robó» con una
  /// negación del contexto de robo.
  static bool _negatesMention(String text, Iterable<String> evidence) {
    final cues = {
      for (final raw in evidence)
        for (final token in GraphMatcher.plainText(raw).split(' '))
          if (token.isNotEmpty) token,
    };
    if (cues.isEmpty) return false;
    for (final clause in GraphMatcher.plainText(
      text,
    ).split(RegExp(r'[,;.!?]+'))) {
      final words = clause.split(' ').where((w) => w.isNotEmpty).toList();
      final no = words.indexOf('no');
      if (no < 0) continue;
      final cue = words.indexWhere(
        (word) => cues.any((e) => word.startsWith(e) || e.startsWith(word)),
        no + 1,
      );
      if (cue < 0) continue;
      final metalinguistic = words
          .sublist(no + 1, cue)
          .any(
            (word) =>
                const ['pregunt', 'habl', 'refer', 'trat'].any(word.startsWith),
          );
      if (metalinguistic) return true;
    }
    return false;
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
    String text = '',
  }) {
    final ids = [for (final r in requests) r.questionId];
    // Una puerta de control que el oyente preguntó («¿Puede describir a los
    // agresores?») se sustituye por las preguntas que abre: pedir la
    // descripción es pedir esos rasgos. La puerta no escribe nada, así que
    // saltarla no responde por la persona sorda; cada rasgo tiene su «No
    // sé».
    final opened = <String>{};
    final targets = <String>[];
    // Una pregunta compuesta («¿Tiene la factura o la caja?») se responde con
    // sus partes: se abren todas, porque el oyente preguntó por cada una.
    final parts = <String>{};
    for (final id in ids) {
      final own = catalog.partsOf(id);
      if (own.isNotEmpty) {
        for (final p in own) {
          if (parts.add(p) && !targets.contains(p)) targets.add(p);
        }
        continue;
      }
      final children = catalog.openedBy(context, id);
      if (children.isEmpty) {
        if (!targets.contains(id)) targets.add(id);
        continue;
      }
      for (final child in children) {
        if (opened.add(child) && !targets.contains(child)) targets.add(child);
      }
    }
    // Si el texto nombra uno de los rasgos que abre la puerta («¿Qué ropa
    // llevaba?»), se abre ese y no toda la descripción. Pedir la ropa
    // («¿qué llevaba puesto?») es el rasgo cuya pregunta habla de ropa.
    if (opened.length > 1 && LsbGlossSemantics.asksClothing(text)) {
      final clothing = [
        for (final c in opened)
          if (catalog.replyEntries.any(
            (e) =>
                e.questionId == c &&
                LsbGlossSemantics.speaksOfClothing(e.phrase),
          ))
            c,
      ];
      if (clothing.length == 1) {
        targets.removeWhere((t) => opened.contains(t) && t != clothing.single);
        opened
          ..clear()
          ..add(clothing.single);
      }
    }
    if (opened.length > 1 && text.isNotEmpty) {
      final scores = matcher.textScores(text);
      final ranked = [for (final c in opened) (c, scores[c] ?? 0.0)]
        ..sort((a, b) => b.$2.compareTo(a.$2));
      if (ranked.first.$2 >= _namedChildMatch &&
          ranked.first.$2 > ranked[1].$2) {
        final keep = ranked.first.$1;
        targets.removeWhere((t) => opened.contains(t) && t != keep);
        opened
          ..clear()
          ..add(keep);
      }
    }
    // Cada «qué + núcleo» del español («¿Cuándo y a QUÉ HORA…?») es su
    // propia pregunta si el recorrido la tiene: la hora no es el «cuándo».
    // Si es el único modo en que se pregunta ese dato («¿A qué hora fue?»),
    // reemplaza a la pregunta general del mismo dato; con «cuándo» dicho
    // aparte, van las dos.
    final heads = <String>{};
    final words = _plainWords(text);
    for (final head in _askedHeads(text)) {
      final own = _ownHeadQuestion(context, head);
      if (own == null) continue;
      final slot = LsbGlossSemantics.spokenHeadSlots[head.split(' ').last];
      final saidApart = words.any(
        (w) => LsbGlossSemantics.spokenInterrogativeSlots[w] == slot,
      );
      if (!saidApart) {
        targets.removeWhere(
          (t) =>
              t != own &&
              !heads.contains(t) &&
              catalog.answerSlotsOf(t).contains(slot),
        );
      }
      if (!targets.contains(own)) targets.add(own);
      heads.add(own);
      // «¿Cuándo y a qué hora…?»: el «cuándo» dicho aparte también es su
      // pregunta, aunque la coincidencia del grafo ya fuera la hora.
      if (saidApart &&
          !targets.any(
            (t) => t != own && catalog.answerSlotsOf(t).contains(slot),
          )) {
        for (final w in words) {
          if (LsbGlossSemantics.spokenInterrogativeSlots[w] != slot) continue;
          final apart = _ownHeadQuestion(context, w);
          if (apart != null && !targets.contains(apart)) {
            targets.add(apart);
            heads.add(apart);
          }
        }
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
            .validate(
              route,
              presupposed: {...ids, ...opened, ...parts, ...heads},
            );
    return validation.route;
  }

  /// Una ruta posible, no segura, para que el modelo elija entre reales.
  ConversationRoute? _candidate(
    List<RequestedQuestion> requests, {
    required String? active,
    required ContextSuggestion? suggestion,
    String reason = 'candidata débil',
    String text = '',
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
      text: text,
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

  /// Parecido mínimo del texto con un rasgo para abrir solo ese rasgo.
  static const double _namedChildMatch = 0.45;

  static const _copulas = {'FUE', 'ES', 'ERES', 'FUISTE', 'SIDO', 'ERA'};

  static List<String> _plainWords(String text) => [
    for (final w in GraphMatcher.plainText(text).split(' '))
      if (w.isNotEmpty) w.toUpperCase(),
  ];

  static bool _hasStem(Iterable<String> words, String stem) =>
      words.any((w) => w.startsWith(stem));

  bool _expectsAnswer(SemanticTurn turn) {
    final words = _plainWords(turn.text);
    // El dictado por voz llega sin puntuación («vino a consultar el estado
    // de su caso»): no dice si es una afirmación. Solo un texto puntuado
    // sin signos de pregunta («Firme aquí, por favor.») es una indicación.
    if (!RegExp(r'[.!¡?¿]').hasMatch(turn.text)) return true;
    return turn.isQuestion ||
        turn.intent == SemanticIntent.askPurpose ||
        turn.intent == SemanticIntent.askInformation ||
        LsbGlossSemantics.spokenSlotsOf(turn.text).isNotEmpty ||
        _hasStem(words, 'CUENT') ||
        _hasStem(words, 'EXPLIC') ||
        _hasStem(words, 'DESCRIB');
  }

  /// Los «qué/cuál + núcleo» que pregunta el español: «QUE HORA», «QUE DIA».
  static List<String> _askedHeads(String text) {
    final words = [
      for (final w in _plainWords(text)) LsbGlossSemantics.spokenWord(w),
    ];
    return [
      for (var i = 0; i + 1 < words.length; i++)
        if (const {'QUE', 'CUAL'}.contains(words[i]) &&
            LsbGlossSemantics.spokenHeadSlots.containsKey(words[i + 1]))
          '${words[i]} ${words[i + 1]}',
    ];
  }

  /// La pregunta de [context] que pregunta por [head] con las mismas
  /// palabras («¿A qué hora ocurrió?» para «QUE HORA»): un paso de su
  /// recorrido o una pregunta real del funcionario en ese contexto. Si el
  /// contexto no tiene una, una pregunta general que no es de ningún otro
  /// recorrido (la hora no es exclusiva del robo).
  String? _ownHeadQuestion(String context, String head) {
    // La más general: la frase más corta que lo pregunta («¿Cuándo
    // ocurrió?», no «¿Cuándo presentó la denuncia?»).
    String? shortest(bool Function(ReplyEntry) where) {
      ReplyEntry? best;
      var size = 0;
      for (final e in catalog.replyEntries) {
        final words = _plainWords(e.phrase);
        if (!where(e) || !' ${words.join(' ')} '.contains(' $head ')) continue;
        if (best == null || words.length < size) {
          best = e;
          size = words.length;
        }
      }
      return best?.questionId;
    }

    return shortest(
          (e) => e.scope == context || catalog.isStepOf(context, e.questionId),
        ) ??
        shortest((e) => catalog.journeysOf(e.questionId).isEmpty);
  }

  /// Una fórmula de apertura de ventanilla: ofrecer ayuda («¿En qué le
  /// puedo ayudar/servir?») o pedir el relato («Cuénteme qué le pasó»,
  /// «¿Qué le pasó?»). Verbos de una clase cerrada; sin contenido propio.
  bool _opensService(String text) {
    final words = _plainWords(text);
    bool stem(String s) => _hasStem(words, s);
    final asks = words.contains('QUE') || words.contains('CUAL');
    final offersHelp = (stem('AYUD') || stem('SIRV') || stem('SERVIR')) && asks;
    final asksStory =
        (stem('CUENT') || stem('CONT')) && (stem('PAS') || stem('OCURR')) ||
        _asksWhatHappened(words);
    return offersHelp || asksStory;
  }

  /// «¿Qué (le) pasó?»: QUÉ interrogativo seguido del verbo. «Lo que pasó»
  /// es una relativa («¿Usted fue testigo de lo que pasó?») y no pide el
  /// relato.
  static bool _asksWhatHappened(List<String> words) {
    const clitics = {'LE', 'LES', 'TE', 'SE', 'ME', 'HA', 'HAN'};
    for (var i = 0; i < words.length; i++) {
      if (words[i] != 'QUE' || (i > 0 && words[i - 1] == 'LO')) continue;
      var j = i + 1;
      while (j < words.length && clitics.contains(words[j])) {
        j++;
      }
      if (j < words.length &&
          (words[j].startsWith('PAS') ||
              words[j].startsWith('OCURRI') ||
              words[j].startsWith('SUCEDI'))) {
        return true;
      }
    }
    return false;
  }

  /// «¿Qué X…?» donde X nombra una clase de contexto: pide elegirlo.
  bool _asksWhichKind(String text) {
    final words = _plainWords(text);
    var i = 0;
    while (i < words.length &&
        LsbGlossSemantics.questionPrepositions.contains(words[i])) {
      i++;
    }
    if (i + 1 >= words.length) return false;
    if (!const {'QUE', 'CUAL', 'CUALES'}.contains(words[i])) return false;
    return spanishContentStems(words[i + 1]).any(catalog.kindStems.contains);
  }

  /// El contexto cuyo papel se atribuye al interlocutor tras un verbo
  /// copulativo («fue testigo»), si es uno solo.
  String? _roleContext(String text) {
    final words = _plainWords(text);
    final found = <String>{};
    for (var i = 0; i + 1 < words.length; i++) {
      if (!_copulas.contains(words[i])) continue;
      final stems = spanishContentStems(words[i + 1]);
      for (final e in catalog.roleStems.entries) {
        if (stems.any(e.value.contains)) found.add(e.key);
      }
    }
    return found.length == 1 ? found.single : null;
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

  /// Confianza del selector cuando el oyente pidió el motivo («¿En qué le
  /// puedo ayudar?», «¿Qué le pasó?», «¿Qué trámite desea?»): elegir el
  /// contexto es la respuesta, no un tema reconocido a medias. Un trámite
  /// del RAG no lo reemplaza: sin caso abierto sería adivinar uno.
  static const double askedMotiveConfidence = 0.9;

  ConversationRoute _selector(String reason, {double confidence = 0.6}) =>
      validator
          .validate(
            ConversationRoute(
              type: ConversationRouteType.contextSelector,
              confidence: confidence,
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
