import 'dart:convert';

import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank_data.g.dart';

/// El banco semántico de preguntas y recorridos.
///
/// Es la **única** fuente de las preguntas que ve la persona sorda en el
/// módulo LSB → texto/audio, de las opciones que puede elegir y de la frase
/// que produce cada elección. Lo genera `tool/build_question_matrix.py` desde
/// `docs/negocio/config/banco_preguntas.json`; la Lambda carga el mismo banco
/// (`aws/question_bank.json`), así que cliente y servidor redactan con las
/// mismas plantillas.
///
/// [questions] conserva el JSON crudo porque [GuidedComposer] lo recorre tal
/// cual (gemelo del compositor Python). Las vistas tipadas —[question],
/// [journey]— son para las reglas del flujo y la interfaz, y se derivan del
/// mismo JSON: no hay una segunda copia de nada.
class QuestionBank {
  final Map<String, dynamic> data;

  late final Map<String, Map<String, dynamic>> questions = {
    for (final raw in data['preguntas'] as List<dynamic>)
      (raw as Map<String, dynamic>)['id'] as String: raw,
  };

  late final Map<String, BankQuestion> _typed = {
    for (final entry in questions.entries)
      entry.key: BankQuestion.fromJson(entry.value),
  };

  late final Map<String, BankJourney> journeys = {
    for (final entry
        in (data['recorridos'] as Map<String, dynamic>? ?? const {}).entries)
      entry.key: BankJourney.fromJson(
          entry.key, entry.value as Map<String, dynamic>),
  };

  QuestionBank(this.data);

  static QuestionBank? _generated;

  /// El banco empaquetado con la aplicación. Se decodifica una sola vez.
  factory QuestionBank.generated() => _generated ??= QuestionBank(
        jsonDecode(kQuestionBankJson) as Map<String, dynamic>,
      );

  BankQuestion? question(String id) => _typed[id];

  BankJourney? journey(String id) => journeys[id];

  Iterable<BankQuestion> get allQuestions => _typed.values;
}

/// Condición de visibilidad de un paso o de una opción.
///
/// `{pregunta, opciones}`: se cumple si esa pregunta tiene elegida alguna de
/// esas opciones. `{pregunta, estados}`: si su respuesta está en alguno de
/// esos estados. `{perfil: false|true}`: según haya o no perfil
/// institucional en la atención. Una respuesta omitida no cumple ninguna
/// condición: «Omitir» no es elegir.
class GuidedCondition {
  final String? questionId;
  final List<String> optionIds;
  final List<String> states;
  final bool? profile;

  const GuidedCondition({
    this.questionId,
    this.optionIds = const [],
    this.states = const [],
    this.profile,
  });

  factory GuidedCondition.fromJson(Map<String, dynamic> json) =>
      GuidedCondition(
        questionId: json['pregunta'] as String?,
        optionIds: _strings(json['opciones']),
        states: _strings(json['estados']),
        profile: json['perfil'] as bool?,
      );
}

/// Un paso de un recorrido: qué pregunta, cuándo se muestra y qué opciones
/// oculta en ese contexto.
class JourneyStep {
  final String questionId;
  final List<GuidedCondition> conditions;
  final bool required;
  final List<String> hiddenOptions;
  final String? parent;
  final String? formulation;

  const JourneyStep({
    required this.questionId,
    this.conditions = const [],
    this.required = false,
    this.hiddenOptions = const [],
    this.parent,
    this.formulation,
  });

  factory JourneyStep.fromJson(Map<String, dynamic> json) => JourneyStep(
        questionId: json['pregunta'] as String,
        conditions: [
          for (final c in (json['cuando'] as List<dynamic>? ?? const []))
            GuidedCondition.fromJson(c as Map<String, dynamic>),
        ],
        required: json['obligatoria'] == true,
        hiddenOptions: _strings(json['ocultar']),
        parent: json['padre'] as String?,
        formulation: json['formulacion'] as String?,
      );
}

class BankJourney {
  final String id;
  final String name;
  final List<JourneyStep> steps;

  /// Orden de redacción, cuando difiere del orden de las preguntas.
  final List<String> writingOrder;

  const BankJourney({
    required this.id,
    required this.name,
    required this.steps,
    this.writingOrder = const [],
  });

  factory BankJourney.fromJson(String id, Map<String, dynamic> json) =>
      BankJourney(
        id: id,
        name: (json['nombre'] ?? id).toString(),
        steps: [
          for (final s in json['pasos'] as List<dynamic>)
            JourneyStep.fromJson(s as Map<String, dynamic>),
        ],
        writingOrder: _strings(json['ordenRedaccion']),
      );
}

class BankQuestion {
  final String id;
  final String formulation;
  final String control;
  final String mode;
  final int? maximum;
  final List<BankOption> options;

  /// Glosas que no se ofrecen como respuesta a esta pregunta (`noOfrecer`):
  /// las que la formulan y las que el banco descarta por otro motivo.
  final List<String> notOfferedGlosses;

  /// Cómo se formula la pregunta en LSB (`formulacionLsb`).
  final LsbFormulation lsb;

  /// Plantilla de la frase suelta de una pregunta en modo `fragmento`.
  final String? looseSentence;

  const BankQuestion({
    required this.id,
    required this.formulation,
    required this.control,
    required this.options,
    this.mode = 'frase',
    this.maximum,
    this.notOfferedGlosses = const [],
    this.lsb = LsbFormulation.none,
    this.looseSentence,
  });

  factory BankQuestion.fromJson(Map<String, dynamic> json) => BankQuestion(
        id: json['id'] as String,
        formulation: (json['formulacion'] ?? '').toString(),
        control: (json['control'] ?? '').toString(),
        mode: (json['modo'] ?? 'frase').toString(),
        maximum: (json['maximo'] as num?)?.toInt(),
        options: [
          for (final o in (json['opciones'] as List<dynamic>? ?? const []))
            BankOption.fromJson(o as Map<String, dynamic>),
        ],
        notOfferedGlosses: _strings(json['noOfrecer']),
        lsb: LsbFormulation.fromJson(json['formulacionLsb']),
        looseSentence: json['fraseSuelta'] as String?,
      );

  bool get isPolar => control == 'polar2' || control == 'polar3';

  bool get isMultiple => control == 'seleccion_multiple';

  bool get isFragment => mode == 'fragmento';

  /// Una pregunta compuesta que el banco divide en otras (`derivacion`): no
  /// se responde ella misma.
  bool get isDerivation => control == 'derivacion';

  /// Máximo de opciones activas a la vez. Toda pregunta que no sea de
  /// selección múltiple admite exactamente una.
  int get maxPicks => isMultiple ? (maximum ?? options.length) : 1;

  /// Mínimo para que cuente como respondida.
  int get minPicks => 1;

  BankOption? option(String id) {
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }
}

class BankOption {
  final String id;
  final String label;
  final List<String> glosses;
  final GuidedAnswerState state;
  final bool isExit;
  final String? editor;
  final bool editorOptional;
  final String? group;
  final List<GuidedCondition> conditions;
  final bool literal;
  final bool noSign;

  /// La edad es exacta por naturaleza (la propia): no se ofrece marcarla
  /// como aproximada.
  final bool noApproximate;
  final List<int>? range;
  final String phrase;
  final String? phraseWithoutValue;
  final String? singularPhrase;

  const BankOption({
    required this.id,
    required this.label,
    required this.glosses,
    required this.state,
    this.isExit = false,
    this.editor,
    this.editorOptional = false,
    this.group,
    this.conditions = const [],
    this.literal = false,
    this.noSign = false,
    this.noApproximate = false,
    this.range,
    this.phrase = '',
    this.phraseWithoutValue,
    this.singularPhrase,
  });

  factory BankOption.fromJson(Map<String, dynamic> json) => BankOption(
        id: json['id'] as String,
        label: (json['etiqueta'] ?? json['id']).toString(),
        glosses: _strings(json['glosas']),
        state: GuidedAnswerStateWire.parse(json['estado'] as String?) ??
            GuidedAnswerState.affirmed,
        isExit: json['salida'] == true,
        editor: json['editor'] as String?,
        editorOptional: json['editorOpcional'] == true,
        group: json['grupo'] as String?,
        conditions: [
          for (final c in (json['cuando'] as List<dynamic>? ?? const []))
            GuidedCondition.fromJson(c as Map<String, dynamic>),
        ],
        literal: json['literal'] == true,
        noSign: json['sinSena'] == true,
        noApproximate: json['sinAproximado'] == true,
        range: json['rango'] == null
            ? null
            : [
                for (final n in json['rango'] as List<dynamic>)
                  (n as num).toInt()
              ],
        phrase: (json['frase'] ?? '').toString(),
        phraseWithoutValue: json['fraseSinValor'] as String?,
        singularPhrase: json['fraseSingular'] as String?,
      );

  bool get hasEditor => editor != null;

  /// La opción no puede elegirse sin su valor (nombre, teléfono, monto…).
  bool get requiresValue => editor != null && !editorOptional;

  /// Si tiene una seña documentada que mostrar. Una opción literal o marcada
  /// sin seña se presenta como texto, sin fingir una tarjeta LSB.
  bool get hasSign => glosses.isNotEmpty && !literal && !noSign;

  /// Si la opción redacta algo por sí misma. Las que no —«Me falta algo»,
  /// «Alguien escapó», «¿Quiere describirla?»— solo abren la pregunta que
  /// sí lo hace.
  bool get writesSomething =>
      phrase.trim().isNotEmpty ||
      (phraseWithoutValue?.trim().isNotEmpty ?? false) ||
      (singularPhrase?.trim().isNotEmpty ?? false);

  /// Excluye a las demás opciones de la misma pregunta: «No sé», «Ninguno»,
  /// «No recuerdo» y cualquier respuesta negativa o desconocida.
  bool get isExclusive => isExit || state != GuidedAnswerState.affirmed;
}

/// Formulación LSB de una pregunta del banco.
///
/// `glosa válida ≠ oración LSB validada`: la secuencia sale del corpus v4 (o
/// de sus patrones) y es provisional hasta que la valide una persona señante;
/// [status] lo dice. Los tokens son glosas del catálogo, dactilología
/// `d(SIGLA)` o el mecanismo numérico `NÚM(...)`. Lo que la secuencia lineal
/// no representa (marcas no manuales, dirección) viaja como metadata.
class LsbFormulation {
  final List<String> glosses;
  final String status;
  final String? type;
  final String? interrogative;
  final String? nonManual;
  final List<List<String>> compounds;
  final Map<int, List<String>> alternatives;
  final String? referent;
  final List<String> gaps;

  const LsbFormulation({
    this.glosses = const [],
    this.status = 'GRAMMAR_PENDING',
    this.type,
    this.interrogative,
    this.nonManual,
    this.compounds = const [],
    this.alternatives = const {},
    this.referent,
    this.gaps = const [],
  });

  static const none = LsbFormulation();

  static const numberToken = 'NÚM(...)';

  factory LsbFormulation.fromJson(dynamic raw) {
    if (raw is! Map) return none;
    final json = Map<String, dynamic>.from(raw);
    final alternativas = json['alternativas'];
    return LsbFormulation(
      glosses: _strings(json['glosas']),
      status: (json['estado'] ?? 'GRAMMAR_PENDING').toString(),
      type: json['tipo'] as String?,
      interrogative: json['interrogativo'] as String?,
      nonManual: json['noManuales'] as String?,
      compounds: [
        for (final c in (json['compuestos'] as List<dynamic>? ?? const []))
          _strings(c),
      ],
      alternatives: alternativas is Map
          ? {
              for (final e in alternativas.entries)
                int.parse(e.key.toString()): _strings(e.value),
            }
          : const {},
      referent: json['referente'] as String?,
      gaps: _strings(json['huecos']),
    );
  }

  bool get isEmpty => glosses.isEmpty;

  bool get isValidated => status == 'GRAMMAR_VALIDATED';

  static bool isDactylology(String token) => token.startsWith('d(');

  /// Piezas para mostrar: un compuesto va en una sola pieza, una glosa con
  /// alternativas muestra las dos (ÉL/ELLA) y un interrogativo lleva ¿?.
  List<LsbFormulationSegment> get segments {
    final out = <LsbFormulationSegment>[];
    var i = 0;
    while (i < glosses.length) {
      final compound = compounds.firstWhere(
        (c) => c.isNotEmpty &&
            i + c.length <= glosses.length &&
            _sameList(glosses.sublist(i, i + c.length), c),
        orElse: () => const [],
      );
      if (compound.isNotEmpty) {
        out.add(LsbFormulationSegment(
          label: compound.join('+'),
          glosses: compound,
          kind: LsbSegmentKind.compound,
        ));
        i += compound.length;
        continue;
      }
      final token = glosses[i];
      if (isDactylology(token)) {
        out.add(LsbFormulationSegment(
            label: token, glosses: const [], kind: LsbSegmentKind.dactylology));
      } else if (token == numberToken) {
        out.add(const LsbFormulationSegment(
            label: 'NÚM', glosses: [], kind: LsbSegmentKind.number));
      } else {
        final alts = alternatives[i];
        final label = alts != null ? alts.join('/') : token;
        out.add(LsbFormulationSegment(
          label: token == interrogative ||
                  const {'QUÉ', 'QUIÉN', 'DÓNDE', 'CUÁNDO', 'CUÁL', 'CÓMO', 'CUÁNTOS'}
                      .contains(token)
              ? '¿$label?'
              : label,
          glosses: [token],
          kind: LsbSegmentKind.sign,
        ));
      }
      i++;
    }
    return out;
  }
}

enum LsbSegmentKind { sign, compound, dactylology, number }

class LsbFormulationSegment {
  final String label;

  /// Glosas del catálogo que componen la pieza (vacío en dactilología y
  /// número, que no son señas del catálogo).
  final List<String> glosses;
  final LsbSegmentKind kind;

  const LsbFormulationSegment({
    required this.label,
    required this.glosses,
    required this.kind,
  });
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<String> _strings(dynamic raw) {
  if (raw is List) return [for (final v in raw) v.toString()];
  if (raw is Map) return [for (final k in raw.keys) k.toString()];
  return const [];
}
