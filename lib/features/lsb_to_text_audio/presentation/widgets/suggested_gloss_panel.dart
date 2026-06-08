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
    final maxPicks = zonesState.activeZone?.maxPicks ?? 1;
    final picksInZone = zonesState.picksInActiveZone;
    final selectedGlosses = zonesState.activeAnswers.toSet();

    return cardsAsync.when(
      data: (cards) {
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
              selectedGlosses: selectedGlosses,
              onCardTap: (card) => _onPick(ref, card),
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

  /// Selecciona o deselecciona la glosa en la zona activa.
  ///
  /// NO avanza de pregunta (el cambio es explícito vía "Continuar") y NO
  /// colapsa la lista expandida, para permitir elegir varias glosas seguidas.
  /// Tras el toggle reconstruye la secuencia en orden narrativo y la sincroniza
  /// con [sentenceProvider] (lo que alimenta la traducción).
  void _onPick(WidgetRef ref, LsbCard card) {
    final notifier = ref.read(semanticZonesProvider.notifier);
    notifier.toggleAnswer(card.gloss);
    ref.read(sentenceProvider.notifier).setWords(notifier.orderedGlosses());
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
          color: Colors.black.withValues(alpha: 0.45),
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
          color: Colors.black.withValues(alpha: 0.45),
          fontSize: 13,
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
        : 'Elegidas $current de $max — toca otra para añadir o vuelve a tocar para quitar';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.black.withValues(alpha: 0.5),
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
