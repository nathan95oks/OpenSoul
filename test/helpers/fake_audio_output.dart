import 'package:lsb_legal_app/core/domain/services/audio_output.dart';

/// Doble de prueba de la salida de audio: registra lo invocado, no reproduce.
///
/// Los plugins nativos (Polly vía url_launcher/audioplayers, flutter_tts) no
/// existen bajo el runner de pruebas; inyectar este doble en
/// `audioOutputProvider` permite auditar el estado sin tocarlos.
class FakeAudioOutput implements AudioOutput {
  final List<String> played = [];
  final List<String> spoken = [];
  void Function()? _onComplete;

  @override
  Future<void> playUrl(String url) async => played.add(url);

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  void setOnComplete(void Function() onComplete) => _onComplete = onComplete;

  @override
  Future<void> dispose() async {}

  /// Simula el final de la reproducción, para auditar el indicador visual.
  void complete() => _onComplete?.call();
}
