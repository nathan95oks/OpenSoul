import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/context_selection_widget.dart';

/// Pruebas de accesibilidad (A11Y-01): los elementos interactivos exponen
/// etiquetas de Semantics para lectores de pantalla.
void main() {
  testWidgets('las tarjetas de contexto son botones accesibles con etiqueta',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ContextSelectionWidget()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Cada contexto se anuncia con su nombre y descripción (excludeSemantics
    // colapsa emoji + flecha + textos en una sola etiqueta de botón).
    expect(
      find.bySemanticsLabel(RegExp('Denunciar robo')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Orientación y trámites legales')),
      findsOneWidget,
    );
  });
}
