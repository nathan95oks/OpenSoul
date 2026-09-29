import 'package:lsb_legal_app/core/domain/conversation/lsb_gloss_semantics.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_values.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

/// De dónde sale una respuesta propuesta.
enum ProposalSource {
  /// El oyente nombró algo que el banco reconoce (`mencionables`).
  hearingMention,

  /// Un clasificador (p. ej. un modelo) la propuso en identificadores del
  /// banco.
  model,
}

/// Una respuesta que alguien **propone** y la persona sorda todavía no
/// confirmó.
///
/// Solo habla en identificadores del banco: pregunta, opción y, si la opción
/// lo pide, su valor. No trae glosas, frases ni estados: la glosa, la frase y
/// si es afirmación, negación o «no sé» los pone la opción del banco. Así un
/// clasificador no puede inventar una seña ni cambiar la polaridad de lo que
/// se dice.
class GuidedProposal {
  final String questionId;
  final String optionId;
  final Map<String, Object?>? values;
  final ProposalSource source;

  /// Qué lo motivó (la palabra del oyente, la cita del modelo). Solo para
  /// explicar la sugerencia, nunca para redactar.
  final String evidence;

  const GuidedProposal({
    required this.questionId,
    required this.optionId,
    required this.source,
    this.values,
    this.evidence = '',
  });

  /// Lee la salida de un clasificador:
  /// `{"respuestas": [{"pregunta": "Q.ROB.QUE", "opcion": "celular",
  /// "valores": {...}, "evidencia": "..."}]}`.
  ///
  /// Lo mal formado se descarta aquí; lo bien formado pero falso (una
  /// pregunta u opción que no existe) lo rechaza [GuidedProposals.review].
  static List<GuidedProposal> fromModelJson(
    Object? json, {
    ProposalSource source = ProposalSource.model,
  }) {
    final respuestas = json is Map ? json['respuestas'] : null;
    if (respuestas is! List) return const [];
    return [
      for (final r in respuestas)
        if (r is Map && r['pregunta'] is String && r['opcion'] is String)
          GuidedProposal(
            questionId: r['pregunta'] as String,
            optionId: r['opcion'] as String,
            values: r['valores'] is Map
                ? Map<String, Object?>.from(r['valores'] as Map)
                : null,
            source: source,
            evidence: (r['evidencia'] ?? '').toString(),
          ),
    ];
  }

  String get key => '$questionId/$optionId';
}

/// Por qué no se acepta una propuesta.
enum ProposalRejection {
  unknownQuestion,

  /// La pregunta existe pero no es un paso de este recorrido.
  notInJourney,
  unknownOption,

  /// El recorrido oculta esa opción en este paso.
  hiddenOption,

  /// La opción exige un valor (monto, nombre…) y no vino, o no es válido.
  needsValue,
  invalidValue,

  /// Choca con otra propuesta de la misma pregunta («Sí» y «No», dos
  /// respuestas donde cabe una): hay que preguntar, no elegir.
  conflicting,
}

class ProposalReview {
  final List<GuidedProposal> accepted;
  final List<({GuidedProposal proposal, ProposalRejection reason})> rejected;

  /// Preguntas donde las propuestas se contradicen: se pide aclaración.
  final Set<String> needsClarification;

  const ProposalReview({
    this.accepted = const [],
    this.rejected = const [],
    this.needsClarification = const {},
  });

  static const empty = ProposalReview();

  GuidedProposal? proposalFor(String questionId, String optionId) {
    for (final p in accepted) {
      if (p.questionId == questionId && p.optionId == optionId) return p;
    }
    return null;
  }
}

/// Valida propuestas contra el banco y el recorrido en curso, sin elegir.
///
/// Es la misma frontera para cualquier fuente: lo que un clasificador diga
/// solo llega a la pantalla como sugerencia si corresponde a una opción real
/// de una pregunta del recorrido, con un valor válido si lo pide y sin
/// contradecir a otra propuesta. Confirmarla es elegirla con la lógica de
/// siempre ([GuidedFlow.select]), que vuelve a aplicar todas las reglas.
class GuidedProposals {
  final GuidedFlow rules;

  GuidedProposals(this.rules);

  QuestionBank get _bank => rules.bank;

  ProposalReview review(
    GuidedSession session,
    Iterable<GuidedProposal> proposals,
  ) {
    final accepted = <GuidedProposal>[];
    final rejected = <({GuidedProposal proposal, ProposalRejection reason})>[];
    final seen = <String>{};

    void reject(GuidedProposal p, ProposalRejection r) =>
        rejected.add((proposal: p, reason: r));

    for (final p in proposals) {
      if (!seen.add(p.key)) continue;
      final question = _bank.question(p.questionId);
      if (question == null) {
        reject(p, ProposalRejection.unknownQuestion);
        continue;
      }
      final step = session.stepOf(p.questionId);
      if (step == null) {
        reject(p, ProposalRejection.notInJourney);
        continue;
      }
      final option = question.option(p.optionId);
      if (option == null) {
        reject(p, ProposalRejection.unknownOption);
        continue;
      }
      if (step.hiddenOptions.contains(option.id)) {
        reject(p, ProposalRejection.hiddenOption);
        continue;
      }
      final values = p.values;
      final editor = option.editor;
      if (editor != null && values != null) {
        final check = GuidedValues.check(editor, values, range: option.range);
        if (!check.isValid) {
          reject(p, ProposalRejection.invalidValue);
          continue;
        }
      }
      if (option.requiresValue && !GuidedValues.isComplete(editor!, values)) {
        reject(p, ProposalRejection.needsValue);
        continue;
      }
      accepted.add(p);
    }

    // Contradicciones dentro de una misma pregunta: ninguna se sugiere.
    final clarify = <String>{};
    final byQuestion = <String, List<GuidedProposal>>{};
    for (final p in accepted) {
      (byQuestion[p.questionId] ??= []).add(p);
    }
    for (final e in byQuestion.entries) {
      if (e.value.length < 2) continue;
      final question = _bank.question(e.key)!;
      final options = [for (final p in e.value) question.option(p.optionId)!];
      final conflict =
          !question.isMultiple ||
          options.any((o) => o.isExclusive) ||
          e.value.length > question.maxPicks;
      if (conflict) clarify.add(e.key);
    }
    for (final p in [...accepted]) {
      if (clarify.contains(p.questionId)) {
        accepted.remove(p);
        reject(p, ProposalRejection.conflicting);
      }
    }
    return ProposalReview(
      accepted: accepted,
      rejected: rejected,
      needsClarification: clarify,
    );
  }

  /// Lo que el oyente nombró y el recorrido puede responder.
  ///
  /// Solo con los `mencionables` del banco (patrón → glosas): una palabra del
  /// oyente propone las opciones del recorrido que tienen exactamente esas
  /// glosas. Si el turno lleva una negación («¿No le robaron nada?») no se
  /// propone nada: una mención negada no es un dato que sugerir.
  List<GuidedProposal> fromHearingText(GuidedSession session, String text) {
    if (text.trim().isEmpty || _hasNegation(text)) return const [];
    final lower = text.toLowerCase();
    final out = <GuidedProposal>[];
    for (final m in _mentionables) {
      final match = m.pattern.firstMatch(lower);
      if (match == null) continue;
      for (final step in session.steps) {
        final question = _bank.question(step.questionId);
        if (question == null) continue;
        for (final o in question.options) {
          if (!o.hasSign) continue;
          if (_sameGlosses(
            LsbGlossSemantics.normalizeAll(o.glosses),
            m.glosses,
          )) {
            out.add(
              GuidedProposal(
                questionId: question.id,
                optionId: o.id,
                source: ProposalSource.hearingMention,
                evidence: match.group(0)!,
              ),
            );
          }
        }
      }
    }
    return out;
  }

  late final List<({RegExp pattern, List<String> glosses})> _mentionables = [
    for (final raw
        in (_bank.data['mencionables'] as List<dynamic>? ?? const []))
      if (raw is Map && raw['patron'] is String && raw['glosas'] is List)
        (
          // La palabra entera (con su plural), no dentro de otra.
          pattern: RegExp(
            '(?<![\\p{L}])(?:${raw['patron']})(?:e?s)?(?![\\p{L}])',
            unicode: true,
          ),
          glosses: LsbGlossSemantics.normalizeAll(
            List<String>.from(raw['glosas'] as List),
          ),
        ),
  ];

  static bool _sameGlosses(List<String> a, List<String> b) {
    if (a.isEmpty || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _hasNegation(String text) {
    final words = AnimationUrlResolver.stripAccents(
      text.toUpperCase(),
    ).split(RegExp(r'[^A-Z]+'));
    return words.any(LsbGlossSemantics.negators.contains);
  }
}
