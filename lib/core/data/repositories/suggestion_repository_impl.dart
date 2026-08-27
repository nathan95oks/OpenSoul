import 'package:lsb_legal_app/core/data/datasources/remote_suggestion_datasource.dart';
import 'package:lsb_legal_app/core/domain/entities/generated_step.dart';
import 'package:lsb_legal_app/core/domain/repositories/suggestion_repository.dart';

class SuggestionRepositoryImpl implements SuggestionRepository {
  final RemoteSuggestionDataSource remoteDataSource;

  SuggestionRepositoryImpl(this.remoteDataSource);

  @override
  Future<GeneratedStep> suggest({
    required String contextId,
    required List<String> selected,
    required List<String> candidates,
    String? replyingTo,
  }) {
    return remoteDataSource.suggest(
      contextId: contextId,
      selected: selected,
      candidates: candidates,
      replyingTo: replyingTo,
    );
  }
}
