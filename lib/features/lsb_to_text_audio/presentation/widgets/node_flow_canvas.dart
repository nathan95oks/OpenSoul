import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/suggested_gloss_panel.dart';

/// Lienzo Central del Flujo Guiado.
///
/// Integra de forma armónica:
/// 1. Tarjeta Hero de la Pregunta Activa con acciones rápidas (No lo sé / Omitir).
/// 2. Fichas de Entidades Configuradas (Chips Visuales Dinámicos).
/// 3. Grilla Adaptativa de Tarjetas de Señas LSB.
class NodeFlowCanvas extends ConsumerWidget {
  const NodeFlowCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final zonesState = ref.watch(semanticZonesProvider);

    if (ctx == null) return const SizedBox.shrink();

    final activeZone = zonesState.activeZone;
    final maxPicks = activeZone?.maxPicks ?? 1;
    final picksInZone = zonesState.picksInActiveZone;

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
              if (activeZone != null)
                _HeroQuestionCard(
                  emoji: activeZone.emoji,
                  question: activeZone.question.isNotEmpty
                      ? activeZone.question
                      : activeZone.hint,
                  hint: activeZone.hint,
                  isOptional: activeZone.optional,
                  maxPicks: maxPicks,
                  currentPicks: picksInZone,
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
  final String emoji;
  final String question;
  final String hint;
  final bool isOptional;
  final int maxPicks;
  final int currentPicks;

  const _HeroQuestionCard({
    required this.emoji,
    required this.question,
    required this.hint,
    required this.isOptional,
    required this.maxPicks,
    required this.currentPicks,
  });

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    final showHint = hint.isNotEmpty && hint.toLowerCase() != question.toLowerCase();

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
              ],
            ),
          ),

        ],
      ),
    );
  }
}
