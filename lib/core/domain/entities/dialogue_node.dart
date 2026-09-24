import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';

/// Con qué recurso real se representa una opción.
///
/// Separado a propósito del significado: que un concepto esté resuelto no
/// dice nada de si existe una seña, y que exista una glosa en el catálogo no
/// dice nada de si el avatar sabe ejecutarla.
enum OptionCoverage {
  directSign,
  dactylology,
  validatedComposition,
  needsValidation,
  unsupported;

  static OptionCoverage parse(String? raw) => switch (raw) {
        'direct_sign' => OptionCoverage.directSign,
        'dactylology' => OptionCoverage.dactylology,
        'validated_composition' => OptionCoverage.validatedComposition,
        'needs_validation' => OptionCoverage.needsValidation,
        _ => OptionCoverage.unsupported,
      };

  /// Si puede ofrecerse como tarjeta sin inventar nada.
  bool get isOfferable =>
      this == OptionCoverage.directSign ||
      this == OptionCoverage.dactylology ||
      this == OptionCoverage.validatedComposition;
}

/// Qué es la opción para quien la toca: una tarjeta del catálogo, un número o
/// una palabra que se deletrea.
enum OptionKind { card, number, spelling }

/// Lo que el avatar puede hacer con ella hoy.
enum AvatarSupport { baked, spelled, placeholder }

class DialogueOption {
  final String concept;
  final String? gloss;
  final OptionKind kind;
  final OptionCoverage coverage;
  final AvatarSupport avatar;
  final String reason;
  final String? corpusSource;
  final List<String> alternatives;

  const DialogueOption({
    required this.concept,
    required this.kind,
    required this.coverage,
    required this.avatar,
    this.gloss,
    this.reason = '',
    this.corpusSource,
    this.alternatives = const [],
  });

  factory DialogueOption.fromJson(Map<String, dynamic> json) => DialogueOption(
        concept: (json['concept'] ?? '').toString(),
        gloss: json['gloss'] as String?,
        kind: switch (json['kind']) {
          'number' => OptionKind.number,
          'spelling' => OptionKind.spelling,
          _ => OptionKind.card,
        },
        coverage: OptionCoverage.parse(json['coverage'] as String?),
        avatar: switch (json['avatar']) {
          'baked' => AvatarSupport.baked,
          'spelled' => AvatarSupport.spelled,
          _ => AvatarSupport.placeholder,
        },
        reason: (json['reason'] ?? '').toString(),
        corpusSource: json['corpusSource'] as String?,
        alternatives: [
          for (final a in (json['alternatives'] as List? ?? const []))
            a.toString(),
        ],
      );
}

/// De dónde sale el nodo. Sin esto no se puede decir que una opción tenga
/// procedencia lingüística, solo que alguien la escribió.
class DialogueProvenance {
  final int section;
  final String subsection;
  final int row;
  final String spanish;
  final String conceptsRaw;
  final String note;

  const DialogueProvenance({
    required this.section,
    required this.subsection,
    required this.row,
    required this.spanish,
    this.conceptsRaw = '',
    this.note = '',
  });

  factory DialogueProvenance.fromJson(Map<String, dynamic> json) =>
      DialogueProvenance(
        section: (json['section'] as num?)?.toInt() ?? 0,
        subsection: (json['subsection'] ?? '').toString(),
        row: (json['row'] as num?)?.toInt() ?? 0,
        spanish: (json['spanish'] ?? '').toString(),
        conceptsRaw: (json['conceptsRaw'] ?? '').toString(),
        note: (json['note'] ?? '').toString(),
      );

  String get citation => 'corpus §$section · $subsection · fila $row';
}

class DialogueTransition {
  final String to;
  final List<String> adds;
  final int priority;

  const DialogueTransition({
    required this.to,
    this.adds = const [],
    this.priority = 0,
  });

  factory DialogueTransition.fromJson(Map<String, dynamic> json) =>
      DialogueTransition(
        to: (json['to'] ?? '').toString(),
        adds: [for (final a in (json['adds'] as List? ?? const [])) a.toString()],
        priority: (json['priority'] as num?)?.toInt() ?? 0,
      );
}

class DialogueNode {
  final String id;
  final int version;
  final DialogueProvenance provenance;
  final String scope;
  final String intent;
  final String speaker;
  final String speechAct;
  final Set<CardsFlowPurpose> modes;
  final String phrase;
  final List<String> keywords;
  final String guideText;
  final List<String> slots;
  final List<String> markers;
  final List<DialogueOption> options;
  final List<DialogueOption> pendingOptions;
  final OptionCoverage coverage;
  final List<DialogueTransition> transitions;

  const DialogueNode({
    required this.id,
    required this.version,
    required this.provenance,
    required this.scope,
    required this.intent,
    required this.speaker,
    required this.speechAct,
    required this.modes,
    required this.phrase,
    required this.keywords,
    required this.slots,
    required this.options,
    this.guideText = '',
    this.markers = const [],
    this.pendingOptions = const [],
    this.coverage = OptionCoverage.unsupported,
    this.transitions = const [],
  });

  static const _modeNames = {
    'A': CardsFlowPurpose.standaloneDeclaration,
    'B': CardsFlowPurpose.conversationInitiative,
    'C': CardsFlowPurpose.conversationReply,
  };

  factory DialogueNode.fromJson(Map<String, dynamic> json) {
    final entry = Map<String, dynamic>.from(
        (json['entry'] as Map?) ?? const <String, dynamic>{});
    return DialogueNode(
      id: (json['id'] ?? '').toString(),
      version: (json['version'] as num?)?.toInt() ?? 0,
      provenance: DialogueProvenance.fromJson(
          Map<String, dynamic>.from(json['provenance'] as Map? ?? {})),
      scope: (json['scope'] ?? '').toString(),
      intent: (json['intent'] ?? '').toString(),
      speaker: (json['speaker'] ?? '').toString(),
      speechAct: (json['speechAct'] ?? '').toString(),
      modes: {
        for (final m in (json['modes'] as List? ?? const []))
          if (_modeNames[m.toString()] != null) _modeNames[m.toString()]!,
      },
      phrase: (entry['phrase'] ?? '').toString(),
      keywords: [
        for (final k in (entry['keywords'] as List? ?? const [])) k.toString(),
      ],
      guideText: (json['guideText'] ?? '').toString(),
      slots: [for (final s in (json['slots'] as List? ?? const [])) s.toString()],
      markers: [
        for (final m in (json['markers'] as List? ?? const [])) m.toString(),
      ],
      options: [
        for (final o in (json['options'] as List? ?? const []))
          DialogueOption.fromJson(Map<String, dynamic>.from(o as Map)),
      ],
      pendingOptions: [
        for (final o in (json['pendingOptions'] as List? ?? const []))
          DialogueOption.fromJson(Map<String, dynamic>.from(o as Map)),
      ],
      coverage: OptionCoverage.parse(json['coverage'] as String?),
      transitions: [
        for (final t in (json['transitions'] as List? ?? const []))
          DialogueTransition.fromJson(Map<String, dynamic>.from(t as Map)),
      ],
    );
  }

  /// Las glosas que se pueden poner como tarjetas, en su orden de utilidad.
  List<String> get offerableGlosses => [
        for (final o in options)
          if (o.coverage.isOfferable && o.gloss != null && o.gloss!.isNotEmpty)
            o.gloss!,
      ];

  bool get invitesPolarAnswer =>
      speechAct == 'question' && slots.contains('polarity');
}
