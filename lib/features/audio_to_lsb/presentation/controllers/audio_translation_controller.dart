import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/di/core_providers.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import '../../domain/usecases/translate_audio_usecase.dart';
import '../../domain/usecases/translate_text_usecase.dart';

/// La cadena http → datasource → repositorio vive en el núcleo compartido
/// (`core/di`), común a ambas direcciones de la conversación.
export 'package:lsb_legal_app/core/di/core_providers.dart'
    show remoteAudioDataSourceProvider, audioTranslationRepositoryProvider;

final translateAudioUseCaseProvider = Provider((ref) {
  return TranslateAudioUseCase(ref.watch(audioTranslationRepositoryProvider));
});

final translateTextUseCaseProvider = Provider((ref) {
  return TranslateTextUseCase(ref.watch(audioTranslationRepositoryProvider));
});

// State definitions
enum AudioTranslationStatus { idle, recording, processing, success, error }

class AudioTranslationState {
  final AudioTranslationStatus status;
  final LsbTranslation? translationResult;
  final String? errorMessage;
  final String? recognizedText;

  AudioTranslationState({
    this.status = AudioTranslationStatus.idle,
    this.translationResult,
    this.errorMessage,
    this.recognizedText,
  });

  AudioTranslationState copyWith({
    AudioTranslationStatus? status,
    LsbTranslation? translationResult,
    String? errorMessage,
    String? recognizedText,
  }) {
    return AudioTranslationState(
      status: status ?? this.status,
      translationResult: translationResult ?? this.translationResult,
      errorMessage: errorMessage ?? this.errorMessage,
      recognizedText: recognizedText ?? this.recognizedText,
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
    state = state.copyWith(status: AudioTranslationStatus.recording, recognizedText: "");
  }

  void updateRecognizedText(String text) {
    state = state.copyWith(recognizedText: text);
  }

  void processAudioAsText(String transcribedText) {
    if (transcribedText.isEmpty) {
      state = state.copyWith(status: AudioTranslationStatus.idle);
      return;
    }
    processText(transcribedText);
  }

  void processText(String text) async {
    state = state.copyWith(
      status: AudioTranslationStatus.processing,
      recognizedText: text,
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
