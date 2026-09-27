import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_rag_datasource.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_handoff.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/rag_suggestions_provider.dart';

/// RAG por significado (fase 2): la app solo pregunta a la Lambda cuando la
/// búsqueda por palabras no encontró nada y el grafo no tiene una pregunta
/// segura. Cualquier fallo es «sin sugerencias».
void main() {
  const url = 'https://api.example.test/translate';
  const felcv = {
    'text': 'Sí.',
    'glosses': ['SI'],
    'scenarioId': 'ESC-FELCV-01',
    'institution': 'Policía Boliviana – FELCV',
    'procedure': 'Denunciar violencia familiar',
    'score': 0.71,
  };

  /// Como responde la Lambda: JSON en UTF-8 sin `charset`.
  http.Response lambda(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: const {'content-type': 'application/json'},
  );

  RemoteRagDataSource source(
    http.Response Function(Map<String, dynamic> body) reply, {
    List<Map<String, dynamic>>? requests,
  }) => RemoteRagDataSource(
    apiUrl: url,
    client: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests?.add(body);
      return reply(body);
    }),
  );

  group('cliente de la Lambda', () {
    test(
      'lee las sugerencias y descarta las que no se pueden ofrecer',
      () async {
        final pedidos = <Map<String, dynamic>>[];
        final found = await source(
          (_) => lambda({
            'generated': true,
            'suggestions': [
              felcv,
              {'text': 'Sin glosas', 'glosses': <String>[]},
              {
                'glosses': ['NO'],
              },
            ],
          }),
          requests: pedidos,
        ).consult('¿Usted está en peligro ahorita?', preferArea: 'FELCV');

        expect(found.map((s) => s.text), ['Sí.']);
        expect(found.single.glosses, ['SI']);
        expect(pedidos.single['action'], 'consulta');
        expect(pedidos.single['preferArea'], 'FELCV');
      },
    );

    test('sin índice, error o sin red: ninguna sugerencia', () async {
      final sinIndice = source(
        (_) => lambda({'generated': false, 'reason': 'sin_indice'}),
      );
      final caida = source((_) => http.Response('error', 500));
      final sinRed = RemoteRagDataSource(
        apiUrl: url,
        client: MockClient((_) async => throw const SocketException('sin red')),
      );
      for (final s in [sinIndice, caida, sinRed]) {
        expect(await s.consult('¿Hola?'), isEmpty);
      }
    });

    test('JSON inválido y timeout remoto: ninguna sugerencia', () async {
      final invalido = RemoteRagDataSource(
        apiUrl: url,
        client: MockClient((_) async => http.Response('{no-json', 200)),
      );
      final lento = RemoteRagDataSource(
        apiUrl: url,
        timeout: const Duration(milliseconds: 5),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return lambda({
            'generated': true,
            'suggestions': [felcv],
          });
        }),
      );
      expect(await invalido.consult('¿Hola?'), isEmpty);
      expect(await lento.consult('¿Hola?'), isEmpty);
    });

    test('sin endpoint configurado no se hace ninguna petición', () async {
      var llamadas = 0;
      final s = RemoteRagDataSource(
        apiUrl: '',
        client: MockClient((_) async {
          llamadas++;
          return http.Response('{}', 200);
        }),
      );
      expect(s.isConfigured, isFalse);
      expect(await s.consult('¿Hola?'), isEmpty);
      expect(llamadas, 0);
    });
  });

  test(
    'solo se pregunta por significado si el grafo no tiene una pregunta',
    () {
      expect(ragMayAskRemote(const ConversationRoute.noSafeRoute()), isTrue);
      expect(
        ragMayAskRemote(
          const ConversationRoute(
            type: ConversationRouteType.directContext,
            targetFamilyId: 'denuncias',
          ),
        ),
        isTrue,
      );
      expect(
        ragMayAskRemote(
          const ConversationRoute(type: ConversationRouteType.contextSelector),
        ),
        isFalse,
      );
      expect(
        ragMayAskRemote(
          const ConversationRoute(
            type: ConversationRouteType.directQuestion,
            targetContextId: 'denuncia_robo',
            targetQuestionIds: ['Q.LUG.DONDE'],
          ),
        ),
        isFalse,
      );
    },
  );

  test(
    'lo que las palabras no encuentran abre su trámite por significado',
    () async {
      final retriever = RagRetriever(
        RagCorpus.fromJsonString(
          File('assets/rag/escenarios_cbba.json').readAsStringSync(),
        ),
      );
      const texto = '¿Usted está en peligro ahorita?';
      expect(
        retriever.suggest(texto),
        isEmpty,
        reason: 'sin palabras en común',
      );

      var llamadas = 0;
      final container = ProviderContainer(
        overrides: [
          ragRetrieverProvider.overrideWithValue(retriever),
          remoteRagProvider.overrideWithValue(
            source((_) {
              llamadas++;
              return lambda({
                'generated': true,
                'suggestions': [felcv],
              });
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(conversationProvider.notifier)
          .replaceConversation(
            Conversation(
              id: 'c',
              startedAt: DateTime(2026, 9, 27),
              turns: [
                ConversationTurn(
                  route: const ConversationRoute.noSafeRoute(),
                  message: SemanticMessage(
                    id: 't1',
                    speaker: SpeakerRole.hearing,
                    source: MessageSource.text,
                    glosses: const [],
                    text: texto,
                  ),
                  outputs: GeneratedOutputs(text: texto),
                ),
              ],
            ),
          );

      // Mientras la Lambda responde, las tarjetas se abren como siempre; cuando
      // vuelve, «Responder con tarjetas LSB» abre la pregunta de su trámite.
      final handoff = container.read(conversationHandoffProvider);
      expect(
        handoff.nextDeafLaunch().route?.type,
        ConversationRouteType.noSafeRoute,
      );
      await container.read(
        remoteRagSuggestionsProvider(('t1', texto, null)).future,
      );
      final route = handoff.nextDeafLaunch().route!;
      expect(route.targetContextId, 'tramite_felcv_01');
      expect(route.pathQuestionIds.single, startsWith('R.ESC-FELCV-01.'));
      // El mismo turno no se vuelve a consultar.
      handoff.nextDeafLaunch();
      expect(llamadas, 1);
    },
  );
}
