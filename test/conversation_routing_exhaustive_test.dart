import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

/// Todas las preguntas del oyente de `casos_ruteo_conversacion.json` (corpus,
/// banco y paráfrasis, con la lectura real de la Lambda) pasan por el router
/// real del cliente. Ver `aws/tests/regenerar_casos_ruteo_conversacion.py`.
///
/// Con `REPORTE_RUTEO=<ruta>` escribe además el detalle de cada caso: lo que
/// preguntó el oyente y lo que ve la persona sorda para responder.
/// Casos que hoy no abren la pregunta esperada, con el motivo. Cualquier
/// falla fuera de esta lista es una regresión.
const _limitacionesConocidas = {
  // La familia «denuncias» comparte preguntas: sin testigos ni avisos en su
  // recorrido, el router abre el contexto hermano que sí los tiene (política
  // de `_placement`).
  'n-s6-testigos_fotos_v-01': 'testigos: el recorrido «otro» no los tiene',
  'n-s6-testigos_fotos_v-02': 'testigos: el recorrido «otro» no los tiene',
  'n-s6-seguimiento_prelim-10': 'Q.ID.AVISO es paso de identificación',
  // «¿Por dónde…?» se lee como lugar; aquí pregunta el canal.
  'banco:Q.DIG.CANAL@amenaza_digital': '«por dónde» leído como lugar',
  // PRUEBA no tiene seña: la traducción la deletrea y no queda contenido
  // con qué reconocer la pregunta.
  'parafrasis-25': 'PRUEBA sin seña; abre «¿Qué tiene?» (evidencia)',
};

void main() {
  final casos =
      (jsonDecode(
                File(
                  'aws/tests/casos_ruteo_conversacion.json',
                ).readAsStringSync(),
              )['casos']
              as List)
          .cast<Map<String, dynamic>>();

  late ConversationGraphCatalog catalog;
  late ConversationGraphRouter router;

  setUpAll(() {
    catalog = ConversationGraphCatalog(
      bank: QuestionBank.generated(),
      graph: DialogueGraph.fromJsonString(
        File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
      ),
    );
    router = ConversationGraphRouter(catalog);
  });

  SemanticTurn turnOf(Map<String, dynamic> c) => SemanticTurn.fromBackend(
    turnId: c['id'] as String,
    text: c['texto'] as String,
    speechAct: classifySpeechAct(c['texto'] as String),
    backend: BackendSemanticTurn.fromJson(c['semanticTurn'])!,
    glosses: List<String>.from(c['glosas'] as List),
  );

  /// La ruta abre la pregunta esperada en su contexto: la persona sorda la
  /// ve en el recorrido que se abre.
  ///
  /// Una puerta de control («¿Quiere describir a la persona?») se cumple
  /// abriendo las preguntas que abre: es lo que el oyente pidió.
  bool opens(ConversationRoute r, String context, String question) {
    if (!r.opensQuestions || r.targetContextId != context) return false;
    bool seen(String q) =>
        r.targetQuestionIds.contains(q) || r.pathQuestionIds.contains(q);
    if (seen(question)) return true;
    final opened = catalog.openedBy(context, question);
    return opened.isNotEmpty && opened.every(seen);
  }

  String? domainOf(String id) =>
      catalog.bank.questions[id]?['dominio'] as String?;

  /// El corpus liga algunas frases a preguntas que no son paso de ningún
  /// recorrido («¿Le robaron algún objeto?» → Q.ROB.ALGO). Abrir en el mismo
  /// contexto una pregunta del recorrido del mismo dominio («¿Qué le
  /// robaron?») responde lo mismo: se cuenta aparte, como equivalente.
  bool equivalent(ConversationRoute r, String context, String question) {
    if (r.targetContextId != context) return false;
    if (catalog.journeysOf(question).isNotEmpty) return false;
    final domain = domainOf(question);
    final opened = r.opensQuestions
        ? r.targetQuestionIds
        : [
            if (r.type == ConversationRouteType.directContext)
              ?catalog.bank.journey(context)?.steps.firstOrNull?.questionId,
          ];
    return domain != null && opened.any((q) => domainOf(q) == domain);
  }

  /// Resultado de un caso en una situación de la conversación.
  String outcome(ConversationRoute r, String context, String question) {
    if (opens(r, context, question)) return 'directa';
    // Abrir el contexto desde el principio es abrir esa pregunta si es su
    // primer paso («¿Qué vio?» en «otro»).
    if (r.type == ConversationRouteType.directContext &&
        r.targetContextId == context &&
        catalog.bank.journey(context)?.steps.firstOrNull?.questionId ==
            question) {
      return 'directa';
    }
    if (equivalent(r, context, question)) return 'equivalente';
    if (r.needsModel && r.candidates.any((c) => opens(c, context, question))) {
      return 'modelo';
    }
    return 'falla';
  }

  /// Primera pregunta de la conversación: sin contexto, una pregunta que
  /// vale en varios recorridos («¿Desea presentar una denuncia?») puede
  /// abrirse en cualquiera de ellos, o pedir que se elija.
  String outcomeAnywhere(ConversationRoute r, String question) {
    final contexts = {
      if (r.targetContextId != null) r.targetContextId!,
      for (final c in r.candidates)
        if (c.targetContextId != null) c.targetContextId!,
    };
    for (final c in contexts) {
      final result = outcome(r, c, question);
      if (result != 'falla') return result;
    }
    return 'falla';
  }

  Map<String, Object?> questionView(String id) {
    final q = catalog.bank.question(id)!;
    return {
      'id': id,
      'formulacion': q.formulation,
      'lsb': q.lsb.glosses,
      'opciones': [
        for (final o in q.options) {'etiqueta': o.label, 'glosas': o.glosses},
      ],
    };
  }

  test('cada pregunta del oyente abre la pregunta del banco que responde', () {
    final reporte = <Map<String, Object?>>[];
    final fallas = <String>[];
    var evaluados = 0;
    for (final c in casos) {
      if (c['preguntaEsperada'] == 'SELECTOR') continue;
      final context = c['contexto'] as String;
      final question = c['preguntaEsperada'] as String;
      // Solo lo que la app puede abrir: un contexto con recorrido y una
      // pregunta respondible (si no es un paso, el router la antepone).
      // `preguntas` es el recorrido donde la persona sorda pregunta al
      // funcionario: el oyente no formula esas preguntas.
      if (!catalog.hasContext(context) ||
          !catalog.hasQuestion(question) ||
          context == 'preguntas') {
        continue;
      }
      evaluados++;
      final turn = turnOf(c);
      final enContexto = router.routeDeterministic(
        turn,
        activeContextId: context,
      );
      final sinContexto = router.routeDeterministic(turn);
      final resultado = outcome(enContexto, context, question);
      if (resultado == 'falla' &&
          !_limitacionesConocidas.containsKey(c['id'])) {
        fallas.add(
          '${c['id']} «${c['texto']}» → ${enContexto.type.wireName} '
          '${enContexto.targetContextId ?? '-'} '
          '${enContexto.targetQuestionIds.join('+')} '
          '(${enContexto.reason})',
        );
      }
      reporte.add({
        'id': c['id'],
        'origen': c['origen'],
        'oyente': c['texto'],
        'glosasSimuladas': c['glosasSimuladas'] == true,
        'glosas': c['glosas'],
        'lectura': c['semanticTurn'],
        'contexto': context,
        'preguntaEsperada': question,
        'enContexto': {
          'resultado': resultado,
          'ruta': enContexto.type.wireName,
          'preguntas': enContexto.targetQuestionIds,
          'recorrido': enContexto.pathQuestionIds,
          'motivo': enContexto.reason,
        },
        'sinContexto': {
          'resultado': outcomeAnywhere(sinContexto, question),
          'ruta': sinContexto.type.wireName,
          'contexto': sinContexto.targetContextId,
          'preguntas': sinContexto.targetQuestionIds,
          'motivo': sinContexto.reason,
        },
        'veLaPersonaSorda': [
          for (final id
              in enContexto.opensQuestions
                  ? enContexto.pathQuestionIds
                  : const <String>[])
            questionView(id),
        ],
      });
    }

    final destino = Platform.environment['REPORTE_RUTEO'];
    if (destino != null && destino.isNotEmpty) {
      File(destino).writeAsStringSync(
        const JsonEncoder.withIndent(
          ' ',
        ).convert({'evaluados': evaluados, 'casos': reporte}),
      );
    }

    expect(evaluados, greaterThan(200));
    expect(fallas, isEmpty, reason: fallas.join('\n'));
  });

  test(
    '«¿Puedes describir a los agresores?» → rasgos en tarjetas, en orden',
    () {
      final caso = casos.firstWhere((c) => c['id'] == 'parafrasis-01');
      final route = router.routeDeterministic(
        turnOf(caso),
        activeContextId: 'denuncia_robo',
      );
      const rasgos = [
        'Q.PER.DESC.SEXO',
        'Q.PER.DESC.EDAD',
        'Q.PER.DESC.ESTATURA',
        'Q.PER.DESC.CONTEXTURA',
        'Q.PER.DESC.ROPA',
      ];
      expect(route.pathQuestionIds, rasgos);
      // La puerta «¿Quiere describir a la persona?» no se responde por nadie.
      expect(route.pathQuestionIds, isNot(contains('Q.PER.DESCRIBIR')));

      final flow = GuidedFlow(catalog.bank);
      var session = flow.startJourney(
        'denuncia_robo',
        purpose: GuidedPurpose.reply,
        requestedQuestionIds: route.presupposedQuestionIds,
        onlySteps: route.pathQuestionIds,
      );
      final vistas = <String>[];
      for (final (pregunta, opcion) in const [
        ('Q.PER.DESC.SEXO', 'hombre'),
        ('Q.PER.DESC.EDAD', 'joven'),
        ('Q.PER.DESC.ESTATURA', 'alto'),
        ('Q.PER.DESC.CONTEXTURA', 'gordo'),
        ('Q.PER.DESC.ROPA', 'chamarra'),
      ]) {
        expect(session.currentQuestionId, pregunta);
        vistas.add(pregunta);
        expect(
          flow.offeredOptions(session, pregunta).map((o) => o.id),
          contains(opcion),
        );
        final outcome = flow.select(session, pregunta, opcion);
        expect(outcome.accepted, isTrue, reason: '$pregunta $opcion');
        session = outcome.session;
        final next = flow.nextQuestion(session);
        if (next != null) session = flow.goTo(session, next);
      }
      expect(vistas, rasgos);
      expect(flow.canFinish(session), isTrue);
      expect(
        flow.glossesOf(session.toIntervention()),
        containsAll(['HOMBRE', 'ALTO', 'GORDO']),
      );
    },
  );

  test('las frases probadas en el teléfono, también sin tema previo', () {
    final fallas = <String>[];
    for (final c in casos.where((c) => c['origen'] == 'dispositivo')) {
      final turn = turnOf(c);
      final question = c['preguntaEsperada'] as String;
      final exigido = c['sinTema'] as String;
      final sinTema = router.routeDeterministic(turn);
      String describe(ConversationRoute r) =>
          '${r.type.wireName} ${r.targetContextId ?? '-'} '
          '${r.targetQuestionIds.join('+')} (${r.reason})';
      if (question == 'SELECTOR') {
        for (final active in [null, 'denuncia_robo']) {
          final r = router.routeDeterministic(turn, activeContextId: active);
          if (r.type != ConversationRouteType.contextSelector) {
            fallas.add('«${c['texto']}» con tema $active → ${describe(r)}');
          }
        }
        continue;
      }
      final context = c['contexto'] as String;
      final enTema = router.routeDeterministic(turn, activeContextId: context);
      final resultadoEnTema = outcome(enTema, context, question);
      final resultadoSinTema = outcomeAnywhere(sinTema, question);
      final seguro = {'directa', 'equivalente', 'modelo'};
      final okEnTema = exigido == 'segura'
          ? seguro.contains(resultadoEnTema)
          : resultadoEnTema == 'directa' || resultadoEnTema == 'equivalente';
      final okSinTema = switch (exigido) {
        'libre' => true,
        'directa' =>
          resultadoSinTema == 'directa' || resultadoSinTema == 'equivalente',
        // Sin tema, una pregunta que vale en varios contextos puede pedir
        // elegir: lo que no puede es abrir otra pregunta.
        _ =>
          seguro.contains(resultadoSinTema) ||
              (sinTema.type == ConversationRouteType.contextSelector ||
                  sinTema.type == ConversationRouteType.noSafeRoute),
      };
      // Pedir la ropa abre la ropa, no toda la descripción.
      if (question == 'Q.PER.DESC.ROPA' &&
          enTema.pathQuestionIds.join() != question) {
        fallas.add('«${c['texto']}» abre ${enTema.pathQuestionIds}');
      }
      if (!okEnTema) {
        fallas.add('«${c['texto']}» en $context → ${describe(enTema)}');
      }
      if (!okSinTema) {
        fallas.add('«${c['texto']}» sin tema → ${describe(sinTema)}');
      }
    }
    expect(fallas, isEmpty, reason: fallas.join('\n'));
  });
}
