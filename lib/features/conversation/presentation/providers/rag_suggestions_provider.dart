import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';

/// Parecido mínimo del RAG cuando el grafo solo reconoció un tema (abrió un
/// contexto o el selector) sin una pregunta concreta.
const double ragOverTopicScore = 0.6;

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
      return ragScore >= ragOverTopicScore;
    case ConversationRouteType.directQuestion:
    case ConversationRouteType.minimalGraphPath:
      return false;
  }
}

/// Situaciones parecidas para el turno del oyente que espera respuesta.
///
/// Se recalcula con la ruta del turno: si el modelo de desempate encuentra
/// después una ruta, el RAG se vuelve a medir contra ella.
List<RagSuggestion> ragSuggestionsFor(
  Conversation conversation,
  RagRetriever? retriever,
) {
  final pending = conversation.pendingReply;
  if (retriever == null || pending == null || pending.pending) {
    return const [];
  }
  final route = pending.route;
  if (route == null) return const [];
  final found = retriever.suggest(
    pending.message.text,
    preferArea: _recentArea(conversation, pending, retriever),
  );
  if (found.isEmpty || !ragOutranksGraph(route, found.first.score)) {
    return const [];
  }
  return found;
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
}) {
  if (retriever == null) return null;
  final activeTramite = _activeTramite(conversation);
  final local = retriever.suggest(
    pending.message.text,
    preferArea: _recentArea(conversation, pending, retriever),
    preferScenarioId: activeTramite?.scenarioId,
  );
  // Dentro de un trámite abierto, su propia pregunta («¿Tiene una foto de
  // ella?» en trata) sigue el hilo: el grafo no conoce los trámites y
  // abriría la parecida de otro contexto.
  final continues =
      activeTramite != null &&
      local.isNotEmpty &&
      local.first.scenarioId == activeTramite.scenarioId &&
      local.first.score >= ragOverTopicScore;
  final found =
      local.isNotEmpty &&
          (continues || ragOutranksGraph(route, local.first.score))
      ? local
      : ragMayAskRemote(route)
      ? remote
      : const <RagSuggestion>[];
  if (found.isEmpty) return null;
  final best = found.first;
  final turn =
      best.questionTurn ??
      retriever.corpus.questionTurnOf(best.scenarioId, best.text);
  final tramite = RagTramites.ofScenario(best.scenarioId);
  if (turn == null || tramite == null) return null;
  final questionId = RagTramites.questionId(best.scenarioId, turn);
  if (RagTramites.bankWithTramites().question(questionId) == null) return null;
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
