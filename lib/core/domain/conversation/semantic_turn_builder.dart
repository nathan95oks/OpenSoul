import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/graph_matcher.dart';
import 'package:lsb_legal_app/core/domain/conversation/lsb_gloss_semantics.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/services/context_inference_engine.dart';

/// Respaldo del cliente para leer un turno del oyente.
///
/// La ruta preferida es la lectura que entrega Audio/Texto→LSB junto con la
/// traducción (`semanticTurn`). Este constructor solo se usa cuando esa
/// lectura no llega (backend desplegado antes del contrato, respuesta
/// incompleta): arma una lectura equivalente con lo que sí llegó —el texto,
/// las glosas y los sentidos resueltos— sin traducir de nuevo ni llamar a un
/// modelo. Se retirará cuando todos los backends envíen la lectura.
class SemanticTurnBuilder {
  final ConversationGraphCatalog catalog;
  final GraphMatcher matcher;

  SemanticTurnBuilder(this.catalog) : matcher = GraphMatcher(catalog);

  SemanticTurn build({
    required String turnId,
    required String text,
    List<String> glosses = const [],
    SpeechAct? speechAct,
    List<SemanticDisambiguation> disambiguations = const [],
    String? activeContextId,
  }) {
    final act = speechAct ?? classifySpeechAct(text);
    final mentions = _mentions(text, glosses);
    // Primero lo que el oyente quiere saber (el interrogativo del texto o de
    // las glosas); las frases del grafo solo cuentan si responden a eso.
    final normalized = LsbGlossSemantics.normalizeAll(glosses);
    final asked = <String>{
      if (act == SpeechAct.question ||
          LsbGlossSemantics.hasInterrogative(normalized))
        ...LsbGlossSemantics.slotsOf(normalized),
      ...LsbGlossSemantics.spokenSlotsOf(text),
    };
    final requests = matcher.byText(
      text,
      activeContextId: activeContextId,
      requestedSlots: asked,
      contexts: {
        if (activeContextId != null && catalog.hasContext(activeContextId))
          activeContextId,
        for (final m in mentions)
          if (m.isFamily)
            ...catalog.contextsOfFamily(m.id)
          else if (catalog.hasContext(m.id))
            m.id,
      },
    );
    final best = requests.isEmpty
        ? 0.0
        : requests.map((r) => r.score).reduce((a, b) => a > b ? a : b);

    final SemanticIntent intent;
    final double confidence;
    if (best >= GraphMatcher.strongMatch ||
        asked.difference(const {'polarity'}).isNotEmpty) {
      intent = SemanticIntent.askInformation;
      confidence = best;
    } else if (mentions.isNotEmpty) {
      intent = SemanticIntent.mentionContext;
      confidence = 0.8;
    } else if (requests.isNotEmpty) {
      intent = SemanticIntent.askInformation;
      confidence = best;
    } else if (act == SpeechAct.question && _isOpenQuestion(text)) {
      intent = SemanticIntent.askPurpose;
      confidence = 0.6;
    } else {
      intent = switch (act) {
        SpeechAct.instruction => SemanticIntent.instruction,
        SpeechAct.statement => SemanticIntent.statement,
        SpeechAct.question => SemanticIntent.unknown,
      };
      confidence = 0.3;
    }

    return SemanticTurn(
      turnId: turnId,
      text: text,
      speechAct: act,
      intent: intent,
      entities: glosses,
      mentionedContexts: mentions,
      requestedSlots: <String>{
        ...asked,
        for (final r in requests)
          if (r.score >= GraphMatcher.strongMatch) ...r.slots,
      }.toList(),
      resolvedSenses: SemanticTurn.resolvedSensesOf(disambiguations),
      negations: _negations(text, glosses),
      confidence: confidence.clamp(0, 1).toDouble(),
      source: SemanticTurnSource.clientFallback,
    );
  }

  List<ContextMention> _mentions(String text, List<String> glosses) {
    final stems = {
      ...spanishContentStems(text),
      ...spanishContentStems(glosses.join(' ').toLowerCase()),
    };
    if (stems.isEmpty) return const [];
    return [
      for (final e in catalog.contextStems.entries)
        if (e.value.intersection(stems).isNotEmpty)
          ContextMention(
            id: e.key,
            isFamily: false,
            evidence: e.value.intersection(stems).toList(),
          ),
      for (final e in catalog.familyStems.entries)
        if (e.value.intersection(stems).isNotEmpty)
          ContextMention(
            id: e.key,
            isFamily: true,
            evidence: e.value.intersection(stems).toList(),
          ),
    ];
  }

  static const _textNegators = {
    'no',
    'nunca',
    'nadie',
    'nada',
    'ningun',
    'ninguna',
    'ninguno',
    'tampoco',
  };

  static List<String> _negations(String text, List<String> glosses) => {
    for (final w in GraphMatcher.plainText(text).split(' '))
      if (_textNegators.contains(w)) w.toUpperCase(),
    for (final g in LsbGlossSemantics.normalizeAll(glosses))
      if (LsbGlossSemantics.negators.contains(g)) g,
  }.toList();

  /// Pregunta abierta: interrogativo sin ranura propia (qué, cuál, cómo).
  static bool _isOpenQuestion(String text) => GraphMatcher.plainText(text)
      .split(' ')
      .toSet()
      .intersection(const {'que', 'cual', 'cuales', 'como'})
      .isNotEmpty;
}
