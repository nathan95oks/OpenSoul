import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:audioplayers/audioplayers.dart';

import '../../domain/repositories/translation_repository.dart';
import '../providers/translation_provider.dart';

class TranslationController extends AsyncNotifier<TranslationResult?> {
  final AudioPlayer _audioPlayer = AudioPlayer();

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
      
      // Auto-reproducir audio si existe
      if (result.audioUrl != null && result.audioUrl!.isNotEmpty) {
        await _audioPlayer.play(UrlSource(result.audioUrl!));
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final translationControllerProvider = AsyncNotifierProvider<TranslationController, TranslationResult?>(
  TranslationController.new,
);
