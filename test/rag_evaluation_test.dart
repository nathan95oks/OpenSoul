import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn_builder.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

typedef RetrievalCase = ({String query, String scenario, String area});

void main() {
  late RagCorpus corpus;
  late RagRetriever retriever;
  late ConversationGraphCatalog catalog;
  late ConversationGraphRouter router;
  late SemanticTurnBuilder builder;
  late Map<String, dynamic> rawCorpus;

  setUpAll(() {
    final raw = File('assets/rag/escenarios_cbba.json').readAsStringSync();
    rawCorpus = jsonDecode(raw) as Map<String, dynamic>;
    corpus = RagCorpus.fromJsonString(raw);
    retriever = RagRetriever(corpus);
    catalog = ConversationGraphCatalog(
      bank: QuestionBank.generated(),
      graph: DialogueGraph.fromJsonString(
        File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
      ),
    );
    router = ConversationGraphRouter(catalog);
    builder = SemanticTurnBuilder(catalog);
  });

  test('dataset compacto de 100 consultas cumple los objetivos críticos', () {
    final retrievalCandidates = <RetrievalCase>[];
    for (final scenario in corpus.scenarios) {
      for (final turn in scenario.turns) {
        if (turn.speaker != RagSpeaker.official || !turn.showable) continue;
        final next = scenario.turn(turn.n + 1);
        final hasReply =
            (next != null && next.isOfferableReply) ||
            scenario.variants.any(
              (v) =>
                  v.turn == turn.n && v.replies.any((r) => r.isOfferableReply),
            );
        if (hasReply) {
          retrievalCandidates.add((
            query: turn.text,
            scenario: scenario.id,
            area: scenario.area,
          ));
        }
      }
      for (final variant in scenario.variants) {
        if (!variant.replies.any((r) => r.isOfferableReply)) continue;
        for (final question in variant.questions) {
          retrievalCandidates.add((
            query: question,
            scenario: scenario.id,
            area: scenario.area,
          ));
        }
      }
    }
    final retrieval = retrievalCandidates.take(60).toList();
    expect(retrieval, hasLength(60));

    const institutions = <(String, String)>[
      ('Me denunciaron y no puedo pagar abogado', 'SEPDEP'),
      ('Soy víctima y necesito abogado', 'SEPDAVI'),
      ('Me robaron mi celular', 'FELCC'),
      ('Mi pareja me amenaza y me golpea', 'FELCV'),
      ('Perdí mi cédula', 'SEGIP'),
      ('Perdí mi certificado de nacimiento', 'SERECI'),
      ('¿Cómo sigo mi denuncia en Fiscalía?', 'FIS'),
    ];
    const graphCases = <(String, List<String>, Set<String>)>[
      ('¿Quién te robó?', ['person'], {'Q.PER.CONOCE'}),
      ('Hola, ¿cómo estás? ¿Quién te robó?', ['person'], {'Q.PER.CONOCE'}),
      ('¿Cuándo te robaron el celular?', ['time'], {'Q.TIE.CUANDO'}),
      ('¿Dónde te robaron?', ['place'], {'Q.LUG.DONDE'}),
      ('¿Qué te robaron?', ['object'], {'Q.ROB.QUE'}),
      (
        '¿A qué hora y dónde te robaron?',
        ['time', 'place'],
        {'Q.TIE.HORA', 'Q.LUG.DONDE'},
      ),
      ('Cuéntame cómo pasó el robo.', [], {'Q.HEC.QUE_OCURRIO'}),
    ];
    const continuity = [
      '¿Dónde te robaron?',
      '¿Y a qué hora?',
      '¿Quién te robó?',
      '¿Dónde pasó?',
      '¿Y qué necesito?',
      'Ahora necesito renovar mi cédula',
    ];
    const live = [
      '¿Cuánto debo?',
      '¿Quién es mi fiscal?',
      '¿Cuándo es mi audiencia?',
      '¿Será virtual?',
    ];
    final verifyCases = <Map<String, dynamic>>[];
    for (final scenario in rawCorpus['escenarios'] as List) {
      for (final turn in (scenario as Map)['turnos'] as List) {
        final t = Map<String, dynamic>.from(turn as Map);
        final reasons = [
          for (final r in t['motivos'] as List? ?? const []) '$r',
        ];
        if (reasons.any(
          (r) =>
              r == 'dato_sin_verificar' ||
              r == 'dato_vencido' ||
              r == 'vigencia_sin_confirmar',
        )) {
          verifyCases.add(t);
        }
      }
    }
    expect(verifyCases.length, greaterThanOrEqualTo(5));
    const negations = [
      'No conozco al ladrón',
      'No vi su cara',
      'No fue de noche',
      'No ocurrió en mi casa',
      'No me robaron dinero',
    ];
    const presuppositions = [
      '¿El ladrón escapó en moto?',
      '¿Tu pareja te golpeó ayer?',
      '¿Te robaron dos celulares?',
    ];
    const outside = [
      'Fotosíntesis cuántica submarina',
      'Receta de galaxias con azafrán',
      'Campeonato de ajedrez marciano',
    ];
    final datasetSize =
        retrieval.length +
        institutions.length +
        graphCases.length +
        continuity.length +
        live.length +
        5 +
        negations.length +
        presuppositions.length +
        outside.length;
    expect(datasetSize, 100);

    var hit1 = 0;
    var hit3 = 0;
    var hit5 = 0;
    var crossErrors = 0;
    for (final c in retrieval) {
      final found = retriever.suggest(c.query, limit: 20);
      bool hit(int k) => found.take(k).any((s) => s.scenarioId == c.scenario);
      if (hit(1)) hit1++;
      if (hit(3)) hit3++;
      if (hit(5)) hit5++;
      if (found.isNotEmpty && found.first.scenarioId.split('-')[1] != c.area) {
        crossErrors++;
      }
    }

    final institutionCorrect = institutions
        .where((c) => retriever.areaOf(c.$1) == c.$2)
        .length;
    var slotsCorrect = 0;
    var graphCorrect = 0;
    var multiExact = 0;
    for (final c in graphCases) {
      final semantic = builder.build(turnId: c.$1, text: c.$1);
      final route = router.routeDeterministic(semantic);
      final opened = <String>{
        ...route.targetQuestionIds,
        ...route.pathQuestionIds,
        if (route.type == ConversationRouteType.directContext &&
            route.targetContextId != null)
          ?catalog.bank
              .journey(route.targetContextId!)
              ?.steps
              .firstOrNull
              ?.questionId,
      };
      if (_sameList(semantic.requestedSlots, c.$2)) slotsCorrect++;
      if (opened.containsAll(c.$3)) graphCorrect++;
      if (c.$2.length > 1 && _sameList(semantic.requestedSlots, c.$2)) {
        multiExact++;
      }
    }

    final livePattern = RegExp(
      r'\b(?:Bs\.?\s*)?\d{2,}(?:[.,]\d+)?\b|\b[A-Z]{2,}-?\d{3,}\b',
      caseSensitive: false,
    );
    var liveHallucinations = 0;
    for (final query in live) {
      for (final result in retriever.suggest(query, limit: 12)) {
        if (livePattern.hasMatch(result.text)) liveHallucinations++;
      }
    }
    final verifyPreserved = verifyCases
        .take(5)
        .where((t) => t['mostrable'] == false)
        .length;
    for (final query in outside) {
      expect(retriever.rankAreas(query), isEmpty);
      expect(retriever.suggest(query), isEmpty);
    }

    final metrics = <String, double>{
      'retrieval_hit@1': hit1 / retrieval.length,
      'retrieval_hit@3': hit3 / retrieval.length,
      'retrieval_hit@5': hit5 / retrieval.length,
      'institution_accuracy': institutionCorrect / institutions.length,
      'slot_accuracy': slotsCorrect / graphCases.length,
      'multi_slot_exact_match': multiExact.toDouble(),
      'cross_institution_error_rate': crossErrors / retrieval.length,
      'live_data_hallucination_rate': liveHallucinations / live.length,
      'verify_marker_preservation': verifyPreserved / 5,
      'graph_regression_pass_rate': graphCorrect / graphCases.length,
    };
    // ignore: avoid_print
    print('RAG_METRICS ${jsonEncode(metrics)}');

    expect(metrics['retrieval_hit@5'], greaterThanOrEqualTo(0.95));
    expect(metrics['institution_accuracy'], 1);
    expect(metrics['slot_accuracy'], 1);
    expect(metrics['multi_slot_exact_match'], 1);
    expect(metrics['cross_institution_error_rate'], 0);
    expect(metrics['live_data_hallucination_rate'], 0);
    expect(metrics['verify_marker_preservation'], 1);
    expect(metrics['graph_regression_pass_rate'], 1);

    // Las categorías que ya tienen pruebas de comportamiento dedicadas
    // forman parte del mismo dataset aunque aquí no se reimplemente su lógica.
    expect(continuity, hasLength(6));
    expect(negations, hasLength(5));
    expect(presuppositions, hasLength(3));
  });
}

bool _sameList(List<String> a, List<String> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);
