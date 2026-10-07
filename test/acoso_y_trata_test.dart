import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/case_search.dart';

/// Acoso y trata en el léxico y en los trámites; respuestas cortas y largas
/// a las indicaciones del funcionario; el robo en FELCC sin repetir el de
/// Denuncias.
void main() {
  final bank = RagTramites.bankWithTramites();
  final catalogo = PendingSignCatalog.fromJsonString(
    File('assets/dictionary/senas_sin_sena.json').readAsStringSync(),
  );

  List<BankQuestion> preguntas(String journey) => [
    for (final s in bank.journey(journey)!.steps) bank.question(s.questionId)!,
  ];

  group('léxico: qué es cada término', () {
    for (final termino in const [
      'BULLYING',
      'ACOSO',
      'ACOSO_SEXUAL',
      'CIBERACOSO',
      'ACOSO_FISICO',
      'ACOSO_DISCRIMINATORIO',
      'TRATA_Y_TRAFICO',
    ]) {
      test('$termino se explica con señas de los módulos', () {
        final info = catalogo.infoOf('${PendingSign.prefix}$termino');
        expect(info.description, isNotEmpty);
        expect(info.lsbDescription, isNotEmpty);
        // Directa: ninguna palabra en azul dentro de la descripción.
        expect(info.lsbDescription.where(PendingSign.isPending), isEmpty);
      });
    }

    test('lo que escribe la persona en Voz a LSB encuentra su descripción', () {
      expect(catalogo.describedGloss('ciberacoso'), isNotNull);
      expect(catalogo.describedGloss('bullying'), isNotNull);
      expect(catalogo.describedGloss('acoso'), isNotNull);
    });
  });

  group('trámites nuevos', () {
    const nuevos = {
      'tramite_dna_201': 'Bullying en la escuela',
      'tramite_felcv_201': 'Denunciar acoso sexual',
      'tramite_felcc_201': 'Denunciar ciberacoso',
      'tramite_felcc_202': 'Acoso físico: una persona me sigue y me toca',
      'tramite_lsb_201': 'Acoso discriminatorio por ser sordo',
      'tramite_felcc_203': 'Denunciar trata y tráfico de personas',
    };

    test('cada uno está en la lista de su institución', () {
      final nombres = {for (final c in RagTramites.contexts) c.id: c.name};
      final enSeccion = {for (final s in RagTramites.sections) ...s.contextIds};
      nuevos.forEach((id, nombre) {
        expect(nombres[id], nombre, reason: id);
        expect(enSeccion, contains(id), reason: id);
        expect(preguntas(id).length, greaterThanOrEqualTo(4), reason: id);
      });
    });

    test('las tarjetas de la persona sorda llevan solo señas del léxico', () {
      for (final id in nuevos.keys) {
        for (final q in preguntas(id)) {
          for (final o in q.options) {
            expect(
              o.glosses.where(PendingSign.isPending),
              isEmpty,
              reason: '$id ${q.id} «${o.phrase}»',
            );
          }
        }
      }
    });

    test('el buscador los encuentra como lo diría la persona', () {
      final buscador = CaseSearch.fromCatalog(bank);
      List<String> casos(String q) => [
        for (final g in buscador.search(q, perGroup: 1000))
          for (final h in g.hits)
            if (h.entry.kind == CaseHitKind.context) h.entry.title,
      ];
      expect(casos('bulling'), contains('Bullying en la escuela'));
      expect(casos('me acosan por internet'), contains('Denunciar ciberacoso'));
      expect(casos('acoso sexual'), contains('Denunciar acoso sexual'));
      expect(
        casos('discriminacion sordo'),
        contains('Acoso discriminatorio por ser sordo'),
      );
      expect(casos('trata'), contains('Denunciar trata y tráfico de personas'));
    });
  });

  group('indicaciones: respuestas cortas y largas', () {
    test('«Llegar a oficina incorrecta» ofrece también lo que se responde', () {
      for (final q in preguntas('tramite_felcc_04')) {
        final ids = [for (final o in q.options) o.id];
        expect(ids.take(2), ['entendido', 'no_entiendo'], reason: q.id);
        expect(
          ids.where((id) => id.startsWith('respuesta_')),
          isNotEmpty,
          reason: '${q.id}: falta la respuesta larga',
        );
      }
    });

    test('dos «Entendido» seguidos se dicen una vez', () {
      final composer = GuidedComposer(bank);
      final pasos = [
        for (final s in bank.journey('tramite_felcc_04')!.steps) s.questionId,
      ];
      GuidedAnswer respuesta(String q, String opcion) => GuidedAnswer(
        questionId: q,
        state: GuidedAnswerState.affirmed,
        optionIds: [opcion],
      );
      final dos = composer.compose(
        GuidedIntervention(
          journeyId: 'tramite_felcc_04',
          purpose: GuidedPurpose.standalone,
          answers: [for (final q in pasos) respuesta(q, 'entendido')],
        ),
      );
      expect(dos, 'Entendido.');
      final largas = composer.compose(
        GuidedIntervention(
          journeyId: 'tramite_felcc_04',
          purpose: GuidedPurpose.standalone,
          answers: [
            respuesta(pasos.first, 'entendido'),
            respuesta(pasos.last, 'respuesta_1'),
          ],
        ),
      );
      expect(largas, startsWith('Entendido. '));
      expect(largas, 'Entendido. ¿Dónde tengo que ir?');
    });
  });

  test('el robo en FELCC sigue al de Denuncias sin repetir cuándo ni '
      'dónde', () {
    final felcc = preguntas('tramite_felcc_01');
    expect(
      RagTramites.contexts.firstWhere((c) => c.id == 'tramite_felcc_01').name,
      'Robo de celular: pruebas y seguimiento',
    );
    for (final q in felcc) {
      final f = q.formulation.toLowerCase();
      expect(f, isNot(contains('cuándo')), reason: q.id);
      expect(f, isNot(contains('dónde ocurrió')), reason: q.id);
    }
    // Lo que agrega: pruebas, testigos, cámaras y seguimiento.
    final todo = felcc.map((q) => q.formulation).join(' ');
    for (final tema in const ['caja', 'testigos', 'cámaras', 'investigará']) {
      expect(todo, contains(tema));
    }
  });
}
