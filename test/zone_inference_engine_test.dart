import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/engines/context_engine/context_catalog.dart';
import 'package:lsb_legal_app/core/engines/context_engine/zone_inference_engine.dart';

/// El enunciado del oyente debe llevar a la pregunta que hizo, no al principio
/// del árbol. Sin esto, «¿a qué hora y dónde te robaron?» obliga a la persona
/// sorda a recorrer nueve preguntas para contestar dos.
void main() {
  const engine = ZoneInferenceEngine();
  final robo = contextById('denuncia_robo')!;

  List<String> zonesOf(String text, [SemanticContext? context]) =>
      engine.zonesFor(context: context ?? robo, text: text);

  group('preguntas simples', () {
    test('el tiempo lleva a la zona de tiempo', () {
      expect(zonesOf('¿A qué hora te robaron?'), ['tiempo']);
      expect(zonesOf('¿Cuándo pasó?'), ['tiempo']);
    });

    test('el lugar lleva a la zona de lugar', () {
      expect(zonesOf('¿Dónde te robaron?'), ['lugar']);
      expect(zonesOf('¿En qué lugar ocurrió?'), ['lugar']);
    });

    test('la persona lleva a la zona de personas', () {
      expect(zonesOf('¿Quién te robó?'), ['personas']);
    });

    test('lo sustraído lleva a la zona de objetos', () {
      expect(zonesOf('¿Qué se llevaron?'), ['objetos']);
    });
  });

  group('preguntas compuestas', () {
    test('devuelve las dos zonas en el orden en que se preguntaron', () {
      expect(zonesOf('¿A qué hora y dónde te robaron?'), ['tiempo', 'lugar']);
    });

    test('el orden sigue a la frase, no al catálogo', () {
      // En el catálogo 'lugar' va antes que 'tiempo'; aquí se preguntó al revés.
      expect(zonesOf('¿Dónde y a qué hora fue?'), ['lugar', 'tiempo']);
    });

    test('reconoce tres zonas', () {
      expect(
        zonesOf('¿Quién te robó, dónde y qué se llevaron?'),
        ['personas', 'lugar', 'objetos'],
      );
    });
  });

  group('prudencia', () {
    test('una frase sin interrogativo no señala ninguna zona', () {
      expect(zonesOf('Le robaron su celular'), isEmpty);
      expect(zonesOf('Buenos días, tome asiento'), isEmpty);
    });

    test('texto vacío no señala nada', () {
      expect(zonesOf(''), isEmpty);
    });

    test('solo devuelve zonas que existen en el contexto dado', () {
      // 'orientacion' no tiene zona de objetos sustraídos ni de arma.
      final orientacion = contextById('orientacion')!;
      final zones = zonesOf('¿Qué se llevaron y usó algún arma?', orientacion);
      for (final id in zones) {
        expect(orientacion.zoneById(id), isNotNull);
      }
    });
  });

  test('toda zona señalada existe en el contexto', () {
    const preguntas = [
      '¿A qué hora fue?',
      '¿Dónde ocurrió?',
      '¿Quién fue?',
      '¿Qué ropa llevaba?',
      '¿Cómo era físicamente?',
      '¿Necesitas ayuda urgente?',
    ];
    for (final ctx in availableContexts) {
      for (final pregunta in preguntas) {
        for (final id in engine.zonesFor(context: ctx, text: pregunta)) {
          expect(ctx.zoneById(id), isNotNull,
              reason: '$pregunta señaló "$id", ausente en ${ctx.id}');
        }
      }
    }
  });
}
