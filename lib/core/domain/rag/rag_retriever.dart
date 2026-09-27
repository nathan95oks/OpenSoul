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

  const RagSuggestion({
    required this.text,
    required this.glosses,
    required this.scenarioId,
    required this.institution,
    required this.procedure,
    required this.score,
  });
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

  late final List<_Entry> _entries = _index();
  late final Map<String, int> _scenarioFrequency = () {
    final perToken = <String, Set<String>>{};
    for (final e in _entries) {
      for (final t in e.tokens) {
        perToken.putIfAbsent(t, () => <String>{}).add(e.scenario.id);
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
        if (t.speaker != RagSpeaker.official) continue;
        final replies = repliesAfter(t.n);
        if (replies.isEmpty) continue;
        out.add(_Entry(s, DialogueGraph.tokensOf(t.text), replies));
      }
      for (final v in s.variants) {
        final replies = [
          for (final r in v.replies)
            if (r.isOfferableReply) r,
        ];
        if (replies.isEmpty) continue;
        for (final q in v.questions) {
          out.add(_Entry(s, DialogueGraph.tokensOf(q), replies));
        }
      }
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
  /// pregunta está en lo dicho y cuánto de lo dicho explica. Las palabras que
  /// el corpus no conoce no cuentan ni a favor ni en contra.
  double _score(Set<String> said, _Entry e) {
    final known = {
      for (final t in said)
        if (_weight(t) > 0) t,
    };
    final shared = known.intersection(e.tokens);
    if (shared.isEmpty) return 0;
    final sharedWeight = _weightOf(shared);
    final recall = sharedWeight / _weightOf(e.tokens);
    final precision = sharedWeight / _weightOf(known);
    return 2 * precision * recall / (precision + recall);
  }

  /// Respuestas documentadas para [hearingText], de la situación más
  /// parecida primero. Vacío si nada se parece lo suficiente.
  List<RagSuggestion> suggest(String hearingText, {int limit = 4}) {
    final said = DialogueGraph.tokensOf(hearingText);
    if (said.isEmpty) return const [];
    final ranked = [for (final e in _entries) (e, _score(said, e))]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    if (ranked.isEmpty || ranked.first.$2 < minScore) return const [];

    final best = ranked.first.$2;
    final out = <RagSuggestion>[];
    for (final (entry, score) in ranked) {
      if (score < minScore || score < best - margin) break;
      for (final r in entry.replies) {
        if (out.any((s) => s.text == r.text)) continue;
        out.add(
          RagSuggestion(
            text: r.text,
            glosses: r.glosses,
            scenarioId: entry.scenario.id,
            institution: entry.scenario.institution,
            procedure: entry.scenario.procedure,
            score: score,
          ),
        );
        if (out.length >= limit) return out;
      }
    }
    return out;
  }
}

class _Entry {
  final RagScenario scenario;
  final Set<String> tokens;
  final List<RagTurn> replies;

  _Entry(this.scenario, this.tokens, this.replies);
}
