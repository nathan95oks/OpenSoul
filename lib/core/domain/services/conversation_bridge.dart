import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

class ReplyPrompt {
  final String question;
  final ContextSuggestion? suggestion;
  final String? activeContextId;

  const ReplyPrompt({
    required this.question,
    this.suggestion,
    this.activeContextId,
  });

  String? get proposedContextId => suggestion?.contextId ?? activeContextId;
}

abstract class ConversationBridge {
  void submitDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
  });
}

class NoConversationBridge implements ConversationBridge {
  const NoConversationBridge();

  @override
  void submitDeclaration({
    required TranslationResult result,
    required List<String> glosses,
    String? contextId,
  }) {}
}
