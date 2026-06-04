import 'package:flutter/material.dart';
import '../../domain/entities/lsb_card.dart';
import 'lsb_icons.dart';

/// Nodo semántico individual.
///
/// Sin seleccionar: fondo blanco, borde negro 2px, texto negro.
/// Seleccionado / activo: fondo naranja, borde naranja, texto blanco.
/// Inspirado en el GlossNode del reference design.
class SemanticNode extends StatefulWidget {
  final LsbCard card;
  final VoidCallback onTap;
  final bool isSelected;

  const SemanticNode({
    super.key,
    required this.card,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  State<SemanticNode> createState() => _SemanticNodeState();
}

class _SemanticNodeState extends State<SemanticNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  static const _orange = Color(0xFFFF6B00);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? _orange : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _orange : Colors.black,
              width: 2,
            ),
            boxShadow: selected
                ? [BoxShadow(color: _orange.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                kLsbIconMap[widget.card.semanticIcon] ?? Icons.circle_outlined,
                size: 20,
                color: selected ? Colors.white : Colors.black,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.card.displayText.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.black,
                    letterSpacing: 0.2,
                    height: 1.2,
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

/// Nodo de respuesta ya seleccionada (muestra glosa, no card).
/// Se usa en el árbol conceptual para las respuestas pasadas.
class AnswerNode extends StatelessWidget {
  final String gloss;
  final VoidCallback? onTap;

  const AnswerNode({super.key, required this.gloss, this.onTap});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _orange,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _orange, width: 2),
        ),
        child: Text(
          gloss.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Nodo de pregunta (zona semántica).
class QuestionNode extends StatelessWidget {
  final String question;
  final bool dimmed;

  const QuestionNode({super.key, required this.question, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: dimmed ? 0.03 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: dimmed ? 0.08 : 0.15),
          width: 1.5,
        ),
      ),
      child: Text(
        question,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black.withValues(alpha: dimmed ? 0.4 : 0.75),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
