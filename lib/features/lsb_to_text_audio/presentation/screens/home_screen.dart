import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sentence_provider.dart';
import '../controllers/translation_controller.dart';
import '../widgets/sentence_builder.dart';
import '../widgets/category_filter.dart';
import '../widgets/card_grid.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWords = ref.watch(sentenceProvider);
    final translationState = ref.watch(translationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comisaría / Juzgado', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: Colors.blueAccent),
            onPressed: () => context.push('/audio-to-lsb'),
            tooltip: 'Ir a Audio -> LSB',
          ),
          if (selectedWords.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: () => ref.read(sentenceProvider.notifier).clearSentence(),
              tooltip: 'Borrar todo',
            ),
        ],
      ),
      body: Column(
        children: [
          const SentenceBuilder(),

          const CategoryFilter(),

          const CardGrid(),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: selectedWords.isEmpty || translationState.isLoading ? null : () async {
                  await ref.read(translationControllerProvider.notifier).translateCards(
                    context: 'legal',
                    cards: selectedWords,
                  );
                  if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio generado con éxito')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: translationState.isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.volume_up, size: 28),
                label: Text(
                  translationState.isLoading ? 'GENERANDO...' : 'GENERAR VOZ',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
