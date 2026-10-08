import 'dart:math' as math;

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

  List<RequestedQuestion> match(SemanticTurn turn, {String? activeContextId}) {
    final requested = requestedSlotsOf(turn);
    final contexts = contextsOf(turn, activeContextId: activeContextId);
    if (turn.source != SemanticTurnSource.backend) {
      return byText(
        turn.text,
        activeContextId: activeContextId,
        requestedSlots: requested,
        contexts: contexts,
      );
    }
    final semantic = bySemantics(turn, activeContextId: activeContextId);
    // La lectura del backend puede perder una cláusula al deletrear un
    // concepto («denuncia») o conservar solo una de dos preguntas. Una forma
    // documentada casi literal es evidencia verificable del propio banco.
    final literal = [
      for (final hit in byText(
        turn.text,
        activeContextId: activeContextId,
        contexts: contexts,
      ))
        if (hit.score >= exactMatch) hit,
    ];
    // Una disyuntiva («¿Tiene fotos o videos?») es una sola pregunta: sus
    // partes coinciden literal con «¿Tiene video?», pero no son dos preguntas.
    if (literal.isEmpty || LsbGlossSemantics.isDisjunction(turn.text)) {
      return semantic;
    }
    final clauses = _clauses(turn.text);
    if (clauses.isNotEmpty && literal.length >= clauses.length) return literal;
    final ids = {for (final hit in literal) hit.questionId};
    final covered = {for (final hit in literal) ...hit.slots};
    return [
      ...literal,
      for (final hit in semantic)
        if (!ids.contains(hit.questionId) &&
            (hit.slots.isEmpty ||
                hit.slots.toSet().difference(covered).isNotEmpty))
          hit,
    ]..sort(
      (a, b) => _position(turn.text, a).compareTo(_position(turn.text, b)),
    );
  }

  /// Lo que el oyente quiere saber: las ranuras de la lectura y las que dicen
  /// sus glosas interrogativas. Es lo primero que decide la ruta; el tema
  /// solo restringe o desempata.
  static Set<String> requestedSlotsOf(SemanticTurn turn) {
    final glosses = LsbGlossSemantics.normalizeAll(turn.entities);
    final declared = turn.requestedSlots.toSet().intersection(
      LsbGlossSemantics.slotVocabulary,
    );
    final inferred = {
      if (turn.isQuestion || LsbGlossSemantics.hasInterrogative(glosses))
        ...LsbGlossSemantics.slotsOf(glosses),
    }.intersection(LsbGlossSemantics.slotVocabulary);
    // La lectura semántica ya declaró lo pedido y se conserva: el router no
    // relee el texto (la Lambda ancla sus ranuras al español). Solo se
    // fundamentan las ranuras adicionales inferidas de glosas: un QUIÉN que
    // puso la traducción por «¿Quiere…?» o «¿Alguien…?» no pide una persona.
    return {
      ...declared,
      ...LsbGlossSemantics.groundSlots(inferred, glosses, turn.text),
    };
  }

  /// Contextos donde se sitúa el turno: el activo y los que nombra.
  Set<String> contextsOf(SemanticTurn turn, {String? activeContextId}) => {
    if (activeContextId != null && catalog.hasContext(activeContextId))
      activeContextId,
    for (final m in turn.mentionedContexts)
      if (m.isFamily)
        ...catalog.contextsOfFamily(m.id)
      else if (catalog.hasContext(m.id))
        m.id,
  };

  /// Lo que el turno nombra y el recorrido de su contexto ofrece como
  /// respuesta (CELULAR en «¿Cuándo te robaron el celular?»): el oyente lo da
  /// por supuesto. No es otra pregunta ni un hecho de la persona sorda.
  Set<String> presupposedOf(SemanticTurn turn, {String? activeContextId}) {
    final content = LsbGlossSemantics.contentOf(
      LsbGlossSemantics.normalizeAll(turn.entities),
    );
    return {
      for (final c in contextsOf(turn, activeContextId: activeContextId))
        ...content.intersection(catalog.optionGlossesOf(c)),
    };
  }

  // ---- Significado (lectura del backend) -----------------------------------

  late final List<_Signature> _signatures = [
    for (final e in catalog.replyEntries)
      _Signature(
        e,
        catalog.answerSlotsOf(e.questionId).difference(const {'object'}),
      ),
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
    final slots = requestedSlotsOf(turn);
    final contexts = contextsOf(turn, activeContextId: activeContextId);
    final presupposed = presupposedOf(turn, activeContextId: activeContextId);
    final cues = {
      for (final m in turn.mentionedContexts)
        for (final e in m.evidence) ?LsbGlossSemantics.normalize(e),
    };

    final found = <_Found>[];
    // Dentro del tema de la conversación una seña identifica aunque abunde
    // en el banco: FOTOS está en muchas preguntas, pero en las amenazas solo
    // en «¿Tiene fotos de la pantalla?».
    bool distinctiveHere(String gloss) =>
        _distinctive(gloss) ||
        (activeContextId != null &&
            _journeyGlossFrequency(activeContextId, gloss) <=
                _distinctiveMaxQuestions);

    // 1. Por contenido, solo entre las preguntas que responden lo pedido:
    //    compartir el tema («robar», «celular») no basta si piden otro dato.
    for (final sig in _signatures) {
      if (sig.content.isEmpty) continue;
      final shared = content.intersection(sig.content);
      if (shared.isEmpty) continue;
      final full = sig.content.every(content.contains);
      final distinctive = shared.where(distinctiveHere).toSet();
      if (!full && distinctive.isEmpty) continue;
      final answerSlots = _answerSlotsFor(sig, slots);
      if (!_slotsAgree(answerSlots, slots, polar: sig.polar)) continue;
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
      // turno dice más cosas (ver paso 3). Una sola seña genérica no basta
      // para reconocer una pregunta: ESCRIBIR aparece en decenas.
      if (full &&
          score < strongMatch &&
          (distinctive.isNotEmpty || sig.content.length > 1)) {
        score = strongMatch;
      }
      if (score < weakMatch) continue;
      final answered = answerSlots.isEmpty && sig.polar
          ? slots.intersection(const {'polarity'})
          : answerSlots.intersection(slots);
      found.add(_Found(sig, score, answered, shared));
    }

    // 2. Por ranura: lo pedido que ninguna pregunta de contenido cubre va a
    //    la pregunta que solo pide ese dato («¿Dónde ocurrió?»). Aquí llega
    //    «¿Cuándo te robaron el celular?»: el robo sitúa, no se pregunta.
    final covered = {
      for (final f in found)
        if (f.score >= strongMatch) ...f.slots,
    };
    for (final slot in slots.difference(covered).difference(const {
      'polarity',
    })) {
      final best = _bySlot(slot, heads, contexts, activeContextId);
      if (best != null) found.add(best);
    }

    // 3. Lo que el turno dice y ninguna pregunta segura explica. Si apunta a
    //    otra pregunta concreta («¿Qué viene a realizar?»: VENIR), las
    //    coincidencias parciales dejan de ser seguras. Lo que el oyente da
    //    por supuesto (una respuesta que ofrece el recorrido de su contexto,
    //    como CELULAR o MOCHILA en el robo) no es otra pregunta.
    final strong = [
      for (final f in found)
        if (f.score >= strongMatch) f,
    ];
    final explained = {for (final f in strong) ...f.sig.content};
    final unexplained = content
        .difference(explained)
        .difference(cues)
        .difference(presupposed);
    // Si el oyente pidió un dato, solo cuentan las preguntas que lo
    // responden: EXPLICAR en «¿Puedes describirlos?» no apunta a «¿Me
    // explico?», que no responde a una descripción.
    final asksData = slots.difference(const {'polarity'}).isNotEmpty;
    bool pointsElsewhere(String gloss) {
      if (!asksData) return _pointsElsewhere(gloss);
      final questions = {
        for (final s in _signatures)
          if (s.content.contains(gloss) &&
              _slotsAgree(_answerSlotsFor(s, slots), slots, polar: s.polar))
            s.entry.questionId,
      };
      return questions.isNotEmpty &&
          questions.length <= _distinctiveMaxQuestions;
    }

    if (unexplained.any(pointsElsewhere)) {
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

    _weighText(found, turn.text, slots);
    // 6. El oyente dijo algo que ni el corpus ni la traducción entendieron
    //    («¿Se burlan de usted por ser sorda?»: BURLAR no está en ninguna
    //    pregunta; «maestro» salió deletreado). Una pregunta reconocida por el
    //    resto («¿Usted es sorda?») no responde a eso: no es segura y decide
    //    el desempate o un trámite documentado.
    if (_notUnderstood(
      turn,
      content.difference(cues).difference(presupposed),
    ).isNotEmpty) {
      for (final f in found) {
        if (f.shared.isNotEmpty &&
            f.score >= strongMatch &&
            f.score < exactMatch) {
          f.score = strongMatch - 0.01;
        }
      }
    }
    // 7. Una pregunta abierta («¿Qué vio exactamente?») no se responde con
    //    una de sí/no («¿Vio al ladrón?»).
    if (LsbGlossSemantics.asksOpen(turn.text)) {
      // Sin formulación LSB la pregunta no tiene interrogativo que leer: se
      // mira su español («¿Qué vio o qué quiere declarar?» es abierta).
      found.removeWhere(
        (f) => f.slots.isEmpty && _polarFormulation(f.sig.entry.questionId),
      );
    }
    //    Y una de sí/no («¿Tiene la denuncia de pérdida?») no abre una
    //    abierta reconocida solo por contenido («¿Qué tiene?»): la persona
    //    terminaría diciendo «Tengo fotos.».
    if (LsbGlossSemantics.asksPolar(turn.text)) {
      found.removeWhere(
        (f) =>
            !f.sig.polar &&
            f.slots.isEmpty &&
            f.shared.isNotEmpty &&
            _openFormulation(f),
      );
    }
    _preferJourney(found, activeContextId, turn);
    return _settle(found, glosses);
  }

  /// Si la pregunta del banco es de sí o no, por su formulación en español
  /// («¿Vio al ladrón?»; no «¿Era hombre o mujer?» ni «¿Qué vio?»).
  bool _polarFormulation(String questionId) {
    final f = catalog.bank.question(questionId)?.formulation;
    return f != null && LsbGlossSemantics.asksPolar(f);
  }

  /// Si la pregunta del banco es abierta, por su formulación (no por una
  /// variante: «¿Viene a ver cómo va su denuncia?» es de sí o no aunque
  /// diga «cómo»).
  bool _openFormulation(_Found f) => LsbGlossSemantics.asksOpen(
    catalog.bank.question(f.sig.entry.questionId)?.formulation ??
        f.sig.entry.phrase,
  );

  /// Verbos que casi nunca dicen de qué trata una pregunta («¿Qué pasó?»).
  /// Que el banco no los use no es perder significado.
  static const _genericVerbs = {
    'PASAR',
    'OCURRIR',
    'SUCEDER',
    'HACER',
    'ESTAR',
    'SER',
    'IR',
    'DECIR',
  };

  /// Palabras de contenido del español que nadie entendió: el corpus no las
  /// usa en ninguna pregunta y la traducción tampoco las llevó a una seña
  /// que el banco conozca (salieron deletreadas, o su seña no está en
  /// ninguna pregunta). «Chorearon» no entra: llega como ROBAR.
  Set<String> _notUnderstood(SemanticTurn turn, Set<String> content) {
    final letters = StringBuffer();
    final runs = <String>[];
    for (final g in turn.entities) {
      final plain = LsbGlossSemantics.spokenWord(g);
      if (plain.length == 1) {
        letters.write(plain);
      } else if (letters.isNotEmpty) {
        runs.add(letters.toString());
        letters.clear();
      }
    }
    if (letters.isNotEmpty) runs.add(letters.toString());
    final unknownSign = content.any(
      (g) => (_questionFrequency[g] ?? 0) == 0 && !_genericVerbs.contains(g),
    );
    return {
      for (final word in RegExp(r'[\wáéíóúüñÁÉÍÓÚÜÑ]+').allMatches(turn.text))
        for (final token in DialogueGraph.tokensOf(word.group(0)!))
          if (_textWeight(token) == 0 &&
              (unknownSign ||
                  runs.any(
                    (r) => r.contains(
                      LsbGlossSemantics.spokenWord(word.group(0)!),
                    ),
                  )))
            token,
    };
  }

  /// Preguntas del recorrido activo que llevan [gloss] en su formulación.
  int _journeyGlossFrequency(String contextId, String gloss) => {
    for (final s in _signatures)
      if (s.content.contains(gloss) &&
          catalog.isStepOf(contextId, s.entry.questionId))
        s.entry.questionId,
  }.length;

  /// En una conversación ya situada, si el recorrido activo tiene una
  /// pregunta segura para el turno, lo demás deja de serlo: una pregunta de
  /// otro recorrido o sin recorrido no debe, por contener más palabras,
  /// desplazar a la del tema. Nombrar otro contexto sí cambia de tema.
  void _preferJourney(
    List<_Found> found,
    String? activeContextId,
    SemanticTurn turn,
  ) {
    if (activeContextId == null) return;
    if (turn.mentionedContexts.any(
      (m) => !m.isFamily && m.id != activeContextId,
    )) {
      return;
    }
    bool inJourney(_Found f) =>
        catalog.isStepOf(activeContextId, f.sig.entry.questionId);
    final ours = [
      for (final f in found)
        if (f.score >= strongMatch && inJourney(f)) f,
    ];
    if (ours.isEmpty) return;
    // Solo compite lo que responde al mismo dato: en «¿Te robaron el
    // celular y cuándo fue?» la confirmación y el cuándo son dos preguntas.
    final covered = {for (final f in ours) ...f.slots};
    for (final f in found) {
      if (f.score >= strongMatch &&
          !inJourney(f) &&
          f.slots.difference(covered).isEmpty) {
        f.score = strongMatch - 0.01;
      }
    }
  }

  /// 5. El español del oyente como segunda evidencia. La traducción puede
  ///    deletrear lo que no tiene seña (NÚMERO, MENSAJE, CONSULTAR) y dejar
  ///    sin qué comparar, mientras el texto repite casi literalmente una
  ///    pregunta real del funcionario.
  ///
  ///    * Casi literal: manda el texto. Lo que las glosas leyeron y el texto
  ///      no respalda con seguridad sale.
  ///    * Si no: donde el texto apunta a otras preguntas, una lectura por
  ///      glosas que el texto no respalda en nada deja de ser segura, y las
  ///      preguntas del texto quedan como candidatas para el modelo.
  void _weighText(List<_Found> found, String text, Set<String> slots) {
    final hits = _textEvidence(text, slots);
    if (hits.isEmpty) return;
    double support(_Found f) => hits[f.sig.entry.questionId]?.score ?? 0;
    // Solo se juzgan por el texto las coincidencias por contenido. Las que
    // responden a un dato pedido («¿Quién…?» → quién fue) se eligieron por
    // lo que se pide, no por parecido de palabras.
    bool byContent(_Found f) => f.shared.isNotEmpty;

    void add(String questionId, double score) {
      final hit = hits[questionId]!;
      final existing = found
          .where((f) => f.sig.entry.questionId == questionId)
          .toList();
      if (existing.isNotEmpty) {
        for (final f in existing) {
          if (f.score < score) f.score = score;
        }
        return;
      }
      final sig = hit.signature;
      final answerSlots = _answerSlotsFor(sig, slots);
      final answered = answerSlots.isEmpty && sig.polar
          ? slots.intersection(const {'polarity'})
          : answerSlots.intersection(slots);
      found.add(_Found(sig, score, answered, const {}));
    }

    final literal = [
      for (final e in hits.entries)
        if (e.value.score >= exactMatch) e.key,
    ];
    if (literal.isNotEmpty) {
      found.removeWhere((f) => byContent(f) && support(f) < strongMatch);
      for (final q in literal) {
        add(q, hits[q]!.score);
      }
      return;
    }
    final supported = [
      for (final e in hits.entries)
        if (e.value.score >= weakMatch) e.key,
    ];
    if (supported.isEmpty) return;
    for (final f in found) {
      if (byContent(f) &&
          f.score >= strongMatch &&
          f.score < exactMatch &&
          support(f) == 0) {
        f.score = strongMatch - 0.01;
      }
    }
    for (final q in supported) {
      add(q, math.min(hits[q]!.score, strongMatch - 0.01));
    }
  }

  /// Preguntas distintas en las que aparece cada palabra del corpus.
  late final Map<String, int> _textQuestionFrequency = () {
    final perToken = <String, Set<String>>{};
    for (final e in catalog.replyEntries) {
      for (final t in _entryTokens[e.id]!) {
        perToken.putIfAbsent(t, () => <String>{}).add(e.questionId);
      }
    }
    return {for (final e in perToken.entries) e.key: e.value.length};
  }();

  late final int _textQuestionCount = {
    for (final e in catalog.replyEntries) e.questionId,
  }.length;

  /// Cuánto identifica una palabra: «tiene» o «puede» aparecen en decenas
  /// de preguntas, «mensajes» en pocas. Una palabra que el corpus no usa no
  /// cuenta ni a favor ni en contra.
  double _textWeight(String token) {
    final df = _textQuestionFrequency[token];
    if (df == null) return 0;
    return math.log(1 + _textQuestionCount / df);
  }

  /// Parecido del texto (o de cada una de sus cláusulas) con cada forma real
  /// de hacer cada pregunta del banco, entre las que responden lo pedido:
  /// cuánto de la pregunta está en el texto y cuánto del texto explica,
  /// pesando cada palabra por lo que identifica.
  /// Puntuación del texto por pregunta (ver [_textEvidence]).
  Map<String, double> textScores(
    String text, {
    Set<String> slots = const {},
  }) => {
    for (final e in _textEvidence(text, slots).entries) e.key: e.value.score,
  };

  Map<String, ({_Signature signature, double score})> _textEvidence(
    String text,
    Set<String> slots,
  ) {
    final best = <String, ({_Signature signature, double score})>{};
    double weightOf(Iterable<String> tokens) =>
        tokens.fold(0.0, (sum, t) => sum + _textWeight(t));
    for (final span in {text, ..._clauses(text)}) {
      final known = {
        for (final t in DialogueGraph.tokensOf(span))
          if (_textWeight(t) > 0) t,
      };
      if (known.isEmpty) continue;
      final knownWeight = weightOf(known);
      for (final sig in _signatures) {
        final answerSlots = _answerSlotsFor(sig, slots);
        if (slots.isNotEmpty &&
            !_slotsAgree(answerSlots, slots, polar: sig.polar)) {
          continue;
        }
        final tokens = _entryTokens[sig.entry.id]!;
        final shared = known.intersection(tokens);
        if (shared.isEmpty) continue;
        final sharedWeight = weightOf(shared);
        final recall = sharedWeight / weightOf(tokens);
        final precision = sharedWeight / knownWeight;
        final score = 2 * precision * recall / (precision + recall);
        final previous = best[sig.entry.questionId];
        if (previous == null || score > previous.score) {
          best[sig.entry.questionId] = (signature: sig, score: score);
        }
      }
    }
    return best;
  }

  /// La pregunta que pide solo [slot], por etapas: primero la misma forma
  /// del dato («¿a qué hora?» es HORA, no FECHA); después, dentro del
  /// contexto de la conversación si alguna lo es; y por último el desempate
  /// de siempre (frase real del corpus, paso de algún recorrido).
  _Found? _bySlot(
    String slot,
    Set<String> heads,
    Set<String> contexts,
    String? activeContextId,
  ) {
    var candidates = [
      for (final sig in _signatures)
        if (sig.content.isEmpty && sig.slots.contains(slot)) sig,
    ];
    final directInContext = [
      for (final sig in candidates)
        if (contexts.any(
          (context) => catalog.isStepOf(context, sig.entry.questionId),
        ))
          sig,
    ];
    if (directInContext.isNotEmpty) {
      candidates = directInContext;
    } else if (contexts.isNotEmpty) {
      // Si el banco no tiene una pregunta QU directa para el dato dentro del
      // contexto, usa una pregunta-puerta del mismo recorrido. Solo se
      // habilita con contexto explícito o activo: un "quién" aislado no basta
      // para adivinar de qué persona se habla.
      final bridge = [
        for (final sig in _signatures)
          if (sig.slots.contains(slot) &&
              contexts.any(
                (context) => catalog.isStepOf(context, sig.entry.questionId),
              ))
            sig,
      ];
      if (bridge.isNotEmpty) candidates = bridge;
    }
    if (candidates.isEmpty) return null;
    final form = candidates
        .map((s) => _dice(heads, s.heads))
        .reduce((a, b) => a > b ? a : b);
    candidates = [
      for (final s in candidates)
        if (_dice(heads, s.heads) == form) s,
    ];
    _Found? best;
    for (final sig in candidates) {
      var score = 0.7 + 0.2 * form;
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
    return best;
  }

  /// Preguntas que comparten algo con la lectura aunque ninguna coincida con
  /// seguridad: las candidatas entre las que el modelo puede elegir. Si el
  /// oyente pidió un dato, solo las que lo responden.
  List<(String, String)> nearby(SemanticTurn turn, {int limit = 3}) {
    final glosses = LsbGlossSemantics.normalizeAll(turn.entities);
    final content = LsbGlossSemantics.contentOf(glosses);
    final slots = requestedSlotsOf(turn);
    final asksData = slots.difference(const {'polarity'}).isNotEmpty;
    final best = <String, (double, String)>{};
    for (final sig in _signatures) {
      if (asksData && !_slotsAgree(sig.slots, slots, polar: sig.polar)) {
        continue;
      }
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

  /// Si una pregunta con ranuras [question] responde a lo que pide el turno.
  /// Una sin ranura solo vale si el turno no pide ningún dato, o si pide
  /// además un sí/no (`polarity`) y ella es de sí/no.
  static bool _slotsAgree(
    Set<String> question,
    Set<String> turn, {
    required bool polar,
  }) {
    final data = turn.difference(const {'polarity'});
    // Una pregunta de sí/no con ranura es una puerta («¿Conoce a la
    // persona?» abre quién fue): responde también cuando el oyente la hace
    // tal cual, sin pedir el dato.
    if (question.isNotEmpty) {
      return question.intersection(data).isNotEmpty || (polar && data.isEmpty);
    }
    return data.isEmpty || (polar && turn.contains('polarity'));
  }

  Set<String> _answerSlotsFor(_Signature signature, Set<String> requested) => {
    ...signature.slots,
    if (requested.contains('object'))
      ...LsbGlossSemantics.spokenSlotsOf(
        signature.entry.phrase,
      ).where((slot) => slot == 'object'),
  };

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
              f.features.length < o.features.length &&
              o.features.containsAll(f.features),
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
  ///
  /// Con [requestedSlots] solo cuentan las frases cuya pregunta responde lo
  /// pedido: «¿Cuándo te robaron el celular?» se parece mucho a «¿Le robaron
  /// el celular?», pero pide una fecha. Lo pedido que ninguna frase cubre va
  /// a la pregunta que solo pide ese dato, preferentemente en [contexts].
  /// Lo que pide [text] sin lectura del backend. Como con ella, una pregunta
  /// abierta («¿Qué viene a realizar?») no se responde con una de sí/no.
  List<RequestedQuestion> byText(
    String text, {
    String? activeContextId,
    Set<String> requestedSlots = const {},
    Set<String> contexts = const {},
  }) {
    final found = _byText(
      text,
      activeContextId: activeContextId,
      requestedSlots: requestedSlots,
      contexts: contexts,
    );
    if (LsbGlossSemantics.asksOpen(text)) {
      return [
        for (final r in found)
          if (r.slots.isNotEmpty || !_polarFormulation(r.questionId)) r,
      ];
    }
    if (LsbGlossSemantics.asksPolar(text)) {
      return [
        for (final r in found)
          if (!LsbGlossSemantics.asksOpen(
            catalog.bank.question(r.questionId)?.formulation ?? '',
          ))
            r,
      ];
    }
    return found;
  }

  List<RequestedQuestion> _byText(
    String text, {
    String? activeContextId,
    Iterable<String> requestedSlots = const [],
    Set<String> contexts = const {},
  }) {
    final requested = requestedSlots.toSet();
    final best = <String, RequestedQuestion>{};
    final whole = _bestEntry(text, activeContextId, requested);
    if (whole != null) best[whole.questionId] = whole;
    final explained = whole == null
        ? const <String>{}
        : _entryTokens[whole.nodeId] ?? const <String>{};
    for (final clause in _clauses(text)) {
      final match = _bestEntry(clause, activeContextId, requested);
      if (match == null) continue;
      // Una cláusula que la pregunta del mensaje entero ya contiene no es
      // otra pregunta: «¿Tiene fotos, video…?» es una sola.
      if (whole != null &&
          match.questionId != whole.questionId &&
          DialogueGraph.tokensOf(clause).every(explained.contains) &&
          match.slots.toSet().difference(whole.slots.toSet()).isEmpty) {
        continue;
      }
      final previous = best[match.questionId];
      if (previous == null || match.score > previous.score) {
        best[match.questionId] = match;
      }
    }
    final covered = {
      for (final r in best.values)
        if (r.score >= strongMatch) ...r.slots,
    };
    final bySlot = <String, RequestedQuestion>{};
    for (final slot in requested.difference(covered).difference(const {
      'polarity',
    })) {
      final f = _bySlot(slot, const {}, contexts, activeContextId);
      if (f == null || best.containsKey(f.sig.entry.questionId)) continue;
      bySlot[f.sig.entry.questionId] = RequestedQuestion(
        questionId: f.sig.entry.questionId,
        nodeId: f.sig.entry.id,
        scope: f.sig.entry.scope,
        slots: f.slots.toList(),
        score: f.score,
      );
    }
    return [...best.values, ...bySlot.values]
      ..sort((a, b) => _position(text, a).compareTo(_position(text, b)));
  }

  RequestedQuestion? _bestEntry(
    String clause,
    String? activeContextId,
    Set<String> requested,
  ) {
    final wanted = DialogueGraph.tokensOf(clause);
    if (wanted.isEmpty) return null;
    final asksOpen = LsbGlossSemantics.asksOpen(clause);
    final asksPolar = LsbGlossSemantics.asksPolar(clause);
    RequestedQuestion? best;
    for (final entry in catalog.replyEntries) {
      if (asksOpen && _polarFormulation(entry.questionId)) continue;
      if (asksPolar &&
          LsbGlossSemantics.asksOpen(
            catalog.bank.question(entry.questionId)?.formulation ?? '',
          )) {
        continue;
      }
      final tokens = _entryTokens[entry.id]!;
      if (tokens.isEmpty) continue;
      final answerSlots = {
        ...catalog.answerSlotsOf(entry.questionId),
        ...LsbGlossSemantics.spokenSlotsOf(entry.phrase),
      };
      if (requested.isNotEmpty &&
          !_slotsAgree(
            answerSlots,
            requested,
            polar:
                entry.glosses.isNotEmpty &&
                !LsbGlossSemantics.hasInterrogative(entry.glosses),
          )) {
        continue;
      }
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
          slots: requested.isEmpty
              ? answerSlots.toList()
              : answerSlots.intersection(requested).toList(),
          score: score.clamp(0, 1).toDouble(),
        );
      }
    }
    return best;
  }

  int _position(String text, RequestedQuestion r) {
    final plain = plainText(text);
    for (final match in RegExp(r'[a-z0-9ñ]+').allMatches(plain)) {
      final key = match.group(0)!.toUpperCase();
      final slot =
          LsbGlossSemantics.spokenInterrogativeSlots[key] ??
          LsbGlossSemantics.spokenHeadSlots[key];
      if (slot != null && r.slots.contains(slot)) return match.start;
    }
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

  _Signature(this.entry, this.slots)
    : glosses = entry.glosses,
      content = LsbGlossSemantics.contentOf(entry.glosses),
      heads = LsbGlossSemantics.headsOf(entry.glosses),
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

  /// Lo que la pregunta tiene en común con lo pedido: su contenido y las
  /// ranuras que responde de verdad. Una puerta de sí/no reconocida sin que
  /// se pidiera su dato («¿Conoce…?») no cuenta esa ranura, así que otra
  /// pregunta que la contiene («¿Conoce el número…?») la sustituye.
  late final Set<String> features = {
    ...sig.content,
    for (final s in slots) '#$s',
  };
}
