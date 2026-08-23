import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_suggestion_datasource.dart';

/// El generador de opciones propone, pero no decide qué existe.
///
/// La selección es generativa —el modelo elige y ordena según lo que la
/// persona ya dijo y lo que le acaban de preguntar—, y esa libertad obliga a
/// una red: lo que devuelva se contrasta contra las candidatas que se le
/// enviaron. Una seña inventada no puede llegar a la pantalla, porque el
/// avatar no sabría representarla y la declaración afirmaría algo que la
/// persona nunca eligió.
void main() {
  const url = 'https://ejemplo.test/translate';
  const candidatas = ['HOMBRE', 'MUJER', 'LADRON', 'CALLE'];

  RemoteSuggestionDataSource conRespuesta(String cuerpo, {int status = 200}) =>
      RemoteSuggestionDataSource(
        apiUrl: url,
        client: MockClient((_) async => http.Response(
              cuerpo,
              status,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )),
      );

  test('propone la pregunta y las opciones que devuelve el modelo', () async {
    final ds = conRespuesta(jsonEncode({
      'generated': true,
      'question': '¿Quién te robó?',
      'options': ['LADRON', 'HOMBRE'],
    }));

    final paso = await ds.suggest(
      contextId: 'denuncia_robo', selected: const [], candidates: candidatas);

    expect(paso.question, '¿Quién te robó?');
    expect(paso.options, ['LADRON', 'HOMBRE'],
        reason: 'respeta el orden propuesto, que es la parte generativa');
  });

  test('una glosa inventada no llega a la pantalla', () async {
    final ds = conRespuesta(jsonEncode({
      'generated': true,
      'question': '¿Quién?',
      'options': ['HOMBRE', 'PISTOLA_LASER', 'MUJER'],
    }));

    final paso = await ds.suggest(
      contextId: 'denuncia_robo', selected: const [], candidates: candidatas);

    expect(paso.options, ['HOMBRE', 'MUJER']);
    expect(paso.options, isNot(contains('PISTOLA_LASER')),
        reason: 'el avatar no sabría representarla y nadie la eligió');
  });

  group('el flujo nunca se bloquea por la sugerencia', () {
    test('sin endpoint configurado no se sugiere nada', () async {
      final ds = RemoteSuggestionDataSource(
          apiUrl: '', client: MockClient((_) async => http.Response('', 500)));
      final paso = await ds.suggest(
        contextId: 'x', selected: const [], candidates: candidatas);
      expect(paso.isEmpty, isTrue);
    });

    test('un error del backend deja el paso vacío', () async {
      final paso = await conRespuesta('{}', status: 500).suggest(
        contextId: 'x', selected: const [], candidates: candidatas);
      expect(paso.isEmpty, isTrue);
    });

    test('una respuesta ilegible deja el paso vacío', () async {
      final paso = await conRespuesta('no soy json').suggest(
        contextId: 'x', selected: const [], candidates: candidatas);
      expect(paso.isEmpty, isTrue);
    });

    test('si el modelo solo devuelve invenciones, el paso queda vacío',
        () async {
      final ds = conRespuesta(jsonEncode({
        'generated': true,
        'options': ['INVENTADA_A', 'INVENTADA_B'],
      }));
      final paso = await ds.suggest(
        contextId: 'x', selected: const [], candidates: candidatas);
      expect(paso.isEmpty, isTrue,
          reason: 'vacío significa "usa tu orden local", no "no hay opciones"');
    });

    test('sin candidatas no se llama al backend', () async {
      var llamado = false;
      final ds = RemoteSuggestionDataSource(
        apiUrl: url,
        client: MockClient((_) async {
          llamado = true;
          return http.Response('{}', 200);
        }),
      );
      await ds.suggest(contextId: 'x', selected: const [], candidates: const []);
      expect(llamado, isFalse);
    });
  });

  test('la pregunta del oyente viaja como contexto de la respuesta', () async {
    late Map<String, dynamic> enviado;
    final ds = RemoteSuggestionDataSource(
      apiUrl: url,
      client: MockClient((req) async {
        enviado = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'generated': true, 'options': ['HOMBRE']}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await ds.suggest(
      contextId: 'denuncia_robo',
      selected: const ['ROBAR'],
      candidates: candidatas,
      replyingTo: '¿Necesitas ayuda para hacer una denuncia?',
    );

    expect(enviado['action'], 'suggest');
    expect(enviado['question'], '¿Necesitas ayuda para hacer una denuncia?');
    expect(enviado['selected'], ['ROBAR']);
    expect(enviado['candidates'], candidatas);
  });
}
