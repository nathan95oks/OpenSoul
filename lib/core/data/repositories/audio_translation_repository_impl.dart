import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';

class AudioTranslationRepositoryImpl implements AudioTranslationRepository {
  final RemoteAudioDataSource remoteDataSource;

  AudioTranslationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<LsbTranslation> translateText(String text, {String? situation}) async {
    try {
      final model =
          await remoteDataSource.translateText(text, situation: situation);
      return model;
    } catch (e) {
      throw Exception('Failed to translate text: $e');
    }
  }
}
