class TranslationResult {
  final String generatedText;
  final String? audioUrl;

  TranslationResult({
    required this.generatedText,
    this.audioUrl,
  });
}

abstract class TranslationRepository {
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  });
}