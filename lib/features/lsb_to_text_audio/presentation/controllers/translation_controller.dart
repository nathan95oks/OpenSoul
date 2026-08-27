import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/services/audio_output.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

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

  Future<void> replayAudio() async {
    final current = state.value;
    if (current == null) return;
    if (current.audioUrl != null && current.audioUrl!.isNotEmpty) {
      try {
        await _audio.playUrl(current.audioUrl!);
        _setPlayback(AudioPlaybackState.playing);
        return;
      } catch (_) {
      }
    }
    await _speakLocally(current.generatedText);
  }

  Future<void> pauseAudio() async {
    await _audio.pause();
    _setPlayback(AudioPlaybackState.paused);
  }

  Future<void> resumeAudio() async {
    final current = state.value;
    if (current == null) return;
    if (current.audioUrl != null && current.audioUrl!.isNotEmpty) {
      try {
        await _audio.resume();
        _setPlayback(AudioPlaybackState.playing);
        return;
      } catch (_) {
      }
    }
    await replayAudio();
  }

  Future<void> translateCards({
    required String context,
    required List<String> cards,
    String? assemblerContext,
  }) async {
    state = const AsyncValue.loading();

    final engine = ref.read(conversationEngineProvider);
    final result = await engine.generateDeclaration(
      contextId: context,
      glosses: cards,
      assemblerContextId: assemblerContext,
    );

    state = AsyncValue.data(result);

    if (result.audioUrl != null && result.audioUrl!.isNotEmpty) {
      try {
        await _audio.playUrl(result.audioUrl!);
        _setPlayback(AudioPlaybackState.playing);
      } catch (_) {
        await _speakLocally(result.generatedText);
      }
    } else {
      await _speakLocally(result.generatedText);
    }
  }
}

final translationControllerProvider =
    AsyncNotifierProvider<TranslationController, TranslationResult?>(
  TranslationController.new,
);
