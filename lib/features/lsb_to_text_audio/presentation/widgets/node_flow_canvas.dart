import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/suggested_gloss_panel.dart';

/// Lienzo central del flujo guiado.
///
/// 1. Tarjeta de la pregunta activa del banco, con «Omitir» si es opcional.
/// 2. Grilla de tarjetas con las respuestas que admite esa pregunta.
class NodeFlowCanvas extends ConsumerWidget {
  const NodeFlowCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final session = ref.watch(guidedFlowProvider).session;

    if (ctx == null) return const SizedBox.shrink();

    final rules = ref.watch(guidedFlowRulesProvider);
    final questionId = session?.currentQuestionId;
    final question = questionId == null
        ? null
        : ref.watch(questionBankProvider).question(questionId);
    final step = questionId == null ? null : session!.stepOf(questionId);
    final answer = questionId == null ? null : session!.answerOf(questionId);
    final maxPicks = question?.maxPicks ?? 1;
    final picks =
        answer == null || answer.isOmitted ? 0 : answer.optionIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera fija: pregunta activa + fichas de lo ya configurado. No
        // va dentro del scroll de la grilla para que, al desplazarse por
        // muchas tarjetas, lo ya elegido no desaparezca de la vista.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (question != null && session != null)
                _HeroQuestionCard(
                  question: rules.formulationOf(session, question.id),
                  isOptional: !(step?.required ?? false),
                  isOmitted: answer?.isOmitted ?? false,
                  maxPicks: maxPicks,
                  currentPicks: picks,
                  onOmit: () {
                    final outcome = ref
                        .read(guidedFlowProvider.notifier)
                        .omit(question.id);
                    if (!outcome.accepted && outcome.message != null) {
                      AppToastManager.showInfo(context, outcome.message!);
                    }
                  },
                ),
            ],
          ),
        ),

        // Única parte que se desplaza: la grilla de tarjetas de la pregunta
        // activa.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const SuggestedGlossPanel(),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroQuestionCard extends StatelessWidget {
  final String question;
  final bool isOptional;
  final bool isOmitted;
  final int maxPicks;
  final int currentPicks;
  final VoidCallback onOmit;

  const _HeroQuestionCard({
    required this.question,
    required this.isOptional,
    required this.isOmitted,
    required this.maxPicks,
    required this.currentPicks,
    required this.onOmit,
  });

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppTheme.lightText,
                    letterSpacing: -0.2,
                  ),
                ),
                if (maxPicks > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Puedes elegir hasta $maxPicks ($currentPicks elegidas)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.lightTextSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (isOptional)
                  TextButton(
                    key: const Key('omitir_pregunta'),
                    onPressed: isOmitted ? null : onOmit,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.lightTextSub,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(isOmitted ? 'Pregunta omitida' : 'Omitir'),
                  ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}
