import '../entities/lsb_translation.dart';
import '../repositories/audio_translation_repository.dart';

class TranslateTextUseCase {
  final AudioTranslationRepository repository;

  TranslateTextUseCase(this.repository);

  Future<LsbTranslation> execute(String text) async {
    return await repository.translateText(text);
  }
}
