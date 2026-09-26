import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_values.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';

/// El estado canónico de una intervención guiada en curso.
///
/// Todo lo que la persona confirmó vive aquí, con sus identificadores del
/// banco: pregunta, opciones, estado, valores literales y relación con su
/// pregunta padre. La interfaz no guarda otra lista: la selección visible, la
/// vista previa, el resultado y el payload del backend se derivan de esta
/// misma sesión.
///
/// Es inmutable. Los cambios los hace [GuidedFlow], que es donde se hacen
/// cumplir las reglas (exclusividad, máximos, dependencias). No depende de
/// ningún turno anterior: la persona sorda puede empezar sola.
class GuidedSession {
  final String journeyId;
  final GuidedPurpose purpose;
  final List<JourneyStep> steps;

  /// Respuestas por pregunta. Una pregunta sin entrada **no fue respondida**,
  /// que es distinto de omitida, negada o desconocida.
  final Map<String, GuidedAnswer> answers;

  final String? currentQuestionId;

  /// Si la atención tiene perfil institucional (condiciones `perfil`).
  final bool hasInstitutionProfile;

  /// Preguntas que el oyente hizo explícitamente al pedir la respuesta. Se
  /// muestran aunque su condición en el recorrido no se cumpla: la pregunta
  /// ya está hecha.
  final Set<String> requestedQuestionIds;

  final String? conversationId;
  final String? hearingTurnId;
  final String? hearingTurnText;

  const GuidedSession({
    required this.journeyId,
    required this.purpose,
    required this.steps,
    this.answers = const {},
    this.currentQuestionId,
    this.hasInstitutionProfile = false,
    this.requestedQuestionIds = const {},
    this.conversationId,
    this.hearingTurnId,
    this.hearingTurnText,
  });

  GuidedAnswer? answerOf(String questionId) => answers[questionId];

  bool isSelected(String questionId, String optionId) {
    final answer = answers[questionId];
    return answer != null &&
        !answer.isOmitted &&
        answer.optionIds.contains(optionId);
  }

  Map<String, Object?>? valuesOf(String questionId, String optionId) =>
      answers[questionId]?.values[optionId];

  JourneyStep? stepOf(String questionId) {
    for (final s in steps) {
      if (s.questionId == questionId) return s;
    }
    return null;
  }

  bool get hasAnswers => answers.values.any((a) => !a.isOmitted);

  GuidedSession copyWith({
    Map<String, GuidedAnswer>? answers,
    String? currentQuestionId,
  }) =>
      GuidedSession(
        journeyId: journeyId,
        purpose: purpose,
        steps: steps,
        answers: answers ?? this.answers,
        currentQuestionId: currentQuestionId ?? this.currentQuestionId,
        hasInstitutionProfile: hasInstitutionProfile,
        requestedQuestionIds: requestedQuestionIds,
        conversationId: conversationId,
        hearingTurnId: hearingTurnId,
        hearingTurnText: hearingTurnText,
      );

  /// La intervención que se redacta y se envía: respuestas en el orden de
  /// los pasos.
  GuidedIntervention toIntervention() {
    final ordered = <GuidedAnswer>[
      for (final step in steps) ?answers[step.questionId],
    ];
    for (final entry in answers.entries) {
      if (!ordered.any((a) => a.questionId == entry.key)) {
        ordered.add(entry.value);
      }
    }
    return GuidedIntervention(
      journeyId: journeyId,
      purpose: purpose,
      answers: ordered,
      steps: [for (final s in steps) s.questionId],
      conversationId: conversationId,
      hearingTurnId: hearingTurnId,
      hearingTurnText: hearingTurnText,
    );
  }
}

/// Por qué el dominio rechazó un cambio.
enum SelectionRejection {
  unknownQuestion,
  unknownOption,

  /// La opción no se ofrece en este paso (oculta o con condición falsa).
  notOffered,

  /// Ya hay `maxPicks` opciones activas en una pregunta de selección
  /// múltiple. No se reemplaza en silencio.
  maxReached,

  /// La opción necesita un valor (nombre, teléfono, monto…) y no llegó.
  needsValue,

  /// El valor no pasa la validación del editor.
  invalidValue,

  /// Una pregunta obligatoria no puede omitirse.
  requiredQuestion,

  /// La pregunta no está alcanzable con las respuestas actuales.
  unreachable,
}

class SelectionOutcome {
  final GuidedSession session;
  final SelectionRejection? rejection;
  final String? message;

  /// Opciones que salieron de la misma pregunta por exclusividad.
  final List<String> replacedOptionIds;

  /// Preguntas cuyas respuestas se borraron porque dejaron de ser
  /// alcanzables (p. ej. «¿Qué relación tiene?» al cambiar Sí por No).
  final List<String> prunedQuestionIds;

  const SelectionOutcome._(
    this.session, {
    this.rejection,
    this.message,
    this.replacedOptionIds = const [],
    this.prunedQuestionIds = const [],
  });

  bool get accepted => rejection == null;
}

/// Las reglas del flujo guiado, sin interfaz.
///
/// Cualquier cambio de respuesta pasa por aquí. La interfaz puede deshabilitar
/// botones, pero no es quien garantiza nada: si una pantalla intentara meter
/// Sí y No a la vez, o una quinta opción donde caben cuatro, esto lo impide.
class GuidedFlow {
  final QuestionBank bank;

  const GuidedFlow(this.bank);

  // ---- Construcción --------------------------------------------------------

  /// Sesión nueva para un recorrido del banco.
  ///
  /// [requestedQuestionIds] son las preguntas que el oyente hizo al pedir la
  /// respuesta (si las hay); la sesión empieza por la primera de ellas.
  GuidedSession startJourney(
    String journeyId, {
    GuidedPurpose purpose = GuidedPurpose.standalone,
    bool hasInstitutionProfile = false,
    Iterable<String> requestedQuestionIds = const [],
    String? conversationId,
    String? hearingTurnId,
    String? hearingTurnText,
  }) {
    final journey = bank.journey(journeyId);
    if (journey == null) {
      throw ArgumentError.value(journeyId, 'journeyId', 'recorrido inexistente');
    }
    final stepIds = {for (final s in journey.steps) s.questionId};
    final requested = [
      for (final id in requestedQuestionIds)
        if (bank.question(id) != null && !bank.question(id)!.isDerivation) id,
    ];
    // Una pregunta que el oyente hizo y que el recorrido no trae se responde
    // igual: se antepone como paso propio en vez de descartarla.
    final extra = [
      for (final id in requested)
        if (!stepIds.contains(id)) JourneyStep(questionId: id),
    ];
    final session = GuidedSession(
      journeyId: journeyId,
      purpose: purpose,
      steps: [...extra, ...journey.steps],
      hasInstitutionProfile: hasInstitutionProfile,
      requestedQuestionIds: requested.toSet(),
      conversationId: conversationId,
      hearingTurnId: hearingTurnId,
      hearingTurnText: hearingTurnText,
    );
    return session.copyWith(
      currentQuestionId: requested.firstOrNull ?? firstQuestion(session),
    );
  }

  // ---- Alcanzabilidad ------------------------------------------------------

  bool conditionHolds(GuidedSession session, GuidedCondition condition) {
    if (condition.profile != null) {
      return condition.profile == session.hasInstitutionProfile;
    }
    final id = condition.questionId;
    if (id == null) return true;
    final answer = session.answers[id];
    if (answer == null || answer.isOmitted) return false;
    if (condition.optionIds.isNotEmpty &&
        !answer.optionIds.any(condition.optionIds.contains)) {
      return false;
    }
    if (condition.states.isNotEmpty &&
        !condition.states.contains(answer.state.wireName)) {
      return false;
    }
    return true;
  }

  bool isReachable(GuidedSession session, JourneyStep step) {
    final question = bank.question(step.questionId);
    if (question == null || question.isDerivation) return false;
    if (session.requestedQuestionIds.contains(step.questionId)) return true;
    return step.conditions.every((c) => conditionHolds(session, c));
  }

  /// Pasos que tocan con las respuestas actuales, en orden.
  List<JourneyStep> reachableSteps(GuidedSession session) =>
      [for (final s in session.steps) if (isReachable(session, s)) s];

  String? firstQuestion(GuidedSession session) =>
      reachableSteps(session).firstOrNull?.questionId;

  /// Opciones que se ofrecen en este paso, en el orden del banco.
  ///
  /// Quita las que el paso oculta y las que tienen una condición falsa. Las
  /// glosas que solo formulan la pregunta (`noOfrecer`) nunca son opciones:
  /// el banco declara las respuestas aparte.
  List<BankOption> offeredOptions(GuidedSession session, String questionId) {
    final question = bank.question(questionId);
    if (question == null) return const [];
    final hidden = session.stepOf(questionId)?.hiddenOptions ?? const [];
    return [
      for (final o in question.options)
        if (!hidden.contains(o.id) &&
            o.conditions.every((c) => conditionHolds(session, c)))
          o,
    ];
  }

  /// Formulación visible del paso (un paso puede precisarla).
  String formulationOf(GuidedSession session, String questionId) =>
      session.stepOf(questionId)?.formulation ??
      bank.question(questionId)?.formulation ??
      '';

  // ---- Cambios -------------------------------------------------------------

  /// Elige [optionId] (con sus [values], si los tiene) en [questionId].
  ///
  /// Reglas:
  ///   * una pregunta de respuesta única reemplaza la anterior;
  ///   * «No sé», «Ninguno» y las respuestas negativas excluyen al resto, y
  ///     las opciones del mismo `grupo` se excluyen entre sí;
  ///   * superar `maxPicks` se rechaza, no se reemplaza en silencio;
  ///   * una opción con editor obligatorio exige su valor válido;
  ///   * elegir de nuevo una opción ya activa solo actualiza su valor.
  ///
  /// Después se podan las respuestas de preguntas que dejaron de alcanzarse.
  SelectionOutcome select(
    GuidedSession session,
    String questionId,
    String optionId, {
    Map<String, Object?>? values,
  }) {
    final question = bank.question(questionId);
    if (question == null) {
      return SelectionOutcome._(session,
          rejection: SelectionRejection.unknownQuestion);
    }
    final option = question.option(optionId);
    if (option == null) {
      return SelectionOutcome._(session,
          rejection: SelectionRejection.unknownOption);
    }
    final step = session.stepOf(questionId);
    if (step == null || !isReachable(session, step)) {
      return SelectionOutcome._(session,
          rejection: SelectionRejection.unreachable);
    }
    if (!offeredOptions(session, questionId).any((o) => o.id == optionId)) {
      return SelectionOutcome._(session,
          rejection: SelectionRejection.notOffered);
    }

    final previous = session.answers[questionId];
    final previousOptions = previous == null || previous.isOmitted
        ? const <String>[]
        : previous.optionIds;

    // Valor del editor: el nuevo, validado; o el que ya tenía la opción.
    Map<String, Object?>? optionValues = previous?.values[optionId];
    if (values != null && option.editor != null) {
      final check =
          GuidedValues.check(option.editor!, values, range: option.range);
      if (!check.isValid) {
        return SelectionOutcome._(session,
            rejection: SelectionRejection.invalidValue, message: check.error);
      }
      optionValues = {
        for (final e in check.values.entries)
          // La edad propia es exacta: «aproximadamente» no se acepta ahí.
          if (!(e.key == 'aprox' && option.noApproximate)) e.key: e.value,
      };
    }
    if (option.requiresValue &&
        !GuidedValues.isComplete(option.editor!, optionValues)) {
      return SelectionOutcome._(session,
          rejection: SelectionRejection.needsValue);
    }

    List<String> chosen;
    if (question.maxPicks <= 1 || option.isExclusive) {
      chosen = [optionId];
    } else {
      bool keeps(String id) {
        if (id == optionId) return true;
        final other = question.option(id);
        if (other == null || other.isExclusive) return false;
        return option.group == null || other.group != option.group;
      }

      chosen = [for (final id in previousOptions) if (keeps(id)) id];
      if (!chosen.contains(optionId)) {
        if (chosen.length >= question.maxPicks) {
          return SelectionOutcome._(session,
              rejection: SelectionRejection.maxReached,
              message: 'Puedes elegir hasta ${question.maxPicks}.');
        }
        chosen.add(optionId);
      }
    }

    final replaced = [
      for (final id in previousOptions) if (!chosen.contains(id)) id,
    ];
    final newValues = <String, Map<String, Object?>>{};
    for (final id in chosen) {
      final kept = id == optionId ? optionValues : previous?.values[id];
      if (kept != null && kept.isNotEmpty) newValues[id] = kept;
    }

    final answer = GuidedAnswer(
      questionId: questionId,
      state: _stateOf(question, chosen),
      optionIds: chosen,
      values: newValues,
      parentQuestionId: step.parent,
    );
    return _commit(session, questionId, answer, replaced: replaced);
  }

  /// Quita [optionId] de [questionId]. Si no queda ninguna, la pregunta
  /// vuelve a no estar respondida (no «omitida», no «no»).
  SelectionOutcome deselect(
      GuidedSession session, String questionId, String optionId) {
    final previous = session.answers[questionId];
    if (previous == null || !previous.optionIds.contains(optionId)) {
      return SelectionOutcome._(session);
    }
    final question = bank.question(questionId)!;
    final remaining = [...previous.optionIds]..remove(optionId);
    if (remaining.isEmpty) {
      return _commit(session, questionId, null, replaced: [optionId]);
    }
    return _commit(
      session,
      questionId,
      previous.copyWith(
        state: _stateOf(question, remaining),
        optionIds: remaining,
        values: {
          for (final e in previous.values.entries)
            if (e.key != optionId) e.key: e.value,
        },
      ),
      replaced: [optionId],
    );
  }

  SelectionOutcome toggle(
          GuidedSession session, String questionId, String optionId) =>
      session.isSelected(questionId, optionId)
          ? deselect(session, questionId, optionId)
          : select(session, questionId, optionId);

  /// «Omitir»: queda registrado que se saltó, sin redactar nada.
  SelectionOutcome omit(GuidedSession session, String questionId) {
    final step = session.stepOf(questionId);
    if (step == null || !isReachable(session, step)) {
      return SelectionOutcome._(session,
          rejection: SelectionRejection.unreachable);
    }
    if (step.required) {
      return SelectionOutcome._(session,
          rejection: SelectionRejection.requiredQuestion,
          message:
              'Esta pregunta es necesaria para que la frase tenga sentido.');
    }
    return _commit(
      session,
      questionId,
      GuidedAnswer(
        questionId: questionId,
        state: GuidedAnswerState.omitted,
        parentQuestionId: step.parent,
      ),
      replaced: session.answers[questionId]?.optionIds ?? const [],
    );
  }

  /// Deja la pregunta sin responder.
  SelectionOutcome clear(GuidedSession session, String questionId) {
    if (!session.answers.containsKey(questionId)) {
      return SelectionOutcome._(session);
    }
    return _commit(session, questionId, null,
        replaced: session.answers[questionId]!.optionIds);
  }

  GuidedAnswerState _stateOf(BankQuestion question, List<String> chosen) {
    final states = {
      for (final id in chosen)
        question.option(id)?.state ?? GuidedAnswerState.affirmed,
    };
    if (states.length == 1) return states.first;
    return GuidedAnswerState.affirmed;
  }

  SelectionOutcome _commit(
    GuidedSession session,
    String questionId,
    GuidedAnswer? answer, {
    List<String> replaced = const [],
  }) {
    final answers = {...session.answers};
    if (answer == null) {
      answers.remove(questionId);
    } else {
      answers[questionId] = answer;
    }
    final pruned = <String>[];
    var next = session.copyWith(answers: answers);
    // Las dependencias pueden encadenarse (Q.ROB.QUE → Q.DOC.ACLARAR): se
    // poda hasta que no quede ninguna respuesta colgando de una rama cerrada.
    // Una opción que dejó de ofrecerse también sale: «La persona que me robó»
    // no puede quedar elegida si ya no se habla de un robo.
    while (true) {
      final dangling = <String>[];
      final trimmed = <String, GuidedAnswer>{};
      for (final entry in next.answers.entries) {
        final step = next.stepOf(entry.key);
        if (step != null && !isReachable(next, step)) {
          dangling.add(entry.key);
          continue;
        }
        final a = entry.value;
        if (a.isOmitted) continue;
        final offered = {
          for (final o in offeredOptions(next, entry.key)) o.id,
        };
        final kept = [for (final id in a.optionIds) if (offered.contains(id)) id];
        if (kept.length != a.optionIds.length) {
          if (kept.isEmpty) {
            dangling.add(entry.key);
          } else {
            trimmed[entry.key] = a.copyWith(
              state: _stateOf(bank.question(entry.key)!, kept),
              optionIds: kept,
              values: {
                for (final e in a.values.entries)
                  if (kept.contains(e.key)) e.key: e.value,
              },
            );
          }
        }
      }
      if (dangling.isEmpty && trimmed.isEmpty) break;
      pruned.addAll(dangling);
      next = next.copyWith(answers: {
        for (final e in next.answers.entries)
          if (!dangling.contains(e.key)) e.key: trimmed[e.key] ?? e.value,
      });
    }
    return SelectionOutcome._(next,
        replacedOptionIds: replaced, prunedQuestionIds: pruned);
  }

  // ---- Navegación ----------------------------------------------------------

  GuidedSession goTo(GuidedSession session, String questionId) {
    final step = session.stepOf(questionId);
    if (step == null || !isReachable(session, step)) return session;
    return session.copyWith(currentQuestionId: questionId);
  }

  /// Siguiente paso alcanzable después del actual, o `null` si es el último.
  String? nextQuestion(GuidedSession session) {
    final steps = reachableSteps(session);
    final index =
        steps.indexWhere((s) => s.questionId == session.currentQuestionId);
    if (index < 0) return steps.firstOrNull?.questionId;
    return index + 1 < steps.length ? steps[index + 1].questionId : null;
  }

  String? previousQuestion(GuidedSession session) {
    final steps = reachableSteps(session);
    final index =
        steps.indexWhere((s) => s.questionId == session.currentQuestionId);
    return index > 0 ? steps[index - 1].questionId : null;
  }

  /// El paso actual, corregido si dejó de ser alcanzable.
  String? currentOrFirst(GuidedSession session) {
    final steps = reachableSteps(session);
    if (steps.any((s) => s.questionId == session.currentQuestionId)) {
      return session.currentQuestionId;
    }
    return steps.firstOrNull?.questionId;
  }

  /// Si la pregunta actual es obligatoria y todavía no tiene respuesta.
  bool isRequiredAndMissing(GuidedSession session, String questionId) {
    final step = session.stepOf(questionId);
    if (step == null || !step.required) return false;
    final answer = session.answers[questionId];
    return answer == null || answer.isOmitted;
  }

  /// Pasos obligatorios alcanzables que aún no tienen respuesta válida.
  List<String> missingRequired(GuidedSession session) => [
        for (final s in reachableSteps(session))
          if (isRequiredAndMissing(session, s.questionId)) s.questionId,
      ];

  /// Suficiencia: se puede terminar cuando hay algo que decir y nada
  /// obligatorio pendiente.
  ///
  /// No hace falta recorrer las preguntas opcionales: la persona termina
  /// cuando ya dijo lo que quería decir. Obligatorio es solo lo que da
  /// sentido a otra respuesta ya dada (p. ej. «¿Quién escapó?» después de
  /// «Alguien escapó»).
  bool canFinish(GuidedSession session) =>
      session.hasAnswers && missingRequired(session).isEmpty;

  /// Glosas LSB de las opciones elegidas, en el orden de la intervención.
  ///
  /// Solo las que la opción declara como seña: un valor escrito (nombre,
  /// monto, teléfono) nunca se convierte en glosa.
  List<String> glossesOf(GuidedIntervention intervention) => [
        for (final a in intervention.answers)
          if (!a.isOmitted)
            for (final id in a.optionIds)
              if (bank.question(a.questionId)?.option(id) case final option?)
                if (option.hasSign) ...option.glosses,
      ];
}
