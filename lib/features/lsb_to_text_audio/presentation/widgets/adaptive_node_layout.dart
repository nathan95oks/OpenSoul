import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/semantic_node.dart';

class AdaptiveNodeLayout extends ConsumerWidget {
  final List<LsbCard> cards;
  final void Function(LsbCard) onCardTap;

  final Set<String> selectedGlosses;

  const AdaptiveNodeLayout({
    super.key,
    required this.cards,
    required this.onCardTap,
    this.selectedGlosses = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final columns = cards.length == 1 ? 1 : 2;

    final conImagen = ref.watch(signImagesEnabledProvider);
    final ratio = cards.length == 1
        ? (conImagen ? 2.6 : 3.5)
        : (conImagen ? 1.05 : 1.5);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: ratio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => SemanticNode(
        card: cards[i],
        isSelected: selectedGlosses.contains(cards[i].gloss),
        onTap: () => onCardTap(cards[i]),
      ),
    );
  }
}
