import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';

void main() {
  group('catálogo: opciones sin sentido retiradas', () {
    test('VER ya no se ofrece como respuesta a "¿conoce a esa persona?"', () {
      final zona = contextById('denuncia_robo')!.zoneById('conocimiento')!;
      expect(zona.glossAllowlist.contains('VER'), false);
      // Sigue siendo una respuesta válida en otros lados (p. ej. testigo).
      expect(zona.glossAllowlist, containsAll(['SÍ', 'NO', 'AMIGO', 'PAREJA']));
    });

    test('la evidencia ofrece fotos, video, factura y "escribir otro"', () {
      final zona = contextById('denuncia_robo')!.zoneById('evidencia')!;
      expect(zona.glossAllowlist, ['FOTOS', 'VIDEO', 'FACTURA', 'ESCRIBIR']);
    });
  });
}
