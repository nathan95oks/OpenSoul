import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/sign_image.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/suggested_gloss_panel.dart';

/// Lienzo central del flujo guiado.
///
/// 1. Tarjeta de la pregunta activa del banco: su formulación en LSB (del
///    banco, la misma que recibe la Lambda) y en español, con «Omitir» si es
///    opcional.
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
                  lsb: question.lsb,
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
  final LsbFormulation lsb;
  final bool isOptional;
  final bool isOmitted;
  final int maxPicks;
  final int currentPicks;
  final VoidCallback onOmit;

  const _HeroQuestionCard({
    required this.question,
    required this.lsb,
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
                if (!lsb.isEmpty) ...[
                  LsbFormulationStrip(formulation: lsb),
                  const SizedBox(height: 8),
                ],
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

/// La pregunta formulada en LSB, pieza a pieza.
///
/// Una glosa del catálogo se muestra con su imagen de seña (si las imágenes
/// están activas) y su nombre; la dactilología `d(SIGLA)` y el número se
/// muestran como tales, sin fingir una seña. Lo que la secuencia no puede
/// mostrar —marca no manual de pregunta, un concepto sin seña en v4— se dice
/// debajo en una línea, en vez de inventar una glosa para ello.
class LsbFormulationStrip extends ConsumerWidget {
  final LsbFormulation formulation;

  const LsbFormulationStrip({super.key, required this.formulation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conImagen = ref.watch(signImagesEnabledProvider);
    final segmentos = formulation.segments;
    final nota = [
      if (formulation.gaps.isNotEmpty)
        'Sin seña en el corpus: ${formulation.gaps.join(', ')}',
      formulation.isValidated ? 'LSB validada' : 'LSB provisional',
    ].join(' · ');
    return Semantics(
      label: 'Pregunta en LSB: ${segmentos.map((s) => s.label).join(' ')}. $nota',
      excludeSemantics: true,
      child: Column(
        key: const Key('formulacion_lsb'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in segmentos)
                _LsbPiece(segment: s, withImage: conImagen),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            nota,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppTheme.lightTextSub),
          ),
        ],
      ),
    );
  }
}

class _LsbPiece extends StatelessWidget {
  final LsbFormulationSegment segment;
  final bool withImage;

  const _LsbPiece({required this.segment, required this.withImage});

  @override
  Widget build(BuildContext context) {
    final esSena = segment.kind == LsbSegmentKind.sign ||
        segment.kind == LsbSegmentKind.compound;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.brandPrimary.withValues(alpha: esSena ? 0.08 : 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withImage && esSena)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final g in segment.glosses)
                  SignImage(
                    gloss: g,
                    semanticIcon: 'sign_language',
                    size: 34,
                    color: AppTheme.brandPrimary,
                  ),
              ],
            ),
          Text(
            segment.label.replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontStyle: esSena ? FontStyle.normal : FontStyle.italic,
              color: AppTheme.lightText,
            ),
          ),
        ],
      ),
    );
  }
}
