import '../../domain/entities/lsb_translation.dart';
import '../../domain/repositories/audio_translation_repository.dart';
import '../datasources/remote_audio_datasource.dart';

class AudioTranslationRepositoryImpl implements AudioTranslationRepository {
  final RemoteAudioDataSource remoteDataSource;

  AudioTranslationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<LsbTranslation> translateAudio(String audioPath) async {
    try {
      final model = await remoteDataSource.translateAudio(audioPath);
      // Depending on architecture, we might map model to entity here if they were different.
      // Since LsbTranslationModel extends LsbTranslation, we can just return it.
      return model;
    } catch (e) {
      // Handle exceptions (e.g. throw a mapped failure)
      throw Exception('Failed to translate audio: $e');
    }
  }

  @override
  Future<LsbTranslation> translateText(String text) async {
    try {
      final model = await remoteDataSource.translateText(text);
      return model;
    } catch (e) {
      throw Exception('Failed to translate text: $e');
    }
  }
}
