import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/lsb_gloss_semantics.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

/// Una pregunta del banco que responde a lo que pidió el oyente.
class RequestedQuestion {
  final String questionId;

  /// La forma de la pregunta con la que coincidió (nodo del grafo o
  /// formulación del banco).
  final String nodeId;
  final String scope;

  /// Ranuras del grafo que cubre (`time`, `place`…).
  final List<String> slots;
  final double score;

  const RequestedQuestion({
    required this.questionId,
    required this.nodeId,
    required this.scope,
    required this.slots,
    required this.score,
  });
}

/// Encuentra en el grafo las preguntas que responden a un [SemanticTurn].
///
/// Con la lectura del backend no relee el texto: compara lo que el turno
/// significa (sus glosas canónicas y ranuras) con la formulación LSB de cada
/// pregunta del banco. «¿Dónde fue?», «¿Dónde pasó?» y «¿En qué lugar
/// ocurrió?» piden `place` y llegan a la misma pregunta.
///
/// Solo si la lectura es del respaldo del cliente (backend antiguo) compara
/// el texto con las frases del grafo, como hacía antes.
class GraphMatcher {
  final ConversationGraphCatalog catalog;

  /// Parecido mínimo para considerar una coincidencia.
  static const double weakMatch = 0.34;

  /// Desde aquí la coincidencia es segura. Es la confianza mínima con la que
  /// el validador acepta una ruta.
  static const double strongMatch = 0.6;

  /// Casi idéntico al corpus: no necesita más pruebas.
  static const double exactMatch = 0.8;

  /// Distintivo: aparece en pocas preguntas («testigo», «herida»). «Tener» o
  /// «querer» aparecen en decenas y no identifican ninguna.
  static const int _distinctiveMaxQuestions = 3;

  GraphMatcher(this.catalog);

  List<RequestedQuestion> match(SemanticTurn turn, {String? activeContextId}) =>
      turn.source == SemanticTurnSource.backend
      ? bySemantics(turn, activeContextId: activeContextId)
      : byText(turn.text, activeContextId: activeContextId);

  // ---- Significado (lectura del backend) -----------------------------------

  late final List<_Signature> _signatures = [
    for (final e in catalog.replyEntries) _Signature(e),
  ];

  late final Map<String, int> _questionFrequency = () {
    final perGloss = <String, Set<String>>{};
    for (final s in _signatures) {
      for (final g in s.content) {
        perGloss.putIfAbsent(g, () => <String>{}).add(s.entry.questionId);
      }
    }
    return {for (final e in perGloss.entries) e.key: e.value.length};
  }();

  bool _distinctive(String gloss) =>
      (_questionFrequency[gloss] ?? 0) <= _distinctiveMaxQuestions;

  /// Glosa que apunta a otra pregunta concreta del banco: aparece en alguna,
  /// pero en pocas. «Pasar» u «ocurrir» no aparecen en ninguna y no apuntan
  /// a nada; «tener» aparece en decenas.
  bool _pointsElsewhere(String gloss) {
    final df = _questionFrequency[gloss] ?? 0;
    return df >= 1 && df <= _distinctiveMaxQuestions;
  }

  List<RequestedQuestion> bySemantics(
    SemanticTurn turn, {
    String? activeContextId,
  }) {
    final glosses = LsbGlossSemantics.normalizeAll(turn.entities);
    final content = LsbGlossSemantics.contentOf(glosses);
    final heads = LsbGlossSemantics.headsOf(glosses);
    final slots = {
      ...turn.requestedSlots,
      ...LsbGlossSemantics.slotsOf(glosses),
    }.intersection(LsbGlossSemantics.slotVocabulary);
    final cues = {
      for (final m in turn.mentionedContexts)
        for (final e in m.evidence) ?LsbGlossSemantics.normalize(e),
    };

    final found = <_Found>[];

    // 1. Por contenido: la pregunta trata de lo mismo y pide el mismo dato.
    for (final sig in _signatures) {
      if (sig.content.isEmpty) continue;
      final shared = content.intersection(sig.content);
      if (shared.isEmpty) continue;
      final full = sig.content.every(content.contains);
      final distinctive = shared.where(_distinctive).toSet();
      if (!full && distinctive.isEmpty) continue;
      if (!_slotsAgree(sig.slots, slots)) continue;
      // Una pregunta de sí/no reconocida solo por la palabra que nombra el
      // contexto («¿Desea presentar una denuncia?» ante «¿Quiere denunciar
      // algo?») no es un dato pedido: es nombrar el contexto.
      if (sig.polar &&
          !full &&
          distinctive.isNotEmpty &&
          distinctive.every(cues.contains)) {
        continue;
      }
      if (sig.polar && full && shared.every(cues.contains)) continue;
      var score = _dice(content, sig.content);
      // Toda la pregunta está en el turno: segura, pero no exacta si el
      // turno dice más cosas (ver paso 3).
      if (full && score < strongMatch) score = strongMatch;
      if (score < weakMatch) continue;
      found.add(_Found(sig, score, sig.slots.intersection(slots), shared));
    }

    // 2. Por ranura: lo pedido que ninguna pregunta de contenido cubre va a
    //    la pregunta que solo pide ese dato («¿Dónde ocurrió?»).
    final covered = {
      for (final f in found)
        if (f.score >= strongMatch) ...f.slots,
    };
    for (final slot in slots.difference(covered)) {
      _Found? best;
      for (final sig in _signatures) {
        if (sig.content.isNotEmpty || !sig.slots.contains(slot)) continue;
        var score = 0.7 + 0.2 * _dice(heads, sig.heads);
        if (sig.entry.fromNode) score += 0.05;
        final q = sig.entry.questionId;
        if (activeContextId != null && catalog.isStepOf(activeContextId, q)) {
          score += 0.03;
        } else if (catalog.journeysOf(q).isNotEmpty) {
          score += 0.02;
        }
        if (best == null || score > best.score) {
          best = _Found(sig, score.clamp(0, 1).toDouble(), {slot}, const {});
        }
      }
      if (best != null) found.add(best);
    }

    // 3. Lo que el turno dice y ninguna pregunta segura explica. Si apunta a
    //    otra pregunta concreta («¿Qué viene a realizar?»: VENIR), las
    //    coincidencias parciales dejan de ser seguras.
    final strong = [
      for (final f in found)
        if (f.score >= strongMatch) f,
    ];
    final explained = {for (final f in strong) ...f.sig.content};
    final unexplained = content.difference(explained).difference(cues);
    if (unexplained.any(_pointsElsewhere)) {
      for (final f in strong) {
        if (f.score < exactMatch) f.score = strongMatch - 0.01;
      }
    }
    // 4. Una pregunta reconocida solo por la palabra del tema («robo» en
    //    «¿Hay testigos del robo?») no es otro dato pedido si otra pregunta
    //    explica lo demás.
    final specific = strong.any((f) => f.shared.difference(cues).isNotEmpty);
    if (specific) {
      found.removeWhere(
        (f) => f.shared.isNotEmpty && f.shared.every(cues.contains),
      );
    }

    return _settle(found, glosses);
  }

  /// Preguntas que comparten algo con la lectura aunque ninguna coincida con
  /// seguridad: las candidatas entre las que el modelo puede elegir.
  List<(String, String)> nearby(SemanticTurn turn, {int limit = 3}) {
    final glosses = LsbGlossSemantics.normalizeAll(turn.entities);
    final content = LsbGlossSemantics.contentOf(glosses);
    final slots = {
      ...turn.requestedSlots,
      ...LsbGlossSemantics.slotsOf(glosses),
    };
    final best = <String, (double, String)>{};
    for (final sig in _signatures) {
      final overlap =
          content.intersection(sig.content).length +
          slots.intersection(sig.slots).length;
      if (overlap == 0) continue;
      final size = sig.content.length + sig.slots.length;
      final score = overlap / (size == 0 ? 1 : size);
      final previous = best[sig.entry.questionId];
      if (previous == null || score > previous.$1) {
        best[sig.entry.questionId] = (score, sig.entry.scope);
      }
    }
    final ordered = best.entries.toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    return [for (final e in ordered.take(limit)) (e.key, e.value.$2)];
  }

  static bool _slotsAgree(Set<String> question, Set<String> turn) =>
      question.isEmpty ? turn.isEmpty : question.intersection(turn).isNotEmpty;

  /// Una por pregunta, sin las que otra más específica ya contiene, en el
  /// orden en que el oyente las hizo.
  List<RequestedQuestion> _settle(List<_Found> found, List<String> glosses) {
    final best = <String, _Found>{};
    for (final f in found) {
      final previous = best[f.sig.entry.questionId];
      if (previous == null || f.score > previous.score) {
        best[f.sig.entry.questionId] = f;
      }
    }
    final kept = [
      for (final f in best.values)
        if (!best.values.any(
          (o) =>
              o != f &&
              o.score >= f.score &&
              f.sig.features.length < o.sig.features.length &&
              o.sig.features.containsAll(f.sig.features),
        ))
          f,
    ];
    int position(_Found f) {
      final at = [
        for (final g in f.sig.glosses)
          if (glosses.contains(g)) glosses.indexOf(g),
      ];
      return at.isEmpty ? glosses.length : at.reduce((a, b) => a < b ? a : b);
    }

    kept.sort((a, b) => position(a).compareTo(position(b)));
    return [
      for (final f in kept)
        RequestedQuestion(
          questionId: f.sig.entry.questionId,
          nodeId: f.sig.entry.id,
          scope: f.sig.entry.scope,
          slots: f.slots.toList(),
          score: f.score,
        ),
    ];
  }

  static double _dice(Set<String> a, Set<String> b) {
    if (a.isEmpty && b.isEmpty) return 0;
    return 2 * a.intersection(b).length / (a.length + b.length);
  }

  // ---- Texto (respaldo sin lectura del backend) -----------------------------

  late final Map<String, Set<String>> _entryTokens = {
    for (final e in catalog.replyEntries)
      e.id: DialogueGraph.tokensOf(e.phrase),
  };

  late final Map<String, int> _tokenFrequency = () {
    final out = <String, int>{};
    for (final tokens in _entryTokens.values) {
      for (final t in tokens) {
        out[t] = (out[t] ?? 0) + 1;
      }
    }
    return out;
  }();

  /// Preguntas del banco formuladas en [text], por parecido con las frases
  /// del grafo. Un mensaje puede traer varias («¿A qué hora y dónde
  /// ocurrió?»): se compara cada cláusula además del mensaje entero.
  List<RequestedQuestion> byText(String text, {String? activeContextId}) {
    final best = <String, RequestedQuestion>{};
    final whole = _bestEntry(text, activeContextId);
    if (whole != null) best[whole.questionId] = whole;
    final explained = whole == null
        ? const <String>{}
        : _entryTokens[whole.nodeId] ?? const <String>{};
    for (final clause in _clauses(text)) {
      final match = _bestEntry(clause, activeContextId);
      if (match == null) continue;
      // Una cláusula que la pregunta del mensaje entero ya contiene no es
      // otra pregunta: «¿Tiene fotos, video…?» es una sola.
      if (whole != null &&
          match.questionId != whole.questionId &&
          DialogueGraph.tokensOf(clause).every(explained.contains)) {
        continue;
      }
      final previous = best[match.questionId];
      if (previous == null || match.score > previous.score) {
        best[match.questionId] = match;
      }
    }
    return best.values.toList()
      ..sort((a, b) => _position(text, a).compareTo(_position(text, b)));
  }

  RequestedQuestion? _bestEntry(String clause, String? activeContextId) {
    final wanted = DialogueGraph.tokensOf(clause);
    if (wanted.isEmpty) return null;
    RequestedQuestion? best;
    for (final entry in catalog.replyEntries) {
      final tokens = _entryTokens[entry.id]!;
      if (tokens.isEmpty) continue;
      final shared = wanted.intersection(tokens);
      if (shared.isEmpty) continue;
      var score = 2 * shared.length / (wanted.length + tokens.length);
      final distinctive = shared.any(
        (t) =>
            !_textInterrogatives.contains(t) &&
            (_tokenFrequency[t] ?? 0) <= _distinctiveMaxQuestions,
      );
      if (score < exactMatch && !distinctive) continue;
      if (activeContextId != null && entry.scope == activeContextId) {
        score += 0.05;
      }
      if (score < weakMatch) continue;
      if (best == null || score > best.score) {
        best = RequestedQuestion(
          questionId: entry.questionId,
          nodeId: entry.id,
          scope: entry.scope,
          slots: LsbGlossSemantics.questionSlotsOf(entry.glosses).toList(),
          score: score.clamp(0, 1).toDouble(),
        );
      }
    }
    return best;
  }

  int _position(String text, RequestedQuestion r) {
    final plain = plainText(text);
    var first = plain.length;
    for (final t in _entryTokens[r.nodeId] ?? const <String>{}) {
      final at = plain.indexOf(t);
      if (at >= 0 && at < first) first = at;
    }
    return first;
  }

  static List<String> _clauses(String text) => [
    for (final sentence in text.split(RegExp(r'[.?!¿¡;:]+')))
      for (final part in sentence.split(RegExp(r',|\s+[ye]\s+')))
        if (part.trim().isNotEmpty) part.trim(),
  ];

  /// Los interrogativos dicen qué tipo de dato se pide, no cuál.
  static const _textInterrogatives = {
    'como',
    'cual',
    'cuales',
    'donde',
    'cuando',
    'quien',
    'quienes',
    'cuanto',
    'cuantos',
    'cuanta',
    'cuantas',
  };

  static String plainText(String input) {
    const from = 'áàäâéèëêíìïîóòöôúùüû';
    const to = 'aaaaeeeeiiiioooouuuu';
    var out = input.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out
        .replaceAll(RegExp(r'[^a-z0-9ñ ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// Lo que dice la formulación LSB de una pregunta.
class _Signature {
  final ReplyEntry entry;
  final List<String> glosses;
  final Set<String> content;
  final Set<String> heads;
  final Set<String> slots;
  final bool polar;

  _Signature(this.entry)
    : glosses = entry.glosses,
      content = LsbGlossSemantics.contentOf(entry.glosses),
      heads = LsbGlossSemantics.headsOf(entry.glosses),
      slots = LsbGlossSemantics.questionSlotsOf(entry.glosses),
      polar = !LsbGlossSemantics.hasInterrogative(entry.glosses);

  late final Set<String> features = {...content, for (final s in slots) '#$s'};
}

class _Found {
  final _Signature sig;
  double score;
  final Set<String> slots;

  /// Glosas de contenido del turno que comparte con la pregunta.
  final Set<String> shared;

  _Found(this.sig, this.score, this.slots, this.shared);
}
