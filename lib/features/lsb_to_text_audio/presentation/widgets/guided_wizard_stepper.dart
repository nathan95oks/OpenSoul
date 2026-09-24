import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/card_grid.dart'
    show expandedAnswersProvider;

/// Barra de Progreso y Navegación Visual por Pasos (Breadcrumbs Modernos).
///
/// Ubicada en la parte superior del flujo, muestra la etapa activa en el proceso
/// de declaración (ej. 1. Hecho ➔ 2. Objetos ➔ 3. Personas ➔ 4. Lugar ➔ 5. Formalizar).
class GuidedWizardStepper extends ConsumerWidget {
  const GuidedWizardStepper({super.key});

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final zonesState = ref.watch(semanticZonesProvider);
    final draft = ref.watch(declarationDraftProvider);

    if (ctx == null || zonesState.activeZone == null) {
      return const SizedBox.shrink();
    }

    final activeZoneId = zonesState.activeZoneId;
    final zones = zonesState.snapshot.orderedZones;

    if (zones.isEmpty) return const SizedBox.shrink();

    final currentIndex = zones.indexWhere((z) => z.zone.id == activeZoneId);
    final activeIndex = currentIndex >= 0 ? currentIndex : 0;
    final hasContent = draft.persons.isNotEmpty ||
        draft.objects.isNotEmpty ||
        !draft.location.isEmpty ||
        draft.facts.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.lightSurface,
        border: Border(
          bottom: BorderSide(color: AppTheme.lightBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < zones.length; i++) ...[
                  _StepPill(
                    index: i + 1,
                    label: zones[i].zone.label,
                    emoji: zones[i].zone.emoji,
                    isActive: i == activeIndex,
                    isCompleted: zonesState.visitedZoneIds.contains(zones[i].zone.id) && i < activeIndex,
                    onTap: () {
                      ref.read(expandedAnswersProvider.notifier).collapse();
                      ref.read(semanticZonesProvider.notifier).activateZone(zones[i].zone.id);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: i < activeIndex ? _orange : AppTheme.lightBorder,
                    ),
                  ),
                ],
                _StepPill(
                  index: zones.length + 1,
                  label: 'Finalizar',
                  emoji: '🏁',
                  isActive: false,
                  isCompleted: false,
                  onTap: () {
                    if (hasContent) {
                      ref.read(resultVisibleProvider.notifier).show();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final int index;
  final String label;
  final String emoji;
  final bool isActive;
  final bool isCompleted;
  final VoidCallback onTap;

  const _StepPill({
    required this.index,
    required this.label,
    required this.emoji,
    required this.isActive,
    required this.isCompleted,
    required this.onTap,
  });

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 12 : 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? _orange
                : (isCompleted
                    ? _orange.withValues(alpha: 0.12)
                    : AppTheme.lightBg),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? _orange
                  : (isCompleted
                      ? _orange.withValues(alpha: 0.45)
                      : AppTheme.lightBorder),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _orange.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompleted)
                const Icon(Icons.check_circle, size: 14, color: _orange)
              else
                Text(
                  emoji,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? Colors.white : AppTheme.lightTextSub,
                  ),
                ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : (isCompleted ? _orange : AppTheme.lightText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
