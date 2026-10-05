import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/rag/tramites_data.g.dart';

/// Un trámite con ramificaciones y composición tal como lo genera
/// `tool/build_rag_corpus.py` desde `tool/tests/fixtures/escenario_ramificado.md`
/// (la prueba de Python comprueba que este archivo está al día).
QuestionBank _bancoConElTramite() {
  final tramite =
      jsonDecode(
            File(
              'test/fixtures/rag_tramite_ramificado.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final base = QuestionBank.generated().data;
  return QuestionBank({
    ...base,
    'preguntas': [
      ...base['preguntas'] as List<dynamic>,
      ...tramite['preguntas'] as List<dynamic>,
    ],
    'recorridos': {
      ...base['recorridos'] as Map<String, dynamic>,
      ...tramite['recorridos'] as Map<String, dynamic>,
    },
  });
}

void main() {
  const cedula = 'R.ESC-DDRR-90.1';
  const documentos = 'R.ESC-DDRR-90.3';
  const fotocopia = 'R.ESC-DDRR-90.5';
  const dondeEsta = 'R.ESC-DDRR-90.7';

  final bank = _bancoConElTramite();
  final rules = GuidedFlow(bank);
  final composer = GuidedComposer(bank);

  Set<String> visibles(GuidedSession s) => {
    for (final step in s.steps)
      if (rules.isReachable(s, step)) step.questionId,
  };

  group('«¿Trajo su cédula de identidad?» ramifica', () {
    test(
      'al principio solo se ve la pregunta de la que dependen las demás',
      () {
        final s = rules.startJourney('tramite_ddrr_90');
        expect(s.currentQuestionId, cedula);
        expect(visibles(s), {cedula});
      },
    );

    test('cada respuesta abre su propia pregunta siguiente', () {
      var s = rules.startJourney('tramite_ddrr_90');
      s = rules.select(s, cedula, 'si').session;
      expect(visibles(s), {cedula, documentos});
      s = rules.select(s, cedula, 'no').session;
      expect(visibles(s), {cedula, fotocopia});
      // «Turno 7: si Turno 1 = «No sé si la traje.»»: la rama se declaró
      // sobre esa frase y vale por su estado, el de NO SÉ.
      s = rules.select(s, cedula, 'no_se').session;
      expect(visibles(s), {cedula, dondeEsta});
    });

    test('se responde con SÍ, NO y NO SÉ: una seña cada una', () {
      final q = bank.question(cedula)!;
      expect(q.isPolar, isTrue);
      expect(
        [
          for (final o in q.options)
            '${o.id} ${o.glosses.join('+')} «${o.phrase}» ${o.state.wireName}',
        ],
        [
          // Lo que se dice al elegirla es la respuesta documentada de ese
          // estado: una frase completa que se entiende sola.
          'si SÍ «Sí, traje mi cédula.» afirmado',
          'no NO «No, no traje mi cédula.» negado',
          'no_se NO_SABER «No sé si la traje.» desconocido',
        ],
      );
      var s = rules.startJourney(
        'tramite_ddrr_90',
        purpose: GuidedPurpose.reply,
      );
      s = rules.select(s, cedula, 'si').session;
      final inter = s.toIntervention();
      // Lo elegido y lo que hace el avatar: la seña SÍ.
      expect(rules.glossesOf(inter), ['SÍ']);
      expect(composer.compose(inter), 'Sí, traje mi cédula.');
      s = rules.select(s, cedula, 'no').session;
      expect(s.answers[cedula]!.optionIds, ['no']);
    });

    test('sin respuesta documentada de un estado, la partícula sola', () {
      final q = bank.question(fotocopia)!;
      expect(q.option('no_se')!.phrase, 'No sé.');
    });

    test('al cambiar la respuesta se borra lo que dependía de ella', () {
      var s = rules.startJourney('tramite_ddrr_90');
      s = rules.select(s, cedula, 'si').session;
      s = rules.select(s, documentos, 'z1').session;
      expect(s.answers.keys, containsAll([cedula, documentos]));

      final cambio = rules.select(s, cedula, 'no');
      expect(cambio.prunedQuestionIds, [documentos]);
      expect(cambio.session.answers.keys, [cedula]);
    });

    test('la pregunta hija que hace el oyente sí se puede responder', () {
      // Así la abre la ruta del RAG (auditoría H5): sola y presupuesta.
      final s = rules.startJourney(
        'tramite_ddrr_90',
        onlySteps: [fotocopia],
        requestedQuestionIds: [fotocopia],
      );
      expect(s.currentQuestionId, fotocopia);
      expect(rules.select(s, fotocopia, 'no').accepted, isTrue);
    });

    test('una pregunta que no se ve no se puede responder', () {
      final s = rules.startJourney('tramite_ddrr_90');
      final intento = rules.select(s, fotocopia, 'si');
      expect(intento.accepted, isFalse);
      expect(intento.rejection, SelectionRejection.unreachable);
    });

    test('Sí, No y No sé se excluyen entre sí', () {
      var s = rules.startJourney('tramite_ddrr_90');
      s = rules.select(s, cedula, 'si').session;
      s = rules.select(s, cedula, 'no_se').session;
      expect(s.answers[cedula]!.optionIds, ['no_se']);
      expect(s.answers[cedula]!.state, GuidedAnswerState.unknown);
    });
  });

  group('«¿Qué documentos trajo?» junta tarjetas', () {
    GuidedSession conCedula() => rules
        .select(rules.startJourney('tramite_ddrr_90'), cedula, 'si')
        .session;

    test(
      'solo ofrece señas sueltas de lo que respondieron a esta pregunta',
      () {
        final q = bank.question(documentos)!;
        expect(q.isMultiple, isTrue);
        expect(q.maxPicks, 3);
        // PAPEL no: «documentos» ya es lo que pregunta.
        expect(
          [for (final o in q.options) o.glosses],
          [
            ['CERTIFICADO'],
            ['FOTOCOPIA'],
            ['FACTURA'],
          ],
        );
      },
    );

    test('la selección es independiente y se compone con su frase', () {
      var s = conCedula();
      s = rules.select(s, documentos, 'z1').session;
      s = rules.select(s, documentos, 'z2').session;
      expect(s.answers[documentos]!.optionIds, ['z1', 'z2']);
      expect(
        composer.compose(s.toIntervention()),
        contains('Traje un certificado y una fotocopia.'),
      );
      // Quitar una tarjeta deja la otra.
      s = rules.deselect(s, documentos, 'z1').session;
      expect(
        composer.compose(s.toIntervention()),
        contains('Traje una fotocopia.'),
      );
    });
  });

  test(
    'los trámites generados no dependen de preguntas ajenas o posteriores',
    () {
      final data = jsonDecode(kRagTramitesJson) as Map<String, dynamic>;
      final preguntas = {
        for (final q in data['preguntas'] as List<dynamic>)
          (q as Map<String, dynamic>)['id'] as String: q,
      };
      for (final MapEntry(key: id, value: raw)
          in (data['recorridos'] as Map<String, dynamic>).entries) {
        final journey = BankJourney.fromJson(id, raw as Map<String, dynamic>);
        final antes = <String>{};
        for (final step in journey.steps) {
          final q = preguntas[step.questionId] as Map<String, dynamic>;
          for (final c in step.conditions) {
            expect(antes, contains(c.questionId), reason: step.questionId);
          }
          // Cada tarjeta es una seña (o una seña con su negación: «No
          // entiendo» = COMPRENDER NO), nunca una frase entera, y nunca una
          // seña que falta; su español va aparte.
          for (final o in q['opciones'] as List<dynamic>) {
            final opcion = o as Map<String, dynamic>;
            final glosas = (opcion['glosas'] as List<dynamic>).cast<String>();
            expect(
              glosas.length,
              inInclusiveRange(1, 2),
              reason: opcion['frase'],
            );
            if (glosas.length == 2) expect(glosas.last, 'NO');
            expect(
              glosas.any((g) => g.startsWith('SENA_PENDIENTE:')),
              isFalse,
              reason: opcion['frase'],
            );
            expect(opcion['frase'], isNotEmpty);
          }
          antes.add(step.questionId);
        }
      }
    },
  );
}
