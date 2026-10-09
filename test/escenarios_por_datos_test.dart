import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/lsb_gloss_semantics.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/guided/bank_contexts.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_proposal.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank_data.g.dart';
import 'package:lsb_legal_app/core/domain/services/context_catalog.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

/// Ampliar escenarios con datos, no con código.
///
/// Un recorrido nuevo que declara su `contexto` en el banco aparece en su
/// familia, lo abre el grafo de conversación y se responde con el flujo
/// guiado de siempre. Lo que antes eran casos especiales en Dart (qué dato
/// recoge una puerta, qué pregunta responde a cada zona del oyente) es
/// configuración del banco. Y cualquier clasificador solo puede proponer
/// identificadores del banco, que un validador determinista acepta o
/// rechaza sin elegir nada.
DialogueGraph _grafo() => DialogueGraph.fromJsonString(
  File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
);

/// El banco empaquetado más un recorrido nuevo declarado solo con datos,
/// que reutiliza preguntas que ya existen.
QuestionBank _bancoConEscenarioNuevo() {
  final data = jsonDecode(kQuestionBankJson) as Map<String, dynamic>;
  (data['recorridos'] as Map<String, dynamic>)['extravio_documento'] = {
    'nombre': 'Pérdida de un objeto o documento',
    'contexto': {
      'nombre': 'Perdí algo',
      'familia': 'tramites',
      'descripcion': 'Pérdida del carnet, el celular u otro objeto',
      'emoji': '📄',
    },
    'pasos': [
      {'pregunta': 'Q.FALTA.QUE', 'obligatoria': true},
      {'pregunta': 'Q.TIE.CUANDO'},
      {'pregunta': 'Q.LUG.DONDE'},
    ],
  };
  return QuestionBank(data);
}

void main() {
  group('un escenario nuevo solo con datos', () {
    final bank = _bancoConEscenarioNuevo();

    test('se convierte en un contexto de su familia', () {
      final contexts = BankContexts.fromBank(bank);
      expect(contexts.map((c) => c.id), ['derivacion', 'extravio_documento']);
      final c = contexts.firstWhere((c) => c.id == 'extravio_documento');
      expect(c.name, 'Perdí algo');
      expect(c.emoji, '📄');
      expect(BankContexts.idsOfFamily(bank, 'tramites'), [
        'extravio_documento',
      ]);
      expect(BankContexts.idsOfFamily(bank, 'denuncias'), isEmpty);
    });

    test('el grafo de conversación lo conoce y lo puede abrir', () {
      final catalog = ConversationGraphCatalog(bank: bank, graph: _grafo());
      expect(catalog.context('extravio_documento'), isNotNull);
      expect(
        catalog.contextsOfFamily('tramites'),
        contains('extravio_documento'),
      );
      expect(catalog.familyOf('extravio_documento'), 'tramites');
      expect(catalog.journeysOf('Q.FALTA.QUE'), contains('extravio_documento'));
      // Sus propias palabras lo nombran («perd…»), como a los demás.
      expect(catalog.contextStems['extravio_documento'], isNotEmpty);
    });

    test('se responde con el flujo guiado y el compositor de siempre', () {
      final rules = GuidedFlow(bank);
      var session = rules.startJourney('extravio_documento');
      expect(rules.firstQuestion(session), 'Q.FALTA.QUE');
      expect(rules.offeredOptions(session, 'Q.FALTA.QUE'), isNotEmpty);

      final outcome = rules.select(session, 'Q.FALTA.QUE', 'celular');
      expect(outcome.accepted, isTrue);
      session = outcome.session;
      final text = GuidedComposer(bank).compose(session.toIntervention());
      expect(text, isNotEmpty);
      expect(text.toLowerCase(), contains('celular'));
      expect(rules.glossesOf(session.toIntervention()), ['CELULAR']);
    });

    test('el banco empaquetado declara solo «Derivación» con datos', () {
      // Los demás recorridos tienen su contexto escrito a mano. «Derivación»
      // («¿Sabe a dónde tiene que ir?», QA 2026-10-09) es el primero que se
      // declaró con datos, en la familia Consultas.
      expect(BankContexts.contexts.map((c) => c.id), ['derivacion']);
      expect(BankContexts.ofFamily('consultas').map((c) => c.id), [
        'derivacion',
      ]);
      final seleccionables = {for (final c in allSelectableContexts) c.id};
      for (final id in QuestionBank.generated().journeys.keys) {
        expect(seleccionables, contains(id), reason: id);
      }
      for (final f in contextFamilies) {
        expect(
          contextsOfFamily(f).map((c) => c.id),
          containsAll(f.contextIds.where((id) => contextById(id) != null)),
        );
      }
    });
  });

  group('ranuras y zonas del oyente como configuración', () {
    final bank = QuestionBank.generated();

    test('las zonas del oyente son las de siempre, ahora en el banco', () {
      expect(bank.listenerZoneQuestions, {
        'tiempo': ['Q.TIE.CUANDO', 'Q.SEG.FECHA_PROGRAMADA'],
        'lugar': ['Q.LUG.DONDE'],
        'conocimiento': ['Q.PER.CONOCE'],
        'persona': [
          'Q.PER.DESCRIBIR',
          'Q.VIO.AGRESOR',
          'Q.DIG.REMITENTE',
          'Q.DIN.RECEPTOR',
          'Q.PER.OBSERVADA',
        ],
        'objetos': ['Q.ROB.QUE'],
        'testigos': ['Q.TES.EXISTE'],
        'evidencia': ['Q.EVI.QUE_TIENE', 'Q.DIG.GUARDO', 'Q.DIN.COMPROBANTE'],
        'emergencia': ['Q.SAL.HERIDO'],
        'denuncia': ['Q.DEN.INTENCION'],
        'apoyo_legal': ['Q.VIO.ASISTENCIA_ESPECIALIZADA'],
        'institucion_autoridad': ['Q.DEN.AUTORIDAD', 'Q.SEG.AUTORIDAD'],
        'identidad': ['Q.ID.NOMBRE'],
        'edad': ['Q.ID.EDAD_PROPIA'],
      });
      for (final ids in bank.listenerZoneQuestions.values) {
        for (final id in ids) {
          expect(bank.question(id), isNotNull, reason: id);
        }
      }
    });

    test('las puertas recogen el dato que declara el banco', () {
      final catalog = ConversationGraphCatalog(bank: bank, graph: _grafo());
      const esperado = {
        'Q.PER.CONOCE': 'person',
        'Q.PER.RECONOCE': 'person',
        'Q.ROB.VIO_LADRON': 'person',
        'Q.VIO.AGRESOR': 'person',
        'Q.PER.DESCRIBIR': 'description',
      };
      for (final e in esperado.entries) {
        expect(bank.question(e.key)!.slots, [e.value], reason: e.key);
        expect(catalog.answerSlotsOf(e.key), contains(e.value), reason: e.key);
      }
    });

    test('toda ranura declarada es del vocabulario común', () {
      final catalog = ConversationGraphCatalog(bank: bank, graph: _grafo());
      for (final q in bank.allQuestions) {
        for (final s in q.slots) {
          expect(catalog.knownSlots, contains(s), reason: '${q.id}: $s');
          expect(LsbGlossSemantics.slotVocabulary, contains(s));
        }
      }
    });
  });

  group('respuestas propuestas', () {
    final bank = QuestionBank.generated();
    final rules = GuidedFlow(bank);
    final proposals = GuidedProposals(rules);
    final session = rules.startJourney(
      'denuncia_robo',
      purpose: GuidedPurpose.reply,
    );

    GuidedProposal modelo(
      String q,
      String o, [
      Map<String, Object?>? valores,
    ]) => GuidedProposal(
      questionId: q,
      optionId: o,
      values: valores,
      source: ProposalSource.model,
    );

    test('lo que nombra el oyente se sugiere en las preguntas que lo '
        'responden, sin elegirlo', () {
      final p = proposals.fromHearingText(session, '¿Le robaron su celular?');
      expect(
        p.map((x) => x.key),
        containsAll(['Q.ROB.QUE/celular', 'Q.FALTA.QUE/celular']),
      );
      expect(p.every((x) => x.source == ProposalSource.hearingMention), isTrue);
      expect(p.first.evidence, 'celular');
      final review = proposals.review(session, p);
      expect(review.proposalFor('Q.ROB.QUE', 'celular'), isNotNull);
      expect(session.answers, isEmpty, reason: 'sugerir no es elegir');
    });

    test('una mención negada no se sugiere', () {
      for (final t in [
        '¿No le robaron el celular?',
        'Nadie tocó su mochila',
        'Nunca tuvo celular',
      ]) {
        expect(proposals.fromHearingText(session, t), isEmpty, reason: t);
      }
    });

    test('la palabra tiene que estar entera', () {
      expect(proposals.fromHearingText(session, '¿Celulares?'), isNotEmpty);
      expect(proposals.fromHearingText(session, '¿Gorrazo?'), isEmpty);
    });

    test('un clasificador no puede inventar preguntas, opciones ni señas', () {
      final review = proposals.review(
        session,
        GuidedProposal.fromModelJson({
          'respuestas': [
            {'pregunta': 'Q.ROB.QUE', 'opcion': 'celular'},
            {'pregunta': 'Q.ROB.QUE', 'opcion': 'zapato'},
            {'pregunta': 'Q.INVENTADA', 'opcion': 'si'},
            {'pregunta': 'Q.DIG.REMITENTE', 'opcion': 'desconocido'},
            {'opcion': 'sin pregunta'},
            'basura',
          ],
        }),
      );
      expect(review.accepted.map((p) => p.key), ['Q.ROB.QUE/celular']);
      final motivos = {
        for (final r in review.rejected) r.proposal.key: r.reason,
      };
      expect(motivos['Q.ROB.QUE/zapato'], ProposalRejection.unknownOption);
      expect(motivos['Q.INVENTADA/si'], ProposalRejection.unknownQuestion);
      expect(
        motivos['Q.DIG.REMITENTE/desconocido'],
        ProposalRejection.notInJourney,
      );
      expect(motivos, hasLength(3), reason: 'lo mal formado ni se lee');
    });

    test('la polaridad la pone el banco: Sí y No a la vez piden aclarar', () {
      final review = proposals.review(session, [
        modelo('Q.PER.CONOCE', 'si'),
        modelo('Q.PER.CONOCE', 'no'),
      ]);
      expect(review.accepted, isEmpty);
      expect(review.needsClarification, {'Q.PER.CONOCE'});
      expect(review.rejected.map((r) => r.reason).toSet(), {
        ProposalRejection.conflicting,
      });
      // Una sola respuesta de sí/no sí se sugiere, con su estado del banco.
      final una = proposals.review(session, [modelo('Q.PER.CONOCE', 'no')]);
      expect(una.accepted.single.optionId, 'no');
      expect(
        bank.question('Q.PER.CONOCE')!.option('no')!.state,
        isNot(bank.question('Q.PER.CONOCE')!.option('si')!.state),
      );
    });

    test('«No sé» no convive con otra respuesta de la misma pregunta', () {
      final review = proposals.review(session, [
        modelo('Q.ROB.QUE', 'celular'),
        modelo('Q.ROB.QUE', 'no_sabe'),
      ]);
      expect(review.needsClarification, {'Q.ROB.QUE'});
      // Varias respuestas compatibles de selección múltiple sí.
      final varias = proposals.review(session, [
        modelo('Q.ROB.QUE', 'celular'),
        modelo('Q.ROB.QUE', 'mochila'),
      ]);
      expect(varias.accepted, hasLength(2));
    });

    test('las cantidades y los valores escritos se validan igual que en el '
        'editor', () {
      final review = proposals.review(session, [
        modelo('Q.ROB.QUE', 'dinero', {'monto': '500', 'moneda': 'Bs'}),
        modelo('Q.TIE.CUANDO', 'hace_min'),
        modelo('Q.FALTA.QUE', 'dinero', {'monto': 'mucho', 'moneda': 'Bs'}),
      ]);
      expect(review.accepted.map((p) => p.key), ['Q.ROB.QUE/dinero']);
      expect(review.accepted.single.values, {'monto': '500', 'moneda': 'Bs'});
      final motivos = {
        for (final r in review.rejected) r.proposal.key: r.reason,
      };
      expect(motivos['Q.TIE.CUANDO/hace_min'], ProposalRejection.needsValue);
      expect(motivos['Q.FALTA.QUE/dinero'], ProposalRejection.invalidValue);
    });

    test('una opción oculta en el paso no se sugiere', () {
      final paso = session.steps.firstWhere((s) => s.hiddenOptions.isNotEmpty);
      final review = proposals.review(session, [
        modelo(paso.questionId, paso.hiddenOptions.first),
      ]);
      expect(review.rejected.single.reason, ProposalRejection.hiddenOption);
    });

    test('confirmar una sugerencia es elegirla con las reglas de siempre', () {
      final review = proposals.review(
        session,
        proposals.fromHearingText(session, '¿Le robaron su celular?'),
      );
      final p = review.proposalFor('Q.ROB.QUE', 'celular')!;
      // Q.ROB.QUE solo se alcanza tras «robar»: la sugerencia espera.
      expect(rules.select(session, p.questionId, p.optionId).accepted, isFalse);
      final tras = rules.select(session, 'Q.HEC.QUE_OCURRIO', 'robar').session;
      final elegida = rules.select(tras, p.questionId, p.optionId);
      expect(elegida.accepted, isTrue);
      expect(
        GuidedComposer(bank).compose(elegida.session.toIntervention()),
        'Me robaron el celular.',
      );
    });
  });
}
