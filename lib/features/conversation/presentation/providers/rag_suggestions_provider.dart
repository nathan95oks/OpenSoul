import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';

/// Parecido mínimo del RAG cuando el grafo solo reconoció un tema (abrió un
/// contexto o el selector) sin una pregunta concreta.
const double ragOverTopicScore = 0.6;

/// Cuando el grafo sí eligió preguntas, el RAG solo entra con una pregunta
/// documentada casi literal…
const double ragOverQuestionScore = 0.8;

/// …y con claramente más seguridad que el grafo…
const double ragOverQuestionMargin = 0.15;

/// …o encontrando la pregunta tal cual está documentada: es la evidencia más
/// fuerte que hay, aunque el grafo también esté seguro de la suya.
const double ragLiteralScore = 0.99;

/// Si el RAG tiene más que decir que el grafo sobre este turno.
///
/// El grafo manda cuando reconoce la pregunta con seguridad: sus tarjetas
/// guiadas son más precisas. El RAG entra cuando el grafo no sabe, cuando
/// solo reconoció una palabra del tema («denunciado» abre Denuncias) o
/// cuando el RAG encontró la pregunta casi tal cual y el grafo dudaba
/// («¿Tiene número de inmueble o código catastral?»). Sus tarjetas se ofrecen
/// junto a las guiadas: la persona elige.
bool ragOutranksGraph(ConversationRoute route, double ragScore) {
  switch (route.type) {
    case ConversationRouteType.noSafeRoute:
      return ragScore >= RagRetriever.minScore;
    case ConversationRouteType.contextSelector:
    case ConversationRouteType.directContext:
      return ragScore >= ragOverTopicScore;
    case ConversationRouteType.directQuestion:
    case ConversationRouteType.minimalGraphPath:
      return ragScore >= ragOverQuestionScore &&
          (ragScore >= ragLiteralScore ||
              ragScore >= route.confidence + ragOverQuestionMargin);
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

/// Primero la búsqueda por palabras, en el teléfono y sin red. Solo si no
/// encuentra nada y el grafo tampoco tiene una pregunta segura, se usa lo que
/// devuelva la búsqueda por significado de la Lambda (cuando llegue).
final ragSuggestionsProvider = Provider<List<RagSuggestion>>((ref) {
  final conversation = ref.watch(conversationProvider).conversation;
  final retriever = ref.watch(ragRetrieverProvider);
  final local = ragSuggestionsFor(conversation, retriever);
  if (local.isNotEmpty) return local;

  final pending = conversation.pendingReply;
  final route = pending?.route;
  if (pending == null ||
      pending.pending ||
      route == null ||
      !ragMayAskRemote(route)) {
    return const [];
  }
  final area = retriever == null
      ? null
      : _recentArea(conversation, pending, retriever);
  return ref
          .watch(
            remoteRagSuggestionsProvider((
              pending.message.id,
              pending.message.text,
              area,
            )),
          )
          .asData
          ?.value ??
      const [];
});
