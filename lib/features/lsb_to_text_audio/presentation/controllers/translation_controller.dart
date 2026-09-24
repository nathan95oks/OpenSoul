import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/services/audio_output.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';

export 'package:lsb_legal_app/core/di/injection.dart'
    show audioOutputProvider;

enum AudioPlaybackState { idle, playing, paused }

class AudioPlaybackNotifier extends Notifier<AudioPlaybackState> {
  @override
  AudioPlaybackState build() => AudioPlaybackState.idle;

  void set(AudioPlaybackState s) => state = s;
}

final audioPlaybackProvider =
    NotifierProvider<AudioPlaybackNotifier, AudioPlaybackState>(
  AudioPlaybackNotifier.new,
);

class TranslationController extends AsyncNotifier<TranslationResult?> {
  late final AudioOutput _audio;

  @override
  Future<TranslationResult?> build() async {
    _audio = ref.read(audioOutputProvider);
    _audio.setOnComplete(() => _setPlayback(AudioPlaybackState.idle));
    return null;
  }

  void _setPlayback(AudioPlaybackState s) {
    ref.read(audioPlaybackProvider.notifier).set(s);
  }

  Future<void> _speakLocally(String text) async {
    if (text.trim().isEmpty) return;
    await _audio.speak(text);
    _setPlayback(AudioPlaybackState.playing);
  }

  Future<void> reset() async {
    await _audio.stop();
    _setPlayback(AudioPlaybackState.idle);
    state = const AsyncValue.data(null);
  }

  Future<void> replayAudio({String? fallbackText}) async {
    final current = state.value;
    if (current != null) {
      if (current.audioUrl != null && current.audioUrl!.isNotEmpty) {
        try {
          await _audio.playUrl(current.audioUrl!);
          _setPlayback(AudioPlaybackState.playing);
          return;
        } catch (_) {}
      }
      if (current.generatedText.isNotEmpty) {
        await _speakLocally(current.generatedText);
        return;
      }
    }
    if (fallbackText != null && fallbackText.trim().isNotEmpty) {
      await _speakLocally(fallbackText);
    }
  }

  Future<void> pauseAudio() async {
    await _audio.pause();
    _setPlayback(AudioPlaybackState.paused);
  }

  Future<void> resumeAudio({String? fallbackText}) async {
    final current = state.value;
    if (current != null) {
      if (current.audioUrl != null && current.audioUrl!.isNotEmpty) {
        try {
          await _audio.resume();
          _setPlayback(AudioPlaybackState.playing);
          return;
        } catch (_) {}
      }
    }
    await replayAudio(fallbackText: fallbackText);
  }

  /// Genera la declaración a partir de las glosas elegidas.
  ///
  /// No reproduce el audio automáticamente: la persona debe poder leer o
  /// revisar el resultado antes de que algo se diga en su nombre ante la
  /// institución. La reproducción queda a un toque explícito en
  /// "Reproducir" (ver [replayAudio]).
  /// Las señales de negocio del momento.
  ///
  /// Van al backend para desambiguar y ordenar. **No son contenido**: el
  /// generador no puede escribir el nombre de la institución dentro de la
  /// declaración de nadie porque venga aquí.
  BusinessSignals _businessSignals() {
    final sesion = ref.read(usageSessionProvider);
    final launch = ref.read(cardsFlowLaunchProvider);
    return BusinessSignals(
      usageMode: sesion.mode?.name,
      institutionProfileId: sesion.institutionProfileId,
      need: ref.read(activeNeedProvider)?.id,
      intentId: launch.intentId,
      conversationId: launch.conversationId,
    );
  }

  Future<void> translateCards({
    required String context,
    required List<String> cards,
    String? assemblerContext,
    DeclarationDraft? declaration,
  }) async {
    state = const AsyncValue.loading();

    final engine = ref.read(conversationEngineProvider);
    final result = await engine.generateDeclaration(
      contextId: context,
      glosses: cards,
      assemblerContextId: assemblerContext,
      declaration: declaration,
      business: _businessSignals(),
    );

    _setPlayback(AudioPlaybackState.idle);
    state = AsyncValue.data(result);
  }
}

final translationControllerProvider =
    AsyncNotifierProvider<TranslationController, TranslationResult?>(
  TranslationController.new,
);
