import 'dart:math' as math;

import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/core/domain/text/spanish_text.dart';

/// Una respuesta documentada que la persona sorda puede enviar.
class RagSuggestion {
  final String text;
  final List<String> glosses;
  final String scenarioId;
  final String institution;
  final String procedure;
  final double score;

  /// Turno del funcionario documentado que se encontró (`null` si la
  /// sugerencia llegó por significado desde la Lambda). Es el paso del
  /// trámite que abre el módulo de tarjetas.
  final int? questionTurn;

  const RagSuggestion({
    required this.text,
    required this.glosses,
    required this.scenarioId,
    required this.institution,
    required this.procedure,
    required this.score,
    this.questionTurn,
  });
}

/// Resultado explicable del clasificador local de institución.
class RagAreaScore {
  final String area;
  final double score;

  const RagAreaScore(this.area, this.score);
}

/// Busca en el corpus RAG lo que el funcionario acaba de decir y devuelve las
/// respuestas que dio la persona sorda en esas mismas situaciones.
///
/// Es la tercera capa de Conversation: solo se consulta cuando el grafo no
/// reconoce el turno (`noSafeRoute`). Es extractiva: las respuestas salen tal
/// cual del corpus revisado, nunca se redactan. Sin un parecido suficiente no
/// devuelve nada, igual que el router no inventa una ruta.
///
/// El parecido es el del texto del oyente con cada pregunta documentada
/// (turnos del funcionario y sus variantes), pesando cada palabra por lo que
/// identifica: «placa» o «matrícula» aparecen en pocos escenarios, «tiene»
/// en muchos.
class RagRetriever {
  final RagCorpus corpus;

  /// Parecido mínimo con una pregunta documentada para ofrecer sus
  /// respuestas.
  static const double minScore = 0.45;

  /// Solo se suman escenarios casi tan parecidos como el mejor: mezclar un
  /// trámite distinto confundiría más que ayudaría.
  static const double margin = 0.1;

  /// Ventaja del trámite del que ya se viene hablando. Decide empates
  /// («¿Trajo su cédula?» vale en muchos trámites) sin imponerse a una
  /// coincidencia claramente mejor de otro.
  static const double topicBonus = 0.05;

  /// Ventaja adicional del recorrido exacto que está abierto. Dos trámites
  /// de una misma institución pueden preguntar por «una foto» o «un
  /// documento»; la continuidad del diálogo es evidencia más precisa que el
  /// área FELCC/FELCV completa.
  static const double scenarioBonus = 0.12;

  /// Vocabulario institucional inequívoco. Complementa las frases del
  /// corpus cuando el escenario describe una derivación desde otra oficina
  /// (por ejemplo, una persona cuenta violencia en FELCC pero corresponde
  /// FELCV).
  static const Map<String, Set<String>> _areaCues = {
    'SEPDEP': {'denunciado', 'denunciaron', 'acusado'},
    'SEPDAVI': {'victima', 'patrocinio'},
    'FELCC': {'robo', 'robaron', 'estafa', 'celular'},
    'FELCV': {'violencia', 'pareja', 'amenaza', 'amenazan', 'golpea'},
    'SEGIP': {'cedula', 'segip'},
    'SERECI': {'sereci', 'nacimiento', 'matrimonio', 'defuncion'},
    'FIS': {'fiscalia', 'roma', 'fiscal'},
    'OJ': {'nurej', 'webid', 'juzgado', 'tribunal'},
  };

  static const Map<String, Set<String>> _retrievalSwitchCues = {
    'SEPDEP': {'sepdep'},
    'SEPDAVI': {'sepdavi'},
    'FELCC': {'felcc'},
    'FELCV': {'felcv'},
    'SEGIP': {'segip'},
    'SERECI': {'sereci'},
    'FIS': {'fiscalia', 'roma'},
    'OJ': {'nurej', 'webid', 'juzgado', 'tribunal'},
  };

  late final List<_Entry> _entries = _index();
  late final List<_TopicEntry> _topicEntries = _topicIndex();
  late final Map<String, int> _scenarioFrequency = () {
    final perToken = <String, Set<String>>{};
    for (final e in _entries) {
      for (final t in e.tokens) {
        perToken.putIfAbsent(t, () => <String>{}).add(e.scenario.id);
      }
    }
    return {for (final e in perToken.entries) e.key: e.value.length};
  }();
  late final Map<String, int> _topicFrequency = () {
    final perToken = <String, Set<String>>{};
    for (final e in _topicEntries) {
      for (final t in e.tokens) {
        perToken.putIfAbsent(t, () => <String>{}).add(e.scenario.area);
      }
    }
    return {for (final e in perToken.entries) e.key: e.value.length};
  }();

  RagRetriever(this.corpus);

  List<_Entry> _index() {
    final out = <_Entry>[];
    for (final s in corpus.scenarios) {
      // Lo que respondió la persona sorda justo después de ese turno.
      List<RagTurn> repliesAfter(int n) {
        final next = s.turn(n + 1);
        return [
          if (next != null && next.isOfferableReply) next,
          for (final v in s.variants)
            if (v.turn == n)
              for (final r in v.replies)
                if (r.isOfferableReply) r,
        ];
      }

      for (final t in s.turns) {
        // Lo no mostrable (habla de la fuente, dato sin verificar o vencido)
        // tampoco es algo que diga un funcionario: como clave atrae ruido.
        if (t.speaker != RagSpeaker.official || !t.showable) continue;
        final replies = repliesAfter(t.n);
        if (replies.isEmpty) continue;
        out.add(_Entry.of(s, t.text, replies, t.n));
      }
      for (final v in s.variants) {
        final replies = [
          for (final r in v.replies)
            if (r.isOfferableReply) r,
        ];
        if (replies.isEmpty) continue;
        for (final q in v.questions) {
          out.add(_Entry.of(s, q, replies, v.turn));
        }
      }
    }
    return out;
  }

  List<_TopicEntry> _topicIndex() {
    final out = <_TopicEntry>[];
    final topics = corpus.deafTopics;
    for (final s in corpus.scenarios) {
      final topic = topics.where((t) => t.area == s.area);
      for (final area in topic) {
        for (final procedure in area.procedures.where(
          (p) => p.scenarioId == s.id,
        )) {
          for (final phrase in procedure.phrases) {
            out.add(_TopicEntry(s, DialogueGraph.tokensOf(phrase.text)));
          }
        }
      }
      out.add(
        _TopicEntry(
          s,
          DialogueGraph.tokensOf('${s.institution} ${s.procedure} ${s.title}'),
        ),
      );
    }
    return out;
  }

  double _weight(String token) {
    final df = _scenarioFrequency[token];
    if (df == null) return 0;
    return math.log(1 + corpus.scenarios.length / df);
  }

  double _weightOf(Iterable<String> tokens) =>
      tokens.fold(0.0, (sum, t) => sum + _weight(t));

  /// Parecido entre lo dicho y una pregunta documentada: cuánto de la
  /// pregunta está en lo dicho y cuánto de lo dicho explica. Una palabra que
  /// el corpus no conoce cuenta en contra (la mitad de la más específica):
  /// «¿Tiene mascota?» habla de algo que ningún trámite cubre, no es «¿La
  /// tiene?». Entera también descartaría paráfrasis con una palabra nueva
  /// («¿Me dice la placa de su moto?»).
  double _score(
    Set<String> said,
    _Entry e, [
    Map<String, String> saidComplements = const {},
  ]) {
    final shared = said.intersection(e.tokens);
    if (shared.isEmpty) return 0;
    // Si el oyente no dijo toda una pregunta de sí o no, sus respuestas no
    // pueden hablar de lo que le falta: «¿El inmueble tiene hipoteca?» no
    // es «¿Tiene la matrícula del inmueble de la hipoteca?», que se responde
    // «Sí, conozco la matrícula…». (Las respuestas a una pregunta abierta sí
    // aportan contenido propio: «¿Qué número de juzgado aparece?» → «No
    // aparece.»)
    final missing = e.tokens.difference(said).difference(_generic);
    if (e.kind == _Kind.polar && missing.any(e.replyTokens.contains)) {
      return 0;
    }
    // La misma palabra con otro complemento es otra cosa: «licencia de
    // conducir» no es «licencia de funcionamiento», ni «certificado de
    // nacimiento» es «certificado de matrimonio».
    if (_otroComplemento(saidComplements, e.complements)) return 0;
    final sharedWeight = _weightOf(shared);
    final recall = sharedWeight / _weightOf(e.tokens);
    final unknown = said.where((t) => _weight(t) == 0).length;
    final precision =
        sharedWeight / (_weightOf(said) + unknown * _unknownWeight);
    return 2 * precision * recall / (precision + recall);
  }

  static final RegExp _complemento = RegExp(
    r'([a-zñ]+)\s+del?\s+(?:(?:la|el|los|las|su|sus|mi|mis|un|una)\s+)?([a-zñ]+)',
  );

  /// «palabra de complemento» de una frase, por raíz: {licenci: conduc}.
  static Map<String, String> complementsOf(String text) {
    final out = <String, String>{};
    final limpio = _sinTildes(text.toLowerCase());
    for (final m in _complemento.allMatches(limpio)) {
      final nucleo = DialogueGraph.tokensOf(m.group(1)!);
      final comp = DialogueGraph.tokensOf(m.group(2)!);
      if (nucleo.length == 1 && comp.length == 1) {
        out[nucleo.single] = comp.single;
      }
    }
    return out;
  }

  static String _sinTildes(String s) => SpanishText.stripAccents(s);

  static bool _otroComplemento(Map<String, String> a, Map<String, String> b) {
    for (final MapEntry(key: nucleo, value: comp) in a.entries) {
      final otro = b[nucleo];
      if (otro != null && otro != comp) return true;
    }
    return false;
  }

  late final double _unknownWeight =
      0.5 * math.log(1 + corpus.scenarios.length);

  double _topicWeight(String token) {
    final df = _topicFrequency[token];
    if (df == null) return 0;
    return math.log(1 + corpus.deafTopics.length / df);
  }

  double _topicScore(Set<String> said, _TopicEntry e) {
    final known = {
      for (final t in said)
        if (_topicWeight(t) > 0) t,
    };
    final shared = known.intersection(e.tokens);
    if (shared.isEmpty) return 0;
    double weightOf(Iterable<String> tokens) =>
        tokens.fold(0.0, (sum, t) => sum + _topicWeight(t));
    final sharedWeight = weightOf(shared);
    final recall = sharedWeight / weightOf(e.tokens);
    final precision = sharedWeight / weightOf(known);
    return 2 * precision * recall / (precision + recall);
  }

  /// Las oraciones de lo dicho: un saludo antes de la pregunta («Buenos
  /// días, bienvenido. ¿Trae su matrícula?») no la diluye, y dos preguntas
  /// en un mensaje se buscan cada una.
  static List<_Said> _sentences(String text) {
    final sentences = [
      // «;» y «:» no separan preguntas: siguen dentro de la misma oración.
      for (final m in RegExp(r'[^.?!]+[.?!]*').allMatches(text))
        if (DialogueGraph.tokensOf(m.group(0)!).isNotEmpty)
          _Said.of(m.group(0)!),
    ];
    return sentences.isEmpty ? [_Said.of(text)] : sentences;
  }

  static final RegExp _openQuestion = RegExp(
    r'^[\s¿¡]*(?:(?:a|de|en|con|para|por|desde|hasta)\s+)?'
    r'(?:qu[eé]|cu[aá]l(?:es)?|cu[aá]nt[oa]s?|d[oó]nde|ad[oó]nde|'
    r'cu[aá]ndo|c[oó]mo|qui[eé]n(?:es)?)(?=$|[^a-záéíóúüñ])',
    caseSensitive: false,
  );

  /// Tipo de una oración: no es pregunta, pregunta abierta («¿Qué trámite
  /// viene a registrar?») o de sí o no («¿Su trámite fue observado?»). Sus
  /// respuestas no se intercambian.
  static _Kind _kindOf(String sentence) {
    final t = sentence.trim();
    if (!t.contains('?') && !t.startsWith('¿')) return _Kind.statement;
    return _openQuestion.hasMatch(t) ? _Kind.open : _Kind.polar;
  }

  static final RegExp _negation = RegExp(
    r'(^|[^a-záéíóúüñ])(no|nunca|tampoco|ningun|ninguna|ninguno|ningún|nada)'
    r'(?=$|[^a-záéíóúüñ])',
    caseSensitive: false,
  );

  /// Si la oración niega («¿No trajo su cédula?»). Las palabras cortas no
  /// cuentan al comparar, así que la negación se mira aparte: a una pregunta
  /// negativa no se le ofrecen las respuestas de la afirmativa, donde «Sí.»
  /// significaría otra cosa.
  static bool isNegated(String text) => _negation.hasMatch(text);

  /// Respuestas documentadas para [hearingText], de la situación más
  /// parecida primero. Vacío si nada se parece lo suficiente.
  ///
  /// Cada oración aporta sus respuestas (hasta [limit] cada una). [preferArea]
  /// es el área del trámite del que ya se viene hablando: gana los empates.
  List<RagSuggestion> suggest(
    String hearingText, {
    int limit = 4,
    String? preferArea,
    String? preferScenarioId,
  }) {
    double ranking((_Entry, double) r) =>
        r.$2 +
        (r.$1.scenario.area == preferArea ? topicBonus : 0) +
        (r.$1.scenario.id == preferScenarioId ? scenarioBonus : 0);

    // Por oración: sus coincidencias casi tan buenas como su mejor.
    final groups = <List<(_Entry, double)>>[];
    for (final sentence in _sentences(hearingText)) {
      final said = sentence.tokens;
      if (said.isEmpty) continue;
      var ranked = [
        for (final e in _entries)
          if (e.negated == sentence.negated && sentence.compatibleWith(e.kind))
            if (_score(said, e, sentence.complements) case final score
                when score >= minScore)
              (e, score),
      ]..sort((a, b) => ranking(b).compareTo(ranking(a)));
      if (ranked.isEmpty) continue;
      // El oyente nombra otra institución («¿Ya fue a la FELCC?»).
      final otherNamed = _retrievalSwitchCues.entries.any(
        (cues) =>
            cues.key != preferArea && said.intersection(cues.value).isNotEmpty,
      );
      if (preferArea != null && !otherNamed) {
        // Se sigue en la institución de la que se viene hablando: una
        // pregunta que vale en muchos trámites («¿Trajo su cédula?») no
        // cambia de institución por una coincidencia algo mejor en otra.
        final same = [
          for (final r in ranked)
            if (r.$1.scenario.area == preferArea) r,
        ];
        if (same.isEmpty) continue;
        // Si otra institución encaja claramente mejor («¿Su cédula ya
        // venció?» es de SEGIP, no el «¿Tiene su cédula?» de Derechos
        // Reales), la pregunta no es de este trámite: ni se cambia de
        // institución ni se responde otra cosa.
        if (ranked.first.$2 - same.first.$2 > margin) continue;
        ranked = same;
      } else if (preferArea == null &&
          (!_identifies(said, ranked) || !_sharesContent(said, ranked.first))) {
        // Sin tema previo, una pregunta que vale en varias instituciones
        // («¿Trajo su cédula?», «¿Tiene algún documento?») no elige una.
        continue;
      }
      if (preferScenarioId != null && !otherNamed) {
        final sameScenario = [
          for (final r in ranked)
            if (r.$1.scenario.id == preferScenarioId) r,
        ];
        // Una coincidencia razonable en el trámite activo conserva el hilo.
        // Si otro trámite es claramente mejor, no se fuerza la continuidad.
        if (sameScenario.isNotEmpty &&
            ranked.first.$2 - sameScenario.first.$2 <= 2 * margin) {
          ranked = sameScenario;
        }
      }
      final best = ranking(ranked.first);
      final winningArea = ranked.first.$1.scenario.area;
      groups.add([
        for (final r in ranked)
          if (r.$1.scenario.area == winningArea && ranking(r) >= best - margin)
            r,
      ]);
    }
    groups.sort((a, b) => ranking(b.first).compareTo(ranking(a.first)));

    final out = <RagSuggestion>[];
    for (final group in groups) {
      var added = 0;
      for (final (entry, score) in group) {
        for (final reply in entry.replies) {
          if (added >= limit) break;
          if (out.any((s) => s.text == reply.text)) continue;
          out.add(
            RagSuggestion(
              text: reply.text,
              glosses: reply.glosses,
              scenarioId: entry.scenario.id,
              institution: entry.scenario.institution,
              procedure: entry.scenario.procedure,
              score: score,
              questionTurn: entry.turn,
            ),
          );
          added++;
        }
      }
    }
    return out;
  }

  /// Áreas en cuyas preguntas aparece cada palabra.
  late final Map<String, Set<String>> _areasOfToken = () {
    final out = <String, Set<String>>{};
    for (final e in _entries) {
      for (final t in e.tokens) {
        out.putIfAbsent(t, () => <String>{}).add(e.scenario.area);
      }
    }
    return out;
  }();

  /// Palabras que no identifican un trámite aunque hoy solo una institución
  /// las use: cuantificadores, demostrativos y verbos de cualquier
  /// ventanilla.
  static final Set<String> _generic = DialogueGraph.tokensOf(
    'algún alguna alguno algo otro otra este esta ese esa usted ahora '
    'actualmente puede quiere necesita tiene trajo trae '
    'uno dos tres cuatro cinco',
  );

  /// Lo que se pide en cualquier ventanilla. No cambia el parecido; solo
  /// impide que una pregunta hecha de estas palabras identifique una
  /// institución por estar escrita tal cual en una sola.
  static final Set<String> _anyCounter = DialogueGraph.tokensOf(
    'cédula carnet identidad documento testigo testigos',
  );

  /// Si lo dicho comparte con la mejor coincidencia algo más que palabras de
  /// cualquier ventanilla. «¿Tiene algún documento?» o «Pase a la ventanilla
  /// tres» no comparten contenido con «¿Tiene los tres documentos
  /// publicados?»: sin tema previo, eso no elige una institución.
  bool _sharesContent(Set<String> said, (_Entry, double) best) => said
      .intersection(best.$1.tokens)
      .any((t) => !_generic.contains(t) && !_anyCounter.contains(t));

  /// Si lo dicho identifica la institución de la mejor coincidencia: solo
  /// esa institución tiene preguntas parecidas, o es exactamente una
  /// pregunta documentada solo en ella, o comparte con ella una palabra que
  /// solo esa institución usa.
  bool _identifies(Set<String> said, List<(_Entry, double)> ranked) {
    final best = ranked.first.$1;
    final area = best.scenario.area;
    if (ranked.every((r) => r.$1.scenario.area == area)) return true;
    final exact = [
      for (final r in ranked)
        if (said.containsAll(r.$1.tokens) && r.$1.tokens.containsAll(said))
          r.$1.scenario.area,
    ];
    // Documentada tal cual en una sola institución, salvo que solo tenga
    // palabras de cualquier ventanilla: «¿Trajo su cédula de identidad?»
    // está literal en Derechos Reales, pero vale igual en SEPDAVI o SEGIP.
    if (exact.isNotEmpty) {
      return exact.every((a) => a == area) &&
          said.any((t) => !_generic.contains(t) && !_anyCounter.contains(t));
    }
    return said
        .intersection(best.tokens)
        .any(
          (t) =>
              !_generic.contains(t) &&
              (_areasOfToken[t] ?? const <String>{}).length == 1,
        );
  }

  /// Instituciones ordenadas por parecido con lo que dijo la persona sorda.
  List<RagAreaScore> rankAreas(
    String text, {
    int limit = 5,
    String? preferArea,
  }) {
    final said = DialogueGraph.tokensOf(text);
    final best = <String, double>{};
    for (final entry in _topicEntries) {
      final score = _topicScore(said, entry);
      if (score <= (best[entry.scenario.area] ?? 0)) continue;
      best[entry.scenario.area] = score;
    }
    for (final cues in _areaCues.entries) {
      final matches = said.intersection(cues.value).length;
      if (matches == 0) continue;
      best[cues.key] = (best[cues.key] ?? 0) + 0.6 * matches;
    }
    if (preferArea != null) {
      best[preferArea] = (best[preferArea] ?? minScore) + topicBonus;
    }
    final ranked = [
      for (final e in best.entries)
        if (e.value >= minScore) RagAreaScore(e.key, e.value),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return ranked.take(limit).toList();
  }

  /// Área del trámite al que más se parece [text], o `null`.
  String? areaOf(String text, {String? preferArea}) {
    final found = rankAreas(text, limit: 1, preferArea: preferArea);
    return found.isEmpty ? preferArea : found.first.area;
  }
}

enum _Kind { statement, open, polar }

/// Una oración del oyente.
class _Said {
  final Set<String> tokens;
  final bool negated;
  final _Kind kind;
  final Map<String, String> complements;

  const _Said(this.tokens, this.negated, this.kind, this.complements);

  factory _Said.of(String text) => _Said(
    DialogueGraph.tokensOf(text),
    RagRetriever.isNegated(text),
    RagRetriever._kindOf(text),
    RagRetriever.complementsOf(text),
  );

  /// Una pregunta abierta no se responde con lo de una de sí o no, ni al
  /// revés. Lo que no es pregunta se compara con todo.
  bool compatibleWith(_Kind other) =>
      kind == _Kind.statement || other == _Kind.statement || kind == other;
}

class _Entry {
  final RagScenario scenario;
  final Set<String> tokens;
  final List<RagTurn> replies;

  /// Turno del funcionario al que responden [replies].
  final int turn;

  /// Si la pregunta documentada niega.
  final bool negated;

  /// Palabras de las respuestas documentadas.
  final Set<String> replyTokens;

  final _Kind kind;

  /// «palabra de complemento» de la pregunta documentada.
  final Map<String, String> complements;

  _Entry(
    this.scenario,
    this.tokens,
    this.replies,
    this.turn, {
    this.negated = false,
    this.replyTokens = const {},
    this.kind = _Kind.statement,
    this.complements = const {},
  });

  factory _Entry.of(
    RagScenario scenario,
    String question,
    List<RagTurn> replies,
    int turn,
  ) => _Entry(
    scenario,
    DialogueGraph.tokensOf(question),
    replies,
    turn,
    negated: RagRetriever.isNegated(question),
    replyTokens: {for (final r in replies) ...DialogueGraph.tokensOf(r.text)},
    kind: RagRetriever._kindOf(question),
    complements: RagRetriever.complementsOf(question),
  );
}

class _TopicEntry {
  final RagScenario scenario;
  final Set<String> tokens;

  _TopicEntry(this.scenario, this.tokens);
}
