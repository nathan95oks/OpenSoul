import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/qualifier_sheets.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/sign_image.dart';

const int _kAnswersPerQuestion = 6;

class ExpandedAnswersNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void expand() => state = true;
  void collapse() => state = false;
}

final expandedAnswersProvider = NotifierProvider<ExpandedAnswersNotifier, bool>(
  ExpandedAnswersNotifier.new,
);

class CardGrid extends ConsumerWidget {
  const CardGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(dynamicCardsProvider);
    final expanded = ref.watch(expandedAnswersProvider);
    final zonesState = ref.watch(semanticZonesProvider);
    final activeZone = zonesState.activeZone;
    final flowComplete = zonesState.isFlowComplete;
    final maxPicks = activeZone?.maxPicks ?? 1;
    final showPairHint = maxPicks > 1 && !flowComplete;

    return cardsAsync.when(
      data: (cards) {
        if (cards.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No hay opciones disponibles para esta pregunta.\nUsa "Saltar" o "Terminé y traducir".',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.lightTextSub, fontSize: 13),
              ),
            ),
          );
        }

        if (flowComplete) {
          return const _FlowCompleteBanner();
        }

        final visible = expanded
            ? cards
            : cards.take(_kAnswersPerQuestion).toList();
        final hasMore = !expanded && cards.length > _kAnswersPerQuestion;

        return Column(
          children: [
            if (showPairHint)
              _PairPickHint(
                current: zonesState.picksInActiveZone,
                max: maxPicks,
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final card = visible[index];
                return _AnswerCard(
                  card: card,
                  onTap: () => _onAnswerPicked(context, ref, card),
                );
              },
            ),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextButton.icon(
                  onPressed: () =>
                      ref.read(expandedAnswersProvider.notifier).expand(),
                  icon: const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: AppTheme.lightTextSub,
                  ),
                  label: Text(
                    'Ver más opciones (${cards.length - _kAnswersPerQuestion})',
                    style: const TextStyle(
                      color: AppTheme.lightTextSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Error al cargar opciones',
            style: TextStyle(color: AppTheme.errorLight),
          ),
        ),
      ),
    );
  }

  Future<void> _onAnswerPicked(
          BuildContext context, WidgetRef ref, LsbCard card) =>
      elegirGlosa(context, ref, card);
}

class _PairPickHint extends StatelessWidget {
  final int current;
  final int max;
  const _PairPickHint({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final remaining = max - current;
    final label = current == 0
        ? 'Puedes elegir hasta $max cards para describir mejor'
        : 'Card $current de $max — toca otra para complementar, o salta';
    final color = remaining > 0
        ? AppTheme.brandPrimary
        : AppTheme.lightTextSub;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowCompleteBanner extends StatelessWidget {
  const _FlowCompleteBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.successLight.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.successLight.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.successLight, size: 28),
            const SizedBox(height: 8),
            const Text(
              'Respondiste todas las preguntas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.lightText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pulsa "TERMINÉ Y TRADUCIR" o toca una pregunta de la barra para editar tu respuesta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.lightTextSub,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
class AnswerCardForTest extends _AnswerCard {
  const AnswerCardForTest({super.key, required super.card, required super.onTap});
}

class _AnswerCard extends ConsumerWidget {
  final LsbCard card;
  final VoidCallback onTap;
  const _AnswerCard({super.key, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEmergency = card.isEmergency;
    final accent = isEmergency ? AppTheme.errorLight : AppTheme.brandPrimary;

    return Semantics(
      button: true,
      label: isEmergency
          ? '${card.displayText}, opción de emergencia'
          : card.displayText,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: SignImage(
                  gloss: card.gloss,
                  semanticIcon: card.semanticIcon,
                  frames: card.imageFrames,
                  size: 44,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  card.displayText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.lightText,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
