import 'package:flutter_riverpod/flutter_riverpod.dart';

class SentenceNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return [];
  }

  void addWord(String word) {
    state = [...state, word];
  }

  void removeWord(String word) {
    state = state.where((w) => w != word).toList();
  }

  /// Reemplaza la secuencia completa de glosas.
  ///
  /// Lo usa la navegación semántica para reconstruir la frase en el orden
  /// narrativo correcto (zona por zona) tras editar o deseleccionar una
  /// respuesta — evitando que una glosa editada salte al final.
  void setWords(List<String> words) {
    state = List<String>.from(words);
  }

  void clearSentence() {
    state = [];
  }
}

final sentenceProvider = NotifierProvider<SentenceNotifier, List<String>>(SentenceNotifier.new);
