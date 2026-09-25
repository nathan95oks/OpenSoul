import 'package:flutter/material.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/qualifier_sheets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/adaptive_node_layout.dart';

class SuggestedGlossPanel extends ConsumerWidget {
  const SuggestedGlossPanel({super.key});

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(dynamicCardsProvider);
    final zonesState = ref.watch(semanticZonesProvider);
    final selectedGlosses = zonesState.activeAnswers.toSet();

    return cardsAsync.when(
      data: (cards) {
        if (cards.isEmpty) {
          return const _EmptyState();
        }

        final visible = cards;

        return AdaptiveNodeLayout(
          cards: visible,
          selectedGlosses: selectedGlosses,
          onCardTap: (card) => _onPick(context, ref, card),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: _orange, strokeWidth: 1.5),
        ),
      ),
      error: (e, s) => const _ErrorState(),
    );
  }

  Future<void> _onPick(BuildContext context, WidgetRef ref, LsbCard card) =>
      elegirGlosa(context, ref, card);
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

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Error al cargar opciones.',
        style: TextStyle(color: AppTheme.lightTextSub, fontSize: 13),
      ),
    );
  }
}
