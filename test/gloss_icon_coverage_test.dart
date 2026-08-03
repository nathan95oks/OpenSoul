import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/lsb_icons.dart';

import 'helpers/official_dictionary.dart';

/// Toda glosa del flujo de tarjetas debe mostrar un dibujo que represente su
/// acción u objeto.
///
/// La entrada del módulo es visual y táctil: quien construye la declaración
/// se apoya en la imagen antes que en la palabra escrita. Una tarjeta con el
/// ícono genérico obliga a leer, que es justo lo que el módulo evita.
void main() {
  test('todas las glosas declaran un ícono', () {
    final sinIcono = [
      for (final entry in loadOfficialEntries())
        if ((entry.semanticIcon).trim().isEmpty) entry.gloss,
    ];

    expect(sinIcono, isEmpty,
        reason: 'Estas glosas no declaran semanticIcon: ${sinIcono.join(", ")}');
  });

  test('todo ícono declarado se resuelve a un dibujo real', () {
    final huerfanos = <String, List<String>>{};
    for (final entry in loadOfficialEntries()) {
      final icono = entry.semanticIcon.trim();
      if (icono.isEmpty) continue;
      if (kLsbIconMap.containsKey(icono)) continue;
      huerfanos.putIfAbsent(icono, () => []).add(entry.gloss);
    }

    expect(huerfanos, isEmpty,
        reason: 'Estos íconos caerían en el genérico. Añádelos a '
            'kLsbIconMap:\n${huerfanos.entries.map((e) => "  ${e.key} → ${e.value.join(", ")}").join("\n")}');
  });
}
