import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';

abstract class AudioTranslationRepository {
  /// Sends the recorded audio file to the backend and returns the LSB translation.
  Future<LsbTranslation> translateAudio(String audioPath);
  
  /// Sends raw text to the backend and returns the LSB translation.
  ///
  /// [situation] carries the conversation's active situational context so the
  /// remote engine can narrow the vocabulary. Null on the first turn.
  Future<LsbTranslation> translateText(String text, {String? situation});
}
