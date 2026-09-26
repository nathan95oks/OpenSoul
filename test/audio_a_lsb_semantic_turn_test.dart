import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

/// El bloque `semanticTurn` de Audio/Texto→LSB llega al cliente sin cambiar
/// nada de lo que el módulo ya entregaba, y su ausencia (backend anterior)
/// no rompe la traducción.
void main() {
  const resolver = AnimationUrlResolver(baseUrl: 'https://s3/');

  RemoteAudioDataSourceImpl fuente(Map<String, dynamic> body) =>
      RemoteAudioDataSourceImpl(
        apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        animationResolver: resolver,
      );

  test(
    '1. la respuesta trae una lectura utilizable por Conversation',
    () async {
      final t = await fuente({
        'glosses': ['DONDE'],
        'glossDetails': [
          {'gloss': 'DONDE', 'animationFile': 'DONDE.glb'},
        ],
        'disambiguation': [],
        'semanticTurn': {
          'version': 1,
          'intent': 'askInformation',
          'requestedSlots': ['place'],
          'mentionedContexts': [],
          'negations': [],
          'confidence': 0.9,
        },
      }).translateText('¿Dónde fue?');

      expect(t.glosses, ['DONDE']);
      expect(t.semanticTurn, isNotNull);
      expect(t.semanticTurn!.intent, SemanticIntent.askInformation);
      expect(t.semanticTurn!.requestedSlots, ['place']);
      expect(t.semanticTurn!.confidence, 0.9);
    },
  );

  test('15. sin lectura (backend anterior) la traducción no cambia', () async {
    final t = await fuente({
      'glosses': ['HOLA', 'ABOGADO'],
      'glossDetails': [
        {'gloss': 'HOLA', 'animationFile': 'HOLA.glb'},
        {'gloss': 'ABOGADO', 'animationFile': 'ABOGADO.glb'},
      ],
    }).translateText('Hola abogado');

    expect(t.semanticTurn, isNull);
    expect(t.glosses, ['HOLA', 'ABOGADO']);
    expect(t.animationGlosses, ['HOLA', 'ABOGADO']);
    expect(t.animationUrls, hasLength(2));
  });

  test('una lectura sin forma se ignora y queda el respaldo', () {
    expect(BackendSemanticTurn.fromJson({'version': 1}), isNull);
    expect(BackendSemanticTurn.fromJson('texto'), isNull);
    expect(BackendSemanticTurn.fromJson(null), isNull);
  });
}
