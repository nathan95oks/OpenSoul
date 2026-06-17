import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Abstracción de la salida de audio del módulo.
///
/// Aísla la reproducción remota (Amazon Polly vía URL) y la síntesis local
/// (TTS del dispositivo) detrás de un contrato, de modo que el
/// `TranslationController` orqueste la estrategia híbrida sin acoplarse a los
/// plugins nativos. Esto permite probar el controlador con un doble de prueba
/// (TST-01) y respeta la separación de capas de Clean Architecture.
abstract class AudioOutput {
  /// Reproduce un audio remoto por URL. Lanza si la reproducción falla, para
  /// que el llamador pueda caer a la síntesis local.
  Future<void> playUrl(String url);

  /// Sintetiza [text] con el TTS local. Best-effort: no lanza.
  Future<void> speak(String text);

  /// Detiene toda reproducción (remota y TTS).
  Future<void> stop();

  /// Pausa la reproducción remota y detiene el TTS local.
  Future<void> pause();

  /// Reanuda la reproducción remota pausada. Lanza si no es posible.
  Future<void> resume();

  /// Registra el callback que se invoca al terminar una reproducción
  /// (remota o TTS local).
  void setOnComplete(void Function() onComplete);

  /// Libera los recursos nativos.
  Future<void> dispose();
}

/// Implementación real sobre `audioplayers` (remoto) y `flutter_tts` (local).
class RealAudioOutput implements AudioOutput {
  RealAudioOutput() {
    _audioPlayer.onPlayerComplete.listen((_) => _onComplete?.call());
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsConfigured = false;
  void Function()? _onComplete;

  /// Locales de español preferidos para el TTS local, en orden (TD-03).
  /// Encabeza `es-US` para sonar coherente con la voz remota de Polly
  /// (Lupe, es-US neural); degrada a otras variantes latinoamericanas y, por
  /// último, al español genérico. Antes estaba fijo en `es-MX`, lo que
  /// desalineaba la voz offline respecto de la online.
  static const List<String> _preferredSpanishLocales = [
    'es-US',
    'es-MX',
    'es-419',
    'es-ES',
    'es',
  ];

  @override
  void setOnComplete(void Function() onComplete) {
    _onComplete = onComplete;
    _tts.setCompletionHandler(() => _onComplete?.call());
  }

  Future<void> _configureTtsOnce() async {
    if (_ttsConfigured) return;
    try {
      await _tts.setLanguage(await _bestSpanishLocale());
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _ttsConfigured = true;
    } catch (_) {
      // Algunas plataformas no soportan ciertas configuraciones.
      _ttsConfigured = true;
    }
  }

  /// Devuelve el primer locale de español que el dispositivo tiene instalado,
  /// según la preferencia de [_preferredSpanishLocales]. Si no puede
  /// consultarse la disponibilidad, cae a `es-US`.
  Future<String> _bestSpanishLocale() async {
    for (final locale in _preferredSpanishLocales) {
      try {
        final available = await _tts.isLanguageAvailable(locale);
        if (available == true) return locale;
      } catch (_) {
        // Plataforma sin soporte para consultar disponibilidad — seguimos.
      }
    }
    return 'es-US';
  }

  @override
  Future<void> playUrl(String url) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(url));
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _configureTtsOnce();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Si TTS falla, no rompemos el flujo — el texto sigue visible.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  @override
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
