import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/lsb_icons.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/sign_image.dart';

class SemanticNode extends ConsumerStatefulWidget {
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
  ConsumerState<SemanticNode> createState() => _SemanticNodeState();
}

class _SemanticNodeState extends ConsumerState<SemanticNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  static const _orange = AppTheme.brandPrimary;

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
    final colorContenido = selected ? Colors.white : AppTheme.lightText;
    final conImagen = ref.watch(signImagesEnabledProvider);

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
            color: selected ? _orange : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _orange : AppTheme.lightBorder,
              width: selected ? 2 : 1.5,
            ),
            boxShadow: selected
                ? [BoxShadow(color: _orange.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                : AppTheme.cardShadow,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: conImagen ? 10 : 14,
          ),
          child: conImagen
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SignImage(
                      gloss: widget.card.gloss,
                      semanticIcon: widget.card.semanticIcon,
                      frames: widget.card.imageFrames,
                      size: 56,
                      color: colorContenido,
                    ),
                    const SizedBox(height: 8),
                    _etiqueta(colorContenido, TextAlign.center),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      kLsbIconMap[widget.card.semanticIcon] ??
                          Icons.circle_outlined,
                      size: 20,
                      color: colorContenido,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _etiqueta(colorContenido, TextAlign.start)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _etiqueta(Color color, TextAlign alineacion) => Text(
        widget.card.displayText.replaceAll('_', ' '),
        textAlign: alineacion,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
          height: 1.2,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
}

class AnswerNode extends StatelessWidget {
  final String gloss;
  final VoidCallback? onTap;

  const AnswerNode({super.key, required this.gloss, this.onTap});

  static const _orange = AppTheme.brandPrimary;

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

class QuestionNode extends StatelessWidget {
  final String question;
  final bool dimmed;

  const QuestionNode({super.key, required this.question, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.lightSubtle.withValues(alpha: dimmed ? 0.5 : 1.0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightBorder,
          width: 1.5,
        ),
      ),
      child: Text(
        question,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.lightText.withValues(alpha: dimmed ? 0.4 : 0.75),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
