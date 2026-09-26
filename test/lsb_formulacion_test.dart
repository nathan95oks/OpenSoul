import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';

/// Formulación LSB de las preguntas, tal como la recibe la app.
///
/// No prueba gramática (eso es validación humana): prueba que lo que se
/// muestra es la secuencia canónica del banco, con su tipo de pregunta, sin
/// respuestas metidas dentro y sin perder compuestos ni dactilología.
void main() {
  final bank = QuestionBank.generated();
  LsbFormulation lsb(String id) => bank.question(id)!.lsb;

  test('todas las preguntas traen su formulación y ninguna está validada', () {
    final estados = {for (final q in bank.allQuestions) q.lsb.status};
    expect(estados, isNot(contains('GRAMMAR_VALIDATED')));
    final conSecuencia =
        bank.allQuestions.where((q) => !q.lsb.isEmpty).length;
    expect(conSecuencia, greaterThanOrEqualTo(130));
    for (final q in bank.allQuestions) {
      if (q.lsb.isEmpty) {
        expect(q.lsb.status, anyOf('GRAMMAR_PENDING', 'LEXICAL_GAP'),
            reason: q.id);
      }
    }
  });

  test('las preguntas sí/no no llevan SÍ, NO ni NO SÉ en la formulación', () {
    for (final q in bank.allQuestions.where((q) => q.lsb.type == 'polar')) {
      expect(q.lsb.glosses, isNot(anyElement(anyOf('SÍ', 'NO', 'NO_SABER'))),
          reason: q.id);
    }
  });

  test('las preguntas QU- conservan su interrogativo', () {
    for (final q in bank.allQuestions
        .where((q) => q.lsb.type == 'qu' || q.lsb.type == 'disyuntiva')) {
      expect(q.lsb.glosses, contains(q.lsb.interrogative), reason: q.id);
    }
    expect(lsb('Q.ROB.QUE').glosses, ['ROBAR', 'QUÉ']);
    expect(lsb('Q.HEC.ESCAPE_ACTOR').glosses, ['QUIÉN', 'ESCAPAR']);
    expect(lsb('Q.ID.EDAD_PROPIA').interrogative, 'CUÁNTOS');
  });

  test('compuestos, dactilología, número y alternativas se muestran como tales',
      () {
    final carnet = lsb('Q.ID.DOC_TIENE').segments;
    expect(carnet.first.label, 'PAPEL+IDENTIDAD');
    expect(carnet.first.kind, LsbSegmentKind.compound);

    final fiscalia = lsb('Q.SEG.DONDE_FISCALIA').segments;
    expect(fiscalia.first.label, 'd(FISCALÍA)');
    expect(fiscalia.first.kind, LsbSegmentKind.dactylology);
    expect(fiscalia.first.glosses, isEmpty,
        reason: 'la dactilología no se muestra como una seña del catálogo');

    final numero = lsb('Q.DIG.NUMERO_CONOCE').segments;
    expect(numero.map((s) => s.kind), contains(LsbSegmentKind.number));

    final conoce = lsb('Q.PER.CONOCE').segments.map((s) => s.label);
    expect(conoce, contains('ÉL/ELLA'));
  });

  test('un hueco léxico se declara, no se rellena con una glosa inventada', () {
    expect(lsb('Q.DEN.INTENCION').gaps, ['DENUNCIA']);
    expect(lsb('Q.DEN.INTENCION').status, 'LEXICAL_GAP');
    expect(lsb('Q.PER.DESCRIBIR').isEmpty, isTrue);
    expect(lsb('Q.PER.DESCRIBIR').gaps, ['DESCRIBIR']);
  });

  test('la app, la Lambda y el grafo usan la misma secuencia', () {
    final lambda = jsonDecode(File('aws/question_bank.json').readAsStringSync())
        as Map<String, dynamic>;
    for (final raw in lambda['preguntas'] as List) {
      final q = raw as Map<String, dynamic>;
      final glosas = ((q['formulacionLsb'] as Map?)?['glosas'] as List?) ?? [];
      expect(glosas, bank.question(q['id'] as String)!.lsb.glosses,
          reason: q['id'] as String);
    }
    final grafo = jsonDecode(File('assets/dialogue/dialogue_graph.json')
        .readAsStringSync()) as Map<String, dynamic>;
    for (final raw in grafo['nodes'] as List) {
      final n = raw as Map<String, dynamic>;
      final id = n['bankQuestion'] as String?;
      if (id == null) continue;
      expect(n['formulationGlosses'], bank.question(id)!.lsb.glosses,
          reason: n['id'] as String);
    }
  });
}
