import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/translate_cards_usecase.dart';

final translateCardsUseCaseProvider = Provider<TranslateCardsUseCase>((ref) {
  final repository = ref.watch(translationRepositoryProvider);
  return TranslateCardsUseCase(repository);
});
