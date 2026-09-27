import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
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
  final found = retriever.suggest(pending.message.text);
  if (found.isEmpty || !ragOutranksGraph(route, found.first.score)) {
    return const [];
  }
  return found;
}

final ragSuggestionsProvider = Provider<List<RagSuggestion>>(
  (ref) => ragSuggestionsFor(
    ref.watch(conversationProvider).conversation,
    ref.watch(ragRetrieverProvider),
  ),
);
