import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/services/zone_inference_engine.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

final questionBankProvider =
    Provider<QuestionBank>((ref) => QuestionBank.generated());

final guidedComposerProvider = Provider<GuidedComposer>(
    (ref) => GuidedComposer(ref.watch(questionBankProvider)));

final guidedFlowRulesProvider =
    Provider<GuidedFlow>((ref) => GuidedFlow(ref.watch(questionBankProvider)));

/// Pregunta del banco que corresponde a cada campo que el oyente puede haber
/// preguntado, en orden de preferencia.
///
/// Es la misma inferencia que ya hacía el módulo al abrirse para responder
/// (`ZoneInferenceEngine`), dirigida ahora a las preguntas del banco en vez
/// de a las zonas. No interpreta nada nuevo del turno del oyente.
const Map<String, List<String>> _questionsForZone = {
  'tiempo': ['Q.TIE.CUANDO', 'Q.SEG.FECHA_PROGRAMADA'],
  'lugar': ['Q.LUG.DONDE'],
  'conocimiento': ['Q.PER.CONOCE'],
  'persona': [
    'Q.PER.DESCRIBIR',
    'Q.VIO.AGRESOR',
    'Q.DIG.REMITENTE',
    'Q.DIN.RECEPTOR',
    'Q.PER.OBSERVADA',
  ],
  'objetos': ['Q.ROB.QUE'],
  'testigos': ['Q.TES.EXISTE'],
  'evidencia': ['Q.EVI.QUE_TIENE', 'Q.DIG.GUARDO', 'Q.DIN.COMPROBANTE'],
  'emergencia': ['Q.SAL.HERIDO'],
  'denuncia': ['Q.DEN.INTENCION'],
  'apoyo_legal': ['Q.VIO.ASISTENCIA_ESPECIALIZADA'],
  'institucion_autoridad': ['Q.DEN.AUTORIDAD', 'Q.SEG.AUTORIDAD'],
  'identidad': ['Q.ID.NOMBRE'],
  'edad': ['Q.ID.EDAD_PROPIA'],
};

/// Estado del flujo guiado del módulo LSB → texto/audio.
class GuidedFlowState {
  final GuidedSession? session;

  /// Aviso pendiente de mostrar (p. ej. respuestas dependientes borradas).
  final String? notice;

  const GuidedFlowState({this.session, this.notice});

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
    return _rules.startJourney(
      context.id,
      purpose: switch (launch.purpose) {
        CardsFlowPurpose.standaloneIntervention => GuidedPurpose.standalone,
        CardsFlowPurpose.conversationInitiative => GuidedPurpose.initiative,
        CardsFlowPurpose.conversationReply => GuidedPurpose.reply,
      },
      hasInstitutionProfile: _hasInstitutionProfile(),
      requestedQuestionIds: pending == null
          ? const []
          : _requestedQuestions(context, pending.question),
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
    for (final zone
        in const ZoneInferenceEngine().zonesFor(context: context, text: text)) {
      final candidates = _questionsForZone[zone] ?? const <String>[];
      final chosen = candidates.where(inJourney.contains).firstOrNull ??
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
    session = session.copyWith(currentQuestionId: _rules.currentOrFirst(session));
    String? notice;
    if (outcome.prunedQuestionIds.isNotEmpty) {
      final names = [
        for (final id in outcome.prunedQuestionIds)
          '«${_bank.question(id)?.formulation ?? id}»',
      ];
      notice = 'Se borraron respuestas que dependían de la anterior: '
          '${names.join(', ')}.';
    }
    state = GuidedFlowState(session: session, notice: notice);
    _syncSentence();
    return outcome;
  }

  SelectionOutcome _require(
      SelectionOutcome Function(GuidedSession session) change) {
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
          String questionId, String optionId, Map<String, Object?> values) =>
      _require((s) => _rules.select(s, questionId, optionId, values: values));

  SelectionOutcome deselect(String questionId, String optionId) =>
      _require((s) => _rules.deselect(s, questionId, optionId));

  SelectionOutcome omit(String questionId) =>
      _require((s) => _rules.omit(s, questionId));

  void clearNotice() => state = GuidedFlowState(session: state.session);

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
    ref.read(sentenceProvider.notifier).setWords(
          intervention == null ? const [] : _rules.glossesOf(intervention),
        );
  }
}

final guidedFlowProvider =
    NotifierProvider<GuidedFlowNotifier, GuidedFlowState>(
  GuidedFlowNotifier.new,
);

/// Texto de la vista previa: la redacción determinista del banco.
///
/// Es la misma función que produce el resultado y la que ejecuta la Lambda:
/// no hay dos redacciones.
final guidedPreviewProvider = Provider<String>((ref) {
  final session = ref.watch(guidedFlowProvider).session;
  if (session == null) return '';
  return ref.watch(guidedComposerProvider).compose(session.toIntervention());
});
