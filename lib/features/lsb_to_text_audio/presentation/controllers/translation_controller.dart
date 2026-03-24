import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/translation_repository.dart';
import '../providers/translation_provider.dart';

class TranslationController extends AsyncNotifier<TranslationResult?> {
  @override
  Future<TranslationResult?> build() async {
    return null;
  }

  Future<void> translateCards({required String context, required List<String> cards}) async {
    state = const AsyncValue.loading();
    
    final translateUseCase = ref.read(translateCardsUseCaseProvider);
    
    try {
      final result = await translateUseCase(context: context, cards: cards);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final translationControllerProvider = AsyncNotifierProvider<TranslationController, TranslationResult?>(
  TranslationController.new,
);
