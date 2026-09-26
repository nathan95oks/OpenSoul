/// Estado semántico de una respuesta.
///
/// Cinco situaciones distintas que nunca se reducen entre sí:
///
///   [affirmed]  eligió una respuesta afirmativa o escribió un valor;
///   [denied]    «No» / «Ninguno»: se redacta en negativo, solo sobre lo
///               preguntado;
///   [unknown]   «No sé» / «No recuerdo»: se redacta como desconocimiento,
///               nunca como «no»;
///   [omitted]   pulsó «Omitir»: queda registrado y no se redacta;
///   (ausencia)  no respondió: la pregunta no tiene entrada en la sesión.
enum GuidedAnswerState { affirmed, denied, unknown, omitted }

extension GuidedAnswerStateWire on GuidedAnswerState {
  String get wireName => switch (this) {
        GuidedAnswerState.affirmed => 'afirmado',
        GuidedAnswerState.denied => 'negado',
        GuidedAnswerState.unknown => 'desconocido',
        GuidedAnswerState.omitted => 'omitido',
      };

  static GuidedAnswerState? parse(String? raw) => switch (raw) {
        'afirmado' => GuidedAnswerState.affirmed,
        'negado' => GuidedAnswerState.denied,
        'desconocido' => GuidedAnswerState.unknown,
        'omitido' => GuidedAnswerState.omitted,
        _ => null,
      };
}

enum GuidedPurpose { standalone, initiative, reply }

class GuidedAnswer {
  final String questionId;
  final GuidedAnswerState state;
  final List<String> optionIds;

  /// Valores literales por opción: `{'solo_numero': {'telefono': '70712345'}}`.
  /// Pertenecen al mismo hecho que la opción y se redactan tal cual; nunca se
  /// convierten en glosas.
  final Map<String, Map<String, Object?>> values;
  final Map<String, Object?>? mention;

  /// Pregunta de la que esta depende en el recorrido (`padre`), si la hay.
  final String? parentQuestionId;

  const GuidedAnswer({
    required this.questionId,
    required this.state,
    this.optionIds = const [],
    this.values = const {},
    this.mention,
    this.parentQuestionId,
  });

  bool get isOmitted => state == GuidedAnswerState.omitted;

  GuidedAnswer copyWith({
    GuidedAnswerState? state,
    List<String>? optionIds,
    Map<String, Map<String, Object?>>? values,
  }) =>
      GuidedAnswer(
        questionId: questionId,
        state: state ?? this.state,
        optionIds: optionIds ?? this.optionIds,
        values: values ?? this.values,
        mention: mention,
        parentQuestionId: parentQuestionId,
      );

  Map<String, Object?> toJson() => {
        'pregunta': questionId,
        'estado': state.wireName,
        'opciones': optionIds,
        if (values.isNotEmpty) 'valores': values,
        if (mention != null) 'mencion': mention,
        if (parentQuestionId != null) 'padre': parentQuestionId,
      };
}

/// La intervención completa: la representación canónica de lo que la persona
/// sorda confirmó.
///
/// Es lo único que consumen la vista previa, el resultado, el audio y el
/// backend. No hay otra lista de glosas paralela que pueda quedarse atrás.
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

  bool get isEmpty => answers.every((a) => a.isOmitted);

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
