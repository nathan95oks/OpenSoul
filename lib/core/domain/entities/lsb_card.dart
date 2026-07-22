/// Estado de una entrada dentro del diccionario evolutivo.
///
/// - [official]: validada por la comunidad de validadores (portal web).
/// - [community]: aportada por la comunidad, visible pero no oficial.
/// - [pending]: propuesta en revisión; nunca se muestra en la app.
enum DictionaryStatus { official, community, pending }

/// Entrada del lexicón LSB (Lengua de Señas Boliviana).
///
/// Es la unidad del diccionario evolutivo: describe la glosa, su
/// representación visual (ícono semántico y animación 3D del avatar),
/// categoría y metadatos de navegación semántica. La fuente canónica es
/// `assets/dictionary/official_dictionary.json` (misma estructura que la
/// tabla DynamoDB del backend); esta clase es su forma tipada en la app.
class LsbCard {
  final String id;
  final String gloss;
  final String displayText;
  final String iconUrl;
  final String categoryId;
  final String subcategoryId;
  final List<String> contexts;
  final int priority;
  final List<String> suggestedNextCardIds;
  final bool isFrequent;
  final bool isEmergency;

  /// Nombre del ícono semántico de Material Icons (ej: 'person', 'gavel').
  final String semanticIcon;

  /// Dialecto LSB al que pertenece la glosa.
  /// Por defecto 'cochabamba' (alcance del proyecto).
  final String dialect;

  /// Procedencia de la entrada en el diccionario evolutivo.
  final DictionaryStatus status;

  /// Archivo de animación 3D (.glb) del avatar para esta glosa, si existe.
  /// Nulo cuando la seña aún no tiene animación (el avatar usa dactilología).
  final String? animationFile;

  LsbCard({
    required this.id,
    required this.gloss,
    required this.displayText,
    required this.iconUrl,
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
