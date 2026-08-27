enum DictionaryStatus { official, community, pending }

class LsbCard {
  final String id;
  final String gloss;
  final String displayText;
  final String iconUrl;
  final int imageFrames;
  final String categoryId;
  final String subcategoryId;
  final List<String> contexts;
  final int priority;
  final List<String> suggestedNextCardIds;
  final bool isFrequent;
  final bool isEmergency;
  final String semanticIcon;
  final String dialect;
  final DictionaryStatus status;
  final String? animationFile;

  LsbCard({
    required this.id,
    required this.gloss,
    required this.displayText,
    required this.iconUrl,
    this.imageFrames = 1,
    required this.categoryId,
    required this.subcategoryId,
    required this.contexts,
    required this.priority,
    required this.suggestedNextCardIds,
    required this.isFrequent,
    required this.isEmergency,
    this.semanticIcon = 'credit_card',
    this.dialect = 'cochabamba',
    this.status = DictionaryStatus.official,
    this.animationFile,
  });

  factory LsbCard.fromJson(Map<String, dynamic> json) {
    return LsbCard(
      id: json['id'] as String,
      gloss: json['gloss'] as String,
      displayText: json['displayText'] as String,
      iconUrl: json['iconUrl'] as String? ?? '',
      imageFrames: (json['imageFrames'] as num?)?.toInt() ?? 1,
      categoryId: json['categoryId'] as String,
      subcategoryId: json['subcategoryId'] as String? ?? '',
      contexts: List<String>.from(json['contexts'] as List? ?? const []),
      priority: json['priority'] as int? ?? 999,
      suggestedNextCardIds:
          List<String>.from(json['suggestedNextCardIds'] as List? ?? const []),
      isFrequent: json['isFrequent'] as bool? ?? false,
      isEmergency: json['isEmergency'] as bool? ?? false,
      semanticIcon: json['semanticIcon'] as String? ?? 'credit_card',
      dialect: json['dialect'] as String? ?? 'cochabamba',
      status: DictionaryStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'official'),
        orElse: () => DictionaryStatus.official,
      ),
      animationFile: json['animationFile'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'gloss': gloss,
        'displayText': displayText,
        'iconUrl': iconUrl,
        'imageFrames': imageFrames,
        'categoryId': categoryId,
        'subcategoryId': subcategoryId,
        'contexts': contexts,
        'priority': priority,
        'suggestedNextCardIds': suggestedNextCardIds,
        'isFrequent': isFrequent,
        'isEmergency': isEmergency,
        'semanticIcon': semanticIcon,
        'dialect': dialect,
        'status': status.name,
        if (animationFile != null) 'animationFile': animationFile,
      };
}
