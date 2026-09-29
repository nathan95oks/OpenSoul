import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_proposal.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';
import 'package:lsb_legal_app/core/domain/services/zone_inference_engine.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

/// El banco del módulo, con los trámites documentados (RAG) sumados.
final questionBankProvider = Provider<QuestionBank>(
  (ref) => RagTramites.bankWithTramites(),
);

final guidedComposerProvider = Provider<GuidedComposer>(
  (ref) => GuidedComposer(ref.watch(questionBankProvider)),
);

final guidedFlowRulesProvider = Provider<GuidedFlow>(
  (ref) => GuidedFlow(ref.watch(questionBankProvider)),
);

/// Estado del flujo guiado del módulo LSB → texto/audio.
class GuidedFlowState {
  final GuidedSession? session;

  /// Aviso pendiente de mostrar (p. ej. respuestas dependientes borradas).
  final String? notice;

  /// Pregunta obligatoria cuyas opciones deben pedir una selección en la UI.
  /// Es una validación visual transitoria, no parte de la declaración.
  final String? requiredSelectionQuestionId;

  const GuidedFlowState({
    this.session,
    this.notice,
    this.requiredSelectionQuestionId,
  });

  static const empty = GuidedFlowState();
}

/// El flujo guiado: la única fuente semántica de lo que declara la persona
/// sorda en este módulo.
///
/// No contiene reglas propias: cualquier cambio pasa por [GuidedFlow], que
/// es quien impide Sí y No a la vez, una quinta opción donde caben cuatro o
/// un teléfono de tres cifras. La vista previa, el resultado y el payload del
/// backend salen de [intervention]; `sentenceProvider` es solo el reflejo en
/// glosas que leen otros módulos (persistencia, aviso de borrador a medias).
class GuidedFlowNotifier extends Notifier<GuidedFlowState> {
  GuidedFlow get _rules => ref.read(guidedFlowRulesProvider);
  QuestionBank get _bank => ref.read(questionBankProvider);

  @override
  GuidedFlowState build() {
    final context = ref.watch(contextProvider);
    return GuidedFlowState(session: _start(context));
  }

  GuidedSession? _start(SemanticContext? context) {
    if (context == null || _bank.journey(context.id) == null) return null;
    final launch = ref.read(cardsFlowLaunchProvider);
    final pending = launch.purpose == CardsFlowPurpose.conversationReply
        ? ref.read(pendingReplyProvider)
        : null;
    // Conversation ya decidió qué preguntas del grafo responden al oyente:
    // se abre esa pregunta o el recorrido mínimo validado, no el contexto
    // entero. Si la persona eligió otro contexto, vale lo de siempre.
    final route = launch.route;
    final routed =
        route != null &&
        route.opensQuestions &&
        route.targetContextId == context.id &&
        route.pathQuestionIds.isNotEmpty;
    return _rules.startJourney(
      context.id,
      purpose: switch (launch.purpose) {
        CardsFlowPurpose.standaloneIntervention => GuidedPurpose.standalone,
        CardsFlowPurpose.conversationInitiative => GuidedPurpose.initiative,
        CardsFlowPurpose.conversationReply => GuidedPurpose.reply,
      },
      hasInstitutionProfile: _hasInstitutionProfile(),
      // Con ruta, lo que pidió el oyente ya está leído: no se reinterpreta
      // su texto. La inferencia por texto queda para encargos sin ruta.
      requestedQuestionIds: routed
          ? route.presupposedQuestionIds
          : (pending == null || route != null
                ? const []
                : _requestedQuestions(context, pending.question)),
      onlySteps: routed ? route.pathQuestionIds : null,
      conversationId: launch.conversationId,
      hearingTurnId: launch.hearingTurnId,
      hearingTurnText: launch.hearingText,
    );
  }

  /// Solo en ventanilla, con una institución conocida, se sabe quién
  /// atiende: ahí no se pregunta «¿ante qué institución?».
  bool _hasInstitutionProfile() {
    if (!ref.read(usageSessionProvider).isCounter) return false;
    final id = ref.read(activeProfileIdProvider);
    return id != null && id != InstitutionProfile.unknown.id;
  }

  List<String> _requestedQuestions(SemanticContext context, String text) {
    final journey = _bank.journey(context.id);
    final inJourney = {
      for (final s in journey?.steps ?? const <JourneyStep>[]) s.questionId,
    };
    final out = <String>[];
    for (final zone in const ZoneInferenceEngine().zonesFor(
      context: context,
      text: text,
    )) {
      // Qué preguntas responden cada zona es configuración del banco
      // (`zonasOyente`), en orden de preferencia.
      final candidates = _bank.listenerZoneQuestions[zone] ?? const <String>[];
      final chosen =
          candidates.where(inJourney.contains).firstOrNull ??
          candidates.firstOrNull;
      if (chosen != null && !out.contains(chosen)) out.add(chosen);
    }
    return out;
  }

  /// Empieza de nuevo el recorrido del contexto actual.
  void reset() {
    state = GuidedFlowState(session: _start(ref.read(contextProvider)));
    ref.read(sentenceProvider.notifier).clearSentence();
  }

  // ---- Respuestas -----------------------------------------------------------

  SelectionOutcome _apply(SelectionOutcome outcome) {
    if (!outcome.accepted) return outcome;
    var session = outcome.session;
    session = session.copyWith(
      currentQuestionId: _rules.currentOrFirst(session),
    );
    String? notice;
    if (outcome.prunedQuestionIds.isNotEmpty) {
      final names = [
        for (final id in outcome.prunedQuestionIds)
          '«${_bank.question(id)?.formulation ?? id}»',
      ];
      notice =
          'Se borraron respuestas que dependían de la anterior: '
          '${names.join(', ')}.';
    }
    final requiredQuestionId = state.requiredSelectionQuestionId;
    final keepRequiredSelection =
        requiredQuestionId != null &&
        _rules.isRequiredAndMissing(session, requiredQuestionId);
    state = GuidedFlowState(
      session: session,
      notice: notice,
      requiredSelectionQuestionId: keepRequiredSelection
          ? requiredQuestionId
          : null,
    );
    _syncSentence();
    return outcome;
  }

  SelectionOutcome _require(
    SelectionOutcome Function(GuidedSession session) change,
  ) {
    final session = state.session;
    if (session == null) {
      throw StateError('No hay recorrido guiado para el contexto actual.');
    }
    return _apply(change(session));
  }

  /// Elige o quita la opción.
  SelectionOutcome toggle(String questionId, String optionId) =>
      _require((s) => _rules.toggle(s, questionId, optionId));

  /// Elige la opción sin quitarla si ya estaba (p. ej. antes de abrir su
  /// editor opcional).
  SelectionOutcome select(String questionId, String optionId) =>
      _require((s) => _rules.select(s, questionId, optionId));

  /// Confirmar en un editor: elige la opción con su valor, de una vez.
  SelectionOutcome commit(
    String questionId,
    String optionId,
    Map<String, Object?> values,
  ) => _require((s) => _rules.select(s, questionId, optionId, values: values));

  SelectionOutcome deselect(String questionId, String optionId) =>
      _require((s) => _rules.deselect(s, questionId, optionId));

  SelectionOutcome omit(String questionId) =>
      _require((s) => _rules.omit(s, questionId));

  void clearNotice() => state = GuidedFlowState(
    session: state.session,
    requiredSelectionQuestionId: state.requiredSelectionQuestionId,
  );

  /// Lleva a una pregunta obligatoria y pide la selección dentro de sus
  /// tarjetas. Elegir una respuesta válida retira la indicación.
  void requireSelection(String questionId) {
    final session = state.session;
    if (session == null) return;
    state = GuidedFlowState(
      session: _rules.goTo(session, questionId),
      notice: state.notice,
      requiredSelectionQuestionId: questionId,
    );
  }

  // ---- Navegación -----------------------------------------------------------

  void goNext() {
    final session = state.session;
    if (session == null) return;
    final next = _rules.nextQuestion(session);
    if (next != null) {
      state = GuidedFlowState(session: _rules.goTo(session, next));
    }
  }

  void goPrevious() {
    final session = state.session;
    if (session == null) return;
    final previous = _rules.previousQuestion(session);
    if (previous != null) {
      state = GuidedFlowState(session: _rules.goTo(session, previous));
    }
  }

  void goTo(String questionId) {
    final session = state.session;
    if (session == null) return;
    state = GuidedFlowState(session: _rules.goTo(session, questionId));
  }

  // ---- Resultado ------------------------------------------------------------

  /// La intervención canónica: la misma para la vista previa, el resultado y
  /// el backend.
  GuidedIntervention? get intervention => state.session?.toIntervention();

  void _syncSentence() {
    final intervention = state.session?.toIntervention();
    ref
        .read(sentenceProvider.notifier)
        .setWords(
          intervention == null ? const [] : _rules.glossesOf(intervention),
        );
  }
}

final guidedFlowProvider =
    NotifierProvider<GuidedFlowNotifier, GuidedFlowState>(
      GuidedFlowNotifier.new,
    );

/// Respuestas que propone una fuente externa (p. ej. un clasificador), ya en
/// identificadores del banco. Vacío por defecto: aquí se conecta un modelo
/// sin tocar el flujo, y sus propuestas pasan por el mismo validador.
final externalGuidedProposalsProvider = Provider<List<GuidedProposal>>(
  (ref) => const [],
);

final guidedProposalsProvider = Provider<GuidedProposals>(
  (ref) => GuidedProposals(ref.watch(guidedFlowRulesProvider)),
);

/// Sugerencias para el recorrido en curso: lo que el oyente nombró (si se
/// responde a un turno) y lo que proponga una fuente externa, validado
/// contra el banco. Nunca elige nada: la persona sorda confirma tocando.
final guidedSuggestionsProvider = Provider<ProposalReview>((ref) {
  final session = ref.watch(guidedFlowProvider).session;
  if (session == null) return ProposalReview.empty;
  final launch = ref.watch(cardsFlowLaunchProvider);
  final proposals = ref.watch(guidedProposalsProvider);
  final hearing = launch.purpose == CardsFlowPurpose.conversationReply
      ? launch.hearingText
      : null;
  return proposals.review(session, [
    if (hearing != null) ...proposals.fromHearingText(session, hearing),
    ...ref.watch(externalGuidedProposalsProvider),
  ]);
});

/// Texto de la vista previa: la redacción determinista del banco.
///
/// Es la misma función que produce el resultado y la que ejecuta la Lambda:
/// no hay dos redacciones.
final guidedPreviewProvider = Provider<String>((ref) {
  final session = ref.watch(guidedFlowProvider).session;
  if (session == null) return '';
  return ref.watch(guidedComposerProvider).compose(session.toIntervention());
});
