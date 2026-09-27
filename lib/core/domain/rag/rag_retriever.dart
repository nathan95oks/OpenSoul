import 'dart:math' as math;

import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

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
        out.add(_Entry(s, DialogueGraph.tokensOf(t.text), replies, t.n));
      }
      for (final v in s.variants) {
        final replies = [
          for (final r in v.replies)
            if (r.isOfferableReply) r,
        ];
        if (replies.isEmpty) continue;
        for (final q in v.questions) {
          out.add(_Entry(s, DialogueGraph.tokensOf(q), replies, v.turn));
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
  double _score(Set<String> said, _Entry e) {
    final shared = said.intersection(e.tokens);
    if (shared.isEmpty) return 0;
    final sharedWeight = _weightOf(shared);
    final recall = sharedWeight / _weightOf(e.tokens);
    final unknown = said.where((t) => _weight(t) == 0).length;
    final precision =
        sharedWeight / (_weightOf(said) + unknown * _unknownWeight);
    return 2 * precision * recall / (precision + recall);
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
  static List<Set<String>> _sentences(String text) {
    final sentences = [
      // «;» y «:» no separan preguntas: siguen dentro de la misma oración.
      for (final s in text.split(RegExp(r'[.?!¿¡]+')))
        if (DialogueGraph.tokensOf(s).isNotEmpty) DialogueGraph.tokensOf(s),
    ];
    return sentences.isEmpty ? [DialogueGraph.tokensOf(text)] : sentences;
  }

  /// Respuestas documentadas para [hearingText], de la situación más
  /// parecida primero. Vacío si nada se parece lo suficiente.
  ///
  /// Cada oración aporta sus respuestas (hasta [limit] cada una). [preferArea]
  /// es el área del trámite del que ya se viene hablando: gana los empates.
  List<RagSuggestion> suggest(
    String hearingText, {
    int limit = 4,
    String? preferArea,
  }) {
    double ranking((_Entry, double) r) =>
        r.$2 + (r.$1.scenario.area == preferArea ? topicBonus : 0);

    // Por oración: sus coincidencias casi tan buenas como su mejor.
    final groups = <List<(_Entry, double)>>[];
    for (final said in _sentences(hearingText)) {
      if (said.isEmpty) continue;
      final ranked = [
        for (final e in _entries)
          if (_score(said, e) case final score when score >= minScore)
            (e, score),
      ]..sort((a, b) => ranking(b).compareTo(ranking(a)));
      if (ranked.isEmpty) continue;
      if (preferArea != null &&
          !ranked.any((r) => r.$1.scenario.area == preferArea) &&
          !_retrievalSwitchCues.values.any(
            (cues) => said.intersection(cues).isNotEmpty,
          )) {
        continue;
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

class _Entry {
  final RagScenario scenario;
  final Set<String> tokens;
  final List<RagTurn> replies;

  /// Turno del funcionario al que responden [replies].
  final int turn;

  _Entry(this.scenario, this.tokens, this.replies, this.turn);
}

class _TopicEntry {
  final RagScenario scenario;
  final Set<String> tokens;

  _TopicEntry(this.scenario, this.tokens);
}
