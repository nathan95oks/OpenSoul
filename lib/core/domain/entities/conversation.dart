import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';

class GeneratedOutputs {
  final String text;
  final String baseText;
  final String? audioUrl;
  final List<String> animationUrls;
  final List<String> animationGlosses;
  final bool refinedByAi;

  const GeneratedOutputs({
    required this.text,
    this.baseText = '',
    this.audioUrl,
    this.animationUrls = const [],
    this.animationGlosses = const [],
    this.refinedByAi = false,
  });

  bool get hasRemoteAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get hasAvatar => animationUrls.isNotEmpty;
}

class ConversationTurn {
  final SemanticMessage message;
  final GeneratedOutputs outputs;
  final bool pending;

  const ConversationTurn({
    required this.message,
    required this.outputs,
    this.pending = false,
  });

  ConversationTurn copyWith({
    SemanticMessage? message,
    GeneratedOutputs? outputs,
    bool? pending,
  }) =>
      ConversationTurn(
        message: message ?? this.message,
        outputs: outputs ?? this.outputs,
        pending: pending ?? this.pending,
      );
}

class Conversation {
  final String id;
  final List<ConversationTurn> turns;
  final DateTime startedAt;

  const Conversation({
    required this.id,
    this.turns = const [],
    required this.startedAt,
  });

  factory Conversation.start() => Conversation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        startedAt: DateTime.now(),
      );

  bool get isEmpty => turns.isEmpty;

  ConversationTurn? get lastTurn => turns.isEmpty ? null : turns.last;

  String? get activeContextId {
    for (final turn in turns.reversed) {
      final ctx = turn.message.contextId;
      if (ctx != null && ctx.isNotEmpty) return ctx;
    }
    return null;
  }

  ConversationTurn? get lastHearingTurn {
    for (final turn in turns.reversed) {
      if (turn.message.speaker == SpeakerRole.hearing) return turn;
    }
    return null;
  }

  ConversationTurn? get pendingReply {
    final last = lastTurn;
    if (last == null) return null;
    return last.message.speaker == SpeakerRole.hearing ? last : null;
  }

  String? get suggestedReplyContextId =>
      pendingReply?.message.contextSuggestion?.contextId ?? activeContextId;

  Conversation addTurn(ConversationTurn turn) => Conversation(
        id: id,
        turns: [...turns, turn],
        startedAt: startedAt,
      );

  Conversation replaceTurn(ConversationTurn turn) {
    final index = turns.indexWhere((t) => t.message.id == turn.message.id);
    if (index < 0) return this;
    return Conversation(
      id: id,
      turns: [...turns]..[index] = turn,
      startedAt: startedAt,
    );
  }
}
