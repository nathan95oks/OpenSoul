import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/core/data/datasources/remote_audio_datasource.dart';
import 'package:lsb_legal_app/core/di/injection.dart'
    show pendingSignCatalogProvider, remoteAudioDataSourceProvider;
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';
import 'package:lsb_legal_app/core/presentation/widgets/shared_avatar.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart';

import 'support/fake_webview_platform.dart';

/// Voz a LSB, con el avatar compartido de la app, en celulares de distintos
/// tamaños y con la letra del sistema agrandada: nada se desborda (en un
/// celular, el desborde se ve como una franja amarilla y negra).
void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  final catalogo = PendingSignCatalog.fromJsonString(
    File('assets/dictionary/senas_sin_sena.json').readAsStringSync(),
  );

  // Una frase que lo junta todo: una seña con expresión (MIEDO), siglas con
  // descripción (FELCC), una palabra con sinónimo (REALIZAR), dos palabras
  // deletreadas seguidas (DERECHOS REALES), una larga y muchos pasos.
  final pasos = [
    'MIEDO',
    ...'REALIZAR'.split(''),
    'TRAMITE',
    ...'FELCC'.split(''),
    ...'DERECHOSREALES'.split(''),
    'MIEDO',
    ...'ELECTROENCEFALOGRAFISTA'.split(''),
  ];
  final respuesta = jsonEncode({
    'glosses': pasos,
    'animationSequence': [
      for (final p in pasos)
        {'gloss': p, 'animationFile': p.length == 1 ? '' : 'avatar_test.glb'},
    ],
    'glossDetails': [
      {
        'gloss': 'FELCC',
        'available': false,
        'spelledLetters': 'FELCC'.split(''),
      },
    ],
    'fidelityFixes': [
      for (final w in [
        'REALIZAR',
        'DERECHOS REALES',
        'ELECTROENCEFALOGRAFISTA',
      ])
        {'palabra': w, 'accion': 'concepto_sin_catalogo'},
    ],
  });

  for (final (ancho, alto) in [
    (280.0, 653.0),
    (320.0, 568.0),
    (360.0, 640.0),
    (393.0, 851.0),
  ]) {
    for (final escala in [1.0, 1.3, 2.0]) {
      testWidgets('$ancho×$alto, letra ×$escala: sin franja de desborde', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(ancho * 3, alto * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              pendingSignCatalogProvider.overrideWith((ref) async => catalogo),
              remoteAudioDataSourceProvider.overrideWithValue(
                RemoteAudioDataSourceImpl(
                  apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
                  client: MockClient(
                    (_) async => http.Response(
                      respuesta,
                      200,
                      headers: {
                        'content-type': 'application/json; charset=utf-8',
                      },
                    ),
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(escala)),
                child: SharedAvatarHost(child: child!),
              ),
              home: const AudioToLsbScreen(),
            ),
          ),
        );
        final problemas = <String>[];
        void revisar() {
          final e = tester.takeException();
          if (e != null) problemas.add('$e'.split('\n').first);
        }

        // En reposo, también con el teclado abierto.
        await tester.pump(const Duration(seconds: 1));
        tester.view.viewInsets = FakeViewPadding(bottom: 300 * 3);
        await tester.pump(const Duration(milliseconds: 500));
        revisar();
        tester.view.resetViewInsets();
        await tester.pump(const Duration(milliseconds: 500));

        // Reproduciendo la frase entera y en reposo al terminar.
        await tester.enterText(
          find.byType(TextField),
          'quiero realizar un tramite en la felcc',
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Enviar mensaje'));
        for (var i = 0; i < 2 * (pasos.length * 3 + 5); i++) {
          await tester.pump(const Duration(milliseconds: 500));
          revisar();
        }
        expect(problemas.toSet(), isEmpty);
      });
    }
  }
}
