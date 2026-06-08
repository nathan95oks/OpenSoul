import 'package:flutter/material.dart';
import '../../domain/entities/lsb_card.dart';
import 'semantic_node.dart';

/// Disposición adaptativa de nodos semánticos.
///
/// Ajusta columnas según cantidad de opciones para maximizar legibilidad
/// y reducir carga cognitiva (máximo 6 nodos visibles simultáneamente).
///
///   1      nodo  → 1 columna (ancho completo)
///   2      nodos → 2 columnas
///   3–6    nodos → 2 columnas (3 filas máx)
class AdaptiveNodeLayout extends StatelessWidget {
  final List<LsbCard> cards;
  final void Function(LsbCard) onCardTap;

  /// Glosas actualmente seleccionadas en la zona activa — para resaltar
  /// las tarjetas elegidas (selección múltiple / deselección).
  final Set<String> selectedGlosses;

  const AdaptiveNodeLayout({
    super.key,
    required this.cards,
    required this.onCardTap,
    this.selectedGlosses = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    final columns = cards.length == 1 ? 1 : 2;
    final ratio = cards.length == 1 ? 3.5 : 1.5;

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
