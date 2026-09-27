import 'package:lsb_legal_app/core/domain/conversation/lsb_gloss_semantics.dart';
import 'package:lsb_legal_app/core/domain/entities/dialogue_node.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/services/context_catalog.dart';
import 'package:lsb_legal_app/core/domain/services/context_inference_engine.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';

/// Lo que el router puede ofrecer: familias, contextos, recorridos,
/// preguntas y ranuras que **ya existen**.
///
/// No declara vocabulario propio. Todo se deriva de:
///   * el banco guiado (recorridos, preguntas, dependencias);
///   * el grafo de diálogo del corpus (preguntas del oyente en modo
///     respuesta, con su pregunta del banco, su ámbito y sus ranuras);
///   * el catálogo de contextos y familias que ve la persona sorda.
///
/// Las palabras con las que se reconoce que el oyente nombra un contexto
/// salen de los nombres de esas familias y contextos, no de una lista de
/// frases.
class ConversationGraphCatalog {
  final QuestionBank bank;
  final DialogueGraph graph;
  final List<ContextFamily> families;
  final List<SemanticContext> contexts;

  ConversationGraphCatalog({
    required this.bank,
    required this.graph,
    List<ContextFamily>? families,
    List<SemanticContext>? contexts,
  }) : families = families ?? contextFamilies,
       contexts = contexts ?? allSelectableContexts;

  late final Map<String, SemanticContext> _contexts = {
    for (final c in contexts)
      if (bank.journey(c.id) != null) c.id: c,
  };

  late final Map<String, ContextFamily> _families = {
    for (final f in families) f.id: f,
  };

  /// Nodos del grafo que el oyente puede preguntar y que el banco sabe
  /// responder.
  late final List<DialogueNode> replyNodes = [
    for (final n in graph.all)
      if (n.modes.contains(CardsFlowPurpose.conversationReply) &&
          n.bankQuestion != null &&
          bank.question(n.bankQuestion!) != null)
        n,
  ];

  /// Formas en que el oyente puede hacer cada pregunta del banco: las frases
  /// del corpus (nodos del grafo) y la formulación del propio banco en cada
  /// recorrido donde es un paso. Cada una lleva la formulación LSB de su
  /// pregunta, que es con lo que se compara el significado del turno.
  late final List<ReplyEntry> replyEntries = () {
    final out = <ReplyEntry>[];
    final seen = <String>{};
    void add(
      String id,
      String questionId,
      String scope,
      String phrase, {
      required bool fromNode,
    }) {
      final key = '$questionId|${DialogueGraph.tokensOf(phrase).join(' ')}';
      if (phrase.trim().isEmpty || !seen.add(key)) return;
      out.add(
        ReplyEntry(
          id: id,
          questionId: questionId,
          scope: scope,
          phrase: phrase,
          glosses: lsbGlossesOf(questionId),
          fromNode: fromNode,
        ),
      );
    }

    for (final n in replyNodes) {
      add(n.id, n.bankQuestion!, n.scope, n.phrase, fromNode: true);
    }
    for (final contextId in _contexts.keys) {
      for (final step in bank.journey(contextId)!.steps) {
        if (!hasQuestion(step.questionId)) continue;
        add(
          'bank:${step.questionId}@$contextId',
          step.questionId,
          contextId,
          step.formulation ?? bank.question(step.questionId)!.formulation,
          fromNode: false,
        );
      }
    }
    return out;
  }();

  /// Formulación LSB de la pregunta, normalizada para comparar.
  List<String> lsbGlossesOf(String questionId) =>
      LsbGlossSemantics.normalizeAll(
        bank.question(questionId)?.lsb.glosses ?? const [],
      );

  /// Dato al que permite responder la pregunta.
  ///
  /// Normalmente sale de su interrogativo LSB (CUÁNDO → `time`). Algunas
  /// preguntas son una puerta segura hacia ese dato: antes de identificar a
  /// un autor, por ejemplo, el recorrido puede preguntar si se lo conoce. El
  /// rol semántico del banco reconoce esa puerta sin depender de una frase o
  /// de un identificador concreto.
  Set<String> answerSlotsOf(String questionId) {
    final direct = LsbGlossSemantics.questionSlotsOf(lsbGlossesOf(questionId));
    final question = bank.question(questionId);
    if (question?.entity.toLowerCase() == 'persona[autor]') {
      return {...direct, 'person'};
    }
    // Una pregunta de control («¿Quiere describir a la persona?») es la
    // puerta del dato de su dominio: abre las preguntas que lo recogen.
    final gateSlot = _slotByDomain[domainOf(questionId)];
    if (gateSlot != null && isControlGate(questionId)) {
      return {...direct, gateSlot};
    }
    return direct;
  }

  /// Dato que recoge cada dominio del banco cuando no hay un interrogativo
  /// que lo diga (las preguntas de descripción son disyuntivas: «¿Era alto o
  /// bajo?»).
  static const Map<String, String> _slotByDomain = {
    'descripcion': 'description',
  };

  /// Dominio de la pregunta en el banco (`dominio`).
  String? domainOf(String questionId) =>
      bank.questions[questionId]?['dominio'] as String?;

  /// Pregunta de control: todas sus opciones solo abren o cierran otras
  /// preguntas (`soloControl`) y no escriben nada en la declaración.
  bool isControlGate(String questionId) {
    final options = bank.questions[questionId]?['opciones'];
    if (options is! List || options.isEmpty) return false;
    return options.every(
      (o) => o is Map && (o['soloControl'] ?? '').toString().trim().isNotEmpty,
    );
  }

  /// Preguntas de [contextId] que abre la puerta [gateId] (su condición es
  /// una respuesta de la puerta), en el orden del recorrido.
  List<String> openedBy(String contextId, String gateId) => [
    if (isControlGate(gateId))
      for (final s in bank.journey(contextId)?.steps ?? const <JourneyStep>[])
        if (s.conditions.any((c) => c.questionId == gateId) &&
            hasQuestion(s.questionId))
          s.questionId,
  ];

  /// Pregunta de sí/no: tiene formulación y ningún interrogativo.
  bool isPolarQuestion(String questionId) {
    final glosses = lsbGlossesOf(questionId);
    return glosses.isNotEmpty && !LsbGlossSemantics.hasInterrogative(glosses);
  }

  /// Si [questionId] responde a lo que pidió el oyente ([requested]).
  ///
  /// Sin ranuras pedidas no hay restricción. Con ranuras, la pregunta tiene
  /// que responder alguna; `polarity` la cumple una pregunta de sí/no. Que
  /// comparta glosas con el turno no basta: «¿Cuándo te robaron el celular?»
  /// no se responde con «¿Le robaron el celular?».
  bool answers(String questionId, Iterable<String> requested) {
    final asked = requested.toSet();
    final data = asked.difference(const {'polarity'});
    if (asked.isEmpty) return true;
    if (answerSlotsOf(questionId).intersection(data).isNotEmpty) return true;
    return asked.contains('polarity') && isPolarQuestion(questionId);
  }

  /// Glosas de las respuestas que ofrece el recorrido de [contextId]
  /// (CELULAR, MOCHILA… en el robo). Si el oyente nombra una, la da por
  /// supuesta: orienta el ruteo, pero no es otra pregunta ni un hecho
  /// confirmado por la persona sorda.
  Set<String> optionGlossesOf(String contextId) => _optionGlosses.putIfAbsent(
    contextId,
    () {
      final out = <String>{};
      for (final step in bank.journey(contextId)?.steps ?? const []) {
        for (final o in bank.question(step.questionId)?.options ?? const []) {
          if (o.hasSign) out.addAll(LsbGlossSemantics.normalizeAll(o.glosses));
        }
      }
      return out;
    },
  );

  final Map<String, Set<String>> _optionGlosses = {};

  /// Ranuras que pueden pedirse: el vocabulario del grafo de diálogo.
  late final Set<String> knownSlots = {
    ...LsbGlossSemantics.slotVocabulary,
    for (final n in replyNodes) ...n.slots,
  };

  bool hasContext(String id) => _contexts.containsKey(id);

  bool hasFamily(String id) => _families.containsKey(id);

  bool hasQuestion(String id) {
    final q = bank.question(id);
    return q != null && !q.isDerivation;
  }

  SemanticContext? context(String id) => _contexts[id];

  ContextFamily? family(String id) => _families[id];

  /// Contextos de [familyId] que tienen recorrido guiado.
  List<String> contextsOfFamily(String familyId) => [
    for (final id in _families[familyId]?.contextIds ?? const <String>[])
      if (hasContext(id)) id,
  ];

  String? familyOf(String contextId) {
    for (final f in families) {
      if (f.contextIds.contains(contextId)) return f.id;
    }
    return null;
  }

  /// Si [questionId] es un paso del recorrido de [contextId].
  bool isStepOf(String contextId, String questionId) =>
      bank.journey(contextId)?.steps.any((s) => s.questionId == questionId) ??
      false;

  /// Recorridos (contextos) donde [questionId] es un paso.
  List<String> journeysOf(String questionId) => [
    for (final id in _contexts.keys)
      if (isStepOf(id, questionId)) id,
  ];

  // ---- Menciones ------------------------------------------------------------

  /// Raíces que nombran una familia: las de su nombre.
  late final Map<String, Set<String>> familyStems = {
    for (final f in families) f.id: spanishContentStems(f.name),
  };

  /// Raíces que nombran un contexto: las de su nombre que no comparte con
  /// otro contexto ni con el nombre de una familia. «Denunciar robo» aporta
  /// `rob`; «denunci» nombra a la familia, no a un contexto.
  late final Map<String, Set<String>> contextStems = () {
    final own = {
      for (final c in _contexts.values) c.id: spanishContentStems(c.name),
    };
    final shared = <String>{for (final s in familyStems.values) ...s};
    final seen = <String>{};
    for (final stems in own.values) {
      for (final s in stems) {
        if (!seen.add(s)) shared.add(s);
      }
    }
    return {for (final e in own.entries) e.key: e.value.difference(shared)};
  }();
}

/// Una forma real de hacer una pregunta del banco: frase del corpus o
/// formulación del banco, con el ámbito donde se hace.
class ReplyEntry {
  final String id;
  final String questionId;
  final String scope;
  final String phrase;

  /// Formulación LSB de la pregunta, normalizada.
  final List<String> glosses;

  /// Sale de un nodo del grafo (una pregunta real del funcionario), no solo
  /// de la formulación del banco.
  final bool fromNode;

  const ReplyEntry({
    required this.id,
    required this.questionId,
    required this.scope,
    required this.phrase,
    this.glosses = const [],
    this.fromNode = false,
  });
}
