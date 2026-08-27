import 'package:lsb_legal_app/core/domain/entities/generated_step.dart';
import 'package:lsb_legal_app/core/domain/repositories/suggestion_repository.dart';

class SuggestNextStepUseCase {
  final SuggestionRepository repository;

  SuggestNextStepUseCase(this.repository);

  Future<GeneratedStep> call({
    required String contextId,
    required List<String> selected,
    required List<String> candidates,
    String? replyingTo,
  }) {
    if (candidates.isEmpty) return Future.value(GeneratedStep.vacio);
    return repository.suggest(
      contextId: contextId,
      selected: selected,
      candidates: candidates,
      replyingTo: replyingTo,
    );
  }
}
