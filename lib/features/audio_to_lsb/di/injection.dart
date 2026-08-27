import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/domain/usecases/translate_text_usecase.dart';

final translateTextUseCaseProvider = Provider<TranslateTextUseCase>((ref) {
  return TranslateTextUseCase(ref.watch(audioTranslationRepositoryProvider));
});
