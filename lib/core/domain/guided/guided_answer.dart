enum GuidedAnswerState { affirmed, denied, unknown, omitted }

enum GuidedPurpose { standalone, initiative, reply }

class GuidedAnswer {
  final String questionId;
  final GuidedAnswerState state;
  final List<String> optionIds;
  final Map<String, Map<String, Object?>> values;
  final Map<String, Object?>? mention;

  const GuidedAnswer({
    required this.questionId,
    required this.state,
    this.optionIds = const [],
    this.values = const {},
    this.mention,
  });

  Map<String, Object?> toJson() => {
        'pregunta': questionId,
        'estado': switch (state) {
          GuidedAnswerState.affirmed => 'afirmado',
          GuidedAnswerState.denied => 'negado',
          GuidedAnswerState.unknown => 'desconocido',
          GuidedAnswerState.omitted => 'omitido',
        },
        'opciones': optionIds,
        if (values.isNotEmpty) 'valores': values,
        if (mention != null) 'mencion': mention,
      };
}

class GuidedIntervention {
  final String journeyId;
  final GuidedPurpose purpose;
  final List<GuidedAnswer> answers;
  final List<String> steps;
  final String? conversationId;
  final String? hearingTurnId;
  final String? hearingTurnText;

  const GuidedIntervention({
    required this.journeyId,
    required this.purpose,
    required this.answers,
    this.steps = const [],
    this.conversationId,
    this.hearingTurnId,
    this.hearingTurnText,
  });

  Map<String, Object?> toJson() => {
        'recorrido': journeyId,
        'proposito': purpose.name,
        'respuestas': answers.map((answer) => answer.toJson()).toList(),
        if (steps.isNotEmpty) 'pasos': steps,
        if (conversationId != null) 'conversationId': conversationId,
        if (hearingTurnId != null) 'hearingTurnId': hearingTurnId,
        if (hearingTurnText != null) 'hearingTurnText': hearingTurnText,
      };
}
