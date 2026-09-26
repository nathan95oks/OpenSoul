import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';

/// Precisión semántica del módulo LSB → texto/audio.
///
/// Todo lo que se prueba aquí vive en el dominio (banco + [GuidedFlow] +
/// [GuidedComposer]), no en los widgets: es lo que la conversación podrá
/// reutilizar después sin pasar por la pantalla.
void main() {
  final bank = QuestionBank.generated();
  final flow = GuidedFlow(bank);
  final composer = GuidedComposer(bank);

  GuidedSession pick(GuidedSession s, String question, String option,
      {Map<String, Object?>? values}) {
    final r = flow.select(s, question, option, values: values);
    expect(r.accepted, isTrue,
        reason: '$question/$option: ${r.rejection} ${r.message ?? ''}');
    return r.session;
  }

  Set<String> reachable(GuidedSession s) =>
      {for (final step in flow.reachableSteps(s)) step.questionId};

  String text(GuidedSession s) => composer.compose(s.toIntervention());

  group('P0: ningún hecho confirmado se pierde', () {
    test('varias selecciones en un relato: todas aparecen en la frase', () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'escapar');
      s = pick(s, 'Q.ROB.QUE', 'celular');
      s = pick(s, 'Q.ROB.QUE', 'dinero',
          values: {'monto': '500', 'moneda': 'Bs'});
      s = pick(s, 'Q.HEC.ESCAPE_ACTOR', 'autor');
      s = pick(s, 'Q.TIE.CUANDO', 'ayer');
      s = pick(s, 'Q.TIE.CUANDO', 'tarde');
      s = pick(s, 'Q.LUG.DONDE', 'calle', values: {'nombre': 'Heroínas'});
      s = pick(s, 'Q.PER.CONOCE', 'no');
      s = pick(s, 'Q.TES.EXISTE', 'si');
      s = pick(s, 'Q.TES.CANTIDAD', 'n', values: {'n': '2'});
      s = pick(s, 'Q.EVI.QUE_TIENE', 'si');
      s = pick(s, 'Q.EVI.TIPOS', 'fotos');
      s = pick(s, 'Q.EVI.TIPOS', 'video');
      s = pick(s, 'Q.DEN.INTENCION', 'si');
      s = pick(s, 'Q.DEN.AUTORIDAD', 'fiscalia');

      final intervention = s.toIntervention();
      final traced = composer.composeTraced(intervention);
      final confirmed = composer.confirmedFacts(intervention);

      expect(confirmed.difference(traced.represented), isEmpty,
          reason: 'confirmedFacts ⊆ representedFacts');
      final known = {
        for (final a in intervention.answers)
          for (final o in a.optionIds) '${a.questionId}#$o',
      };
      expect(traced.represented.difference(known), isEmpty,
          reason: 'representedFacts ⊆ explicitlyKnownFacts');

      final t = traced.text;
      for (final fragment in [
        'Me robaron el celular y Bs 500.',
        'La persona que me robó escapó.',
        'Ocurrió ayer por la tarde.',
        'Ocurrió en la calle Heroínas.',
        'No conozco a esa persona.',
        'Hay 2 testigos.',
        'Tengo fotos y un video.',
        'Quiero presentar una denuncia.',
        'Quiero presentarla ante la Fiscalía.',
      ]) {
        expect(t, contains(fragment));
      }
    });

    test('una pregunta hecha por el oyente fuera de su rama se redacta igual',
        () {
      // Antes: «¿Qué le robaron?» sin haber elegido ROBAR no llegaba a la
      // frase (fragmento sin nadie que lo citara).
      var s = flow.startJourney('denuncia_robo',
          purpose: GuidedPurpose.reply,
          requestedQuestionIds: const ['Q.ROB.QUE']);
      expect(s.currentQuestionId, 'Q.ROB.QUE');
      s = pick(s, 'Q.ROB.QUE', 'celular');
      expect(text(s), 'Me robaron el celular.');
    });

    test('una pregunta pedida que el recorrido no trae se añade como paso', () {
      var s = flow.startJourney('denuncia_robo',
          purpose: GuidedPurpose.reply,
          requestedQuestionIds: const ['Q.SAL.HERIDO']);
      expect(s.currentQuestionId, 'Q.SAL.HERIDO');
      s = pick(s, 'Q.SAL.HERIDO', 'no');
      expect(text(s), 'No estoy herido.');
    });
  });

  group('Sí / No / No sé', () {
    test('la pregunta polar solo ofrece Sí, No y No sé', () {
      final s = flow.startJourney('denuncia_robo');
      final ids = [
        for (final o in flow.offeredOptions(s, 'Q.PER.CONOCE')) o.id,
      ];
      expect(ids, ['si', 'no', 'no_sabe']);
      final glosas = {
        for (final o in bank.question('Q.PER.CONOCE')!.options) ...o.glosses,
      };
      expect(glosas, {'SÍ', 'NO', 'NO_SABER'},
          reason: 'PAREJA o AMIGO no responden «¿Conoce a esa persona?»');
    });

    test('Sí activa la pregunta dependiente de la relación', () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      expect(reachable(s), isNot(contains('Q.PER.VINCULO')));
      s = pick(s, 'Q.PER.CONOCE', 'si');
      expect(reachable(s), containsAll(['Q.PER.VINCULO', 'Q.PER.NOMBRE_TERCERO']));
      s = pick(s, 'Q.PER.VINCULO', 'pareja');
      expect(text(s), allOf(contains('Conozco a esa persona.'),
          contains('Es mi pareja.')));
    });

    test('No no activa el detalle y conserva la negación', () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      s = pick(s, 'Q.PER.CONOCE', 'no');
      expect(s.answerOf('Q.PER.CONOCE')!.state, GuidedAnswerState.denied);
      expect(reachable(s), isNot(contains('Q.PER.VINCULO')));
      expect(text(s), contains('No conozco a esa persona.'));
    });

    test('No sé queda como desconocido, nunca como no', () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      s = pick(s, 'Q.PER.CONOCE', 'no_sabe');
      expect(s.answerOf('Q.PER.CONOCE')!.state, GuidedAnswerState.unknown);
      expect(reachable(s), isNot(contains('Q.PER.VINCULO')));
      final t = text(s);
      expect(t, contains('No sé si la conozco.'));
      expect(t, isNot(contains('No conozco')));
    });

    test('cambiar Sí por No borra las respuestas que dependían del Sí', () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      s = pick(s, 'Q.PER.CONOCE', 'si');
      s = pick(s, 'Q.PER.VINCULO', 'amigo');
      final r = flow.select(s, 'Q.PER.CONOCE', 'no');
      expect(r.accepted, isTrue);
      expect(r.prunedQuestionIds, contains('Q.PER.VINCULO'));
      expect(text(r.session), isNot(contains('amigo')));
    });

    test('Sí y No no pueden quedar a la vez (lo impide el dominio)', () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.TES.EXISTE', 'si');
      s = pick(s, 'Q.TES.EXISTE', 'no');
      expect(s.answerOf('Q.TES.EXISTE')!.optionIds, ['no']);
      s = pick(s, 'Q.TES.EXISTE', 'no_sabe');
      expect(s.answerOf('Q.TES.EXISTE')!.optionIds, ['no_sabe']);
    });
  });

  group('detalles solo cuando corresponden', () {
    test('COMPROBANTE = No no pregunta el tipo; Sí lo pregunta', () {
      var s = flow.startJourney('engano_dinero');
      s = pick(s, 'Q.DIN.MECANISMO', 'banco');
      s = pick(s, 'Q.DIN.COMPROBANTE', 'no');
      expect(reachable(s), isNot(contains('Q.DIN.COMPROBANTE_TIPO')));
      expect(text(s), contains('No tengo comprobante.'));

      s = pick(s, 'Q.DIN.COMPROBANTE', 'si');
      expect(reachable(s), contains('Q.DIN.COMPROBANTE_TIPO'));
      s = pick(s, 'Q.DIN.COMPROBANTE_TIPO', 'banco');
      expect(text(s), contains('Tengo el comprobante del banco.'));

      // Volver a No borra el tipo que colgaba del Sí.
      s = pick(s, 'Q.DIN.COMPROBANTE', 'no_sabe');
      expect(s.answerOf('Q.DIN.COMPROBANTE_TIPO'), isNull);
      expect(text(s), contains('No sé si tengo comprobante.'));
    });

    test('la pregunta compuesta se divide en dos respuestas independientes', () {
      final compuesta = bank.question('Q.EVI.FACTURA_O_CAJA')!;
      expect(compuesta.isDerivation, isTrue);
      for (final journey in bank.journeys.values) {
        expect(journey.steps.map((s) => s.questionId),
            isNot(contains('Q.EVI.FACTURA_O_CAJA')));
      }
      // «¿Está herido o necesita atención médica?» son dos preguntas.
      var s = flow.startJourney('violencia');
      s = pick(s, 'Q.VIO.TIPO', 'pegar');
      expect(reachable(s), contains('Q.SAL.HERIDO'));
      expect(reachable(s), isNot(contains('Q.SAL.ASISTENCIA')));
      s = pick(s, 'Q.SAL.HERIDO', 'si');
      expect(reachable(s), contains('Q.SAL.ASISTENCIA'));
      s = pick(s, 'Q.SAL.ASISTENCIA', 'no');
      expect(text(s), allOf(contains('Estoy herido.'),
          contains('No necesito atención médica.')));
    });

    test('las glosas que formulan una pregunta nunca son su respuesta', () {
      for (final q in bank.allQuestions) {
        for (final o in q.options) {
          if (o.isExit || o.glosses.isEmpty) continue;
          expect(q.notOfferedGlosses, isNot(contains(o.glosses.first)),
              reason: '${q.id}/${o.id}');
        }
      }
    });
  });

  group('valores literales', () {
    test('500 Bs (BOB) se conserva exactamente, como un solo hecho', () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      s = pick(s, 'Q.ROB.QUE', 'dinero',
          values: {'monto': '500', 'moneda': 'Bs'});
      final json = jsonEncode(s.toIntervention().toJson());
      expect(json, contains('"dinero":{"monto":"500","moneda":"Bs"}'));
      expect(text(s), 'Me robaron Bs 500.');
    });

    test('el monto se guarda tal como se escribió', () {
      var s = flow.startJourney('engano_dinero');
      s = pick(s, 'Q.DIN.MECANISMO', 'mano');
      s = pick(s, 'Q.DIN.MONTO', 'monto',
          values: {'monto': '1.500,50', 'moneda': 'Bs'});
      expect(text(s), contains('Entregué Bs 1.500,50 en mano.'));
    });

    test('sin moneda elegida el monto no entra (no se inventa la moneda)', () {
      var s = flow.startJourney('engano_dinero');
      s = pick(s, 'Q.DIN.MECANISMO', 'mano');
      final r = flow.select(s, 'Q.DIN.MONTO', 'monto', values: {'monto': '500'});
      expect(r.accepted, isFalse);
      expect(r.rejection, SelectionRejection.invalidValue);
    });

    test('nombre, teléfono y número de documento se conservan literales', () {
      var s = flow.startJourney('identificacion');
      s = pick(s, 'Q.ID.NOMBRE', 'nombre', values: {'nombre': 'María Quispe'});
      s = pick(s, 'Q.ID.DOC_TIPO', 'carnet');
      s = pick(s, 'Q.ID.DOC_NUMERO', 'numero', values: {'numero': '4567890 CB'});
      s = pick(s, 'Q.ID.TELEFONO_PROPIO', 'telefono',
          values: {'telefono': '71234567'});
      final t = text(s);
      expect(t, contains('Me llamo María Quispe.'));
      expect(t, contains('El número de mi documento es 4567890 CB.'));
      expect(t, contains('Mi número de celular es 71234567.'));
    });
  });

  group('no inventa', () {
    test('persona + mensajes por celular: ni WhatsApp, ni Telegram, ni SMS', () {
      var s = flow.startJourney('amenaza_digital');
      s = pick(s, 'Q.DIG.CONTENIDO', 'amenazas');
      s = pick(s, 'Q.DIG.CANAL', 'celular');
      s = pick(s, 'Q.DIG.REMITENTE', 'hombre');
      final t = text(s).toLowerCase();
      for (final inventado in ['whatsapp', 'telegram', 'sms', 'facebook']) {
        expect(t, isNot(contains(inventado)));
      }
      expect(t, contains('me llegaron mensajes por celular.'));
    });

    test('elegir BILLETES o ENVIAR no afirma un engaño', () {
      var s = flow.startJourney('engano_dinero');
      s = pick(s, 'Q.DIN.MECANISMO', 'banco');
      expect(text(s).toLowerCase(), isNot(contains('engañ')));
      s = pick(s, 'Q.DIN.ENGANO', 'si');
      expect(text(s), contains('Me engañaron con dinero.'));
    });
  });

  group('relevancia', () {
    test('CONSULTAR AUDIENCIA (citación) no pregunta monto, agresor ni hospital',
        () {
      var s = flow.startJourney('seguimiento');
      s = pick(s, 'Q.SEG.MOTIVO', 'citacion');
      final visibles = reachable(s);
      expect(visibles, {
        'Q.SEG.MOTIVO',
        'Q.SEG.FECHA_PROGRAMADA',
        'Q.SEG.NUM_REFERENCIA',
        'Q.SEG.AUTORIDAD',
      });
      for (final id in visibles) {
        expect(id, isNot(anyOf(startsWith('Q.DIN.'), startsWith('Q.VIO.'),
            startsWith('Q.SAL.'), startsWith('Q.EVI.'), startsWith('Q.PER.'))));
      }
    });

    test('al principio solo se ve la intención general', () {
      for (final journey in bank.journeys.values) {
        final s = flow.startJourney(journey.id);
        expect(s.currentQuestionId, journey.steps.first.questionId);
      }
      final s = flow.startJourney('denuncia_robo');
      expect(reachable(s), isNot(contains('Q.ROB.QUE')),
          reason: '«¿Qué le robaron?» depende de haber dicho que le robaron');
    });
  });

  group('suficiencia', () {
    test('se puede terminar sin recorrer las preguntas opcionales', () {
      var s = flow.startJourney('denuncia_robo');
      expect(flow.canFinish(s), isFalse, reason: 'todavía no se dijo nada');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      expect(flow.canFinish(s), isTrue);
      expect(flow.nextQuestion(s), isNotNull,
          reason: 'quedan preguntas opcionales, y no son obligatorias');
    });

    test('lo que da sentido a otra respuesta sí es obligatorio', () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'escapar');
      expect(flow.canFinish(s), isFalse);
      expect(flow.missingRequired(s), ['Q.HEC.ESCAPE_ACTOR']);
      final omitir = flow.omit(s, 'Q.HEC.ESCAPE_ACTOR');
      expect(omitir.rejection, SelectionRejection.requiredQuestion);
      s = pick(s, 'Q.HEC.ESCAPE_ACTOR', 'no_sabe');
      expect(flow.canFinish(s), isTrue);
      expect(text(s), 'Alguien escapó, pero no sé quién.');
    });
  });

  group('máximos y estados en el dominio', () {
    test('superar el máximo se rechaza, no reemplaza en silencio', () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'danar');
      final r = flow.select(s, 'Q.HEC.QUE_OCURRIO', 'escapar');
      expect(r.rejection, SelectionRejection.maxReached);
      expect(r.session.answerOf('Q.HEC.QUE_OCURRIO')!.optionIds,
          ['robar', 'danar']);
    });

    test('«No sé» excluye al resto en una selección múltiple', () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      s = pick(s, 'Q.ROB.QUE', 'celular');
      s = pick(s, 'Q.ROB.QUE', 'no_sabe');
      expect(s.answerOf('Q.ROB.QUE')!.optionIds, ['no_sabe']);
      s = pick(s, 'Q.ROB.QUE', 'mochila');
      expect(s.answerOf('Q.ROB.QUE')!.optionIds, ['mochila']);
    });

    test('omitida y sin responder son estados distintos, y ninguno redacta',
        () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      expect(s.answerOf('Q.TES.EXISTE'), isNull, reason: 'sin responder');
      final r = flow.omit(s, 'Q.TES.EXISTE');
      expect(r.accepted, isTrue);
      s = r.session;
      expect(s.answerOf('Q.TES.EXISTE')!.state, GuidedAnswerState.omitted);
      expect(text(s), isNot(contains('testigo')));
      expect(jsonEncode(s.toIntervention().toJson()),
          contains('"estado":"omitido"'));
    });

    test('una opción que ya no corresponde sale al cambiar lo anterior', () {
      var s = flow.startJourney('denuncia_robo');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      s = pick(s, 'Q.HEC.QUE_OCURRIO', 'escapar');
      s = pick(s, 'Q.HEC.ESCAPE_ACTOR', 'autor');
      // Sin robo ya no hay «persona que me robó».
      final r = flow.deselect(s, 'Q.HEC.QUE_OCURRIO', 'robar');
      expect(r.session.answerOf('Q.HEC.ESCAPE_ACTOR'), isNull);
      expect(flow.missingRequired(r.session), ['Q.HEC.ESCAPE_ACTOR']);
    });

    test('una opción con editor obligatorio exige su valor', () {
      var s = flow.startJourney('identificacion');
      final r = flow.select(s, 'Q.ID.NOMBRE', 'nombre');
      expect(r.rejection, SelectionRejection.needsValue);
      s = pick(s, 'Q.ID.EDAD_PROPIA', 'edad', values: {'n': '30', 'aprox': 'si'});
      expect(text(s), 'Tengo 30 años.',
          reason: 'la edad propia no admite «aproximadamente»');
    });
  });
}
