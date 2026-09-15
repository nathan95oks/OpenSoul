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

/// Una opción concreta que la persona puede elegir para resolver
/// [PendingClarification.term] (p. ej. "Vehículo" para el término "AUTO").
class ClarificationOption {
  final String id;
  final String label;

  const ClarificationOption({required this.id, required this.label});

  factory ClarificationOption.fromJson(Map<String, dynamic> json) =>
      ClarificationOption(
        id: (json['id'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
      );
}

/// Una decisión de significado pendiente que la persona emisora tiene que
/// resolver antes de que la traducción se dé por completa (sección 4/5 del
/// encargo "Audio/Texto -> LSB"): a diferencia de [SemanticDisambiguation]
/// (una explicación posterior de lo que ya se decidió), esto es una pregunta
/// sin responder todavía, con sus alternativas.
class PendingClarification {
  final String term;
  final String question;
  final List<ClarificationOption> options;

  const PendingClarification({
    required this.term,
    required this.question,
    required this.options,
  });

  factory PendingClarification.fromJson(Map<String, dynamic> json) =>
      PendingClarification(
        term: (json['term'] ?? '').toString(),
        question: (json['question'] ?? '').toString(),
        options: [
          for (final o in (json['options'] as List? ?? const []))
            ClarificationOption.fromJson(Map<String, dynamic>.from(o as Map)),
        ],
      );
}

/// Estado del SIGNIFICADO, separado del estado de la REPRESENTACIÓN en LSB
/// (sección 7 del encargo): tener uno resuelto no resuelve el otro.
enum SemanticStatus { resolved, needsClarification }

/// Estado de la REPRESENTACIÓN en LSB del significado ya resuelto: puede
/// haber quedado incompleta (dactilología, glosa sin animación) aunque el
/// significado esté clarísimo.
enum RepresentationStatus { complete, partial }

SemanticStatus semanticStatusFromJson(String? raw) =>
    raw == 'needs_clarification'
        ? SemanticStatus.needsClarification
        : SemanticStatus.resolved;

RepresentationStatus representationStatusFromJson(String? raw) =>
    raw == 'partial' ? RepresentationStatus.partial : RepresentationStatus.complete;

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
