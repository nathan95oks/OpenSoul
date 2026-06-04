import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sentence_provider.dart';
import '../providers/story_preview_provider.dart';

/// Vista previa en tiempo real del relato construido.
///
/// Mientras el usuario selecciona glosas, muestra simultáneamente:
///   • La interpretación en español formal ensamblada localmente
///   • La secuencia de glosas LSB como ruta visual
///
/// Retroalimentación instantánea sin latencia — usa LocalSentenceAssembler
/// en la capa de dominio vía storyPreviewProvider.
class StoryPreviewCard extends ConsumerWidget {
  const StoryPreviewCard({super.key});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(storyPreviewProvider);
    final glosses = ref.watch(sentenceProvider);

    if (glosses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 6),
                Text(
                  'VISTA PREVIA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.35),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Relato en español
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                preview.isNotEmpty ? preview : '...',
                key: ValueKey(preview),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.45,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Ruta de glosas LSB
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (int i = 0; i < glosses.length; i++) ...[
                  Text(
                    glosses[i].replaceAll('_', ' '),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _orange,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (i < glosses.length - 1)
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
