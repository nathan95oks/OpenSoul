import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_values.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/adaptive_node_layout.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/guided_value_editor.dart';

/// Las respuestas posibles de la pregunta activa, como tarjetas.
///
/// Cada tarjeta es una **opción del banco**, no una glosa suelta: lleva su
/// pregunta, su identificador, su significado y, si lo pide, su valor
/// escrito. La imagen es la de su primera glosa del corpus; una opción sin
/// seña (un valor escrito) se muestra con un icono, sin fingir una seña.
class SuggestedGlossPanel extends ConsumerWidget {
  const SuggestedGlossPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(guidedFlowProvider).session;
    final questionId = session?.currentQuestionId;
    if (session == null || questionId == null) return const _EmptyState();

    final rules = ref.watch(guidedFlowRulesProvider);
    final options = rules.offeredOptions(session, questionId);
    if (options.isEmpty) return const _EmptyState();

    final dictionary = ref.watch(allCardsProvider).asData?.value ?? const [];
    final byGloss = {for (final c in dictionary) c.gloss: c};

    final cards = [
      for (final o in options)
        _cardFor(o, byGloss, session.valuesOf(questionId, o.id)),
    ];
    final selected = {
      for (final o in options)
        if (session.isSelected(questionId, o.id)) o.id,
    };

    return AdaptiveNodeLayout(
      cards: cards,
      selectedIds: selected,
      onCardTap: (card) {
        final option = options.firstWhere((o) => o.id == card.id);
        elegirOpcionGuiada(context, ref, questionId, option);
      },
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
    return LsbCard(
      id: option.id,
      gloss: option.hasSign ? option.glosses.first : '',
      displayText: summary.isEmpty ? option.label : '${option.label}: $summary',
      iconUrl: '',
      imageFrames: base?.imageFrames ?? 1,
      categoryId: base?.categoryId ?? '',
      subcategoryId: base?.subcategoryId ?? '',
      contexts: const [],
      priority: 0,
      suggestedNextCardIds: const [],
      isFrequent: false,
      isEmergency: base?.isEmergency ?? false,
      semanticIcon: base?.semanticIcon ??
          switch (option.editor) {
            'monto' => 'payments',
            null => 'help',
            _ => 'draw',
          },
    );
  }
}

/// Elige o quita [option] en [questionId], abriendo su editor si lo tiene.
///
/// Las reglas (exclusividad, máximos, valores válidos) las aplica el
/// dominio; aquí solo se decide qué hoja abrir y se avisa de un rechazo.
Future<void> elegirOpcionGuiada(
  BuildContext context,
  WidgetRef ref,
  String questionId,
  BankOption option,
) async {
  final flow = ref.read(guidedFlowProvider.notifier);
  final session = ref.read(guidedFlowProvider).session;
  if (session == null) return;
  final selected = session.isSelected(questionId, option.id);

  if (!option.hasEditor) {
    _informar(context, flow.toggle(questionId, option.id));
    return;
  }

  // Un editor opcional («En la calle» + su nombre, si se sabe) elige la
  // opción de inmediato; el valor escrito se añade si se confirma.
  if (!selected && option.editorOptional) {
    final outcome = flow.select(questionId, option.id);
    if (!outcome.accepted) {
      _informar(context, outcome);
      return;
    }
  }
  if (!context.mounted) return;

  final result = await showGuidedValueEditor(
    context,
    option: option,
    question: ref.read(guidedFlowRulesProvider).formulationOf(session, questionId),
    initial: session.valuesOf(questionId, option.id),
    canRemove: selected || option.editorOptional,
  );
  if (!context.mounted) return;
  switch (result) {
    case ValueConfirmed(:final values):
      _informar(context, flow.commit(questionId, option.id, values));
    case ValueRemoved():
      _informar(context, flow.deselect(questionId, option.id));
    case null:
      break;
  }
}

void _informar(BuildContext context, SelectionOutcome outcome) {
  if (!context.mounted) return;
  if (!outcome.accepted) {
    final mensaje = outcome.message ??
        switch (outcome.rejection!) {
          SelectionRejection.needsValue =>
            'Escribe el dato para elegir esta respuesta.',
          SelectionRejection.maxReached => 'Ya elegiste el máximo de respuestas.',
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
