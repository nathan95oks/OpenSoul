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

  test('en la pantalla de un teléfono ningún dibujo se repite', () {
    // El chat se ancla arriba a la izquierda; 430×800 cubre los teléfonos.
    final pantalla = (Offset.zero & const Size(430, 800)).inflate(24);
    final tipos = [
      for (final (centro, tipo) in chatDoodleLayout())
        if (pantalla.contains(centro)) tipo,
    ];
    expect(tipos.length, greaterThan(15), reason: 'hay dibujos de sobra');
    expect(tipos.toSet().length, tipos.length);
  });

  test('en una tableta los dibujos iguales quedan lejos entre sí', () {
    final pantalla = (Offset.zero & const Size(1280, 1280)).inflate(24);
    final dentro = chatDoodleLayout()
        .where((e) => pantalla.contains(e.$1))
        .toList();
    for (var i = 0; i < dentro.length; i++) {
      for (var j = i + 1; j < dentro.length; j++) {
        if (dentro[i].$2 != dentro[j].$2) continue;
        expect((dentro[i].$1 - dentro[j].$1).distance, greaterThan(450));
      }
    }
  });
}
