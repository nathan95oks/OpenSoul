import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/services/context_catalog.dart';
import 'package:lsb_legal_app/core/domain/services/context_inference_engine.dart';

import 'helpers/official_dictionary.dart';

/// El motor se audita contra el diccionario canónico real, no contra un
/// léxico de laboratorio: su calidad depende de cómo estén etiquetadas las
/// entradas, así que la prueba debe fallar si esas etiquetas se degradan.
void main() {
  late ContextInferenceEngine engine;

  setUp(() {
    engine = ContextInferenceEngine.fromLexicon(loadOfficialEntries());
  });

  group('inferencia a partir de las glosas del motor de traducción', () {
    test('glosa exclusiva de robo decide el contexto', () {
      final suggestion = engine.infer(glosses: ['AYER', 'TU', 'ROBAR']);

      expect(suggestion, isNotNull);
      expect(suggestion!.contextId, 'denuncia_robo');
      expect(suggestion.evidence, contains('ROBAR'));
    });

    test('glosa exclusiva de violencia decide el contexto', () {
      final suggestion = engine.infer(glosses: ['HOMBRE', 'MALTRATAR']);

      expect(suggestion?.contextId, 'violencia');
    });

    test('los trámites resuelven al contexto de trámite', () {
      final suggestion = engine.infer(glosses: ['PASAPORTE', 'GESTIONAR']);

      expect(suggestion?.contextId, 'tramite');
    });

    test('una consulta de estado no se confunde con un trámite', () {
      final suggestion = engine.infer(glosses: ['ESTADO', 'SEGUIMIENTO']);

      expect(suggestion?.contextId, 'consulta',
          reason: 'desde la escisión, consultar el estado de un caso y '
              'presentar documentación son flujos distintos');
    });

    test('las glosas presentes en todos los contextos no sugieren nada', () {
      // HOMBRE y MUJER aparecen en todos los contextos: su peso es cero y no
      // hay evidencia real que respalde ninguna propuesta.
      expect(engine.infer(glosses: ['HOMBRE', 'MUJER']), isNull);
    });
  });

  group('respaldo por texto cuando no hay glosas', () {
    test('reconoce la raíz léxica aunque el verbo esté conjugado', () {
      final suggestion = engine.infer(text: '¿Le robaron su teléfono?');

      expect(suggestion?.contextId, 'denuncia_robo');
    });

    test('reconoce una gestión de trámite', () {
      final suggestion = engine.infer(text: 'Necesito gestionar mi pasaporte');

      expect(suggestion?.contextId, 'tramite');
    });

    test('la evidencia mostrada son glosas, nunca raices internas', () {
      // Las raices lexicas ('rob') puntuan pero no se enseñan: no significan
      // nada para quien lee la pantalla.
      final suggestion = engine.infer(
        glosses: ['ROBAR', 'TELEFONO'],
        text: 'Le robaron su teléfono',
      );

      expect(suggestion!.evidence, isNotEmpty);
      for (final item in suggestion.evidence) {
        expect(item, isNot('ROB'));
        expect(item, anyOf('ROBAR', 'TELEFONO'));
      }
    });
  });

  group('prudencia: mejor no sugerir que sugerir mal', () {
    test('una frase de cortesía no dispara ninguna sugerencia', () {
      expect(engine.infer(text: 'Buenos días, tome asiento por favor'), isNull);
    });

    test('sin entrada no hay sugerencia', () {
      expect(engine.infer(), isNull);
    });

    test('el motor vacío nunca sugiere', () {
      final empty = ContextInferenceEngine.empty();

      expect(empty.infer(glosses: ['ROBAR'], text: 'me robaron'), isNull);
    });
  });

  group('resolución del contexto propuesto', () {
    test('todo contexto sugerible existe en el catálogo', () {
      // Si la inferencia propusiera un id sin contexto real, el flujo de
      // tarjetas no podría abrirse y la respuesta se quedaría bloqueada.
      for (final frase in const [
        'Le robaron su teléfono',
        'Un hombre la maltrató',
        'Necesito gestionar mi pasaporte',
      ]) {
        final suggestion = engine.infer(text: frase);
        expect(suggestion, isNotNull, reason: frase);
        expect(contextById(suggestion!.contextId), isNotNull, reason: frase);
      }
    });

    test('un id desconocido no resuelve a ningún contexto', () {
      expect(contextById('no_existe'), isNull);
    });
  });
}
