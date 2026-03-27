import '../entities/lsb_translation.dart';
import '../repositories/audio_translation_repository.dart';

class TranslateAudioUseCase {
  final AudioTranslationRepository repository;

  TranslateAudioUseCase(this.repository);

  Future<LsbTranslation> execute(String audioPath) {
    return repository.translateAudio(audioPath);
  }
}
