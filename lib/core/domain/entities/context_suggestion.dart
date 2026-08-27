class ContextSuggestion {
  final String contextId;
  final double confidence;
  final List<String> evidence;

  const ContextSuggestion({
    required this.contextId,
    required this.confidence,
    this.evidence = const [],
  });

  @override
  String toString() =>
      'ContextSuggestion($contextId, ${(confidence * 100).round()}%, $evidence)';
}
