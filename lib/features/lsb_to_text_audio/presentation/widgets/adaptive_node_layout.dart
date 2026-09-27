import 'package:flutter/material.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/semantic_node.dart';

/// Tarjetas de respuesta en una grilla que se adapta al ancho disponible.
///
/// Cada fila mide lo que necesita su tarjeta más alta: con una proporción
/// fija, una etiqueta de dos líneas o una imagen desbordaban la tarjeta y se
/// pintaban encima de la fila siguiente.
class AdaptiveNodeLayout extends StatelessWidget {
  final List<LsbCard> cards;
  final void Function(LsbCard) onCardTap;

  final Set<String> selectedGlosses;

  /// Selección por identificador de tarjeta. Cuando se da, manda sobre
  /// [selectedGlosses]: dos opciones pueden compartir glosa («Cuándo vuelvo»
  /// y «Cuándo me avisan» empiezan por CUÁNDO) y no por eso son la misma.
  final Set<String>? selectedIds;

  /// Resalta las opciones como un campo obligatorio pendiente.
  final bool requiresSelection;

  /// Mantener una tarjeta muestra su seña en el avatar sin elegirla (ver
  /// [SemanticNode.onPreview]). Sin él, las tarjetas solo responden al toque.
  final Future<void> Function(LsbCard)? onCardPreview;

  const AdaptiveNodeLayout({
    super.key,
    required this.cards,
    required this.onCardTap,
    this.selectedGlosses = const {},
    this.selectedIds,
    this.onCardPreview,
    this.requiresSelection = false,
  });

  static const _spacing = 12.0;
  static const _padding = 16.0;
  static const _cardAspect = 1.15;
  static const _minCardHeight = 96.0;
  static const _maxCardHeight = 220.0;
  static const _singleColumnHeight = 96.0;
  static const _compactBreakpoint = 340.0;
  static const _wideBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final preferredColumns = constraints.maxWidth < _compactBreakpoint
            ? 1
            : constraints.maxWidth >= _wideBreakpoint
            ? 3
            : 2;
        final columns = cards.length < preferredColumns
            ? cards.length
            : preferredColumns;
        final rows = <List<LsbCard>>[
          for (var i = 0; i < cards.length; i += columns)
            cards.sublist(
              i,
              i + columns < cards.length ? i + columns : cards.length,
            ),
        ];
        // Tarjetas grandes, casi cuadradas, con la glosa en el centro. El
        // alto sale del ancho de la columna, no de la pregunta; una etiqueta
        // larga o un texto ampliado siguen pudiendo estirarlas.
        final cellWidth =
            (constraints.maxWidth - 2 * _padding - (columns - 1) * _spacing) /
            columns;
        final minHeight = columns == 1
            ? _singleColumnHeight
            : (cellWidth * _cardAspect).clamp(_minCardHeight, _maxCardHeight);

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _padding,
            vertical: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) const SizedBox(height: _spacing),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var c = 0; c < columns; c++) ...[
                        if (c > 0) const SizedBox(width: _spacing),
                        Expanded(
                          child: c < rows[r].length
                              ? ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: minHeight,
                                  ),
                                  child: _node(rows[r][c]),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _node(LsbCard card) {
    final preview = onCardPreview;
    return SemanticNode(
      key: ValueKey(card.id),
      card: card,
      isSelected:
          selectedIds?.contains(card.id) ??
          selectedGlosses.contains(card.gloss),
      requiresSelection: requiresSelection,
      onTap: () => onCardTap(card),
      onPreview: preview == null ? null : () => preview(card),
    );
  }
}
