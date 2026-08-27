class TranslationResult {
  final String baseSentence;
  final String generatedText;
  final String? audioUrl;
  final bool cacheHit;
  final bool bedrockUsed;
  final bool coverageValidated;
  final Map<String, dynamic>? intermediateRepresentation;
  final List<Map<String, dynamic>>? glossSequence;

  TranslationResult({
    required this.baseSentence,
    required this.generatedText,
    this.audioUrl,
    this.cacheHit = false,
    this.bedrockUsed = false,
    this.coverageValidated = false,
    this.intermediateRepresentation,
    this.glossSequence,
  });
}
