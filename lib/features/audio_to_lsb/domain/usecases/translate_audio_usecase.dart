import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';

class TranslateAudioUseCase {
  final AudioTranslationRepository repository;

  TranslateAudioUseCase(this.repository);

  Future<LsbTranslation> execute(String audioPath) {
    return repository.translateAudio(audioPath);
  }
}
