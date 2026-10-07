import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/di/injection.dart'
    show pendingSignCatalogProvider, remoteAudioDataSourceProvider;
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';
import 'package:lsb_legal_app/core/domain/services/spelling_help.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/domain/services/lost_verbs.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';

const _modelo = 'https://x/avatar_test.glb';

final _catalogo = PendingSignCatalog.fromJsonString(
  File('assets/dictionary/senas_sin_sena.json').readAsStringSync(),
);

LsbTranslation _traduccion(List<String> pasos) => LsbTranslation(
  glosses: pasos,
  animationUrl: '',
  animationGlosses: pasos,
  animationUrls: [for (final _ in pasos) _modelo],
);

List<String> _letras(String w) => w.split('');

void main() {
  group('el verbo que la traducción perdió vuelve a la seña', () {
    test('«quiere realizar un tramite en la felcc?»: REALIZAR antes de '
        'TRÁMITE, deletreado, con su sinónimo', () {
      // Lo que devuelve hoy la Lambda desplegada para esa frase.
      final t = LostVerbs.apply(
        'quiere realizar un tramite en la felcc?',
        _traduccion(['QUERER', 'TRAMITE', ..._letras('FELCC')]),
        _catalogo,
      );
      expect(t.animationGlosses, [
        'QUERER',
        ..._letras('REALIZAR'),
        'TRAMITE',
        ..._letras('FELCC'),
      ]);
      expect(t.animationUrls, hasLength(t.animationGlosses.length));
      expect(t.spelledWords, contains('REALIZAR'));
      // Mientras se deletrea, abajo: «Sinónimo en LSB: HACER».
      final ayuda = SpellingHelp.forSteps(
        t.animationGlosses,
        t.spelledWords,
        _catalogo,
      ).single;
      expect((ayuda.start, ayuda.end), (1, 8));
      expect(ayuda.synonyms, ['HACER']);
    });

    test('si ya viene (deletreado o con seña) no se repite', () {
      final pasos = ['QUERER', 'TRAMITE', ..._letras('REALIZAR')];
      final t = _traduccion(pasos);
      expect(
        LostVerbs.apply('quiero realizar un tramite', t, _catalogo),
        same(t),
      );
      final conSena = _traduccion(['NECESITAR', 'EXPLICAR']);
      expect(
        LostVerbs.apply('necesito explicar', conSena, _catalogo),
        same(conSena),
      );
    });

    test(
      '«quiere hacer un trámite»: HACER no tiene animación, se deletrea',
      () {
        final t = LostVerbs.apply(
          'quiere hacer un trámite en la felcc?',
          _traduccion(['QUERER', 'TRAMITE', ..._letras('FELCC')]),
          _catalogo,
        );
        expect(t.animationGlosses, [
          'QUERER',
          ..._letras('HACER'),
          'TRAMITE',
          ..._letras('FELCC'),
        ]);
      },
    );

    test('un verbo con animación se seña, no se deletrea', () {
      final t = LostVerbs.apply(
        'necesito explicar lo que pasó',
        _traduccion(['NECESITAR']),
        _catalogo,
      );
      expect(t.animationGlosses, ['NECESITAR', 'EXPLICAR']);
      expect(t.animationUrls.last, isNot(startsWith('placeholder')));
    });

    test('«voy a denunciar», «tengo que pagar»', () {
      expect(
        LostVerbs.apply(
          'voy a denunciar',
          _traduccion(['YO', 'IR']),
          _catalogo,
        ).animationGlosses,
        ['YO', 'IR', ..._letras('DENUNCIAR')],
      );
      expect(
        LostVerbs.apply(
          'tengo que pagar',
          _traduccion(['TENER']),
          _catalogo,
        ).animationGlosses,
        // PAGAR tiene seña equivalente (DAR BILLETES) pero no es la misma
        // palabra: si falta, se deletrea.
        ['TENER', ..._letras('PAGAR')],
      );
    });

    test('un sustantivo terminado en -ar no se toca', () {
      final t = _traduccion(['DÓNDE', 'PASADO']);
      expect(LostVerbs.apply('¿en qué lugar ocurrió?', t, _catalogo), same(t));
    });
  });

  test('Voz a LSB, de extremo a extremo: no se pierde REALIZAR', () async {
    final respuesta = {
      'glosses': ['QUERER', 'TRAMITE', 'FELCC'],
      'animationSequence': [
        {'gloss': 'QUERER', 'animationFile': 'avatar_test.glb'},
        {'gloss': 'TRAMITE', 'animationFile': 'avatar_test.glb'},
        for (final l in 'FELCC'.split(''))
          {'gloss': l, 'animationFile': 'avatar_test.glb'},
      ],
      'glossDetails': [
        {'gloss': 'QUERER', 'available': true},
        {'gloss': 'TRAMITE', 'available': true},
        {
          'gloss': 'FELCC',
          'available': false,
          'spelledLetters': ['F', 'E', 'L', 'C', 'C'],
        },
      ],
      'fidelityFixes': <Object>[],
      'semanticStatus': 'resolved',
      'representationStatus': 'complete',
    };
    final c = ProviderContainer(
      overrides: [
        remoteAudioDataSourceProvider.overrideWithValue(
          RemoteAudioDataSourceImpl(
            apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
            client: MockClient(
              (_) async => http.Response(
                jsonEncode(respuesta),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
            ),
            animationResolver: const AnimationUrlResolver(
              baseUrl: 'https://x/',
            ),
          ),
        ),
        pendingSignCatalogProvider.overrideWith((ref) async => _catalogo),
      ],
    );
    addTearDown(c.dispose);
    c
        .read(audioTranslationControllerProvider.notifier)
        .processText('quiere realizar un tramite en la felcc?');
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (c.read(audioTranslationControllerProvider).status !=
          AudioTranslationStatus.processing) {
        break;
      }
    }
    final estado = c.read(audioTranslationControllerProvider);
    expect(estado.status, AudioTranslationStatus.success);
    final t = estado.translationResult!;
    expect(t.animationGlosses, [
      'QUERER',
      ..._letras('REALIZAR'),
      'TRAMITE',
      ..._letras('FELCC'),
    ]);

    // Lo que se ve abajo mientras deletrea cada una.
    final ayudas = SpellingHelp.forSteps(t.animationGlosses, [
      ...t.unanimatedSigns,
      ...t.spelledWords,
    ], _catalogo);
    expect(ayudas.map((h) => h.word), ['REALIZAR', 'FELCC']);
    expect(ayudas[0].synonyms, ['HACER']);
    final felcc = ayudas[1].description!;
    expect(felcc.isAcronym, isTrue);
    expect(felcc.lsbDescription, [
      'POLICÍA',
      'INVESTIGACIÓN',
      'ROBAR',
      'ENGAÑAR',
    ]);
  });

  test('toda sigla que la Lambda deletrea siempre tiene descripción', () {
    for (final sigla in ['FELCC', 'FELCV', 'SEPDAVI', 'SEPDEP', 'NUREJ']) {
      final gloss = _catalogo.describedGloss(sigla);
      expect(gloss, isNotNull, reason: sigla);
      expect(_catalogo.infoOf(gloss!).lsbDescription, isNotEmpty);
    }
  });
}
