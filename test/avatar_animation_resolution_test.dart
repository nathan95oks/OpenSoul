import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/animation_url_resolver.dart';

/// Matriz de resolución del avatar Multi-Action.
///
/// Sustituye a las señas compuestas (`FISCAL = F.glb + ABOGADO.glb`): ya no
/// hay un `.glb` por glosa que encadenar, sino un único contenedor 3D con las
/// señas horneadas dentro. Lo que decide qué se reproduce son tres estados,
/// en este orden:
///   1. la glosa está horneada en el modelo → el contenedor unificado;
///   2. es un término jurídico de [AnimationUrlResolver.wordsToSpell] → se
///      deletrea letra por letra en dactilología;
///   3. no hay animación → placeholder de texto.
///
/// La invariante que sobrevive al cambio de diseño: la lista semántica tiene
/// **una entrada por glosa** y la de reproducción **una por animación**. Al
/// deletrear, sus cardinalidades vuelven a diferir a propósito.
void main() {
  const resolver = AnimationUrlResolver(baseUrl: 'https://s3/');
  const modelo = 'https://s3/avatar_test.glb';

  group('AnimationUrlResolver', () {
    test('una seña horneada en el modelo apunta al contenedor unificado', () {
      expect(resolver.resolveAll(gloss: 'HOLA'), [modelo]);
    });

    test('una seña con archivo propio también cae al contenedor', () {
      expect(
        resolver.resolveAll(gloss: 'POLICIA', animationFile: 'POLICIA.glb'),
        [modelo],
      );
    });

    test('un término jurídico se deletrea letra por letra', () {
      // DENUNCIA no tiene seña propia: se dactilología, una animación por
      // letra, y por eso devuelve ocho URLs y no una.
      expect(
        resolver.resolveAll(gloss: 'DENUNCIA'),
        List.filled('DENUNCIA'.length, modelo),
      );
    });

    test('una seña sin animación cae al placeholder de texto', () {
      expect(
        resolver.resolveAll(gloss: 'TESTIGO'),
        ['${AnimationUrlResolver.placeholderScheme}TESTIGO'],
      );
    });

    test('las tildes se normalizan antes de buscar en el catálogo', () {
      expect(resolver.resolveAll(gloss: 'Á'), [modelo]);
    });

    test('resolve() devuelve la primera URL de la secuencia', () {
      expect(resolver.resolve(gloss: 'DENUNCIA'), modelo);
    });
  });

  group('RemoteAudioDataSource', () {
    Future<http.Response> Function(http.Request) respondingWith(
            Map<String, dynamic> body) =>
        (_) async => http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});

    test('el deletreo no infla la lista semántica', () async {
      final datasource = RemoteAudioDataSourceImpl(
        apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
        client: MockClient(respondingWith({
          'glosses': ['DENUNCIA', 'LLAMAR'],
          'glossDetails': [
            {'gloss': 'DENUNCIA', 'animationFile': 'DENUNCIA.glb'},
            {'gloss': 'LLAMAR', 'animationFile': 'LLAMA.glb'},
          ],
        })),
        animationResolver: resolver,
      );

      final result =
          await datasource.translateText('Quiero hacer una denuncia');

      // Semántica: una entrada por glosa — si DENUNCIA se contara ocho veces,
      // la inferencia de contexto la pesaría ocho veces.
      expect(result.glosses, ['DENUNCIA', 'LLAMAR']);
      // Reproducción: cada letra deletreada es su propia animación, rotulada
      // con la letra que el avatar está haciendo en ese momento.
      expect(result.animationGlosses,
          ['D', 'E', 'N', 'U', 'N', 'C', 'I', 'A', 'LLAMAR']);
      expect(result.animationUrls, hasLength(9));
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
