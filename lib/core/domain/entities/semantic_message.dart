import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';

class SemanticDisambiguation {
  final String original;
  final String meaning;
  final String reason;

  const SemanticDisambiguation({
    required this.original,
    required this.meaning,
    this.reason = '',
  });

  factory SemanticDisambiguation.fromJson(Map<String, dynamic> json) =>
      SemanticDisambiguation(
        original: (json['original'] ?? '').toString(),
        meaning: (json['meaning'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
      );
}

enum SpeakerRole { deaf, hearing }

enum MessageSource { cards, speech, text }

class SemanticMessage {
  final String id;
  final SpeakerRole speaker;
  final MessageSource source;
  final List<String> glosses;
  final String? contextId;
  final ContextSuggestion? contextSuggestion;
  final String? replyToId;
  final List<SemanticDisambiguation> disambiguations;
  final String text;
  final Map<String, dynamic>? intermediateRepresentation;
  final DateTime createdAt;
  final SpeechAct speechAct;

  SemanticMessage({
    this.speechAct = SpeechAct.statement,
    required this.id,
    required this.speaker,
    required this.source,
    required this.glosses,
    required this.text,
    this.contextId,
    this.contextSuggestion,
    this.replyToId,
    this.disambiguations = const [],
    this.intermediateRepresentation,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
