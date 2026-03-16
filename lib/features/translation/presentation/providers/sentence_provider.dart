
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SentenceNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return [];
  }

  void addWord(String word) {
    state = [...state, word]; // Creamos una nueva lista con la palabra extra
  }

  void removeWord(String word) {
    state = state.where((w) => w != word).toList();
  }

  void clearSentence() {
    state = [];
  }
}

final sentenceProvider = NotifierProvider<SentenceNotifier, List<String>>(SentenceNotifier.new);
