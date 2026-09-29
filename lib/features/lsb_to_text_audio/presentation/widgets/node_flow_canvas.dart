import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/di/injection.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/sign_image.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/suggested_gloss_panel.dart';

/// Lienzo central del flujo guiado.
///
/// 1. Tarjeta de la pregunta activa del banco: su formulación completa en LSB
///    o, cuando no existe, el español de fallback.
/// 2. Lista de filas con las respuestas que admite esa pregunta.
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
    final answer = questionId == null ? null : session!.answerOf(questionId);
    final maxPicks = question?.maxPicks ?? 1;
    final picks = answer == null || answer.isOmitted
        ? 0
        : answer.optionIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera fija: solo la pregunta activa. No va dentro del scroll
        // de la lista para que no desaparezca al desplazarse por muchas
        // respuestas.
        SafeArea(
          key: const Key('guided_question_header'),
          bottom: false,
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (question != null && session != null)
                _HeroQuestionCard(
                  question: rules.formulationOf(session, question.id),
                  lsb: question.lsb,
                  maxPicks: maxPicks,
                  currentPicks: picks,
                ),
            ],
          ),
        ),

        // Única parte que se desplaza: las filas de respuesta de la pregunta
        // activa.
        Expanded(
          child: SingleChildScrollView(
            key: const Key('guided_options_scroll'),
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
            child: const SuggestedGlossPanel(),
          ),
        ),
      ],
    );
  }
}

class _HeroQuestionCard extends StatelessWidget {
  final String question;
  final LsbFormulation lsb;
  final int maxPicks;
  final int currentPicks;

  const _HeroQuestionCard({
    required this.question,
    required this.lsb,
    required this.maxPicks,
    required this.currentPicks,
  });

  @override
  Widget build(BuildContext context) {
    // Sin recuadro: la pregunta sola, grande y centrada.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        LsbQuestionDisplay(spanish: question, formulation: lsb),
        if (maxPicks > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Puedes elegir hasta $maxPicks ($currentPicks elegidas)',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.lightTextSub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Representación única de una pregunta para la persona sorda.
///
/// La decisión es central para todas las preguntas: LSB cuando la secuencia
/// está completa y utilizable; español natural cuando falta cobertura. Nunca
/// se muestran ambas versiones a la vez.
class LsbQuestionDisplay extends StatelessWidget {
  final String spanish;
  final LsbFormulation formulation;

  const LsbQuestionDisplay({
    super.key,
    required this.spanish,
    required this.formulation,
  });

  /// Tamaño de la pregunta, en LSB o en español.
  static double fontSizeFor(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360 ? 20 : 22;

  @override
  Widget build(BuildContext context) {
    if (formulation.hasUsableLsb) {
      return LsbFormulationStrip(formulation: formulation);
    }
    return Text(
      spanish,
      key: const Key('formulacion_es_fallback'),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSizeFor(context),
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: AppTheme.lightText,
      ),
    );
  }
}

/// La pregunta formulada en LSB, pieza a pieza.
///
/// Una glosa del catálogo se muestra con su imagen de seña (si las imágenes
/// están activas) y su nombre; la dactilología `d(SIGLA)` y el número se
/// muestran como tales, sin fingir una seña. El estado de auditoría y las
/// notas técnicas permanecen en el modelo, pero no se exponen en la interfaz.
class LsbFormulationStrip extends ConsumerWidget {
  final LsbFormulation formulation;

  const LsbFormulationStrip({super.key, required this.formulation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Como en las tarjetas: la imagen solo si hay una seña que enseñar.
    final conImagen =
        ref.watch(signImagesEnabledProvider) &&
        ref.watch(signImageResolverProvider).isConfigured;
    final segmentos = formulation.segments;
    return Semantics(
      label: 'Pregunta en LSB: ${segmentos.map((s) => s.label).join(' ')}',
      excludeSemantics: true,
      child: Wrap(
        key: const Key('formulacion_lsb'),
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final s in segmentos)
            _LsbPiece(segment: s, withImage: conImagen),
        ],
      ),
    );
  }
}

class _LsbPiece extends StatelessWidget {
  final LsbFormulationSegment segment;
  final bool withImage;

  const _LsbPiece({required this.segment, required this.withImage});

  static const _imageSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final esSena =
        segment.kind == LsbSegmentKind.sign ||
        segment.kind == LsbSegmentKind.compound;
    final marca = withImage ? _marca(esSena) : null;

    // Cada glosa como palabra de la pregunta, sin recuadro. La imagen, si la
    // hay, va en la misma fila: apilada, la cabecera empujaba las tarjetas.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (marca != null) ...[marca, const SizedBox(width: 5)],
        Flexible(
          child: Text(
            PendingSign.isPending(segment.label)
                ? PendingSign.wordOf(segment.label)
                : segment.label.replaceAll('_', ' '),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: LsbQuestionDisplay.fontSizeFor(context),
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              fontStyle: esSena ? FontStyle.normal : FontStyle.italic,
              // Sin seña en el catálogo: azul claro, como en las tarjetas.
              color: PendingSign.isPending(segment.label)
                  ? AppTheme.pendingSign
                  : AppTheme.lightText,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _marca(bool esSena) {
    if (esSena) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final g in segment.glosses)
            SignImage(
              gloss: g,
              semanticIcon: 'sign_language',
              size: _imageSize,
              color: AppTheme.lightTextSub,
            ),
        ],
      );
    }
    final icono = switch (segment.kind) {
      LsbSegmentKind.number => Icons.tag_rounded,
      LsbSegmentKind.dactylology => Icons.front_hand_rounded,
      _ => null,
    };
    if (icono == null) return null;
    return Container(
      width: _imageSize,
      height: _imageSize,
      decoration: BoxDecoration(
        color: AppTheme.lightBorder,
        shape: BoxShape.circle,
      ),
      child: Icon(icono, size: 12, color: AppTheme.lightTextSub),
    );
  }
}
