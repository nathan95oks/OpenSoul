import 'dart:convert';

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
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart';

import 'support/fake_webview_platform.dart';

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  const pasos = ['QUERER', 'TRAMITE', 'HOLA', 'GRACIAS'];

  Future<void> enviar(WidgetTester tester, String texto) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingSignCatalogProvider.overrideWith(
            (ref) async => PendingSignCatalog.empty,
          ),
          remoteAudioDataSourceProvider.overrideWithValue(
            RemoteAudioDataSourceImpl(
              apiGatewayUrl: 'https://example.test/OpenSoul-TextToLSB',
              client: MockClient(
                (_) async => http.Response(
                  jsonEncode({
                    'glosses': pasos,
                    // Sin clip: cada paso dura lo de un aviso (3 s).
                    'animationSequence': [
                      for (final p in pasos) {'gloss': p, 'animationFile': ''},
                    ],
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AudioToLsbScreen()),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), texto);
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar mensaje'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('mientras el avatar hace la frase, la flecha vuelve a escribir '
      'con el mensaje para corregirlo', (tester) async {
    await enviar(tester, 'quiero realizar un tramite');

    // El campo se fue y el avatar está haciendo la frase: flecha arriba a
    // la izquierda, repetir a la derecha.
    expect(find.byType(TextField), findsNothing);
    final flecha = find.byKey(const Key('avatar_volver'));
    expect(flecha, findsOneWidget);
    final rect = tester.getRect(flecha);
    final pantalla = tester.getSize(find.byType(AudioToLsbScreen));
    expect(rect.center.dx, lessThan(pantalla.width / 2));
    expect(
      tester.getRect(find.byKey(const Key('avatar_repetir'))).center.dx,
      greaterThan(pantalla.width / 2),
    );

    await tester.tap(flecha);
    await tester.pump();
    // Se termina la seña en curso (no se corta en seco) y vuelve el campo.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'quiero realizar un tramite',
    );
    expect(find.byKey(const Key('avatar_volver')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('sin tocar la flecha, al terminar el campo vuelve vacío', (
    tester,
  ) async {
    await enviar(tester, 'hola');
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byKey(const Key('avatar_volver')), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 2));
  });
}
