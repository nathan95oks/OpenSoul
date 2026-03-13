// lib/providers/sentence_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Esta clase controla la lista de palabras seleccionadas
class SentenceNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    // Estado inicial: una lista vacía
    return [];
  }

  // Agregar una palabra a la frase
  void addWord(String word) {
    state = [...state, word]; // Creamos una nueva lista con la palabra extra
  }

  // Quitar una palabra de la frase
  void removeWord(String word) {
    state = state.where((w) => w != word).toList();
  }

  // Limpiar toda la frase (útil después de generar el audio)
  void clearSentence() {
    state = [];
  }
}

// Notifier para manejar la categoría seleccionada (por ejemplo: "Sujetos", "Verbos", etc.)
class CategoryNotifier extends Notifier<String> {
  @override
  String build() {
    return 'Sujetos';
  }
}

// Este es el "puente" para que la interfaz se conecte con la clase de arriba
final sentenceProvider =
    NotifierProvider<SentenceNotifier, List<String>>(SentenceNotifier.new);
final categoryProvider =
    NotifierProvider<CategoryNotifier, String>(CategoryNotifier.new);

