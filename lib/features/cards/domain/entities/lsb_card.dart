class LsbCard {
  final String id;
  final String gloss; 
  final String displayText; 
  final String iconUrl;
  final String videoUrl;
  final String categoryId;
  final String subcategoryId;
  final List<String> contexts;
  final int priority;
  final List<String> suggestedNextCardIds;
  final bool isFrequent;
  final bool isEmergency;

  LsbCard({
    required this.id,
    required this.gloss,
    required this.displayText,
    required this.iconUrl,
    required this.videoUrl,
    required this.categoryId,
    required this.subcategoryId,
    required this.contexts,
    required this.priority,
    required this.suggestedNextCardIds,
    required this.isFrequent,
    required this.isEmergency,
  });
}