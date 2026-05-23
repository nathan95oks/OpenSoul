import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/context_provider.dart';
import '../../domain/entities/semantic_context.dart';

class ContextSelectionWidget extends ConsumerWidget {
  const ContextSelectionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            '¿En qué podemos ayudarte?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, bottom: 16.0),
          child: Text(
            'Selecciona una situación para guiarte mejor.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8B949E),
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: availableContexts.length,
          itemBuilder: (context, index) {
            final semanticCtx = availableContexts[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: _ContextCard(semanticContext: semanticCtx),
            );
          },
        ),
      ],
    );
  }
}

class _ContextCard extends ConsumerWidget {
  final SemanticContext semanticContext;

  const _ContextCard({required this.semanticContext});

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'warning_amber': return Icons.warning_amber_rounded;
      case 'assignment': return Icons.assignment_rounded;
      case 'local_hospital': return Icons.local_hospital_rounded;
      case 'chat': return Icons.chat_rounded;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        ref.read(contextProvider.notifier).setContext(semanticContext);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconData(semanticContext.icon),
                color: const Color(0xFFFFD700),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    semanticContext.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    semanticContext.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8B949E),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFF8B949E), size: 16),
          ],
        ),
      ),
    );
  }
}
