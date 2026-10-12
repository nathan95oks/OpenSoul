import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/features/conversation/presentation/widgets/chat_doodle_background.dart';

/// Los dibujitos del chat son decoración: van debajo de los mensajes, no
/// roban toques ni se leen con el lector de pantalla.
void main() {
  testWidgets('los dibujos van debajo y no roban toques', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatDoodleBackground(
          child: Center(
            child: TextButton(
              onPressed: () => tocado = true,
              child: const Text('mensaje'),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('fondo_chat_dibujos')), findsOneWidget);
    await tester.tap(find.text('mensaje'));
    expect(tocado, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el lector de pantalla no los anuncia', (tester) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: ChatDoodleBackground(child: SizedBox.expand())),
    );
    expect(
      find.descendant(
        of: find.byType(ExcludeSemantics),
        matching: find.byKey(const Key('fondo_chat_dibujos')),
      ),
      findsOneWidget,
    );
    semantica.dispose();
  });
}
