import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/theme.dart';
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
        color: AppTheme.lightSurface,
        border: Border(bottom: BorderSide(color: AppTheme.brandPrimary, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.sign_language, size: 16, color: AppTheme.brandPrimary),
              const SizedBox(width: 6),
              const Text(
                'SECUENCIA LSB',
                style: TextStyle(
                  color: AppTheme.lightTextSub,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (selectedWords.isNotEmpty)
                Text(
                  '${selectedWords.length} glosas',
                  style: const TextStyle(color: AppTheme.lightTextSub, fontSize: 11),
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
                        color: AppTheme.lightTextSub.withValues(alpha: 0.7),
                      ),
                    ),
                  ]
                : selectedWords.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final word = entry.value;
                    return Chip(
                      label: Text(
                        // La secuencia guarda la glosa cruda (p. ej.
                        // "TRES"); para el chip se muestra legible.
                        word.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.white24,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      backgroundColor: AppTheme.brandPrimary,
                      deleteIconColor: Colors.white70,
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
