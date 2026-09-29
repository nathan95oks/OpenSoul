import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_proposal.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_values.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_preview_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/gloss_row.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/guided_value_editor.dart';

/// Las respuestas posibles de la pregunta activa, como filas.
///
/// Cada fila es una **opción del banco**, no una glosa suelta: lleva su
/// pregunta, su identificador, su significado y, si lo pide, su valor
/// escrito. La imagen es la de su primera glosa del corpus; una opción sin
/// seña (un valor escrito) se muestra con un icono, sin fingir una seña.
///
/// Tocar una fila la elige y tocarla otra vez la quita; deslizarla a la
/// derecha o pulsar su flecha enseña su seña en el avatar 3D. Elegir nunca
/// avanza de pregunta ni emite: eso sigue siendo de los botones de abajo.
class SuggestedGlossPanel extends ConsumerWidget {
  const SuggestedGlossPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowState = ref.watch(guidedFlowProvider);
    final session = flowState.session;
    final questionId = session?.currentQuestionId;
    if (session == null || questionId == null) return const _EmptyState();

    final rules = ref.watch(guidedFlowRulesProvider);
    final options = rules.offeredOptions(session, questionId);
    if (options.isEmpty) return const _EmptyState();

    final dictionary = ref.watch(allCardsProvider).asData?.value ?? const [];
    final byGloss = {for (final c in dictionary) c.gloss: c};
    final planner = ref.watch(signPreviewPlannerProvider);

    final cards = [
      for (final o in options)
        _cardFor(o, byGloss, session.valuesOf(questionId, o.id)),
    ];
    final selected = {
      for (final o in options)
        if (session.isSelected(questionId, o.id)) o.id,
    };
    // Una seña que el avatar aún no sabe hacer se dice en la fila; tocarla
    // da el aviso de siempre en vez de abrir un visor vacío.
    final sinAnimacion = {
      for (final o in options)
        if (o.hasSign && !planner.plan(o.glosses).isPlayable) o.id,
    };
    final requiresSelection =
        flowState.requiredSelectionQuestionId == questionId &&
        rules.isRequiredAndMissing(session, questionId);
    // Lo que el oyente nombró o un clasificador propuso, ya validado contra
    // el banco. Se marca en la fila; elegirlo sigue siendo de la persona.
    final sugerencias = ref.watch(guidedSuggestionsProvider);
    final sugeridas = {
      for (final o in options)
        if (!selected.contains(o.id))
          if (sugerencias.proposalFor(questionId, o.id) case final p?)
            o.id: switch (p.source) {
              ProposalSource.hearingMention => 'Mencionado por el oyente',
              ProposalSource.model => 'Sugerida',
            },
    };

    BankOption optionOf(LsbCard card) =>
        options.firstWhere((o) => o.id == card.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (requiresSelection) const _RequiredSelectionHint(),
        const SizedBox(height: 8),
        GlossRowList(
          cards: cards,
          selectedIds: selected,
          requiresSelection: requiresSelection,
          unavailableAnimationIds: sinAnimacion,
          suggestionLabels: sugeridas,
          onToggle: (card) => alternarOpcionGuiada(
            context,
            ref,
            questionId,
            optionOf(card),
            proposedValues: sugerencias
                .proposalFor(questionId, card.id)
                ?.values,
          ),
          onPreview: (card) {
            final option = optionOf(card);
            // La secuencia completa de la opción, en el orden en que se ve.
            // Una opción sin seña (un valor escrito) no tiene nada que
            // enseñar: el controlador lo avisa.
            ref
                .read(signPreviewControllerProvider)
                .show(context, option.hasSign ? option.glosses : const []);
          },
        ),
      ],
    );
  }

  static LsbCard _cardFor(
    BankOption option,
    Map<String, LsbCard> byGloss,
    Map<String, Object?>? values,
  ) {
    final base = option.hasSign ? byGloss[option.glosses.first] : null;
    final summary = option.editor == null
        ? ''
        : GuidedValues.summary(option.editor!, values);
    final visible = option.displayFormulation;
    return LsbCard(
      id: option.id,
      gloss: option.hasSign ? option.glosses.first : '',
      displayText: summary.isEmpty ? visible : '$visible: $summary',
      iconUrl: '',
      imageFrames: base?.imageFrames ?? 1,
      categoryId: base?.categoryId ?? '',
      subcategoryId: base?.subcategoryId ?? '',
      contexts: const [],
      priority: 0,
      suggestedNextCardIds: const [],
      isFrequent: false,
      isEmergency: base?.isEmergency ?? false,
      semanticIcon:
          base?.semanticIcon ??
          switch (option.editor) {
            'monto' => 'payments',
            null => 'help',
            _ => 'draw',
          },
    );
  }
}

class _RequiredSelectionHint extends StatelessWidget {
  const _RequiredSelectionHint();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('seleccion_obligatoria'),
      liveRegion: true,
      label: 'Pregunta obligatoria. Selecciona una opción.',
      excludeSemantics: true,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 18,
              color: GlossRow.requiredSelectionColor,
            ),
            SizedBox(width: 8),
            Text(
              'Selecciona una opción',
              style: TextStyle(
                color: GlossRow.requiredSelectionColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elige [option] en [questionId], abriendo su editor si lo tiene.
///
/// Elegir no quita: una opción ya elegida sigue elegida (su editor, si lo
/// tiene, se abre para corregir el valor). Quitar es [alternarOpcionGuiada].
/// Las reglas (exclusividad, máximos, valores válidos) las aplica el
/// dominio; aquí solo se decide qué hoja abrir y se avisa de un rechazo.
/// Devuelve si la opción quedó elegida. [proposedValues] es el valor que
/// traía una sugerencia: solo rellena el editor, que la persona confirma.
Future<bool> seleccionarOpcionGuiada(
  BuildContext context,
  WidgetRef ref,
  String questionId,
  BankOption option, {
  Map<String, Object?>? proposedValues,
}) async {
  final flow = ref.read(guidedFlowProvider.notifier);
  final session = ref.read(guidedFlowProvider).session;
  if (session == null) return false;
  final selected = session.isSelected(questionId, option.id);

  if (!option.hasEditor) {
    if (selected) return true;
    final outcome = flow.select(questionId, option.id);
    _informar(context, outcome);
    return outcome.accepted;
  }

  // Un editor opcional («En la calle» + su nombre, si se sabe) elige la
  // opción de inmediato; el valor escrito se añade si se confirma.
  if (!selected && option.editorOptional) {
    final outcome = flow.select(questionId, option.id);
    if (!outcome.accepted) {
      _informar(context, outcome);
      return false;
    }
  }
  if (!context.mounted) return false;

  final result = await showGuidedValueEditor(
    context,
    option: option,
    question: ref
        .read(guidedFlowRulesProvider)
        .formulationOf(session, questionId),
    initial: session.valuesOf(questionId, option.id) ?? proposedValues,
    canRemove: selected || option.editorOptional,
  );
  if (!context.mounted) return false;
  switch (result) {
    case ValueConfirmed(:final values):
      _informar(context, flow.commit(questionId, option.id, values));
    case ValueRemoved():
      _informar(context, flow.deselect(questionId, option.id));
    case null:
      break;
  }
  return ref
          .read(guidedFlowProvider)
          .session
          ?.isSelected(questionId, option.id) ??
      false;
}

/// Tocar una fila: la elige o, si ya estaba elegida, la quita.
///
/// Quitar pasa por el dominio ([GuidedFlowNotifier.deselect]), que también
/// borra lo que dependía de esa respuesta y lo avisa. Una opción con valor
/// escrito (nombre, monto…) abre su editor, donde se corrige o se quita.
/// Devuelve si la opción quedó elegida.
Future<bool> alternarOpcionGuiada(
  BuildContext context,
  WidgetRef ref,
  String questionId,
  BankOption option, {
  Map<String, Object?>? proposedValues,
}) async {
  final session = ref.read(guidedFlowProvider).session;
  if (session == null) return false;
  if (!option.hasEditor && session.isSelected(questionId, option.id)) {
    _informar(
      context,
      ref.read(guidedFlowProvider.notifier).deselect(questionId, option.id),
    );
    return false;
  }
  return seleccionarOpcionGuiada(
    context,
    ref,
    questionId,
    option,
    proposedValues: proposedValues,
  );
}

void _informar(BuildContext context, SelectionOutcome outcome) {
  if (!context.mounted) return;
  if (!outcome.accepted) {
    final mensaje =
        outcome.message ??
        switch (outcome.rejection!) {
          SelectionRejection.needsValue =>
            'Escribe el dato para elegir esta respuesta.',
          SelectionRejection.maxReached =>
            'Ya elegiste el máximo de respuestas.',
          _ => 'Esta respuesta no corresponde a la pregunta actual.',
        };
    AppToastManager.showInfo(context, mensaje);
    return;
  }
  if (outcome.prunedQuestionIds.isNotEmpty) {
    AppToastManager.showInfo(
      context,
      'Se borraron respuestas que dependían de lo que cambiaste.',
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Text(
        'No hay opciones para esta pregunta.\nPulsa "Continuar" para seguir o "Volver".',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.lightTextSub,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}
