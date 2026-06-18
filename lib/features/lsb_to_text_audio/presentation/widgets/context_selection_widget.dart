import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme.dart';
import '../providers/context_provider.dart';
import '../../domain/entities/semantic_context.dart';

/// Pantalla de selección de contexto — estilo reference design.
/// Fondo blanco, botones con borde negro, hover naranja.
class ContextSelectionWidget extends ConsumerWidget {
  const ContextSelectionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Selecciona el contexto',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.lightText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '¿Sobre qué necesitas hacer una declaración?',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.lightTextSub,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 28),
            ...availableContexts.map((ctx) => _ContextButton(context: ctx)),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Diseñado para ser accesible y fácil de usar',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.lightTextSub.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ContextButton extends ConsumerStatefulWidget {
  final SemanticContext context;
  const _ContextButton({required this.context});

  @override
  ConsumerState<_ContextButton> createState() => _ContextButtonState();
}

class _ContextButtonState extends ConsumerState<_ContextButton> {
  bool _hovered = false;

  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // A11Y-01: el lector de pantalla anuncia cada contexto como un botón con
      // su nombre y descripción (el emoji y la flecha son decorativos).
      child: Semantics(
        button: true,
        label: '${widget.context.name}. ${widget.context.description}',
        excludeSemantics: true,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _hovered = true),
          onTapUp: (_) {
            setState(() => _hovered = false);
            ref.read(contextProvider.notifier).setContext(widget.context);
          },
          onTapCancel: () => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovered ? _orange : AppTheme.lightBorder,
                width: _hovered ? 2 : 1.5,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Text(
                  widget.context.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.context.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _hovered ? _orange : AppTheme.lightText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.context.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.lightTextSub,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: _hovered
                      ? _orange
                      : AppTheme.lightTextSub,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
