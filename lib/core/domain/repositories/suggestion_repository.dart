import 'package:lsb_legal_app/core/domain/entities/generated_step.dart';

abstract class SuggestionRepository {
  Future<GeneratedStep> suggest({
    required String contextId,
    required List<String> selected,
    required List<String> candidates,
    String? replyingTo,
  });
}
