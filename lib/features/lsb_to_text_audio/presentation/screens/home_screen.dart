import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/translation_repository.dart';
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

    // Escucha cambios en el estado para mostrar SnackBars correctamente
    ref.listen<AsyncValue<TranslationResult?>>(
      translationControllerProvider,
      (previous, next) {
        if (next is AsyncData && next.value != null) {
          final result = next.value!;
          if (result.audioUrl != null && result.audioUrl!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Audio generado y reproduciendo...')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Texto generado con éxito (Sin audio disponible)')),
            );
          }
        } else if (next is AsyncError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${next.error}')),
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comisaría / Juzgado', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
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

          // Bloque UI para mostrar el texto generado persistentemente
          if (translationState.value != null && translationState.value!.generatedText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Traducción Generada:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      translationState.value!.generatedText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

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
