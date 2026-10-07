import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';

import 'support/fake_webview_platform.dart';

const _marca = AnimationUrlResolver.placeholderScheme;
const _pasos = ['HOLA', 'TRAMITE'];

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  Future<void> montar(WidgetTester tester, {required bool conFlecha}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 700,
              child: Avatar3DViewer(
                isProcessing: false,
                expandToFit: true,
                showBackButton: conFlecha,
                animationDuration: const Duration(milliseconds: 500),
                glosses: _pasos,
                animationUrls: [for (final p in _pasos) '$_marca$p'],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// La glosa de la esquina (el rótulo violeta), no el texto del aviso de
  /// seña sin animación del centro.
  Finder glosaDeLaEsquina(String g) => find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.data == g &&
        w.style?.fontSize == 14 &&
        w.style?.color == Colors.white,
  );

  testWidgets('Voz a LSB: al terminar se va la última glosa y repetir queda '
      'en su lugar', (tester) async {
    await montar(tester, conFlecha: false);

    // Mientras se hace la seña: la glosa, y repetir debajo.
    expect(glosaDeLaEsquina('HOLA'), findsOneWidget);
    final glosa = tester.getRect(glosaDeLaEsquina('HOLA'));
    final repetirAntes = tester.getRect(
      find.byKey(const Key('avatar_repetir')),
    );
    expect(repetirAntes.top, greaterThan(glosa.bottom));

    // Termina la frase.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(glosaDeLaEsquina('TRAMITE'), findsNothing);
    expect(glosaDeLaEsquina('HOLA'), findsNothing);

    // Repetir sigue, arriba a la derecha: donde estaba la glosa.
    final repetir = tester.getRect(find.byKey(const Key('avatar_repetir')));
    expect(repetir.top, lessThan(repetirAntes.top));
    // La esquina superior derecha: 14 px del borde, como la glosa.
    expect(repetir.top, closeTo(14, 2));
    expect(repetir.right, closeTo(400 - 14, 2));
    expect(repetir.top, lessThanOrEqualTo(glosa.top));

    // Y vuelve a hacer la frase: reaparece la glosa.
    await tester.tap(find.byKey(const Key('avatar_repetir')));
    await tester.pump();
    await tester.pump();
    expect(glosaDeLaEsquina('HOLA'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('con flecha de volver (otras vistas) nada cambia', (
    tester,
  ) async {
    await montar(tester, conFlecha: true);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(glosaDeLaEsquina('TRAMITE'), findsOneWidget);
    expect(find.byKey(const Key('avatar_repetir')), findsNothing);
    expect(find.byTooltip('Volver a hacer la seña'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
