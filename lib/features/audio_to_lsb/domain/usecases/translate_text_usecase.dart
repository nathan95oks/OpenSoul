import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';

class TranslateTextUseCase {
  final AudioTranslationRepository repository;

  TranslateTextUseCase(this.repository);

  Future<LsbTranslation> execute(String text) async {
    return await repository.translateText(text);
  }
}
