import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';

/// Respuestas completas de «Trámites» (2026-10-14): una respuesta dice de qué
/// se trata, una indicación se contesta diciendo cuál, y «¿Trajo algún
/// documento?» se detalla. Todo con el banco real y sin señas nuevas.
void main() {
  final bank = RagTramites.bankWithTramites();
  final rules = GuidedFlow(bank);
  final composer = GuidedComposer(bank);

  final preguntas = [
    for (final q in bank.data['preguntas'] as List<dynamic>)
      q as Map<String, dynamic>,
  ];
  // Las preguntas de los recorridos de «Trámites» (`R.ESC-…`).
  final polares = [
    for (final q in preguntas)
      if (q['control'] == 'polar3' && (q['id'] as String).startsWith('R.')) q,
  ];

  String contextOf(String id) =>
      'tramite_${id.toLowerCase().replaceFirst('esc-', '').replaceAll('-', '_')}';

  Set<String> visibles(GuidedSession s) => {
    for (final step in s.steps)
      if (rules.isReachable(s, step)) step.questionId,
  };

  String decir(GuidedSession s) => composer.compose(s.toIntervention());

  group('una respuesta de sí o no dice de qué se trata', () {
    test('ninguna respuesta del banco es «Sí.», «No.» o «No sé.» a secas', () {
      expect(polares.length, greaterThan(300));
      for (final q in polares) {
        for (final o in q['opciones'] as List<dynamic>) {
          expect(
            (o as Map<String, dynamic>)['frase'],
            isNot(matches(r'^(Sí|No|No sé)\.$')),
            reason: '${q['id']} ${o['id']}',
          );
        }
      }
    });

    test('las tarjetas siguen siendo una seña: SÍ, NO y NO SÉ', () {
      for (final q in polares) {
        final b = bank.question(q['id'] as String)!;
        expect(
          [for (final o in b.options) o.glosses],
          [
            ['SÍ'],
            ['NO'],
            ['NO_SABER'],
          ],
          reason: q['id'] as String,
        );
      }
    });

    test('«¿Tiene abogado para este caso?» se contesta con el abogado', () {
      final q = polares.firstWhere(
        (q) => q['formulacion'] == '¿Tiene abogado para este caso?',
      );
      final id = q['id'] as String;
      final b = bank.question(id)!;
      expect(b.option('si')!.phrase, 'Sí, tengo abogado para este caso.');
      expect(b.option('no')!.phrase, 'No, no tengo abogado para este caso.');
      expect(
        b.option('no_se')!.phrase,
        'No sé quién es mi abogado para este caso.',
      );
    });
  });

  group('«¿Trajo algún documento?» se detalla con tarjetas', () {
    const padre = 'R.ESC-SEGIP-101.6';
    const hijo = '$padre.docs';
    final ctx = contextOf('ESC-SEGIP-101');

    test('el detalle solo aparece después de decir que sí', () {
      var s = rules.startJourney(ctx, purpose: GuidedPurpose.reply);
      expect(visibles(s), isNot(contains(hijo)));
      s = rules.select(s, padre, 'no').session;
      expect(visibles(s), isNot(contains(hijo)));
      s = rules.select(s, padre, 'no_se').session;
      expect(visibles(s), isNot(contains(hijo)));
      s = rules.select(s, padre, 'si').session;
      expect(visibles(s), contains(hijo));
      // Cambiar a «No» lo borra junto con lo que se eligió.
      s = rules.select(s, hijo, 'z1').session;
      final r = rules.select(s, padre, 'no');
      expect(r.prunedQuestionIds, contains(hijo));
      expect(r.session.answers.keys, isNot(contains(hijo)));
    });

    test('Sí y los documentos elegidos forman una sola declaración', () {
      var s = rules.startJourney(ctx, purpose: GuidedPurpose.reply);
      s = rules.select(s, padre, 'si').session;
      expect(decir(s), 'Sí, traje documentos relacionados con mi solicitud.');
      s = rules.select(s, hijo, 'z1').session;
      s = rules.select(s, hijo, 'z2').session;
      expect(
        decir(s),
        'Sí, traje documentos relacionados con mi solicitud. '
        'Traje mi cédula de identidad y mi certificado de nacimiento.',
      );
    });

    test('cada tarjeta de documento es una sola seña y hay «otro» escrito', () {
      final q = bank.question(hijo)!;
      for (final o in q.options) {
        expect(o.glosses, hasLength(1), reason: o.id);
      }
      expect(q.option('otro')!.editor, 'texto_detalle');
      expect(q.option('no_se')!.isExit, isTrue);
    });

    test('toda pregunta de documentos con institución conocida lo tiene', () {
      final conDetalle = {
        for (final q in preguntas)
          if ((q['id'] as String).endsWith('.docs')) q['id'] as String,
      };
      expect(conDetalle.length, greaterThanOrEqualTo(40));
      for (final id in conDetalle) {
        final padreId = id.substring(0, id.length - '.docs'.length);
        expect(bank.question(padreId), isNotNull, reason: id);
      }
    });
  });

  group('una indicación se contesta diciendo cuál es', () {
    final indicaciones = [
      for (final q in preguntas)
        if (q['acto'] == 'indicacion' &&
            (q['opciones'] as List<dynamic>).any(
              (o) => (o as Map<String, dynamic>)['id'] == 'entendido',
            ))
          q,
    ];

    test('«Entendido» y «No entiendo» siguen igual', () {
      expect(indicaciones.length, greaterThanOrEqualTo(40));
      for (final q in indicaciones) {
        final b = bank.question(q['id'] as String)!;
        expect(b.option('entendido')!.phrase, 'Entendido.');
        expect(b.option('entendido')!.glosses, ['COMPRENDER']);
        expect(b.option('no_entiendo')!.phrase, 'No entiendo.');
        expect(b.option('no_entiendo')!.glosses, ['COMPRENDER', 'NO']);
      }
    });

    test('además hay respuestas que nombran la indicación', () {
      for (final q in indicaciones) {
        final b = bank.question(q['id'] as String)!;
        final ind = (q['formulacion'] as String).trim().replaceAll(
          RegExp(r'[.!]+$'),
          '',
        );
        final si = b.option('respuesta_con_contexto_si')!;
        final no = b.option('respuesta_con_contexto_no')!;
        expect(si.phrase, contains('«$ind»'), reason: q['id'] as String);
        expect(no.phrase, contains('«$ind»'), reason: q['id'] as String);
        expect(si.glosses.last, 'COMPRENDER');
        expect(no.glosses.sublist(no.glosses.length - 2), ['COMPRENDER', 'NO']);
      }
    });
  });
}
