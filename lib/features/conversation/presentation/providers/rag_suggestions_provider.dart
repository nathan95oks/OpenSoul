import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/graph_matcher.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';

/// Parecido mínimo del RAG cuando el grafo solo reconoció un tema (abrió un
/// contexto o el selector) sin una pregunta concreta.
const double ragOverTopicScore = 0.6;

/// Parecido de una frase documentada de un trámite que se toma por la misma
/// pregunta dicha (casi literal).
const double ragLiteralScore = 0.95;

/// Si un trámite que documenta la pregunta casi literal le gana a la
/// pregunta del grafo: solo cuando el grafo la reconoció por señas y su
/// español no la respalda ([graphText]: parecido del texto con cada
/// pregunta del grafo). «¿Tiene la denuncia de pérdida?» no es «¿Tiene el
/// número de referencia?» aunque compartan TENER.
bool ragLiteralOutranksGraph(
  ConversationRoute route,
  double ragScore,
  Map<String, double> graphText,
) {
  if (ragScore < ragLiteralScore) return false;
  if (route.type != ConversationRouteType.directQuestion &&
      route.type != ConversationRouteType.minimalGraphPath) {
    return false;
  }
  final support = route.targetQuestionIds.fold(
    0.0,
    (best, q) => math.max(best, graphText[q] ?? 0.0),
  );
  return ragScore >= support;
}

/// Si el RAG tiene más que decir que el grafo sobre este turno.
///
/// Una ruta que ya eligió preguntas es determinista: sus tarjetas guiadas
/// mandan y el RAG no ofrece una respuesta competidora. El RAG entra cuando
/// el grafo no tiene ruta segura, deja un selector de contexto o solo abrió
/// un tema por una palabra suelta («¿Usted fue denunciado o es víctima?»
/// abre Denuncias, pero la respuesta documentada es «Soy la víctima»).
bool ragOutranksGraph(ConversationRoute route, double ragScore) {
  switch (route.type) {
    case ConversationRouteType.noSafeRoute:
      return ragScore >= RagRetriever.minScore;
    case ConversationRouteType.contextSelector:
      if (route.confidence >= ConversationGraphRouter.askedMotiveConfidence) {
        return false;
      }
      return ragScore >= ragOverTopicScore;
    case ConversationRouteType.directContext:
      return route.targetContextId == null && ragScore >= ragOverTopicScore;
    case ConversationRouteType.directQuestion:
    case ConversationRouteType.minimalGraphPath:
      return false;
  }
}

/// El trámite del que se venía hablando: el de las preguntas anteriores del
/// funcionario más recientes que se parecen a alguno. Decide empates en
/// preguntas que valen en muchos trámites («¿Trajo su cédula?»).
String? _recentArea(
  Conversation conversation,
  ConversationTurn pending,
  RagRetriever retriever, {
  int lookBack = 3,
}) {
  final active = _activeTramite(conversation);
  if (active != null) return active.area;
  var seen = 0;
  for (final t in conversation.turns.reversed) {
    if (identical(t, pending) ||
        t.message.id == pending.message.id ||
        t.message.speaker != SpeakerRole.hearing) {
      continue;
    }
    final area = retriever.areaOf(t.message.text);
    if (area != null) return area;
    if (++seen >= lookBack) break;
  }
  return null;
}

RagTramite? _activeTramite(Conversation conversation) {
  final active = conversation.activeContextId;
  if (active == null) return null;
  for (final tramite in RagTramites.all) {
    if (tramite.contextId == active) return tramite;
  }
  return null;
}

/// Tema establecido antes del turno que aún espera respuesta.
///
/// La ruta provisional de [pending] no cuenta: puede ser precisamente la que
/// el RAG deba corregir.
String? topicBeforePending(
  Conversation conversation,
  ConversationTurn pending,
) {
  for (final turn in conversation.turns.reversed) {
    if (identical(turn, pending) || turn.message.id == pending.message.id) {
      continue;
    }
    final context = turn.message.contextId;
    if (context != null && context.isNotEmpty) return context;
    final routed = turn.route?.targetContextId;
    if (turn.message.speaker == SpeakerRole.hearing &&
        routed != null &&
        routed.isNotEmpty) {
      return routed;
    }
  }
  return null;
}

/// La pregunta del trámite documentado que responde [pending], como ruta del
/// módulo de tarjetas: «¿Necesita un duplicado del certificado de
/// matrimonio?» abre el paso de SERECI con sus respuestas documentadas.
///
/// Solo donde el grafo no tiene una ruta segura ([ragOutranksGraph]), o
/// cuando la pregunta es del trámite que ya está abierto: lo demás que el
/// grafo reconoce se sigue respondiendo con sus tarjetas guiadas. Primero
/// la búsqueda por palabras; si no encuentra nada, lo que ya haya devuelto la
/// búsqueda por significado ([remote]). `null` si nada se parece lo
/// suficiente.
ConversationRoute? ragTramiteRoute(
  Conversation conversation,
  ConversationTurn pending,
  ConversationRoute route,
  RagRetriever? retriever, {
  List<RagSuggestion> remote = const [],
  Map<String, double> graphText = const {},
  bool graphSupportsActiveContext = false,
}) {
  if (retriever == null) return null;
  final activeTramite = _activeTramite(conversation);
  final preferred = retriever.suggest(
    pending.message.text,
    preferArea: _recentArea(conversation, pending, retriever),
    preferScenarioId: activeTramite?.scenarioId,
  );
  // El área reciente ordena la conversación, pero no debe ocultar una
  // pregunta casi literal de otra institución.
  final unrestricted = retriever.suggest(pending.message.text);
  final local = [
    ...preferred,
    for (final candidate in unrestricted)
      if (!preferred.any(
        (x) =>
            x.scenarioId == candidate.scenarioId &&
            x.questionTurn == candidate.questionTurn &&
            x.text == candidate.text,
      ))
        candidate,
  ];
  // Dentro de un trámite abierto, su propia pregunta («¿Tiene una foto de
  // ella?» en trata) sigue el hilo: el grafo no conoce los trámites y
  // abriría la parecida de otro contexto.
  final continues =
      activeTramite != null &&
      local.isNotEmpty &&
      local.first.scenarioId == activeTramite.scenarioId &&
      local.first.score >= ragOverTopicScore;
  // La pregunta documentada casi literal, aunque el área del tema ponga
  // antes otra («¿Tiene la denuncia de pérdida?» es de SEGIP aunque se
  // venga hablando de un robo).
  final literal = [
    for (final x in local)
      if (x.score >= ragLiteralScore) x,
  ];
  // Una pregunta resuelta dentro del contexto no RAG que ya se atiende
  // conserva ese hilo, aunque la misma frase exista en un trámite.
  final topic = topicBeforePending(conversation, pending);
  final graphKeepsActiveContext =
      activeTramite == null &&
      topic != null &&
      (graphSupportsActiveContext ||
          (route.targetContextId == topic &&
              route.targetQuestionIds.isNotEmpty) ||
          route.candidates.any(
            (candidate) =>
                candidate.targetContextId == topic &&
                candidate.targetQuestionIds.any(
                  (question) =>
                      (graphText[question] ?? 0) >= GraphMatcher.weakMatch,
                ),
          ));
  final found = graphKeepsActiveContext
      ? const <RagSuggestion>[]
      : literal.isNotEmpty &&
            !graphKeepsActiveContext &&
            ragLiteralOutranksGraph(route, literal.first.score, graphText)
      ? [...literal, ...local.where((x) => !literal.contains(x))]
      : local.isNotEmpty &&
            (continues || ragOutranksGraph(route, local.first.score))
      ? local
      : ragMayAskRemote(route)
      ? remote
      : const <RagSuggestion>[];
  // Una afirmación del funcionario («Para violencia tiene que ir a la
  // FELCV.») solo puede ser una indicación documentada: abrir una pregunta
  // («¿Hay testigos del robo?») haría contestar algo que nadie preguntó.
  final text = pending.message.text;
  final statement = !text.contains('?') && RegExp(r'[.!]').hasMatch(text);
  final bank = RagTramites.bankWithTramites();
  for (final best in found) {
    final turn =
        best.questionTurn ??
        retriever.corpus.questionTurnOf(best.scenarioId, best.text);
    final tramite = RagTramites.ofScenario(best.scenarioId);
    if (turn == null || tramite == null) continue;
    final questionId = RagTramites.questionId(best.scenarioId, turn);
    final question = bank.question(questionId);
    if (question == null) continue;
    if (statement && !question.isIndication) continue;
    // Y una pregunta («¿Fue con violencia?») no es una indicación que se
    // contesta «Entendido».
    if (text.contains('?') && question.isIndication) continue;
    return _tramiteRoute(best, turn, tramite);
  }
  return null;
}

ConversationRoute _tramiteRoute(
  RagSuggestion best,
  int turn,
  RagTramite tramite,
) {
  // «¿Cuándo y dónde ocurrió?» son dos preguntas, cada una con sus tarjetas.
  final questionIds = RagTramites.questionIdsOfTurn(best.scenarioId, turn);
  return ConversationRoute(
    type: ConversationRouteType.directQuestion,
    targetFamilyId: 'tramites',
    targetContextId: tramite.contextId,
    targetQuestionIds: questionIds,
    // La hizo el oyente: se responde aunque en el recorrido dependa de una
    // respuesta anterior (una ramificación del escenario).
    presupposedQuestionIds: questionIds,
    pathQuestionIds: questionIds,
    confidence: best.score,
    reason: 'rag:${best.scenarioId}#$turn',
  );
}

/// La consulta por significado de [pending] (una por turno).
RagRemoteQuery ragRemoteQueryFor(
  Conversation conversation,
  ConversationTurn pending,
  RagRetriever? retriever,
) => (
  pending.message.id,
  pending.message.text,
  retriever == null ? null : _recentArea(conversation, pending, retriever),
);

/// Si vale la pena preguntar a la Lambda por significado: solo cuando el
/// grafo no tiene una pregunta segura (no sabe, o abrió un contexto por una
/// palabra suelta). Con preguntas del grafo o un selector ya hay un camino
/// para responder.
bool ragMayAskRemote(ConversationRoute route) =>
    route.type == ConversationRouteType.noSafeRoute ||
    route.type == ConversationRouteType.directContext;

/// Consulta por significado de un turno: (id del turno, texto, área del
/// tema). El id hace que cada turno se consulte una sola vez.
typedef RagRemoteQuery = (String turnId, String text, String? preferArea);

final remoteRagSuggestionsProvider =
    FutureProvider.family<List<RagSuggestion>, RagRemoteQuery>((ref, q) async {
      final remote = ref.watch(remoteRagProvider);
      if (remote == null) return const [];
      return remote.consult(q.$2, preferArea: q.$3);
    });
