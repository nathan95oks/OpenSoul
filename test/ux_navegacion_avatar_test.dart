import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/context_selection_widget.dart';

import 'support/fake_webview_platform.dart';

/// Mejoras de experiencia: el avatar de Conversación sin controles y la
/// flecha de un contexto que vuelve a la lista de su familia.
void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  group('avatar de Conversación', () {
    Future<void> montar(WidgetTester tester, {required bool controles}) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Avatar3DViewer(
                isProcessing: false,
                showControls: controles,
                glosses: const ['HOLA'],
                animationUrls: const [
                  '${AnimationUrlResolver.placeholderScheme}HOLA',
                ],
                animationDuration: const Duration(milliseconds: 1),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('sin flecha de volver ni botón de repetir', (tester) async {
      await montar(tester, controles: false);
      expect(find.byTooltip('Volver a escribir'), findsNothing);
      expect(find.byTooltip('Volver a hacer la seña'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Voz a LSB conserva los dos botones', (tester) async {
      await montar(tester, controles: true);
      expect(find.byTooltip('Volver a escribir'), findsOneWidget);
      expect(find.byTooltip('Volver a hacer la seña'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('volver desde un contexto', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    Future<void> seleccion(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ContextSelectionWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Entrar a un contexto desmonta la selección; la flecha la vuelve a
    /// montar al limpiar el contexto.
    Future<void> entrarYVolver(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await seleccion(tester);
    }

    for (final familia in ['Denuncias', 'Trámites']) {
      testWidgets('la flecha vuelve a la lista de $familia', (tester) async {
        await seleccion(tester);
        await tester.tap(find.text(familia));
        await tester.pumpAndSettle();
        expect(find.text('Volver'), findsOneWidget);

        await entrarYVolver(tester);
        expect(
          find.text('Volver'),
          findsOneWidget,
          reason: 'sigue en la lista de $familia, no en el menú principal',
        );
        expect(container.read(openFamilyProvider), isNotNull);
      });
    }

    testWidgets('«Volver» de la lista lleva al menú principal', (tester) async {
      await seleccion(tester);
      await tester.tap(find.text('Denuncias'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Volver'), findsNothing);

      await entrarYVolver(tester);
      expect(find.text('Volver'), findsNothing);
      expect(find.text('Trámites'), findsOneWidget);
    });
  });
}
