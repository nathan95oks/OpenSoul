import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/card_grid.dart' show expandedAnswersProvider;
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/suggested_gloss_panel.dart';

class NodeFlowCanvas extends ConsumerWidget {
  const NodeFlowCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final zonesState = ref.watch(semanticZonesProvider);

    if (ctx == null) return const SizedBox.shrink();

    final orderedVisited = zonesState.visitedZoneOrder
        .where((id) => id != zonesState.activeZoneId)
        .toList();
    final activeZone = zonesState.activeZone;

    final hasTranslated =
        ref.watch(translationControllerProvider).value != null;

    final requested = zonesState.requestedZoneIds;
    final answeringRequest =
        requested.isNotEmpty && requested.contains(zonesState.activeZoneId);
    final totalZones = answeringRequest ? requested.length : ctx.zones.length;
    final reachedZones = answeringRequest
        ? (requested.indexOf(zonesState.activeZoneId!) + 1)
        : zonesState.visitedZoneIds.length.clamp(1, totalZones);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _ContextChip(emoji: ctx.emoji, label: ctx.name)),
          const SizedBox(height: 14),
          _ProgressBar(
            reached: reachedZones,
            total: totalZones,
            label: answeringRequest ? 'Respondiendo' : 'Pregunta',
          ),
          const SizedBox(height: 22),

          if (activeZone != null)
            _ActiveCard(
              question: activeZone.question.isNotEmpty
                  ? activeZone.question
                  : activeZone.hint,
            ),

          if (hasTranslated && orderedVisited.isNotEmpty) ...[
            const SizedBox(height: 26),
            const _HistoryHeader(),
            const SizedBox(height: 10),
            for (final zoneId in orderedVisited)
              _CompactAnswerRow(
                zoneId: zoneId,
                zonesState: zonesState,
                onEditTap: () {
                  ref.read(expandedAnswersProvider.notifier).collapse();
                  ref.read(semanticZonesProvider.notifier).activateZone(zoneId);
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final String emoji;
  final String label;
  const _ContextChip({required this.emoji, required this.label});

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _orange.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _orange,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int reached;
  final int total;
  final String label;

  const _ProgressBar({
    required this.reached,
    required this.total,
    this.label = 'Pregunta',
  });

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : (reached / total).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 5,
            backgroundColor: AppTheme.lightBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(_orange),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$label $reached de $total',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.lightTextSub,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'TU RELATO HASTA AHORA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.lightTextSub,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: AppTheme.lightBorder,
          ),
        ),
      ],
    );
  }
}

class _CompactAnswerRow extends StatelessWidget {
  final String zoneId;
  final SemanticZonesState zonesState;
  final VoidCallback onEditTap;

  const _CompactAnswerRow({
    required this.zoneId,
    required this.zonesState,
    required this.onEditTap,
  });

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    final zone = zonesState.snapshot.orderedZones
        .cast<dynamic>()
        .firstWhere((p) => (p.zone.id as String) == zoneId, orElse: () => null);
    if (zone == null) return const SizedBox.shrink();

    final question = (zone.zone.question as String).isNotEmpty
        ? zone.zone.question as String
        : zone.zone.hint as String;
    final answers = (zonesState.zoneAnswers[zoneId] ?? const <String>[]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEditTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.lightBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.lightTextSub,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (answers.isEmpty)
                        Text(
                          'Sin responder',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.lightTextSub.withValues(alpha: 0.7),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: answers
                              .map((g) => _MiniChip(label: g))
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.edit_outlined,
                    size: 16, color: _orange.withValues(alpha: 0.9)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  const _MiniChip({required this.label});

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _orange,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final String question;

  const _ActiveCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandPrimary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _ActiveQuestion(question: question),
          const SizedBox(height: 16),
          const _OptionsPanel(),
        ],
      ),
    );
  }
}

class GuidedNavBar extends ConsumerWidget {
  const GuidedNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextProvider);
    final zonesState = ref.watch(semanticZonesProvider);
    if (ctx == null || zonesState.activeZone == null) {
      return const SizedBox.shrink();
    }

    return Container(
      color: AppTheme.lightBg,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: _NavControls(
        canGoBack: zonesState.canGoBack,
        hasNext: zonesState.hasNextQuestion,
        onBack: () {
          ref.read(expandedAnswersProvider.notifier).collapse();
          ref.read(semanticZonesProvider.notifier).goToPreviousZone();
        },
        onContinue: () {
          ref.read(expandedAnswersProvider.notifier).collapse();
          ref.read(semanticZonesProvider.notifier).goToNextZone();
        },
      ),
    );
  }
}

class _ActiveQuestion extends StatelessWidget {
  final String question;
  const _ActiveQuestion({required this.question});

  @override
  Widget build(BuildContext context) {
    return Text(
      question,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: AppTheme.lightText,
        height: 1.25,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _NavControls extends StatelessWidget {
  final bool canGoBack;
  final bool hasNext;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const _NavControls({
    required this.canGoBack,
    required this.hasNext,
    required this.onBack,
    required this.onContinue,
  });

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _NavButton(
              label: 'Volver',
              icon: Icons.arrow_back,
              filled: false,
              enabled: canGoBack,
              onTap: canGoBack ? onBack : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: hasNext
                ? _NavButton(
                    label: 'Continuar',
                    icon: Icons.arrow_forward,
                    filled: true,
                    enabled: true,
                    onTap: onContinue,
                  )
                : Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: _orange.withValues(alpha: 0.45)),
                    ),
                    child: const Text(
                      'Relato completo — pulsa TRADUCIR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _orange,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? _orange
        : AppTheme.lightSurface;
    final fg = filled
        ? Colors.white
        : (enabled ? AppTheme.lightText : AppTheme.lightTextSub.withValues(alpha: 0.5));
    final borderColor = filled
        ? _orange
        : (enabled ? AppTheme.lightBorder : AppTheme.lightBorder.withValues(alpha: 0.5));

    return SizedBox(
      height: 48,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: filled ? 2 : 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionsPanel extends ConsumerWidget {
  const _OptionsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SuggestedGlossPanel();
  }
}

