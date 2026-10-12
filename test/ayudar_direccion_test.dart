import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/help_direction.dart';
import 'package:lsb_legal_app/core/domain/services/local_audio_translator.dart';

/// El avatar no tiene AYUDAR: tiene AYUDAR_DAR (yo te ayudo) y AYUDAR_PEDIR
/// (ayúdame, necesito ayuda). «Buenos días, ¿en qué le puedo ayudar?»
/// deletreaba AYUDAR.
void main() {
  const casos = {
    'Buenos días, ¿en qué le puedo ayudar?': 'AYUDAR_DAR',
    'buenos dias en que le puedo ayudar': 'AYUDAR_DAR',
    'Le ayudo con su trámite': 'AYUDAR_DAR',
    'Lo vamos a ayudar': 'AYUDAR_DAR',
    'Podemos ayudarle con eso': 'AYUDAR_DAR',
    'Necesito ayuda': 'AYUDAR_PEDIR',
    '¿Necesita ayuda?': 'AYUDAR_PEDIR',
    '¿Me puede ayudar?': 'AYUDAR_PEDIR',
    '¿Puede ayudarme?': 'AYUDAR_PEDIR',
    'Ayúdeme por favor': 'AYUDAR_PEDIR',
    'Pido ayuda': 'AYUDAR_PEDIR',
    '¡Auxilio!': 'AYUDAR_PEDIR',
  };

  group('regla', () {
    casos.forEach((texto, esperada) {
      test('«$texto» → $esperada', () {
        expect(HelpDirection.forText(texto).first, esperada);
      });
    });

    test('cada aparición con su dirección', () {
      expect(
        HelpDirection.apply([
          'AYUDAR',
          'AYUDAR',
        ], 'Le voy a ayudar. ¿Usted me ayuda también?'),
        ['AYUDAR_DAR', 'AYUDAR_PEDIR'],
      );
    });
  });

  group('sin conexión', () {
    casos.forEach((texto, esperada) {
      test('«$texto»', () {
        final t = const LocalAudioTranslator().translate(texto);
        expect(t.glosses, contains(esperada));
        expect(t.animationGlosses, contains(esperada));
      });
    });
  });

  test(
    'la Lambda desplegada manda AYUDAR deletreado: se hace AYUDAR_DAR',
    () async {
      // La forma real: AYUDAR no tiene clip en el .glb y llega letra por letra.
      final respuesta = {
        'glosses': ['BUENOS_DIAS', 'AYUDAR', 'PUEDO'],
        'glossDetails': [
          {'gloss': 'BUENOS_DIAS', 'available': true},
          {
            'gloss': 'AYUDAR',
            'available': false,
            'spelledLetters': 'AYUDAR'.split(''),
          },
          {'gloss': 'PUEDO', 'available': true},
        ],
        'animationSequence': [
          {
            'gloss': 'BUENOS_DIAS',
            'animationFile': 'x.glb',
            'sourceGloss': 'BUENOS_DIAS',
          },
          for (final l in 'AYUDAR'.split(''))
            {'gloss': l, 'animationFile': 'x.glb', 'sourceGloss': 'AYUDAR'},
          {'gloss': 'PUEDO', 'animationFile': 'x.glb', 'sourceGloss': 'PUEDO'},
        ],
      };
      final fuente = RemoteAudioDataSourceImpl(
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
      final t = await fuente.translateText(
        'Buenos días, ¿en qué le puedo ayudar?',
      );
      expect(t.animationGlosses, ['BUENOS_DIAS', 'AYUDAR_DAR', 'PUEDO']);
      expect(
        t.animationUrls.any((u) => u.startsWith('placeholder://')),
        isFalse,
      );
      expect(t.glosses, contains('AYUDAR_DAR'));
      expect(t.glosses, isNot(contains('AYUDAR')));
    },
  );
}
