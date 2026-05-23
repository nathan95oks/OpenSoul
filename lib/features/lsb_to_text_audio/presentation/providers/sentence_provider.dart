import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'guided_flow_provider.dart';

class SentenceNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return [];
  }

  void addWord(String word) {
    state = [...state, word]; // Creamos una nueva lista con la palabra extra
    // Avanzar flujo guiado automáticamente al agregar glosa
    ref.read(guidedFlowProvider.notifier).advanceStep();
  }

  void removeWord(String word) {
    state = state.where((w) => w != word).toList();
  }

  void clearSentence() {
    state = [];
  }
}

final sentenceProvider = NotifierProvider<SentenceNotifier, List<String>>(SentenceNotifier.new);
