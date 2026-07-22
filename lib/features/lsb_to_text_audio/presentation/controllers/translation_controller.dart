import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/core_providers.dart';
import 'package:lsb_legal_app/core/generators/audio_generator/audio_output.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';

/// El provider de la salida de audio vive en el núcleo compartido
/// (`core/di`); se re-exporta para mantener estables a los consumidores
/// y tests que lo sobrescriben desde aquí.
export 'package:lsb_legal_app/core/di/core_providers.dart'
    show audioOutputProvider;

/// Estado de reproducción del audio de la declaración. Alimenta únicamente
/// el indicador visual de la pantalla de resultado; no altera la lógica de
/// generación de audio.
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

/// Controlador de presentación de la declaración (flujo de tarjetas).
///
/// La estrategia híbrida (motor semántico local + Bedrock/Polly con
/// degradación elegante) vive en el [ConversationEngine] del núcleo; este
/// controlador solo orquesta el estado de la pantalla y la reproducción:
///   - Si la declaración trae `audioUrl` (AWS Polly), reproduce ese audio
///     neuronal remoto.
///   - Si no, sintetiza localmente con `flutter_tts` en español.
///
/// Esto garantiza que el usuario sordo siempre obtenga salida multimodal
/// (texto + audio) — requisito del módulo de salida en el perfil.
class TranslationController extends AsyncNotifier<TranslationResult?> {
  late final AudioOutput _audio;

  @override
  Future<TranslationResult?> build() async {
    // La salida de audio es inyectable (RVP-02/TST-01): el provider posee su
    // ciclo de vida y la libera al destruirse.
    _audio = ref.read(audioOutputProvider);
    // Al terminar una reproducción (remota o TTS), el indicador vuelve a idle.
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

  /// Limpia el resultado actual y detiene cualquier reproducción de audio
  /// (remota o TTS local). El siguiente `translateCards` empieza de cero.
  Future<void> reset() async {
    await _audio.stop();
    _setPlayback(AudioPlaybackState.idle);
    state = const AsyncValue.data(null);
  }

  /// Reproduce nuevamente el último resultado.
  ///
  /// Si el resultado actual tiene `audioUrl`, se reproduce remoto; si no,
  /// se sintetiza localmente con TTS. Permite que el botón "Audio" del
  /// panel de resultado siempre haga algo, independientemente del origen
  /// del texto (Bedrock o motor propio).
  Future<void> replayAudio() async {
    final current = state.value;
    if (current == null) return;
    if (current.audioUrl != null && current.audioUrl!.isNotEmpty) {
      try {
        await _audio.playUrl(current.audioUrl!);
        _setPlayback(AudioPlaybackState.playing);
        return;
      } catch (_) {
        // cae a TTS local
      }
    }
    await _speakLocally(current.generatedText);
  }

  /// Pausa la reproducción en curso (audio remoto) o la detiene (TTS local,
  /// que no admite pausa real en todas las plataformas). Solo control de
  /// reproducción — no toca la generación de audio.
  Future<void> pauseAudio() async {
    await _audio.pause();
    _setPlayback(AudioPlaybackState.paused);
  }

  /// Reanuda el audio remoto pausado; para TTS local reinicia la locución.
  Future<void> resumeAudio() async {
    final current = state.value;
    if (current == null) return;
    if (current.audioUrl != null && current.audioUrl!.isNotEmpty) {
      try {
        await _audio.resume();
        _setPlayback(AudioPlaybackState.playing);
        return;
      } catch (_) {
        // cae a reproducción desde cero
      }
    }
    await replayAudio();
  }

  /// Genera la declaración híbrida.
  ///
  /// [context] es el contexto de UI (lo que se envía al backend AWS).
  /// [assemblerContext] es el sub-contexto resuelto que usa el motor local
  /// (RVP-03): para el contexto fusionado 'orientacion' la UI lo enruta a
  /// 'perdida'/'tramite_id' solo para el compositor local, sin contaminar la
  /// llamada remota con ids internos no contractuales. Si se omite, se usa
  /// [context] para ambos.
  Future<void> translateCards({
    required String context,
    required List<String> cards,
    String? assemblerContext,
  }) async {
    state = const AsyncValue.loading();

    // La fusión híbrida (motor local + backend, detección de degeneración,
    // fallback sin red) es responsabilidad del motor de conversación.
    final engine = ref.read(conversationEngineProvider);
    final result = await engine.generateDeclaration(
      contextId: context,
      glosses: cards,
      assemblerContextId: assemblerContext,
    );

    state = AsyncValue.data(result);

    // Reproducción híbrida: URL remota si existe, TTS local si no.
    if (result.audioUrl != null && result.audioUrl!.isNotEmpty) {
      try {
        await _audio.playUrl(result.audioUrl!);
        _setPlayback(AudioPlaybackState.playing);
      } catch (_) {
        // Si la reproducción remota falla, caemos a TTS local.
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
