class TranslationResult {
  final String generatedText;
  final String? audioUrl;
  final bool cacheHit;

  TranslationResult({
    required this.generatedText,
    this.audioUrl,
    this.cacheHit = false,
  });
}

abstract class TranslationRepository {
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  });
}
