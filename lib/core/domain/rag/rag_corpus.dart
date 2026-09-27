import 'dart:convert';

/// Corpus RAG de trámites de Cochabamba: situaciones reales documentadas.
///
/// Lo genera `tool/build_rag_corpus.py` desde
/// `docs/negocio/escenarios_tramites_cochabamba_RAG_2026-09-27.md`. Aquí solo
/// se lee: qué se puede mostrar ya lo decidió el constructor (`mostrable`).
class RagCorpus {
  final List<RagScenario> scenarios;

  const RagCorpus(this.scenarios);

  static const empty = RagCorpus([]);

  factory RagCorpus.fromJsonString(String raw) =>
      RagCorpus.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  factory RagCorpus.fromJson(Map<String, dynamic> json) => RagCorpus([
    for (final e in (json['escenarios'] as List? ?? const []))
      RagScenario.fromJson(Map<String, dynamic>.from(e as Map)),
  ]);
}

enum RagSpeaker { deaf, official }

class RagScenario {
  final String id;
  final String title;
  final String institution;
  final String procedure;
  final List<RagTurn> turns;

  /// Otras formas de hacer una pregunta del funcionario, con las respuestas
  /// posibles de la persona sorda.
  final List<RagVariant> variants;

  const RagScenario({
    required this.id,
    required this.title,
    required this.institution,
    required this.procedure,
    required this.turns,
    required this.variants,
  });

  factory RagScenario.fromJson(Map<String, dynamic> json) => RagScenario(
    id: json['id'] as String,
    title: (json['titulo'] ?? '').toString(),
    institution: (json['institucion'] ?? '').toString(),
    procedure: (json['tramite'] ?? '').toString(),
    turns: [
      for (final t in (json['turnos'] as List? ?? const []))
        RagTurn.fromJson(Map<String, dynamic>.from(t as Map)),
    ],
    variants: [
      for (final v in (json['variantes'] as List? ?? const []))
        RagVariant.fromJson(Map<String, dynamic>.from(v as Map)),
    ],
  );

  RagTurn? turn(int n) {
    for (final t in turns) {
      if (t.n == n) return t;
    }
    return null;
  }
}

class RagTurn {
  final int n;
  final RagSpeaker speaker;
  final String text;
  final List<String> glosses;

  /// El constructor lo aprobó para mostrarlo: no depende de un dato sin
  /// verificar ni lleva un dato personal de ejemplo.
  final bool showable;

  const RagTurn({
    required this.n,
    required this.speaker,
    required this.text,
    required this.glosses,
    required this.showable,
  });

  factory RagTurn.fromJson(Map<String, dynamic> json) => RagTurn(
    n: (json['n'] as num).toInt(),
    speaker: json['rol'] == 'sordo' ? RagSpeaker.deaf : RagSpeaker.official,
    text: (json['texto'] ?? '').toString(),
    glosses: [for (final g in (json['glosas'] as List? ?? const [])) '$g'],
    showable: json['mostrable'] == true,
  );

  /// Una respuesta que se puede ofrecer como tarjeta a la persona sorda.
  bool get isOfferableReply =>
      speaker == RagSpeaker.deaf && showable && glosses.isNotEmpty;
}

class RagVariant {
  /// Turno del funcionario al que se refiere la variante.
  final int turn;
  final List<String> questions;
  final List<RagTurn> replies;

  const RagVariant({
    required this.turn,
    required this.questions,
    required this.replies,
  });

  factory RagVariant.fromJson(Map<String, dynamic> json) => RagVariant(
    turn: (json['turno'] as num).toInt(),
    questions: [for (final q in (json['preguntas'] as List? ?? const [])) '$q'],
    replies: [
      for (final r in (json['respuestas'] as List? ?? const []))
        RagTurn(
          n: 0,
          speaker: RagSpeaker.deaf,
          text: ((r as Map)['texto'] ?? '').toString(),
          glosses: [for (final g in (r['glosas'] as List? ?? const [])) '$g'],
          showable: r['mostrable'] == true,
        ),
    ],
  );
}

/// Un trámite con lo que una persona sorda puede decir para abrirlo o
/// preguntar sobre él.
class RagProcedure {
  final String scenarioId;
  final String title;
  final List<RagTurn> phrases;

  const RagProcedure({
    required this.scenarioId,
    required this.title,
    required this.phrases,
  });
}

/// Una institución (área del corpus: DDRR, SEGIP…) con sus trámites.
class RagTopic {
  final String area;
  final String institution;
  final List<RagProcedure> procedures;

  const RagTopic({
    required this.area,
    required this.institution,
    required this.procedures,
  });
}

extension RagCorpusTopics on RagCorpus {
  /// Lo que la persona sorda puede decir para iniciar, por institución: la
  /// frase con que abrió cada situación y sus preguntas. Se dejan fuera las
  /// que solo se entienden a mitad del diálogo («¿Entonces no pago…?»,
  /// «¿Eso incluye…?») y, como siempre, lo no aprobado o sin glosas.
  List<RagTopic> get deafTopics {
    final byArea = <String, List<RagScenario>>{};
    for (final s in scenarios) {
      final parts = s.id.split('-');
      if (parts.length < 3) continue;
      byArea.putIfAbsent(parts[1], () => []).add(s);
    }
    return [
      for (final e in byArea.entries)
        if (_proceduresOf(e.value) case final procedures
            when procedures.isNotEmpty)
          RagTopic(
            area: e.key,
            institution: e.value.first.institution,
            procedures: procedures,
          ),
    ];
  }

  static final RegExp _anaphoric = RegExp(
    r'^¿?\s*(entonces|eso|ese|esa|esos|esas|después|también|y)\b',
    caseSensitive: false,
  );

  static List<RagProcedure> _proceduresOf(List<RagScenario> scenarios) {
    final seen = <String>{};
    final out = <RagProcedure>[];
    for (final s in scenarios) {
      final phrases = [
        for (final t in s.turns)
          if (t.isOfferableReply &&
              (t.n == 1 || t.text.contains('?')) &&
              !_anaphoric.hasMatch(t.text) &&
              seen.add(t.text))
            t,
      ];
      if (phrases.isNotEmpty) {
        out.add(
          RagProcedure(scenarioId: s.id, title: s.procedure, phrases: phrases),
        );
      }
    }
    return out;
  }
}
