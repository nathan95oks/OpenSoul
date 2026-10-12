import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

/// Voz a LSB: una palabra con seña en el avatar (ACOSO, BULLYING…) se hace
/// con su seña aunque la Lambda —desplegada antes del arreglo, o desde su
/// caché— la mande deletreada, y no se explica ni se resalta como deletreo.
void main() {
  Map<String, Object?> deletreada(String palabra, {String? otra}) => {
    'glosses': [?otra, ...palabra.split('')],
    'glossDetails': [
      if (otra != null) {'gloss': otra, 'available': true},
      {
        'gloss': palabra,
        'available': false,
        'spelledLetters': palabra.split(''),
      },
    ],
    'animationSequence': [
      if (otra != null)
        {'gloss': otra, 'animationFile': 'x.glb', 'sourceGloss': otra},
      for (final l in palabra.split(''))
        {'gloss': l, 'animationFile': 'x.glb', 'sourceGloss': palabra},
    ],
    'fidelityFixes': [
      {'palabra': palabra, 'accion': 'concepto_sin_catalogo'},
    ],
  };

  RemoteAudioDataSourceImpl fuente(Map<String, Object?> respuesta) =>
      RemoteAudioDataSourceImpl(
        apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(respuesta),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        animationResolver: const AnimationUrlResolver(baseUrl: 'https://x/'),
      );

  for (final palabra in ['ACOSO', 'BULLYING', 'JUICIO', 'TRATA_TRAFICO']) {
    test('$palabra deletreada por el servidor se hace con su seña', () async {
      final t = await fuente(
        deletreada(palabra, otra: 'VIOLENCIA'),
      ).translateText('violencia ${palabra.toLowerCase()}');
      expect(t.animationGlosses, ['VIOLENCIA', palabra]);
      expect(
        t.animationUrls.every((u) => !u.startsWith('placeholder://')),
        isTrue,
      );
      expect(t.spelledWords, isEmpty, reason: 'sin descripción');
      expect(t.unanimatedSigns, isEmpty, reason: 'sin resaltar');
    });
  }

  test('una palabra sin seña en el avatar se sigue deletreando', () async {
    final t = await fuente(deletreada('DENUNCIA')).translateText('denuncia');
    expect(t.animationGlosses, 'DENUNCIA'.split(''));
    expect(t.unanimatedSigns, ['DENUNCIA']);
  });

  // Respuesta real de la Lambda desplegada (grabada en el QA): BULLYING viene
  // en letras sueltas en `glosses` y en la secuencia, y HIJO deletreado porque
  // al .glb de S3 le faltaba su clip.
  for (final frase in [
    '¿Su hijo sufre bullying en la escuela?',
    '¿Usted o su hijo sufre bullying?',
  ]) {
    test('respuesta real: «$frase»', () async {
      final grabadas =
          jsonDecode(File('test/qa/lambda_respuestas.json').readAsStringSync())
              as Map<String, dynamic>;
      final clave = grabadas.keys.firstWhere(
        (k) => k.startsWith('texto/') && k.contains(jsonEncode(frase)),
      );
      final cuerpo =
          jsonDecode((grabadas[clave] as Map)['cuerpo'] as String)
              as Map<String, Object?>;
      final t = await fuente(cuerpo).translateText(frase);
      expect(t.animationGlosses, containsAll(['HIJO', 'BULLYING']));
      expect(t.glosses, contains('BULLYING'));
      expect(t.glosses.join(' '), isNot(contains('B U L L')));
      expect(t.animationGlosses.length, t.animationUrls.length);
      expect(t.spelledWords, isNot(contains('BULLYING')));
    });
  }
}
