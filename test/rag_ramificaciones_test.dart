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
      s = rules.select(s, cedula, 'r1').session; // Sí
      expect(visibles(s), {cedula, documentos});
      s = rules.select(s, cedula, 'r2').session; // No
      expect(visibles(s), {cedula, fotocopia});
      s = rules.select(s, cedula, 'r3').session; // No sé
      expect(visibles(s), {cedula, dondeEsta});
    });

    test('se responde con las unidades SÍ, NO y NO SÉ', () {
      final q = bank.question(cedula)!;
      expect(q.isPolar, isTrue);
      expect(
        [
          for (final o in q.options.take(3))
            '${o.id} ${o.glosses.join('+')} «${o.phrase}» ${o.state.wireName}',
        ],
        [
          'si SÍ «Sí.» afirmado',
          'no NO «No.» negado',
          'no_se NO_SABER «No sé.» desconocido',
        ],
      );
      var s = rules.startJourney(
        'tramite_ddrr_90',
        purpose: GuidedPurpose.reply,
      );
      s = rules.select(s, cedula, 'si').session;
      // Una rama declarada por estado se abre igual con la unidad.
      expect(visibles(s), {cedula, documentos});
      final inter = s.toIntervention();
      // Lo elegido, lo que hace el avatar y lo que se envía coinciden.
      expect(rules.glossesOf(inter), ['SÍ']);
      expect(composer.compose(inter), 'Sí.');
      s = rules.select(s, cedula, 'no').session;
      expect(visibles(s), {cedula, fotocopia});
      expect(s.answers[cedula]!.optionIds, ['no']);
    });

    test('una rama declarada sobre una respuesta concreta pide esa '
        'respuesta', () {
      // «Turno 7: si Turno 1 = «No sé si la traje.»»: la unidad NO SÉ no
      // dice lo mismo, así que no abre la pregunta.
      var s = rules.startJourney('tramite_ddrr_90');
      s = rules.select(s, cedula, 'no_se').session;
      expect(visibles(s), {cedula});
      s = rules.select(s, cedula, 'r3').session;
      expect(visibles(s), {cedula, dondeEsta});
    });

    test('al cambiar la respuesta se borra lo que dependía de ella', () {
      var s = rules.startJourney('tramite_ddrr_90');
      s = rules.select(s, cedula, 'r1').session;
      s = rules.select(s, documentos, 'z1').session;
      expect(s.answers.keys, containsAll([cedula, documentos]));

      final cambio = rules.select(s, cedula, 'r2');
      expect(cambio.prunedQuestionIds, [documentos]);
      expect(cambio.session.answers.keys, [cedula]);
      expect(
        composer.compose(cambio.session.toIntervention()),
        // Una declaración suelta no empieza con «No,»: el composer lo quita.
        'No traje mi cédula.',
      );
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
      final intento = rules.select(s, fotocopia, 'r1');
      expect(intento.accepted, isFalse);
      expect(intento.rejection, SelectionRejection.unreachable);
    });

    test('Sí, No y No sé se excluyen entre sí', () {
      var s = rules.startJourney('tramite_ddrr_90');
      s = rules.select(s, cedula, 'r1').session;
      s = rules.select(s, cedula, 'r3').session;
      expect(s.answers[cedula]!.optionIds, ['r3']);
      expect(s.answers[cedula]!.state, GuidedAnswerState.unknown);
    });
  });

  group('«¿Qué documentos trajo?» junta tarjetas', () {
    GuidedSession conCedula() => rules
        .select(rules.startJourney('tramite_ddrr_90'), cedula, 'r1')
        .session;

    test('solo ofrece lo que respondieron a esta pregunta', () {
      final q = bank.question(documentos)!;
      expect(q.isMultiple, isTrue);
      expect(q.maxPicks, 3);
      expect(
        [
          for (final o in q.options)
            if (!o.isExit) o.glosses,
        ],
        [
          ['CERTIFICADO'],
          ['FOTOCOPIA'],
          ['FACTURA'],
        ],
      );
    });

    test('la selección es independiente y se compone con su frase', () {
      var s = conCedula();
      s = rules.select(s, documentos, 'z1').session;
      s = rules.select(s, documentos, 'z2').session;
      expect(s.answers[documentos]!.optionIds, ['z1', 'z2']);
      expect(
        composer.compose(s.toIntervention()),
        'Traje mi cédula. Traje un certificado y una fotocopia.',
      );
      // Quitar una tarjeta deja la otra.
      s = rules.deselect(s, documentos, 'z1').session;
      expect(
        composer.compose(s.toIntervention()),
        'Traje mi cédula. Traje una fotocopia.',
      );
    });

    test('una frase documentada va sola y reemplaza a las tarjetas', () {
      var s = conCedula();
      s = rules.select(s, documentos, 'z1').session;
      final frase = rules.select(s, documentos, 'r1');
      expect(frase.replacedOptionIds, ['z1']);
      expect(
        composer.compose(frase.session.toIntervention()),
        'Traje mi cédula. Traje el certificado y la fotocopia.',
      );
      // Y una tarjeta reemplaza a la frase.
      s = rules.select(frase.session, documentos, 'z3').session;
      expect(s.answers[documentos]!.optionIds, ['z3']);
    });

    test('al responder al oyente se conserva el «Sí,» de la frase', () {
      var s = rules.startJourney(
        'tramite_ddrr_90',
        purpose: GuidedPurpose.reply,
      );
      s = rules.select(s, cedula, 'r1').session;
      s = rules.select(s, documentos, 'z3').session;
      expect(
        composer.compose(s.toIntervention()),
        'Sí, traje mi cédula. Traje la factura.',
      );
    });

    test('cada opción conserva su secuencia de glosas completa', () {
      final r1 = bank.question(documentos)!.option('r1')!;
      expect(r1.glosses, ['CERTIFICADO', 'FOTOCOPIA', 'TRAER']);
      expect(r1.label, 'Traje el certificado y la fotocopia.');
      // La fila muestra (y el avatar hace) toda la secuencia, no solo la
      // primera glosa.
      expect(r1.displayFormulation, 'CERTIFICADO · FOTOCOPIA · TRAER');
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
          // Cada opción tiene su secuencia y su español por separado.
          for (final o in q['opciones'] as List<dynamic>) {
            final opcion = o as Map<String, dynamic>;
            expect(opcion['glosas'], isNotEmpty, reason: opcion['frase']);
            expect(opcion['frase'], isNotEmpty);
          }
          antes.add(step.questionId);
        }
      }
    },
  );
}
