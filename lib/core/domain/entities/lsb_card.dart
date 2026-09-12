/// Estado de revisión de una entrada del diccionario.
///
/// `unknown` no es un estado real del corpus: es lo que se asigna cuando el
/// JSON trae un valor de `status` que esta versión de la app no reconoce. No
/// debe tratarse como `official` — eso aprobaría automáticamente una entrada
/// que nadie confirmó.
enum DictionaryStatus { official, community, pending, unknown }

class LsbCard {
  final String id;
  final String gloss;

  /// Glosa canónica del corpus, cuando difiere de [gloss] (p. ej. cambios de
  /// guion a guion bajo). Conservarla por separado permite reconciliar
  /// variantes sin perder la forma con la que se indexó la tarjeta.
  final String canonicalGloss;
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

  /// Valor crudo de `status` tal como venía en el JSON, para no perder la
  /// trazabilidad cuando [status] cae en [DictionaryStatus.unknown].
  final String? rawStatus;

  /// Referencia a la fuente (módulo, página o entrada del corpus) que
  /// documenta esta seña.
  final String source;

  /// Nota de auditoría lingüística (p. ej. "A — M1–M4 trazado").
  final String audit;
  final String? animationFile;

  LsbCard({
    required this.id,
    required this.gloss,
    String? canonicalGloss,
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
    this.rawStatus,
    this.source = '',
    this.audit = '',
    this.animationFile,
  }) : canonicalGloss = canonicalGloss ?? gloss;

  factory LsbCard.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String?;
    return LsbCard(
      id: json['id'] as String,
      gloss: json['gloss'] as String,
      canonicalGloss: json['canonicalGloss'] as String?,
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
        (s) => s.name == rawStatus,
        orElse: () => DictionaryStatus.unknown,
      ),
      rawStatus: rawStatus,
      source: json['source'] as String? ?? '',
      audit: json['audit'] as String? ?? '',
      animationFile: json['animationFile'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'gloss': gloss,
        'canonicalGloss': canonicalGloss,
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
        // Se conserva el valor crudo cuando el estado no se reconoce, para no
        // fabricar un nombre de estado que el corpus nunca declaró.
        'status': status == DictionaryStatus.unknown
            ? (rawStatus ?? status.name)
            : status.name,
        'source': source,
        'audit': audit,
        if (animationFile != null) 'animationFile': animationFile,
      };
}
