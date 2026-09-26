import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route_validator.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn_builder.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

/// Modelo de prueba: devuelve lo que se le indique y cuenta las llamadas.
class _FakeModel implements GraphRouteModel {
  _FakeModel(this.answer);

  final ConversationRoute? Function(List<ConversationRoute> candidates) answer;
  int calls = 0;

  @override
  Future<ConversationRoute?> rank({
    required SemanticTurn turn,
    required List<ConversationRoute> candidates,
    String? activeContextId,
  }) async {
    calls++;
    return answer(candidates);
  }
}

/// Casos capturados de la Lambda real (`build_semantic_turn`); ver
/// `aws/tests/regenerar_casos_semantic_turn.py`.
final Map<String, Map<String, dynamic>> _casos = {
  for (final c
      in (jsonDecode(
                File('aws/tests/casos_semantic_turn.json').readAsStringSync(),
              )['casos']
              as List)
          .cast<Map<String, dynamic>>())
    c['id'] as String: c,
};

/// El turno tal como lo recibe Conversation: la lectura del backend
/// completada con las glosas que ya trae la traducción.
SemanticTurn backendTurn(String id) {
  final c = _casos[id]!;
  return SemanticTurn.fromBackend(
    turnId: id,
    text: c['texto'] as String,
    speechAct: classifySpeechAct(c['texto'] as String),
    backend: BackendSemanticTurn.fromJson(c['semanticTurn'])!,
    glosses: List<String>.from(c['glosas'] as List),
  );
}

void main() {
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

  ConversationRoute route(String id, {String? activeContextId}) => router
      .routeDeterministic(backendTurn(id), activeContextId: activeContextId);

  group('lectura del backend → ruta real del grafo', () {
    test('1. «¿Qué viene a realizar?» abre el selector de contextos', () {
      expect(backendTurn('motivo').intent, SemanticIntent.askPurpose);
      final r = route('motivo');
      expect(r.type, ConversationRouteType.contextSelector);
      expect(r.targetContextId, isNull);
      expect(r.targetQuestionIds, isEmpty);
      expect(r.needsModel, isFalse);
    });

    test('2. «¿Quiere denunciar algo?» abre la familia Denuncias', () {
      final r = route('denunciar');
      expect(r.type, ConversationRouteType.directContext);
      expect(r.targetFamilyId, 'denuncias');
      expect(r.targetContextId, isNull);
    });

    test('2b. un contexto concreto nombrado se abre directamente', () {
      final r = route('violencia');
      expect(r.type, ConversationRouteType.directContext);
      expect(r.targetContextId, 'violencia');
    });

    test('3. una pregunta exacta del banco abre solo esa pregunta', () {
      final r = route('donde_ocurrio');
      expect(r.type, ConversationRouteType.directQuestion);
      expect(r.targetQuestionIds, ['Q.LUG.DONDE']);
      expect(r.pathQuestionIds, ['Q.LUG.DONDE']);
      expect(r.requestedSlots, ['place']);
    });

    test('frases equivalentes: el mismo significado, la misma ruta', () {
      // Nada de esto está escrito en el router: la traducción normaliza la
      // frase a DONDE (o el núcleo «lugar») y la lectura pide `place`.
      final esperada = route('donde_ocurrio');
      for (final id in ['donde_fue', 'donde_paso', 'en_que_lugar']) {
        final r = route(id);
        expect(backendTurn(id).requestedSlots, ['place'], reason: id);
        expect(r.type, esperada.type, reason: id);
        expect(r.targetQuestionIds, esperada.targetQuestionIds, reason: id);
        expect(r.targetContextId, esperada.targetContextId, reason: id);
      }
    });

    test('4. dos datos pedidos arman el recorrido mínimo', () {
      final r = route('hora_y_donde');
      expect(r.type, ConversationRouteType.minimalGraphPath);
      expect(r.targetQuestionIds, ['Q.TIE.HORA', 'Q.LUG.DONDE']);
      expect(r.requestedSlots, ['time', 'place']);
      expect(
        r.pathQuestionIds,
        ['Q.TIE.HORA', 'Q.LUG.DONDE'],
        reason: 'Nada que no se haya pedido: ni testigos, ni objetos.',
      );
    });

    test('4b. el recorrido mínimo trae las hijas obligatorias', () {
      final r = route('que_robaron');
      expect(r.targetQuestionIds, ['Q.ROB.QUE']);
      // «Papel» exige «¿Qué papel es?»: sin ella no se redacta.
      expect(r.pathQuestionIds, ['Q.ROB.QUE', 'Q.DOC.ACLARAR']);
    });

    test('el tema nombrado no se cuela como otro dato pedido', () {
      final r = route('testigos_robo');
      expect(r.targetQuestionIds, ['Q.TES.EXISTE']);
      expect(r.targetContextId, 'denuncia_robo');
    });

    test('cada pregunta concreta llega a la suya', () {
      const esperado = {
        'robaron_celular': 'Q.ROB.CONFIRMA_OBJETO',
        'nombre': 'Q.ID.NOMBRE',
        'cuantos_testigos': 'Q.TES.CANTIDAD',
        'herido': 'Q.SAL.HERIDO',
        'quien_escapo': 'Q.HEC.ESCAPE_ACTOR',
        'cuando': 'Q.TIE.CUANDO',
      };
      for (final e in esperado.entries) {
        final r = route(e.key);
        expect(r.type, ConversationRouteType.directQuestion, reason: e.key);
        expect(r.targetQuestionIds, [e.value], reason: e.key);
        expect(
          catalog.isStepOf(r.targetContextId!, e.value) ||
              catalog.journeysOf(e.value).isEmpty,
          isTrue,
          reason: '${e.key}: se abre donde la pregunta es un paso',
        );
      }
    });

    test('5. sin nada que reconocer no se inventa ruta', () {
      final r = route('parqueo');
      expect(r.type, ConversationRouteType.noSafeRoute);
      expect(r.targetContextId, isNull);
      expect(r.targetQuestionIds, isEmpty);
      expect(r.needsModel, isFalse);
    });

    test('el router no relee el texto: la ruta sale del significado', () {
      final original = backendTurn('donde_ocurrio');
      final sinTexto = SemanticTurn(
        turnId: original.turnId,
        text: 'texto cualquiera sin relación',
        speechAct: original.speechAct,
        intent: original.intent,
        entities: original.entities,
        requestedSlots: original.requestedSlots,
        source: SemanticTurnSource.backend,
      );
      expect(router.routeDeterministic(sinTexto).targetQuestionIds, [
        'Q.LUG.DONDE',
      ]);
    });
  });

  group('contexto entre turnos', () {
    test('11. con Denuncias activo, «¿Dónde ocurrió?» se queda en él', () {
      expect(
        route('donde_ocurrio', activeContextId: 'violencia').targetContextId,
        'violencia',
      );
      expect(
        route('cuando', activeContextId: 'violencia').targetContextId,
        'violencia',
      );
    });

    test('11b. sin el paso en el contexto activo, se queda en su familia', () {
      // «¿Cuántos testigos hay?» no es un paso de violencia: se busca en
      // Denuncias antes que en todo el grafo.
      final r = route('cuantos_testigos', activeContextId: 'violencia');
      expect(catalog.familyOf(r.targetContextId!), 'denuncias');
    });

    test('12b. nombrar otro contexto gana al activo aunque la pregunta '
        'también sea suya', () {
      // Q.LUG.DONDE es paso de violencia, pero el oyente habla del robo.
      final r = route('donde_robo', activeContextId: 'violencia');
      expect(r.targetQuestionIds, ['Q.LUG.DONDE']);
      expect(r.targetContextId, 'denuncia_robo');
      // Sin nombrar nada, se queda en el contexto activo.
      expect(
        route('donde_ocurrio', activeContextId: 'violencia').targetContextId,
        'violencia',
      );
    });

    test('12. un cambio explícito de contexto no se bloquea', () {
      expect(
        route('violencia', activeContextId: 'denuncia_robo').targetContextId,
        'violencia',
      );
      expect(
        route('nombre', activeContextId: 'denuncia_robo').targetContextId,
        'identificacion',
      );
      expect(
        route('que_robaron', activeContextId: 'violencia').targetContextId,
        'denuncia_robo',
      );
    });
  });

  group('respaldo del cliente (backend sin semanticTurn)', () {
    late SemanticTurnBuilder builder;
    setUpAll(() => builder = SemanticTurnBuilder(catalog));

    SemanticTurn fallback(String text) =>
        builder.build(turnId: 't', text: text);

    test('la lectura se marca como respaldo', () {
      expect(
        fallback('¿Dónde ocurrió?').source,
        SemanticTurnSource.clientFallback,
      );
    });

    test('los mismos casos siguen resueltos sin la lectura del backend', () {
      expect(
        router
            .routeDeterministic(
              fallback('Hola, ¿cómo está? ¿Qué viene a realizar?'),
            )
            .type,
        ConversationRouteType.contextSelector,
      );
      expect(
        router
            .routeDeterministic(fallback('¿Quiere denunciar algo?'))
            .targetFamilyId,
        'denuncias',
      );
      expect(
        router
            .routeDeterministic(fallback('¿Dónde ocurrió?'))
            .targetQuestionIds,
        ['Q.LUG.DONDE'],
      );
      final dos = router.routeDeterministic(
        fallback('¿A qué hora y dónde ocurrió?'),
      );
      expect(dos.type, ConversationRouteType.minimalGraphPath);
      expect(dos.targetQuestionIds, ['Q.TIE.HORA', 'Q.LUG.DONDE']);
      expect(dos.requestedSlots, ['time', 'place']);
    });
  });

  group('desempate con el modelo', () {
    test('6. una ruta determinista no llama a Bedrock', () async {
      final model = _FakeModel((_) => null);
      final r = await ConversationGraphRouter(
        catalog,
        model: model,
      ).route(backendTurn('donde_ocurrio'));
      expect(model.calls, 0);
      expect(r.source, RouteSource.deterministic);
    });

    test('7. una pregunta ambigua sí llama a Bedrock (una vez)', () async {
      final ambigua = route('consultar_o_denunciar');
      expect(ambigua.needsModel, isTrue);
      expect(
        ambigua.candidates.map((c) => c.targetFamilyId),
        unorderedEquals(['consultas', 'denuncias']),
      );

      final model = _FakeModel(
        (cands) => cands
            .firstWhere((c) => c.targetFamilyId == 'denuncias')
            .copyWith(confidence: 0.8, source: RouteSource.bedrock),
      );
      final r = await ConversationGraphRouter(
        catalog,
        model: model,
      ).route(backendTurn('consultar_o_denunciar'));
      expect(model.calls, 1);
      expect(r.source, RouteSource.bedrock);
      expect(r.sourceLabel, 'bedrock');
      expect(r.type, ConversationRouteType.directContext);
      expect(r.targetFamilyId, 'denuncias');
    });

    test('una ruta servida desde la caché conserva su origen', () async {
      final model = _FakeModel(
        (cands) => cands
            .firstWhere((c) => c.targetFamilyId == 'denuncias')
            .copyWith(confidence: 0.8, source: RouteSource.cache),
      );
      final r = await ConversationGraphRouter(
        catalog,
        model: model,
      ).route(backendTurn('consultar_o_denunciar'));
      expect(r.sourceLabel, 'cache');
    });

    test('F. confianza baja: NO_SAFE_ROUTE, sin ruta inventada', () async {
      expect(route('persona_vio').needsModel, isTrue);
      final model = _FakeModel(
        (cands) => cands
            .firstWhere((c) => c.opensQuestions)
            .copyWith(confidence: 0.3, source: RouteSource.bedrock),
      );
      final r = await ConversationGraphRouter(
        catalog,
        model: model,
      ).route(backendTurn('persona_vio'));
      expect(model.calls, 1);
      expect(r.type, ConversationRouteType.noSafeRoute);
      expect(r.sourceLabel, 'noSafeRoute');
      expect(r.targetQuestionIds, isEmpty);
    });

    test('G. una pregunta inexistente del modelo se rechaza', () async {
      final model = _FakeModel(
        (_) => const ConversationRoute(
          type: ConversationRouteType.directQuestion,
          targetContextId: 'denuncia_robo',
          targetQuestionIds: ['Q.NO.EXISTE'],
          confidence: 0.95,
          source: RouteSource.bedrock,
        ),
      );
      final r = await ConversationGraphRouter(
        catalog,
        model: model,
      ).route(backendTurn('persona_vio'));
      expect(r.type, ConversationRouteType.noSafeRoute);
      expect(r.targetQuestionIds, isEmpty);
    });

    test('G2. un contexto o una ranura inventados se rechazan', () {
      final v = ConversationRouteValidator(catalog);
      expect(
        v
            .validate(
              const ConversationRoute(
                type: ConversationRouteType.directContext,
                targetContextId: 'contexto_inventado',
                confidence: 0.9,
              ),
            )
            .isValid,
        isFalse,
      );
      expect(
        v
            .validate(
              const ConversationRoute(
                type: ConversationRouteType.directQuestion,
                targetContextId: 'denuncia_robo',
                targetQuestionIds: ['Q.LUG.DONDE'],
                requestedSlots: ['ranura_inventada'],
                confidence: 0.9,
              ),
            )
            .isValid,
        isFalse,
      );
    });

    test('G3. una propuesta con respuestas no es una ruta', () {
      expect(
        ConversationRoute.fromModelJson({
          'routeType': 'DIRECT_QUESTION',
          'targetContextId': 'denuncia_robo',
          'targetQuestionIds': ['Q.LUG.DONDE'],
          'optionIds': ['calle'],
          'confidence': 0.9,
        }),
        isNull,
      );
    });

    test('G4. el modelo no puede traer preguntas fuera de las candidatas', () {
      final t = backendTurn('persona_vio');
      final chosen = router.acceptModelRoute(
        const ConversationRoute(
          type: ConversationRouteType.directQuestion,
          targetContextId: 'denuncia_robo',
          targetQuestionIds: ['Q.TES.EXISTE'],
          confidence: 0.9,
          source: RouteSource.bedrock,
        ),
        turn: t,
        fallback: router.routeDeterministic(t),
      );
      expect(chosen.source, RouteSource.deterministic);
      expect(chosen.type, ConversationRouteType.noSafeRoute);
    });

    test('8. saltar una dependencia obligatoria no pasa: se recalcula', () {
      // «¿Qué relación tiene con esa persona?» depende de «¿Conoce a la
      // persona?». Si el modelo la propone sin que el oyente la haya hecho,
      // vuelve su pregunta padre.
      final t = backendTurn('persona_vio');
      const fallback = ConversationRoute.noSafeRoute(
        needsModel: true,
        candidates: [
          ConversationRoute(
            type: ConversationRouteType.directQuestion,
            targetContextId: 'denuncia_robo',
            targetQuestionIds: ['Q.PER.VINCULO'],
          ),
        ],
      );
      final chosen = router.acceptModelRoute(
        const ConversationRoute(
          type: ConversationRouteType.directQuestion,
          targetContextId: 'denuncia_robo',
          targetQuestionIds: ['Q.PER.VINCULO'],
          confidence: 0.9,
          source: RouteSource.bedrock,
        ),
        turn: t,
        fallback: fallback,
      );
      expect(chosen.source, RouteSource.bedrock);
      final path = chosen.pathQuestionIds;
      expect(path, containsAll(['Q.PER.CONOCE', 'Q.PER.VINCULO']));
      expect(
        path.indexOf('Q.PER.CONOCE'),
        lessThan(path.indexOf('Q.PER.VINCULO')),
      );
      expect(chosen.presupposedQuestionIds, isEmpty);
    });
  });

  test('el contrato de candidatas que viaja a la Lambda', () {
    final r = route('hora_y_donde');
    final json = r.toJson();
    expect(json['routeType'], 'MINIMAL_GRAPH_PATH');
    expect(json['targetContextId'], r.targetContextId);
    expect(json['targetQuestionIds'], ['Q.TIE.HORA', 'Q.LUG.DONDE']);
    expect(json['requestedSlots'], ['time', 'place']);
    expect(json['id'], r.candidateKey);
    expect(
      json.keys.toSet().intersection(ConversationRoute.answerKeys),
      isEmpty,
    );
  });
}
