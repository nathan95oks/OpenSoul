import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';

/// Situaciones parecidas para el turno del oyente que espera respuesta.
///
/// Solo cuando el grafo no lo reconoce (`noSafeRoute`): lo que el grafo
/// resuelve se sigue respondiendo con las tarjetas guiadas, que son más
/// precisas. Si el modelo de desempate encuentra después una ruta, la
/// sugerencia desaparece sola, porque la ruta del turno cambia.
List<RagSuggestion> ragSuggestionsFor(
  Conversation conversation,
  RagRetriever? retriever,
) {
  final pending = conversation.pendingReply;
  if (retriever == null || pending == null || pending.pending) {
    return const [];
  }
  final route = pending.route;
  if (route == null || route.type != ConversationRouteType.noSafeRoute) {
    return const [];
  }
  return retriever.suggest(pending.message.text);
}

final ragSuggestionsProvider = Provider<List<RagSuggestion>>(
  (ref) => ragSuggestionsFor(
    ref.watch(conversationProvider).conversation,
    ref.watch(ragRetrieverProvider),
  ),
);
