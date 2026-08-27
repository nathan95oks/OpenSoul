abstract class AudioOutput {
  Future<void> playUrl(String url);

  Future<void> speak(String text);

  Future<void> stop();

  Future<void> pause();

  Future<void> resume();

  void setOnComplete(void Function() onComplete);

  Future<void> dispose();
}
