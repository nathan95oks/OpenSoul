import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/di/injection.dart';

enum AudioTranslationStatus {
  idle,
  recording,
  processing,
  // Hay un significado con más de una lectura plausible: la reproducción no
  // debe empezar hasta que la persona elija (sección 4 del encargo "Audio/
  // Texto -> LSB": "significado pendiente de aclaración" y "significado
  // comprendido con representación incompleta" son dos problemas distintos).
  needsClarification,
  success,
  error,
}

/// Sentinela para distinguir "no tocar este campo" de "poner este campo en
/// null" dentro de `copyWith`. Sin esto, `errorMessage ?? this.errorMessage`
/// nunca puede limpiar un error una vez puesto — quedaba pegado en el estado
/// aunque la persona ya hubiera corregido o reiniciado (sección 10 del
/// encargo).
const _unset = Object();

class AudioTranslationState {
  final AudioTranslationStatus status;
  final LsbTranslation? translationResult;
  final String? errorMessage;
  final String? recognizedText;

  /// El texto que generó una aclaración pendiente (`needsClarification`), o
  /// que está en revisión de audio: se conserva aparte de `recognizedText`
  /// porque `recognizedText` puede seguir cambiando mientras la persona edita
  /// el borrador, y aquí se necesita el texto exacto que se envió a traducir.
  final String? pendingSourceText;
  final List<PendingClarification> pendingClarifications;

  /// Sentidos ya elegidos por la persona para términos ambiguos de esta
  /// conversación (p. ej. {"AUTO": "vehiculo"}). Se conservan mientras la
  /// pantalla siga abierta; `reset()` los descarta.
  final Map<String, String> resolvedSenses;

  AudioTranslationState({
    this.status = AudioTranslationStatus.idle,
    this.translationResult,
    this.errorMessage,
    this.recognizedText,
    this.pendingSourceText,
    this.pendingClarifications = const [],
    this.resolvedSenses = const {},
  });

  bool get isBlockedOnClarification =>
      status == AudioTranslationStatus.needsClarification;

  AudioTranslationState copyWith({
    AudioTranslationStatus? status,
    Object? translationResult = _unset,
    Object? errorMessage = _unset,
    Object? recognizedText = _unset,
    Object? pendingSourceText = _unset,
    List<PendingClarification>? pendingClarifications,
    Map<String, String>? resolvedSenses,
  }) {
    return AudioTranslationState(
      status: status ?? this.status,
      translationResult: identical(translationResult, _unset)
          ? this.translationResult
          : translationResult as LsbTranslation?,
      errorMessage:
          identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
      recognizedText: identical(recognizedText, _unset)
          ? this.recognizedText
          : recognizedText as String?,
      pendingSourceText: identical(pendingSourceText, _unset)
          ? this.pendingSourceText
          : pendingSourceText as String?,
      pendingClarifications: pendingClarifications ?? this.pendingClarifications,
      resolvedSenses: resolvedSenses ?? this.resolvedSenses,
    );
  }
}

final audioTranslationControllerProvider =
    NotifierProvider<AudioTranslationController, AudioTranslationState>(() {
  return AudioTranslationController();
});

class AudioTranslationController extends Notifier<AudioTranslationState> {
  // Un identificador de solicitud simple: si llega una respuesta de una
  // petición que ya no es la más reciente (la persona editó el texto, canceló
  // o reinició mientras se esperaba), se descarta en vez de sobrescribir un
  // estado más nuevo (sección 10 del encargo).
  int _requestToken = 0;

  @override
  AudioTranslationState build() {
    return AudioTranslationState();
  }

  void setRecordingState() {
    _requestToken++; // cualquier traducción en curso deja de ser vigente.
    state = AudioTranslationState(
      status: AudioTranslationStatus.recording,
      recognizedText: "",
      resolvedSenses: state.resolvedSenses,
    );
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

  void processText(String text, {String? situation}) async {
    final myToken = ++_requestToken;
    state = state.copyWith(
      status: AudioTranslationStatus.processing,
      recognizedText: text,
      pendingSourceText: text,
      pendingClarifications: const [],
      errorMessage: null,
    );

    try {
      final useCase = ref.read(translateTextUseCaseProvider);
      final result = await useCase.execute(
        text,
        situation: situation,
        resolvedSenses:
            state.resolvedSenses.isEmpty ? null : state.resolvedSenses,
      );
      if (myToken != _requestToken) return; // ya no es la solicitud vigente.

      if (result.needsClarification) {
        state = state.copyWith(
          status: AudioTranslationStatus.needsClarification,
          pendingClarifications: result.pendingClarifications,
          pendingSourceText: text,
        );
        return;
      }

      state = state.copyWith(
        status: AudioTranslationStatus.success,
        translationResult: result,
        pendingClarifications: const [],
      );
    } catch (e) {
      if (myToken != _requestToken) return;
      state = state.copyWith(
        status: AudioTranslationStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// La persona responde la aclaración pendiente para [term] con la opción
  /// [optionId] ("vehiculo", "resolucion", ...): se guarda la elección y se
  /// vuelve a traducir la MISMA frase completa (no solo el término), porque
  /// resolver un sentido puede cambiar el análisis del resto de la frase.
  void resolveClarification(String term, String optionId) {
    final text = state.pendingSourceText;
    if (text == null || text.isEmpty) return;
    final senses = {...state.resolvedSenses, term: optionId};
    state = state.copyWith(resolvedSenses: senses);
    processText(text);
  }

  /// La persona cancela la aclaración: se conserva el borrador de texto para
  /// que pueda reformular en vez de reproducirse una interpretación por
  /// defecto (sección 5.3 del encargo).
  void cancelClarification() {
    _requestToken++;
    state = state.copyWith(
      status: AudioTranslationStatus.idle,
      pendingClarifications: const [],
    );
  }

  void reset() {
    _requestToken++;
    state = AudioTranslationState();
  }
}
