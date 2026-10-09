import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/rag_suggestions_provider.dart';

/// Lo que el QA de Conversación del 2026-10-09 encontró con frases reales del
/// funcionario (testigos, fiscal, cámaras, a dónde ir, acoso, fotos). Las
/// glosas son las que devolvió la Lambda Texto→LSB desplegada. Ver
/// docs/QA_CONVERSACION_2026-10-09.md.
void main() {
  final bank = QuestionBank.generated();
  final catalog = ConversationGraphCatalog(
    bank: bank,
    graph: DialogueGraph.fromJsonString(
      File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
    ),
  );
  final router = ConversationGraphRouter(catalog);

  ConversationRoute ruta(String text, List<String> glosses, {String? active}) =>
      router.routeDeterministic(
        SemanticTurn.fromBackend(
          turnId: text,
          text: text,
          speechAct: SpeechAct.question,
          glosses: glosses,
          backend: const BackendSemanticTurn(
            version: 1,
            intent: SemanticIntent.askInformation,
            confidence: 0.5,
          ),
        ),
        activeContextId: active,
      );

  group('testigos', () {
    test('«¿Quiénes son los testigos?» pregunta si los conoce, y el sí pide '
        'su nombre y su celular', () {
      final r = ruta('quienes son los testigos', const [
        'TESTIGO',
        'QUIEN',
      ], active: 'denuncia_robo');
      expect(r.targetQuestionIds, ['Q.TES.CONOCE']);
      expect(r.pathQuestionIds, [
        'Q.TES.CONOCE',
        'Q.TES.NOMBRE',
        'Q.TES.TELEFONO',
      ]);
      expect(
        bank.question('Q.TES.NOMBRE')!.options.first.phrase,
        'El testigo se llama {nombre}.',
      );
    });

    test('«¿No sabe quién fue?» en la violencia sigue siendo el agresor', () {
      final r = ruta('¿No sabe quién fue?', const [
        'QUIEN',
        'F',
        'U',
        'E',
        'NO_SABER',
      ], active: 'violencia');
      expect(r.targetQuestionIds, ['Q.VIO.AGRESOR']);
    });
  });

  group('fiscal e investigador: sí o no', () {
    test('«¿Sabe quién es su fiscal?»: el sí dice su nombre', () {
      final r = ruta('sabe quien es su fiscal', const [
        'SABER',
        'QUIEN',
        'E',
        'S',
        'S',
        'U',
        'F',
        'I',
        'S',
        'C',
        'A',
        'L',
      ], active: 'seguimiento');
      expect(r.targetQuestionIds, ['Q.SEG.CONOCE_FISCAL']);
      final q = bank.question('Q.SEG.CONOCE_FISCAL')!;
      expect([for (final o in q.options) o.id], ['si', 'no']);
      expect(q.options.first.phrase, 'Sí, mi fiscal es {nombre}.');
      expect(q.options.last.phrase, 'No sé quién es mi fiscal.');
    });

    test(
      '«¿Quiere saber quién investigará su caso?» no es «¿A quién vio?»',
      () {
        final r = ruta('¿Quiere saber quién investigará su caso?', const [
          'C',
          'A',
          'S',
          'O',
          'SUYO',
          'INVESTIGACION',
          'QUIEN',
          'SABER',
          'QUERER',
        ], active: 'otro');
        expect(r.targetQuestionIds, ['Q.SEG.SABER_INVESTIGADOR']);
      },
    );
  });

  group('derivar y pruebas', () {
    test('«¿Entiende a dónde tiene que ir?» ofrece instituciones y «Dígame '
        'usted», no calles', () {
      final r = ruta('¿Entiende a dónde tiene que ir?', const [
        'IR',
        'DONDE',
        'NECESITAR',
      ], active: 'denuncia_robo');
      expect(r.targetContextId, 'derivacion');
      expect(r.targetQuestionIds, ['Q.ORI.DESTINO']);
      final opciones = bank.question('Q.ORI.DESTINO')!.options;
      expect([for (final o in opciones) o.id], containsAll(['felcc', 'felcv']));
      expect(opciones.last.phrase, contains('Dígame usted'));
    });

    test('«¿Hay cámaras en esa calle?» en un robo', () {
      final r = ruta('¿Hay cámaras en esa calle?', const [
        'CALLE',
        'CAMARA_FOTOGRAFICA',
        'E',
        'S',
        'T',
        'A',
        'R',
      ], active: 'denuncia_robo');
      expect(r.targetQuestionIds, ['Q.EVI.CAMARAS']);
    });

    test('«¿Publicaron fotos suyas…?» en las amenazas no son las capturas, y '
        'el no dice que no publicaron nada', () {
      final r = ruta('¿Publicaron fotos suyas sin su permiso?', const [
        'FOTOS',
        'SUYO',
        'P',
        'U',
        'B',
        'L',
        'I',
        'C',
        'A',
        'R',
        'PERMISO',
        'NO',
      ], active: 'amenaza_digital');
      expect(r.targetQuestionIds, ['Q.DIG.PUBLICACION']);
      expect(
        bank
            .question('Q.DIG.PUBLICACION')!
            .options
            .firstWhere((o) => o.id == 'no')
            .phrase,
        'No, no publicaron nada.',
      );
    });
  });

  group('acoso: el trámite sigue el hilo', () {
    final retriever = RagRetriever(
      RagCorpus.fromJsonString(
        File('assets/rag/escenarios_cbba.json').readAsStringSync(),
      ),
    );

    ConversationTurn oyente(String id, String text, {ConversationRoute? r}) =>
        ConversationTurn(
          route: r ?? const ConversationRoute.noSafeRoute(reason: 'prueba'),
          message: SemanticMessage(
            id: id,
            speaker: SpeakerRole.hearing,
            source: MessageSource.text,
            glosses: const [],
            text: text,
          ),
          outputs: GeneratedOutputs(text: text),
        );

    test('«¿Conoce a la persona que lo acosa?»: el sí pregunta quién es', () {
      final turn = oyente('t1', '¿Conoce a la persona que lo acosa?');
      final r = ragTramiteRoute(
        Conversation(id: 'qa', startedAt: DateTime(2026, 10, 9), turns: [turn]),
        turn,
        turn.route!,
        retriever,
      )!;
      expect(r.targetQuestionIds, ['R.ESC-FELCV-201.6']);
      expect(r.pathQuestionIds, ['R.ESC-FELCV-201.6', 'R.ESC-FELCV-201.8']);
    });

    test('responder en el trámite no deja el robo provisional como tema', () {
      // El grafo había puesto «¿Conoce a la persona que lo acosa?» en el
      // robo; la persona la respondió en el trámite de acoso.
      final pregunta = oyente(
        'p1',
        '¿Conoce a la persona que lo acosa?',
        r: const ConversationRoute(
          type: ConversationRouteType.directQuestion,
          targetContextId: 'denuncia_robo',
          targetQuestionIds: ['Q.PER.CONOCE'],
          confidence: 1,
          reason: 'prueba',
        ),
      );
      final respuesta = ConversationTurn(
        message: SemanticMessage(
          id: 'r1',
          speaker: SpeakerRole.deaf,
          source: MessageSource.cards,
          glosses: ['SÍ'],
          text: 'Sí, conozco a esa persona.',
          contextId: 'tramite_felcv_201',
          replyToId: 'p1',
        ),
        outputs: GeneratedOutputs(text: 'Sí, conozco a esa persona.'),
      );
      final conversation = Conversation(
        id: 'qa',
        startedAt: DateTime(2026, 10, 9),
        turns: [pregunta, respuesta],
      );
      expect(conversation.topicContextWhere(catalog.hasContext), isNull);
      expect(conversation.topicContextId, 'tramite_felcv_201');
    });
  });
}
