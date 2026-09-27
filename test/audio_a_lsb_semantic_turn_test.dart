import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
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

  test(
    'donde sin signos reemplaza PLAZA inventada en glosas, avatar y ruta',
    () async {
      final t = await fuente({
        'glosses': ['PLAZA', 'CELULAR', 'ROBAR'],
        'animationSequence': [
          {'gloss': 'PLAZA', 'animationFile': 'PLAZA.glb'},
          {'gloss': 'CELULAR', 'animationFile': 'CELULAR.glb'},
          {'gloss': 'ROBAR', 'animationFile': 'ROBAR.glb'},
        ],
        'semanticTurn': {
          'version': 1,
          'intent': 'mentionContext',
          'requestedSlots': <String>[],
          'mentionedContexts': [
            {
              'id': 'denuncia_robo',
              'evidence': ['ROBAR'],
            },
          ],
          'confidence': 0.8,
        },
      }).translateText('donde te robaron el celular');

      expect(t.glosses, ['DONDE', 'CELULAR', 'ROBAR']);
      expect(t.animationGlosses, ['DONDE', 'CELULAR', 'ROBAR']);
      expect(t.animationUrls.first, 'https://s3/avatar_test.glb');

      final turn = SemanticTurn.fromBackend(
        turnId: 'bug-donde',
        text: 'donde te robaron el celular',
        speechAct: SpeechAct.question,
        backend: t.semanticTurn!,
        glosses: t.glosses,
      );
      expect(turn.intent, SemanticIntent.askInformation);
      expect(turn.requestedSlots, ['place']);
      expect(turn.entities, isNot(contains('PLAZA')));
    },
  );

  test('donde esta la plaza conserva el lugar que sí fue dicho', () async {
    final t = await fuente({
      'glosses': ['PLAZA'],
      'glossDetails': [
        {'gloss': 'PLAZA', 'animationFile': 'PLAZA.glb'},
      ],
    }).translateText('donde esta la plaza');

    expect(t.glosses, ['DONDE', 'PLAZA']);
    expect(t.animationGlosses, ['DONDE', 'PLAZA']);
  });

  test('un pronombre corto no respalda una persona inventada', () async {
    final t = await fuente({
      'glosses': ['TESTIGO', 'ROBAR'],
      'glossDetails': [
        {'gloss': 'TESTIGO', 'animationFile': 'TESTIGO.glb'},
        {'gloss': 'ROBAR', 'animationFile': 'ROBAR.glb'},
      ],
    }).translateText('quien te robo');

    expect(t.glosses, ['QUIEN', 'ROBAR']);
    expect(t.animationGlosses, ['QUIEN', 'ROBAR']);
  });

  test('una lectura sin forma se ignora y queda el respaldo', () {
    expect(BackendSemanticTurn.fromJson({'version': 1}), isNull);
    expect(BackendSemanticTurn.fromJson('texto'), isNull);
    expect(BackendSemanticTurn.fromJson(null), isNull);
  });
}
