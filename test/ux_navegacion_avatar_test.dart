import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';
import 'package:lsb_legal_app/core/presentation/widgets/motion.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/context_selection_widget.dart';

import 'support/fake_webview_platform.dart';

/// Mejoras de experiencia: el avatar de Conversación sin controles y la
/// flecha de un contexto que vuelve a la lista de su familia.
void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();

  group('avatar de Conversación', () {
    Future<void> montar(
      WidgetTester tester, {
      required bool controles,
      bool flecha = true,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Avatar3DViewer(
                isProcessing: false,
                showControls: controles,
                showBackButton: flecha,
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

    testWidgets('la vista previa conserva los dos botones', (tester) async {
      await montar(tester, controles: true);
      expect(find.byTooltip('Volver a escribir'), findsOneWidget);
      expect(find.byTooltip('Volver a hacer la seña'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Voz a LSB: sin flecha y repetir bajo la glosa', (
      tester,
    ) async {
      await montar(tester, controles: true, flecha: false);
      expect(find.byTooltip('Volver a escribir'), findsNothing);
      final repetir = tester.getTopLeft(
        find.byTooltip('Volver a hacer la seña'),
      );
      final glosa = tester.getBottomLeft(find.text('HOLA'));
      expect(repetir.dy, greaterThan(glosa.dy), reason: 'debajo de la glosa');
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

  group('burbuja', () {
    testWidgets('la sección entra creciendo y termina en su tamaño', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BubbleEntrance(
            index: 0,
            child: SizedBox(width: 50, height: 50),
          ),
        ),
      );
      final escala = find.byType(ScaleTransition);
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.widget<ScaleTransition>(escala).scale.value, lessThan(1));
      await tester.pumpAndSettle();
      expect(tester.widget<ScaleTransition>(escala).scale.value, 1);
    });

    testWidgets('al tocar se hunde y al soltar vuelve', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: BubblePress(
              child: ColoredBox(
                color: Colors.black,
                child: SizedBox(width: 80, height: 80),
              ),
            ),
          ),
        ),
      );
      double escala() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      final gesto = await tester.startGesture(
        tester.getCenter(find.byType(BubblePress)),
      );
      await tester.pump();
      expect(escala(), lessThan(1));
      await gesto.up();
      await tester.pumpAndSettle();
      expect(escala(), 1);
    });
  });
}
