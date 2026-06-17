import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/datasources/remote_translation_datasource.dart';

/// Pruebas del datasource remoto (TST-02).
///
/// Cubren el parseo de la respuesta del backend AWS, los defaults cuando
/// faltan campos opcionales, el manejo de error HTTP y el timeout (RDS-01).
void main() {
  RemoteTranslationDataSourceImpl makeDs(MockClient client) =>
      RemoteTranslationDataSourceImpl(
        client: client,
        apiGatewayUrl: 'https://example.test/translate',
      );

  group('RemoteTranslationDataSource — parsing 200', () {
    test('payload completo se mapea a TranslationResult', () async {
      final client = MockClient((req) async {
        // El cuerpo enviado incluye los campos del contrato.
        final sent = jsonDecode(req.body) as Map<String, dynamic>;
        expect(sent['context'], 'denuncia_robo');
        expect(sent['cards'], ['HOMBRE', 'ROBAR']);
        expect(sent['language'], 'es-BO');
        expect(sent['institutionType'], 'entidad_publica');

        return http.Response(
          jsonEncode({
            'baseSentence': 'Un hombre me robó.',
            'generatedText': 'Un hombre me robó el celular.',
            'audioUrl': 'https://s3.test/audio.mp3',
            'cacheHit': true,
            'bedrockUsed': true,
            'intermediateRepresentation': {'tipo_evento': 'ROBO'},
            'glossSequence': [
              {'gloss': 'HOMBRE', 'videoKey': 'lsb-videos/HOMBRE.mp4'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await makeDs(client).translateCards(
        context: 'denuncia_robo',
        cards: ['HOMBRE', 'ROBAR'],
      );

      expect(result.baseSentence, 'Un hombre me robó.');
      expect(result.generatedText, 'Un hombre me robó el celular.');
      expect(result.audioUrl, 'https://s3.test/audio.mp3');
      expect(result.cacheHit, true);
      expect(result.bedrockUsed, true);
      expect(result.intermediateRepresentation?['tipo_evento'], 'ROBO');
      expect(result.glossSequence?.first['gloss'], 'HOMBRE');
    });

    test('campos opcionales ausentes usan defaults sin romper', () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({'generatedText': 'Texto mínimo.'}),
          200,
        );
      });

      final result = await makeDs(client).translateCards(
        context: 'orientacion',
        cards: ['INTERPRETE'],
      );

      // baseSentence cae a generatedText cuando no viene.
      expect(result.baseSentence, 'Texto mínimo.');
      expect(result.generatedText, 'Texto mínimo.');
      expect(result.audioUrl, isNull);
      expect(result.cacheHit, false);
      expect(result.bedrockUsed, false);
      expect(result.intermediateRepresentation, isNull);
      expect(result.glossSequence, isNull);
    });
  });

  group('RemoteTranslationDataSource — errores', () {
    test('statusCode != 200 lanza Exception', () async {
      final client = MockClient((req) async => http.Response('boom', 500));

      expect(
        () => makeDs(client).translateCards(context: 'x', cards: ['ROBAR']),
        throwsA(isA<Exception>()),
      );
    });

    test('una respuesta lenta supera el timeout y lanza TimeoutException',
        () async {
      final client = MockClient((req) async {
        // Más que requestTimeout configurado en el datasource.
        await Future<void>.delayed(
          RemoteTranslationDataSourceImpl.requestTimeout +
              const Duration(seconds: 1),
        );
        return http.Response('{}', 200);
      });

      expect(
        () => makeDs(client).translateCards(context: 'x', cards: ['ROBAR']),
        throwsA(isA<TimeoutException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
