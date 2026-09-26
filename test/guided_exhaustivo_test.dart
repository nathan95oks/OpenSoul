import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';

/// Exploración de los ocho recorridos con respuestas aleatorias (semilla fija).
///
/// Por cada intervención se comprueban las invariantes que pide la
/// precisión semántica:
///
///   * confirmedFacts ⊆ representedFacts ⊆ hechos conocidos;
///   * ningún valor escrito cambia ni desaparece;
///   * no aparece un canal, una moneda o un dato que nadie eligió;
///   * toda glosa enviada existe en el Corpus Maestro Unificado LSB v4.
///
/// Además deja (o comprueba) `test/fixtures/guided/paridad.json`, que
/// `aws/tests/test_guiado_precision.py` pasa por el compositor de la Lambda:
/// así se prueba que cliente y servidor redactan lo mismo.
///
/// Para regenerar el fixture: `ACTUALIZAR_PARIDAD=1 flutter test
/// test/guided_exhaustivo_test.dart`.
void main() {
  final bank = QuestionBank.generated();
  final flow = GuidedFlow(bank);
  final composer = GuidedComposer(bank);

  final corpus = {
    for (final e in (jsonDecode(File('assets/dictionary/official_dictionary.json')
            .readAsStringSync()) as Map<String, dynamic>)['entries'] as List)
      (e as Map<String, dynamic>)['gloss'] as String,
  };

  // Valores de ejemplo válidos para cada editor. Ninguno contiene palabras
  // que el test busca como inventadas.
  Map<String, Object?> valoresPara(BankOption o, Random r) {
    final n = o.range == null
        ? 1 + r.nextInt(9)
        : o.range![0] + r.nextInt(o.range![1] - o.range![0] + 1);
    return switch (o.editor) {
      'texto_nombre' => {'nombre': ['María Quispe', 'Juan Mamani'][r.nextInt(2)]},
      'telefono' => {'telefono': '7${1000000 + r.nextInt(8999999)}'},
      'entero' || 'edad' => {'n': '$n'},
      'monto' => {
          'monto': ['500', '1.500,50', '20'][r.nextInt(3)],
          'moneda': ['Bs', 'USD'][r.nextInt(2)],
        },
      'texto_detalle' => {'texto': 'un recibo firmado'},
      'lugar_literal' => {'nombre': 'Heroínas'},
      'referencia' => {'referencia': 'el mercado 25 de Mayo'},
      'documento_numero' => {'numero': '4567890 CB'},
      'hora' => {'hora': '18:30'},
      _ => const {},
    };
  }

  GuidedSession recorrer(String journeyId, int seed) {
    final r = Random(seed);
    var s = flow.startJourney(journeyId,
        purpose: GuidedPurpose.values[seed % GuidedPurpose.values.length]);
    final visitadas = <String>{};
    while (true) {
      final q = s.currentQuestionId;
      if (q == null || !visitadas.add(q)) break;
      final step = s.stepOf(q)!;
      final dado = r.nextDouble();
      if (!step.required && dado < 0.12) {
        // sin responder
      } else if (!step.required && dado < 0.2) {
        s = flow.omit(s, q).session;
      } else {
        final ofrecidas = flow.offeredOptions(s, q);
        final question = bank.question(q)!;
        final intentos = 1 + r.nextInt(question.maxPicks);
        for (var i = 0; i < intentos && ofrecidas.isNotEmpty; i++) {
          final o = ofrecidas[r.nextInt(ofrecidas.length)];
          final valores = o.editor == null ||
                  (o.editorOptional && r.nextBool())
              ? null
              : valoresPara(o, r);
          final res = flow.select(s, q, o.id, values: valores);
          if (res.accepted) s = res.session;
        }
      }
      s = s.copyWith(currentQuestionId: flow.currentOrFirst(s));
      final next = flow.nextQuestion(s.copyWith(currentQuestionId: q));
      if (next == null) break;
      s = flow.goTo(s, next);
    }
    return s;
  }

  const semillas = 150;
  final paridad = <Map<String, Object?>>[];

  for (final journeyId in bank.journeys.keys) {
    test('$journeyId: $semillas intervenciones sin pérdidas ni invenciones', () {
      for (var seed = 0; seed < semillas; seed++) {
        final s = recorrer(journeyId, seed);
        final intervention = s.toIntervention();
        final traced = composer.composeTraced(intervention);
        final t = traced.text;
        final donde = '$journeyId#$seed «$t»';

        // Cobertura en las dos direcciones.
        final confirmed = composer.confirmedFacts(intervention);
        expect(confirmed.difference(traced.represented), isEmpty,
            reason: 'hecho confirmado perdido en $donde');
        final known = {
          for (final a in intervention.answers)
            for (final o in a.optionIds) '${a.questionId}#$o',
        };
        expect(traced.represented.difference(known), isEmpty,
            reason: 'hecho no declarado en $donde');

        // Plantillas completas y ningún dato inventado.
        expect(t, isNot(contains('{')), reason: donde);
        final plano = t.toLowerCase();
        for (final inventado in ['whatsapp', 'telegram', 'sms', 'facebook',
            'bolivianos', 'dólares']) {
          expect(plano, isNot(contains(inventado)), reason: donde);
        }

        // Valores escritos, literales.
        for (final a in intervention.answers) {
          for (final entry in a.values.entries) {
            final option = bank.question(a.questionId)!.option(entry.key)!;
            for (final v in entry.value.entries) {
              if (v.key == 'aprox') continue;
              if (v.key == 'n' && '${v.value}' == '1' &&
                  option.singularPhrase != null) {
                continue;
              }
              expect(t, contains('${v.value}'),
                  reason: 'valor ${v.key}=${v.value} perdido en $donde');
            }
          }
        }

        // Estados coherentes.
        for (final a in intervention.answers) {
          if (a.isOmitted) {
            expect(a.optionIds, isEmpty, reason: donde);
            continue;
          }
          final q = bank.question(a.questionId)!;
          expect(a.optionIds, isNotEmpty, reason: donde);
          expect(a.optionIds.length, lessThanOrEqualTo(q.maxPicks),
              reason: donde);
          if (a.optionIds.length > 1) {
            for (final id in a.optionIds) {
              expect(q.option(id)!.isExclusive, isFalse,
                  reason: 'Sí/No/No sé mezclados en $donde');
            }
          }
        }

        // Toda glosa que viaja al backend existe en el corpus v4.
        for (final g in flow.glossesOf(intervention)) {
          expect(corpus, contains(g), reason: 'glosa $g fuera del corpus v4');
        }

        if (seed < 12) {
          paridad.add({
            'guided': intervention.toJson(),
            'texto': t,
            'representadas': (traced.represented.toList()..sort()),
          });
        }
      }
    });
  }

  test('paridad cliente/servidor: fixture al día', () {
    final file = File('test/fixtures/guided/paridad.json');
    final actual = '${const JsonEncoder.withIndent(' ').convert(paridad)}\n';
    if (Platform.environment['ACTUALIZAR_PARIDAD'] == '1') {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(actual);
    }
    expect(file.existsSync(), isTrue,
        reason: 'Genera el fixture con ACTUALIZAR_PARIDAD=1');
    // Git puede entregar el fixture con CRLF en Windows: se compara el
    // contenido, no el fin de línea.
    expect(file.readAsStringSync().replaceAll('\r\n', '\n'), actual,
        reason: 'El compositor cambió: regenera el fixture y pasa '
            'aws/tests/test_guiado_precision.py');
  });
}
