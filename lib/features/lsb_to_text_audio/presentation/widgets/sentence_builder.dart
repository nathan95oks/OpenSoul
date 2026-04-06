import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sentence_provider.dart';

/// Panel de construcción de secuencia de glosas.
/// Muestra las tarjetas seleccionadas como chips dorados con opción de eliminar.
class SentenceBuilder extends ConsumerWidget {
  const SentenceBuilder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWords = ref.watch(sentenceProvider);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Color(0xFFFFD700), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.sign_language, size: 16, color: Color(0xFFFFD700)),
              const SizedBox(width: 6),
              const Text(
                'SECUENCIA LSB',
                style: TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (selectedWords.isNotEmpty)
                Text(
                  '${selectedWords.length} glosas',
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: selectedWords.isEmpty
                ? [
                    Text(
                      'Selecciona tarjetas para construir tu mensaje...',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ]
                : selectedWords.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final word = entry.value;
                    return Chip(
                      label: Text(
                        word.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.black26,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                      backgroundColor: const Color(0xFFFFD700),
                      deleteIconColor: Colors.black54,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onDeleted: () => ref.read(sentenceProvider.notifier).removeWord(word),
                    );
                  }).toList(),
          ),
        ],
      ),
    );
  }
}
