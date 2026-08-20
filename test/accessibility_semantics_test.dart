import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/context_selection_widget.dart';

/// Pruebas de accesibilidad (A11Y-01): los elementos interactivos exponen
/// etiquetas de Semantics para lectores de pantalla.
///
/// La primera pantalla pregunta *qué gestión trae* la persona, no el subtipo
/// del hecho: ese detalle solo aparece dentro de Denuncias, que es la única
/// familia con varios contextos debajo.
void main() {
  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ContextSelectionWidget())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('las cuatro entradas son botones accesibles con etiqueta',
      (tester) async {
    await abrir(tester);

    for (final familia in ['Denuncias', 'Consultas', 'Trámites', 'Preguntas']) {
      expect(
        find.bySemanticsLabel(RegExp(familia)),
        findsOneWidget,
        reason: '$familia debe anunciarse como un único botón etiquetado',
      );
    }
  });

  testWidgets('el subtipo del hecho no se pide antes de elegir la gestión',
      (tester) async {
    await abrir(tester);

    expect(find.bySemanticsLabel(RegExp('Denunciar robo')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Declarar como testigo')), findsNothing);
  });

  testWidgets('Denuncias despliega sus contextos, ya etiquetados',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('Denuncias')));
    await tester.pumpAndSettle();

    for (final ctx in [
      'Denunciar robo',
      'Denunciar violencia',
      'Reportar accidente',
      'Declarar como testigo',
    ]) {
      expect(find.bySemanticsLabel(RegExp(ctx)), findsOneWidget,
          reason: '$ctx debe estar disponible dentro de Denuncias');
    }
  });

  testWidgets('se puede volver de una familia desplegada', (tester) async {
    await abrir(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('Denuncias')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Preguntas')), findsOneWidget);
  });
}
