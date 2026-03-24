import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sentence_provider.dart';

class SentenceBuilder extends ConsumerWidget {
  const SentenceBuilder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWords = ref.watch(sentenceProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),
        border: Border(bottom: BorderSide(color: Color(0xFFFFD700), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mensaje a generar:', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: selectedWords.isEmpty
                ? [const Text('Selecciona tarjetas abajo...', style: TextStyle(fontStyle: FontStyle.italic))]
                : selectedWords.map((word) => Chip(
                    label: Text(word.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    backgroundColor: const Color(0xFFFFD700),
                    deleteIconColor: Colors.black,
                    onDeleted: () {
                      ref.read(sentenceProvider.notifier).removeWord(word);
                    },
                  )).toList(),
          ),
        ],
      ),
    );
  }
}
