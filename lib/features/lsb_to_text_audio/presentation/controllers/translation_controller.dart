import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/audio_output.dart';
import '../../domain/repositories/translation_repository.dart';
import '../../domain/services/local_sentence_assembler.dart';
import '../providers/translation_provider.dart';

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

/// Provee la salida de audio. La implementación real usa los plugins nativos;
/// los tests la sobrescriben con un doble (TST-01). El provider posee el ciclo
/// de vida: libera los recursos al destruirse (RVP-02).
final audioOutputProvider = Provider<AudioOutput>((ref) {
  final output = RealAudioOutput();
  ref.onDispose(output.dispose);
  return output;
});

/// Controlador de la traducción híbrida.
///
/// Arquitectura híbrida (declarada en el perfil):
///   1. **Motor semántico propio** ([LocalSentenceAssembler]) — siempre
///      construye una `baseSentence` fiel a las glosas seleccionadas.
///   2. **Modelo fundacional** (backend AWS Bedrock) — refina la oración
///      cuando responde correctamente.
///
/// Para la síntesis de voz seguimos la misma estrategia híbrida:
///   - Si el backend entrega un `audioUrl` válido (AWS Polly), se
///     reproduce ese audio neuronal remoto.
///   - Si no hay `audioUrl` (backend degenerado o caído), se sintetiza
///     localmente con `flutter_tts` usando el motor TTS nativo del
///     dispositivo en español latinoamericano.
///
/// Esto garantiza que el usuario sordo siempre obtenga salida multimodal
/// (texto + audio) — requisito del módulo de salida en el perfil.
class TranslationController extends AsyncNotifier<TranslationResult?> {
  final LocalSentenceAssembler _assembler = const LocalSentenceAssembler();
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

    final localSentence = _assembler.assemble(
      contextId: assemblerContext ?? context,
      glosses: cards,
    );

    // Garantía: si por alguna razón el motor local no produjo texto,
    // construimos un texto mínimo desde las glosas para que el panel
    // de resultado siempre tenga algo que mostrar.
    final safeLocal = localSentence.isNotEmpty
        ? localSentence
        : cards.join(' ');

    try {
      final translateUseCase = ref.read(translateCardsUseCaseProvider);
      final remote = await translateUseCase(context: context, cards: cards);

      final degenerate = _assembler.isBackendDegenerate(
        backendText: remote.generatedText,
        glosses: cards,
      );

      final merged = TranslationResult(
        baseSentence: safeLocal,
        generatedText: degenerate ? safeLocal : remote.generatedText,
        audioUrl: degenerate ? null : remote.audioUrl,
        cacheHit: remote.cacheHit,
        bedrockUsed: !degenerate && remote.bedrockUsed,
        intermediateRepresentation: remote.intermediateRepresentation,
        glossSequence: remote.glossSequence,
      );

      state = AsyncValue.data(merged);

      // Reproducción híbrida: URL remota si existe, TTS local si no.
      if (merged.audioUrl != null && merged.audioUrl!.isNotEmpty) {
        try {
          await _audio.playUrl(merged.audioUrl!);
          _setPlayback(AudioPlaybackState.playing);
        } catch (_) {
          // Si la reproducción remota falla, caemos a TTS local.
          await _speakLocally(merged.generatedText);
        }
      } else {
        await _speakLocally(merged.generatedText);
      }
    } catch (_) {
      // El backend falló — usar exclusivamente el motor propio + TTS local.
      final fallback = TranslationResult(
        baseSentence: safeLocal,
        generatedText: safeLocal,
        audioUrl: null,
        cacheHit: false,
        bedrockUsed: false,
      );
      state = AsyncValue.data(fallback);
      await _speakLocally(safeLocal);
    }
  }
}

final translationControllerProvider =
    AsyncNotifierProvider<TranslationController, TranslationResult?>(
  TranslationController.new,
);
