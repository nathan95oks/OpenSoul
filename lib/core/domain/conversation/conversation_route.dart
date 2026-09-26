/// Qué parte del grafo LSB→Texto/Audio se abre para que la persona sorda
/// responda a un turno del oyente.
enum ConversationRouteType {
  /// Elegir contexto: el oyente preguntó a qué viene.
  contextSelector('CONTEXT_SELECTOR'),

  /// Un contexto concreto, o una familia de contextos, desde el principio.
  directContext('DIRECT_CONTEXT'),

  /// Una pregunta del banco (más sus dependencias obligatorias).
  directQuestion('DIRECT_QUESTION'),

  /// Varias preguntas del banco: solo esas y lo que exigen.
  minimalGraphPath('MINIMAL_GRAPH_PATH'),

  /// Nada del grafo responde con seguridad. No se inventa ruta: se abre el
  /// selector como cualquier respuesta sin guía.
  noSafeRoute('NO_SAFE_ROUTE');

  final String wireName;

  const ConversationRouteType(this.wireName);

  static ConversationRouteType? parse(String? raw) {
    for (final t in values) {
      if (t.wireName == raw || t.name == raw) return t;
    }
    return null;
  }
}

/// De dónde salió la ruta. `noSafeRoute` no es una fuente: es el tipo de
/// ruta (ver [ConversationRoute.sourceLabel]).
enum RouteSource {
  /// Reglas deterministas sobre la lectura del turno y el grafo.
  deterministic,

  /// Elegida por el Bedrock de LSB→Texto/Audio entre candidatas reales.
  bedrock,

  /// Una elección anterior del modelo, servida desde la caché S3 y
  /// revalidada.
  cache,
}

/// La ruta con la que se abre LSB→Texto/Audio para responder.
///
/// Solo contiene identificadores reales del catálogo (familias, contextos,
/// preguntas del banco y ranuras del grafo). Nunca opciones ni respuestas:
/// eso lo elige la persona sorda con las tarjetas.
///
/// [reason] y [confidence] son internos; la interfaz no los muestra.
class ConversationRoute {
  final ConversationRouteType type;
  final String? targetFamilyId;
  final String? targetContextId;

  /// Preguntas cuyas respuestas pidió el oyente.
  final List<String> targetQuestionIds;

  /// Objetivos que el oyente formuló tal cual: se muestran aunque su
  /// condición en el recorrido no se cumpla, porque la pregunta ya está hecha.
  final List<String> presupposedQuestionIds;

  /// El recorrido mínimo validado (dependencias incluidas), en orden. Vacío
  /// mientras la ruta no pase por el validador.
  final List<String> pathQuestionIds;
  final List<String> requestedSlots;
  final double confidence;
  final String reason;
  final RouteSource source;

  /// El determinista no pudo decidir entre varias rutas reales: si hay un
  /// modelo disponible, puede rankearlas.
  final bool needsModel;

  /// Rutas reales entre las que el modelo puede elegir.
  final List<ConversationRoute> candidates;

  const ConversationRoute({
    required this.type,
    this.targetFamilyId,
    this.targetContextId,
    this.targetQuestionIds = const [],
    this.presupposedQuestionIds = const [],
    this.pathQuestionIds = const [],
    this.requestedSlots = const [],
    this.confidence = 0,
    this.reason = '',
    this.source = RouteSource.deterministic,
    this.needsModel = false,
    this.candidates = const [],
  });

  const ConversationRoute.noSafeRoute({
    this.reason = '',
    this.needsModel = false,
    this.candidates = const [],
    this.source = RouteSource.deterministic,
  }) : type = ConversationRouteType.noSafeRoute,
       targetFamilyId = null,
       targetContextId = null,
       targetQuestionIds = const [],
       presupposedQuestionIds = const [],
       pathQuestionIds = const [],
       requestedSlots = const [],
       confidence = 0;

  /// Abre preguntas concretas en vez de un contexto desde el principio.
  bool get opensQuestions =>
      type == ConversationRouteType.directQuestion ||
      type == ConversationRouteType.minimalGraphPath;

  /// La persona sorda elige contexto (o subcontexto de una familia).
  bool get opensSelector => targetContextId == null;

  /// Etiqueta técnica para trazas: `deterministic|bedrock|cache|noSafeRoute`.
  String get sourceLabel =>
      type == ConversationRouteType.noSafeRoute ? 'noSafeRoute' : source.name;

  /// Id estable de una ruta candidata, para que el modelo la elija por
  /// referencia y no copiando identificadores.
  String get candidateKey => [
    type.wireName,
    targetFamilyId ?? '',
    targetContextId ?? '',
    targetQuestionIds.join('+'),
  ].join('|');

  ConversationRoute copyWith({
    ConversationRouteType? type,
    String? targetFamilyId,
    String? targetContextId,
    List<String>? targetQuestionIds,
    List<String>? presupposedQuestionIds,
    List<String>? pathQuestionIds,
    List<String>? requestedSlots,
    double? confidence,
    String? reason,
    RouteSource? source,
    bool? needsModel,
    List<ConversationRoute>? candidates,
  }) => ConversationRoute(
    type: type ?? this.type,
    targetFamilyId: targetFamilyId ?? this.targetFamilyId,
    targetContextId: targetContextId ?? this.targetContextId,
    targetQuestionIds: targetQuestionIds ?? this.targetQuestionIds,
    presupposedQuestionIds:
        presupposedQuestionIds ?? this.presupposedQuestionIds,
    pathQuestionIds: pathQuestionIds ?? this.pathQuestionIds,
    requestedSlots: requestedSlots ?? this.requestedSlots,
    confidence: confidence ?? this.confidence,
    reason: reason ?? this.reason,
    source: source ?? this.source,
    needsModel: needsModel ?? this.needsModel,
    candidates: candidates ?? this.candidates,
  );

  Map<String, dynamic> toJson() => {
    'id': candidateKey,
    'routeType': type.wireName,
    if (targetFamilyId != null) 'targetFamilyId': targetFamilyId,
    if (targetContextId != null) 'targetContextId': targetContextId,
    'targetQuestionIds': targetQuestionIds,
    'requestedSlots': requestedSlots,
  };

  /// Claves con las que una ruta intentaría fijar respuestas. Una ruta solo
  /// dice **dónde** responder; si trae alguna de estas, no es una ruta.
  static const answerKeys = {
    'optionIds',
    'opciones',
    'answers',
    'respuestas',
    'facts',
    'glosses',
  };

  /// Lee la propuesta de un modelo. Devuelve `null` si no tiene forma de
  /// ruta o si intenta proponer respuestas. No valida contra el catálogo:
  /// eso lo hace el validador.
  static ConversationRoute? fromModelJson(Map<String, dynamic> json) {
    if (json.keys.any(answerKeys.contains)) return null;
    final type = ConversationRouteType.parse(json['routeType']?.toString());
    if (type == null) return null;
    List<String> ids(dynamic raw) => [
      for (final v in (raw as List? ?? const []))
        if (v is String && v.trim().isNotEmpty) v.trim(),
    ];
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0;
    return ConversationRoute(
      type: type,
      targetFamilyId: json['targetFamilyId'] as String?,
      targetContextId: json['targetContextId'] as String?,
      targetQuestionIds: ids(json['targetQuestionIds']),
      requestedSlots: ids(json['requestedSlots']),
      confidence: confidence.clamp(0, 1).toDouble(),
      reason: (json['reason'] ?? '').toString(),
      source: json['routeSource'] == 'cache'
          ? RouteSource.cache
          : RouteSource.bedrock,
    );
  }

  @override
  String toString() =>
      'ConversationRoute(${type.wireName}, family: $targetFamilyId, '
      'context: $targetContextId, questions: $targetQuestionIds, '
      'path: $pathQuestionIds, source: ${source.name})';
}
