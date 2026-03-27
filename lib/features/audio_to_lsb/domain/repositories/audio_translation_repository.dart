import '../entities/lsb_translation.dart';

abstract class AudioTranslationRepository {
  /// Sends the recorded audio file to the backend and returns the LSB translation.
  Future<LsbTranslation> translateAudio(String audioPath);
}
