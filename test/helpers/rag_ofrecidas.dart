import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/rag_suggestions_provider.dart';

/// Las respuestas de un trámite documentado que se le ofrecen a la persona
/// sorda para el último turno del oyente, por el camino que usa la app
/// ([ragTramiteRoute]). Vacío si responde el grafo, si el turno aún se
/// traduce o si no hay corpus.
List<({String scenarioId, String text})> ragOfrecidas(
  Conversation conversation,
  RagRetriever? retriever,
) {
  final pending = conversation.pendingReply;
  final route = pending?.route;
  if (retriever == null ||
      pending == null ||
      pending.pending ||
      route == null) {
    return const [];
  }
  final tramite = ragTramiteRoute(conversation, pending, route, retriever);
  if (tramite == null) return const [];
  final scenarioId = tramite.reason.replaceFirst('rag:', '').split('#').first;
  final bank = RagTramites.bankWithTramites();
  return [
    for (final id in tramite.targetQuestionIds)
      for (final option in bank.question(id)?.options ?? const [])
        (scenarioId: scenarioId, text: option.phrase),
  ];
}
