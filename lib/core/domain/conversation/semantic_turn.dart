import 'package:lsb_legal_app/core/domain/conversation/lsb_gloss_semantics.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';

/// Qué pide el turno del oyente.
enum SemanticIntent {
  /// Pregunta abierta por el motivo de la atención («¿Qué viene a
  /// realizar?»): la respuesta es elegir un contexto.
  askPurpose,

  /// Pide datos concretos (lugar, hora…) o una confirmación.
  askInformation,

  /// Nombra un contexto o una familia de contextos («¿Quiere denunciar
  /// algo?»).
  mentionContext,

  statement,
  instruction,
  unknown;

  static SemanticIntent parse(String? raw) => SemanticIntent.values.firstWhere(
    (v) => v.name == raw,
    orElse: () => SemanticIntent.unknown,
  );
}

/// De dónde salió la lectura del turno.
enum SemanticTurnSource {
  /// Audio/Texto→LSB la entregó con la traducción (ruta preferida).
  backend,

  /// El backend no la trajo (versión anterior, sin red): la armó el cliente
  /// con lo que sí llegó. Compatibilidad temporal.
  clientFallback,
}

/// Un contexto (o una familia de contextos) que el oyente nombró.
///
/// [id] es un identificador real: el de una situación/contexto
/// («denuncia_robo») o, si [isFamily], el de una familia («denuncias»).
class ContextMention {
  final String id;
  final bool isFamily;
  final List<String> evidence;

  const ContextMention({
    required this.id,
    required this.isFamily,
    this.evidence = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    if (isFamily) 'isFamily': true,
    'evidence': evidence,
  };

  factory ContextMention.fromJson(Map<String, dynamic> json) => ContextMention(
    id: (json['id'] ?? '').toString(),
    isFamily: json['isFamily'] == true,
    evidence: [for (final e in (json['evidence'] as List? ?? const [])) '$e'],
  );
}

/// El bloque `semanticTurn` de la respuesta de Audio/Texto→LSB.
///
/// Solo trae lo que la respuesta no trae ya: las glosas y los sentidos
/// resueltos viajan en sus campos de siempre (`glosses`, `disambiguation`).
class BackendSemanticTurn {
  final int version;
  final SemanticIntent intent;
  final List<String> requestedSlots;
  final List<ContextMention> mentionedContexts;
  final List<String> negations;
  final double confidence;

  const BackendSemanticTurn({
    required this.version,
    required this.intent,
    this.requestedSlots = const [],
    this.mentionedContexts = const [],
    this.negations = const [],
    this.confidence = 0,
  });

  /// `null` si no hay bloque o no tiene forma: entonces se usa el respaldo
  /// del cliente.
  static BackendSemanticTurn? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final intent = json['intent'];
    if (intent is! String || intent.isEmpty) return null;
    List<String> texts(Object? v) => [
      for (final e in (v as List? ?? const []))
        if (e is String && e.isNotEmpty) e,
    ];
    return BackendSemanticTurn(
      version: (json['version'] as num?)?.toInt() ?? 0,
      intent: SemanticIntent.parse(intent),
      requestedSlots: texts(json['requestedSlots']),
      mentionedContexts: [
        for (final m in (json['mentionedContexts'] as List? ?? const []))
          if (m is Map) ContextMention.fromJson(Map<String, dynamic>.from(m)),
      ],
      negations: texts(json['negations']),
      confidence: ((json['confidence'] as num?)?.toDouble() ?? 0)
          .clamp(0, 1)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'intent': intent.name,
    'requestedSlots': requestedSlots,
    'mentionedContexts': [for (final m in mentionedContexts) m.toJson()],
    'negations': negations,
    'confidence': confidence,
  };
}

/// La lectura semántica de un turno del oyente: lo que Conversation consume
/// y entrega al router de LSB→Texto/Audio.
///
/// Se interpreta una sola vez, en Audio/Texto→LSB, junto con la traducción.
/// No lleva identificadores del banco guiado: qué pregunta del grafo responde
/// a esto lo decide el router.
class SemanticTurn {
  final String turnId;

  /// Texto del oyente tal como se mostró. Solo para el prompt de desempate y
  /// para el respaldo del cliente; el router determinista no lo relee.
  final String text;
  final SpeechAct speechAct;
  final SemanticIntent intent;

  /// Glosas LSB del turno (la traducción de Audio/Texto→LSB).
  final List<String> entities;
  final List<ContextMention> mentionedContexts;

  /// Datos que pide el oyente, con el vocabulario de ranuras del grafo
  /// (`time`, `place`, `person`, `amount`…).
  final List<String> requestedSlots;

  /// Sentido elegido para términos ambiguos (`AUTO` → `vehiculo`).
  final Map<String, String> resolvedSenses;
  final List<String> negations;
  final double confidence;
  final SemanticTurnSource source;

  const SemanticTurn({
    required this.turnId,
    required this.text,
    required this.speechAct,
    required this.intent,
    this.entities = const [],
    this.mentionedContexts = const [],
    this.requestedSlots = const [],
    this.resolvedSenses = const {},
    this.negations = const [],
    this.confidence = 0,
    this.source = SemanticTurnSource.clientFallback,
  });

  /// La lectura del backend completada con lo que la respuesta ya traía.
  factory SemanticTurn.fromBackend({
    required String turnId,
    required String text,
    required SpeechAct speechAct,
    required BackendSemanticTurn backend,
    List<String> glosses = const [],
    List<SemanticDisambiguation> disambiguations = const [],
  }) => SemanticTurn(
    turnId: turnId,
    text: text,
    speechAct: speechAct,
    intent: backend.intent,
    entities: glosses,
    mentionedContexts: backend.mentionedContexts,
    requestedSlots: backend.requestedSlots,
    resolvedSenses: resolvedSensesOf(disambiguations),
    negations: backend.negations,
    confidence: backend.confidence,
    source: SemanticTurnSource.backend,
  );

  static Map<String, String> resolvedSensesOf(
    List<SemanticDisambiguation> disambiguations,
  ) => {
    for (final d in disambiguations)
      if (d.original.isNotEmpty && d.meaning.isNotEmpty)
        d.original.toUpperCase(): d.meaning,
  };

  bool get isQuestion => speechAct == SpeechAct.question;

  /// De qué o de quién habla el oyente, sin lo que pregunta ni las pistas del
  /// contexto: CELULAR en «¿Cuándo te robaron el celular?» (el robo es el
  /// contexto; el tiempo, lo pedido).
  ///
  /// Sitúa la conversación y orienta el ruteo. Nunca es un hecho declarado
  /// por la persona sorda: sus hechos son solo las respuestas que ella elige.
  List<String> get mentionedEntities {
    final cues = {
      for (final m in mentionedContexts)
        for (final e in m.evidence) ?LsbGlossSemantics.normalize(e),
    };
    final out = <String>[];
    for (final g in LsbGlossSemantics.normalizeAll(entities)) {
      if (LsbGlossSemantics.contentOf([g]).isEmpty ||
          LsbGlossSemantics.negators.contains(g) ||
          cues.contains(g) ||
          out.contains(g)) {
        continue;
      }
      out.add(g);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'turnId': turnId,
    'text': text,
    'speechAct': speechAct.name,
    'intent': intent.name,
    'entities': entities,
    'mentionedContexts': [for (final m in mentionedContexts) m.toJson()],
    'requestedSlots': requestedSlots,
    'resolvedSenses': resolvedSenses,
    'negations': negations,
    'confidence': confidence,
    'source': source.name,
  };
}
