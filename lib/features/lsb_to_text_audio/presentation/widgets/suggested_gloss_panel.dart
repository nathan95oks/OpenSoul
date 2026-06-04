import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lsb_card.dart';
import '../providers/cards_provider.dart';
import '../providers/semantic_zones_provider.dart';
import '../providers/sentence_provider.dart';
import 'adaptive_node_layout.dart';
import 'card_grid.dart' show expandedAnswersProvider;

/// Panel de sugerencias progresivas — reemplaza CardGrid.
///
/// Muestra entre 4 y 6 SemanticNodes según el motor semántico.
/// Cada selección revela las siguientes opciones más probables,
/// creando un flujo de árbol semántico / conversación guiada.
class SuggestedGlossPanel extends ConsumerWidget {
  const SuggestedGlossPanel({super.key});

  static const _kMaxVisible = 6;
  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(dynamicCardsProvider);
    final expanded = ref.watch(expandedAnswersProvider);
    final zonesState = ref.watch(semanticZonesProvider);
    final flowComplete = zonesState.isFlowComplete;
    final maxPicks = zonesState.activeZone?.maxPicks ?? 1;
    final picksInZone = zonesState.picksInActiveZone;

    return cardsAsync.when(
      data: (cards) {
        if (flowComplete) return const _FlowCompleteState();

        if (cards.isEmpty) {
          return const _EmptyState();
        }

        final visible = expanded ? cards : cards.take(_kMaxVisible).toList();
        final remaining = cards.length - _kMaxVisible;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (maxPicks > 1)
              _PairHint(current: picksInZone, max: maxPicks),
            AdaptiveNodeLayout(
              cards: visible,
              onCardTap: (card) => _onPick(ref, card, cards),
            ),
            if (!expanded && remaining > 0)
              _ExpandButton(
                remaining: remaining,
                onTap: () => ref.read(expandedAnswersProvider.notifier).expand(),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(
            color: _orange,
            strokeWidth: 1.5,
          ),
        ),
      ),
      error: (e, s) => const _ErrorState(),
    );
  }

  void _onPick(WidgetRef ref, LsbCard card, List<LsbCard> allCards) {
    final activeZoneId = ref.read(semanticZonesProvider).activeZoneId;
    if (activeZoneId != null) {
      ref.read(semanticZonesProvider.notifier).recordAnswer(activeZoneId, card.gloss);
    }
    ref.read(sentenceProvider.notifier).addWord(card.gloss);
    ref.read(expandedAnswersProvider.notifier).collapse();
    ref.read(semanticZonesProvider.notifier).advanceFromCard(card, allCards);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Text(
        'No hay opciones para esta pregunta.\nUsa "Saltar" o "Terminé y traducir".',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Error al cargar opciones.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _FlowCompleteState extends StatelessWidget {
  const _FlowCompleteState();

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _orange.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: _orange, size: 28),
            const SizedBox(height: 10),
            const Text(
              'Respondiste todas las preguntas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Toca una zona superior para editar,\no presiona "Traducir".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PairHint extends StatelessWidget {
  final int current;
  final int max;
  const _PairHint({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    final label = current == 0
        ? 'Puedes elegir hasta $max tarjetas para describir mejor'
        : 'Tarjeta ${current + 1} de $max — toca otra o salta';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.45),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _ExpandButton extends StatelessWidget {
  final int remaining;
  final VoidCallback onTap;
  const _ExpandButton({required this.remaining, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 6),
              Text(
                'Ver $remaining más',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
