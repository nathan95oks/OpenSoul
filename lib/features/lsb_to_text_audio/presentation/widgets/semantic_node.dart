import 'package:flutter/material.dart';
import '../../domain/entities/lsb_card.dart';
import 'lsb_icons.dart';

/// Nodo semántico individual — unidad visual mínima del flujo progresivo.
///
/// Diseño inspirado en Linear/Notion: fondo negro, texto blanco,
/// naranja (#FF6B00) como único acento. Sin colores de categoría.
/// La jerarquía visual se construye con tamaño, peso tipográfico y posición.
class SemanticNode extends StatefulWidget {
  final LsbCard card;
  final VoidCallback onTap;

  const SemanticNode({super.key, required this.card, required this.onTap});

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
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
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
    final isEmergency = widget.card.isEmergency;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEmergency
                  ? _orange.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.07),
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                kLsbIconMap[widget.card.semanticIcon] ?? Icons.circle_outlined,
                size: 22,
                color: isEmergency
                    ? _orange
                    : Colors.white.withValues(alpha: 0.65),
              ),
              const SizedBox(height: 10),
              Text(
                widget.card.displayText.replaceAll('_', ' '),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: isEmergency ? 1.0 : 0.9),
                  letterSpacing: 0.2,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (isEmergency) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'URGENTE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: _orange,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
