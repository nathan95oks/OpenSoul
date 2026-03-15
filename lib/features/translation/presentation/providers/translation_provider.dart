import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:lsb_legal_app/features/translation/data/repositories/translation_repository_impl.dart';
import 'package:lsb_legal_app/features/translation/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/features/translation/domain/usecases/translate_cards_usecase.dart';

// Provider para la instancia de FlutterTts
final flutterTtsProvider = Provider<FlutterTts>((ref) {
  return FlutterTts();
});

// Provider para el repositorio de traducción
final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  final tts = ref.watch(flutterTtsProvider);
  return TranslationRepositoryImpl(tts);
});

// Provider para el caso de uso
final translateCardsUseCaseProvider = Provider<TranslateCardsUseCase>((ref) {
  final repository = ref.watch(translationRepositoryProvider);
  return TranslateCardsUseCase(repository);
});
