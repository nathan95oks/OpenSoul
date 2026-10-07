import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/spelling_help.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';

import 'support/fake_webview_platform.dart';

const _marca = AnimationUrlResolver.placeholderScheme;

/// Las letras que se ven arriba a la derecha, en orden.
List<String> _letrasVisibles(WidgetTester tester) {
  final caja = find.byKey(const Key('avatar_deletreo_letras'));
  return [
    for (final t in tester.widgetList<Text>(
      find.descendant(of: caja, matching: find.byType(Text)),
    ))
      t.data!,
  ];
}

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  Future<void> montar(
    WidgetTester tester,
    List<String> pasos,
    List<SpellingHelp> ayudas,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            // Letra grande del sistema, como en algunos celulares.
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.4),
            ),
            child: Scaffold(
              body: Avatar3DViewer(
                isProcessing: false,
                expandToFit: true,
                showBackButton: false,
                animationDuration: const Duration(milliseconds: 800),
                glosses: pasos,
                animationUrls: [for (final p in pasos) '$_marca$p'],
                spellingHelp: ayudas,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('«DERECHOS REALES»: dos palabras, nunca más de 7 letras y sin '
      'salirse de la pantalla', (tester) async {
    final pasos = [...'DERECHOS'.split(''), ...'REALES'.split('')];
    await montar(tester, pasos, const [
      SpellingHelp(start: 0, end: 7, word: 'DERECHOS'),
      SpellingHelp(start: 8, end: 13, word: 'REALES'),
    ]);

    final vistas = <String>[];
    for (var i = 0; i < pasos.length; i++) {
      final letras = _letrasVisibles(tester);
      vistas.add(letras.join());
      expect(
        letras.where((l) => l != '…').length,
        lessThanOrEqualTo(7),
        reason: letras.join(),
      );
      // Nunca se desborda (la franja amarilla y negra de Flutter).
      expect(tester.takeException(), isNull);
      final caja = tester.getRect(
        find.byKey(const Key('avatar_deletreo_letras')),
      );
      expect(caja.right, lessThanOrEqualTo(320));
      expect(caja.left, greaterThanOrEqualTo(0));
      await tester.pump(const Duration(milliseconds: 800));
    }
    // Primero DERECHOS, con «…» porque no entra entera…
    expect(vistas.first, 'DERECHO…');
    expect(vistas[7], '…ERECHOS');
    // …y después REALES sola, sin pegarse a DERECHOS.
    expect(vistas[8], 'REALES');
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('sin saber dónde empieza cada palabra, también se recorta', (
    tester,
  ) async {
    final pasos = 'ELECTROENCEFALOGRAFISTA'.split('');
    await montar(tester, pasos, const []);
    for (var i = 0; i < pasos.length; i++) {
      final letras = _letrasVisibles(tester);
      expect(letras.where((l) => l != '…').length, lessThanOrEqualTo(7));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 800));
    }
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
