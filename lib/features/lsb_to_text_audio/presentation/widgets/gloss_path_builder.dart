import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sentence_provider.dart';

/// Constructor de ruta de glosas — reemplaza SentenceBuilder.
///
/// Muestra la secuencia construida como un flujo horizontal de nodos:
///   ROBAR  ›  CELULAR  ›  AYER  ›  PLAZA
///
/// Diseño minimalista: texto naranja en negro, sin chips de colores.
/// Toca una glosa para eliminarla.
class GlossPathBuilder extends ConsumerWidget {
  const GlossPathBuilder({super.key});

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glosses = ref.watch(sentenceProvider);

    if (glosses.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sign_language,
                size: 13,
                color: Colors.white.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 6),
              Text(
                'SECUENCIA LSB',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${glosses.length}',
                style: const TextStyle(
                  fontSize: 10,
                  color: _orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < glosses.length; i++) ...[
                  _GlossNode(
                    gloss: glosses[i],
                    index: i + 1,
                    onRemove: () =>
                        ref.read(sentenceProvider.notifier).removeWord(glosses[i]),
                  ),
                  if (i < glosses.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '›',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlossNode extends StatelessWidget {
  final String gloss;
  final int index;
  final VoidCallback onRemove;

  const _GlossNode({
    required this.gloss,
    required this.index,
    required this.onRemove,
  });

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    final label = gloss.replaceAll('_', ' ').toUpperCase();

    return GestureDetector(
      onLongPress: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$index',
              style: TextStyle(
                fontSize: 9,
                color: _orange.withValues(alpha: 0.6),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
