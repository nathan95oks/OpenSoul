import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lsb_legal_app/core/domain/services/audio_output.dart';

class RealAudioOutput implements AudioOutput {
  RealAudioOutput() {
    _audioPlayer.onPlayerComplete.listen((_) => _onComplete?.call());
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsConfigured = false;
  void Function()? _onComplete;

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
      _ttsConfigured = true;
    }
  }

  Future<String> _bestSpanishLocale() async {
    for (final locale in _preferredSpanishLocales) {
      try {
        final available = await _tts.isLanguageAvailable(locale);
        if (available == true) return locale;
      } catch (_) {
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
