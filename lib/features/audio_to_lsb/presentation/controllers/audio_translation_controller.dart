import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/lsb_translation.dart';
import '../../domain/usecases/translate_audio_usecase.dart';
import '../../domain/usecases/translate_text_usecase.dart';
import '../../data/datasources/remote_audio_datasource.dart';
import '../../data/repositories/audio_translation_repository_impl.dart';

// Providers for dependencies
final httpClientProviderForAudio = Provider((ref) => http.Client());

final remoteAudioDataSourceProvider = Provider<RemoteAudioDataSource>((ref) {
  return RemoteAudioDataSourceImpl(client: ref.read(httpClientProviderForAudio));
});

final audioTranslationRepositoryProvider = Provider((ref) {
  return AudioTranslationRepositoryImpl(remoteDataSource: ref.read(remoteAudioDataSourceProvider));
});

final translateAudioUseCaseProvider = Provider((ref) {
  return TranslateAudioUseCase(ref.read(audioTranslationRepositoryProvider));
});

final translateTextUseCaseProvider = Provider((ref) {
  return TranslateTextUseCase(ref.read(audioTranslationRepositoryProvider));
});

// State definitions
enum AudioTranslationStatus { idle, recording, processing, success, error }

class AudioTranslationState {
  final AudioTranslationStatus status;
  final LsbTranslation? translationResult;
  final String? errorMessage;
  final String? recordedAudioPath;

  AudioTranslationState({
    this.status = AudioTranslationStatus.idle,
    this.translationResult,
    this.errorMessage,
    this.recordedAudioPath,
  });

  AudioTranslationState copyWith({
    AudioTranslationStatus? status,
    LsbTranslation? translationResult,
    String? errorMessage,
    String? recordedAudioPath,
  }) {
    return AudioTranslationState(
      status: status ?? this.status,
      translationResult: translationResult ?? this.translationResult,
      errorMessage: errorMessage ?? this.errorMessage,
      recordedAudioPath: recordedAudioPath ?? this.recordedAudioPath,
    );
  }
}

// Controller definition
final audioTranslationControllerProvider = NotifierProvider<AudioTranslationController, AudioTranslationState>(() {
  return AudioTranslationController();
});

class AudioTranslationController extends Notifier<AudioTranslationState> {

  @override
  AudioTranslationState build() {
    return AudioTranslationState();
  }

  void setRecordingState() {
    state = state.copyWith(status: AudioTranslationStatus.recording);
  }

  void processAudio(String audioPath) async {
    state = state.copyWith(
      status: AudioTranslationStatus.processing,
      recordedAudioPath: audioPath,
    );

    try {
      final useCase = ref.read(translateAudioUseCaseProvider);
      final result = await useCase.execute(audioPath);
      state = state.copyWith(
        status: AudioTranslationStatus.success,
        translationResult: result,
      );
    } catch (e) {
      state = state.copyWith(
        status: AudioTranslationStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void processText(String text) async {
    state = state.copyWith(
      status: AudioTranslationStatus.processing,
    );

    try {
      final useCase = ref.read(translateTextUseCaseProvider);
      final result = await useCase.execute(text);
      state = state.copyWith(
        status: AudioTranslationStatus.success,
        translationResult: result,
      );
    } catch (e) {
      state = state.copyWith(
        status: AudioTranslationStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = AudioTranslationState();
  }
}
