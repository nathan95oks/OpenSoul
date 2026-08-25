import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/generators/avatar_generator/animation_url_resolver.dart';

/// Señas compuestas: las que no tienen un modelo propio y se ejecutan
/// encadenando varios (FISCAL = letra F deletreada + el rol).
///
/// Es una función que llegó desde `main` y que la reorganización del núcleo
/// estuvo a punto de perder en el merge. Queda fijada aquí: son **varias
/// animaciones de una sola glosa**, y las dos listas —la semántica y la de
/// reproducción— tienen cardinalidades distintas a propósito.
void main() {
  const resolver = AnimationUrlResolver(baseUrl: 'https://s3/');

  group('AnimationUrlResolver', () {
    test('una seña simple (archivo == glosa.glb) apunta al modelo Multi-Action', () {
      // Arquitectura Multi-Action: un solo modelo 3D unificado en S3 con
      // varias animaciones internas, no un .glb por glosa. Una seña sin
      // secuencia compuesta apunta siempre al mismo contenedor.
      expect(
        resolver.resolveAll(gloss: 'POLICIA', animationFile: 'POLICIA.glb'),
        ['https://s3/avatar_test.glb'],
      );
    });

    test('una seña compuesta produce la secuencia completa', () {
      expect(
        resolver.resolveAll(gloss: 'FISCAL', animationFile: 'F.glb+ABOGADO.glb'),
        ['https://s3/F.glb', 'https://s3/ABOGADO.glb'],
      );
    });

    test('sin archivo también apunta al modelo Multi-Action', () {
      expect(
        resolver.resolveAll(gloss: 'TESTIGO'),
        ['https://s3/avatar_test.glb'],
      );
    });

    test('las tildes se limpian en cada componente', () {
      expect(
        resolver.resolveAll(gloss: 'MAÑANA', animationFile: 'MAÑANA.glb+Á.glb'),
        ['https://s3/MANANA.glb', 'https://s3/A.glb'],
      );
    });

    test('resolve() sigue devolviendo una sola URL', () {
      expect(
        resolver.resolve(gloss: 'FISCAL', animationFile: 'F.glb+ABOGADO.glb'),
        'https://s3/F.glb',
      );
    });
  });

  group('RemoteAudioDataSource', () {
    Future<http.Response> Function(http.Request) respondingWith(
            Map<String, dynamic> body) =>
        (_) async => http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});

    test('la glosa compuesta no se duplica en la lista semántica', () async {
      final datasource = RemoteAudioDataSourceImpl(
        apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
        client: MockClient(respondingWith({
          'glosses': ['FISCAL', 'LLAMAR'],
          'glossDetails': [
            {'gloss': 'FISCAL', 'animationFile': 'F.glb+ABOGADO.glb'},
            {'gloss': 'LLAMAR', 'animationFile': 'LLAMA.glb'},
          ],
        })),
        animationResolver: resolver,
      );

      final result = await datasource.translateText('El fiscal llama');

      // Semántica: una entrada por glosa — si FISCAL apareciera dos veces,
      // la inferencia de contexto la contaría doble.
      expect(result.glosses, ['FISCAL', 'LLAMAR']);
      // Reproducción: tres animaciones, cada una con su etiqueta alineada.
      expect(result.animationUrls, [
        'https://s3/F.glb',
        'https://s3/ABOGADO.glb',
        'https://s3/LLAMA.glb',
      ]);
      expect(result.animationGlosses, ['FISCAL', 'FISCAL', 'LLAMAR']);
      expect(result.animationGlosses, hasLength(result.animationUrls.length));
    });

    test('el contexto situacional viaja aparte del dominio', () async {
      late Map<String, dynamic> sent;
      final datasource = RemoteAudioDataSourceImpl(
        apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'glosses': [], 'glossDetails': []}),
              200, headers: {'content-type': 'application/json'});
        }),
        animationResolver: resolver,
      );

      await datasource.translateText('hola', situation: 'denuncia_robo');

      expect(sent['context'], 'legal');
      expect(sent['situation'], 'denuncia_robo');
    });
  });
}

/// Cliente HTTP de prueba: responde con lo que dicte [handler].
class MockClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request) handler;

  MockClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
