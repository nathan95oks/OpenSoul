import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/services/conversation_bridge.dart';
import 'package:lsb_legal_app/core/domain/services/zone_inference_engine.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';

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
      // 'tramite' no tiene zona de objetos sustraídos ni de arma.
      final tramite = contextById('tramite')!;
      final zones = zonesOf('¿Qué se llevaron y usó algún arma?', tramite);
      for (final id in zones) {
        expect(tramite.zoneById(id), isNotNull);
      }
    });
  });

  group('preguntas de ventanilla — consultas y trámites', () {
    // El hueco real: hasta ahora el motor solo reconocía lugar y tiempo, así
    // que "¿sabes qué documento debes llevar?" no abría nada y la persona
    // tenía que buscar la pregunta a mano.
    List<String> enTramite(String t) =>
        engine.zonesFor(context: contextById('tramite')!, text: t);
    List<String> enConsulta(String t) =>
        engine.zonesFor(context: contextById('consulta')!, text: t);

    test('el funcionario pregunta por un documento', () {
      expect(enTramite('¿Sabes qué documento debes llevar?'), ['documento']);
      expect(enConsulta('¿Qué documentación necesita?'), contains('documento'));
    });

    test('el funcionario pide el número de caso', () {
      expect(enTramite('¿Tiene el número de su caso?'), contains('caso'));
      expect(enConsulta('¿Me da su NUREJ?'), contains('identificador'));
    });

    test('el funcionario pregunta a dónde acudir', () {
      expect(enTramite('¿Ante qué institución?'), contains('donde'));
      expect(enConsulta('¿Ante qué institución?'), contains('donde'));
    });

    test('el funcionario ofrece apoyo', () {
      expect(enTramite('¿Necesita un intérprete?'), contains('apoyo'));
    });

    test('una pregunta sin marcador sigue sin abrir nada', () {
      // Prudencia: mejor la zona de entrada que una adivinada.
      expect(enTramite('Buenos días, tome asiento'), isEmpty);
    });
  });

  group('el flujo guiado abre donde se preguntó', () {
    ProviderContainer containerAsking(String question) {
      final container = ProviderContainer(overrides: [
        pendingReplyProvider
            .overrideWithValue(ReplyPrompt(question: question)),
      ]);
      addTearDown(container.dispose);
      container.read(contextProvider.notifier).setContext(robo);
      return container;
    }

    test('abre en la zona preguntada, no en la de entrada', () {
      final container = containerAsking('Donde te robaron');

      final state = container.read(semanticZonesProvider);
      expect(state.activeZoneId, 'lugar');
      expect(state.requestedZoneIds, ['lugar']);
    });

    test('sin pregunta reconocible abre en la zona de entrada', () {
      final container = containerAsking('Le robaron su celular');

      expect(container.read(semanticZonesProvider).activeZoneId,
          robo.entryZoneId);
    });

    test('responder una pregunta nueva no hereda el recorrido anterior', () {
      // El fallo que esto fija: tras responder una vez, la zona activa
      // sobrevivía y la siguiente pregunta abría donde quedó la anterior.
      final container = containerAsking('Que paso');
      expect(container.read(semanticZonesProvider).activeZoneId, 'situacion');

      container.read(semanticZonesProvider.notifier).reset();

      // `reset` recalcula desde la pregunta vigente del puerto.
      expect(container.read(semanticZonesProvider).activeZoneId, 'situacion');
    });

    test('reset respeta la zona preguntada', () {
      final container = containerAsking('Donde te robaron');
      container.read(semanticZonesProvider.notifier).activateZone('personas');
      expect(container.read(semanticZonesProvider).activeZoneId, 'personas');

      container.read(semanticZonesProvider.notifier).reset();

      expect(container.read(semanticZonesProvider).activeZoneId, 'lugar');
    });

    test('Continuar sigue por las zonas preguntadas antes que por el motor',
        () {
      final container = containerAsking('A que hora y donde te robaron');
      final notifier = container.read(semanticZonesProvider.notifier);
      expect(container.read(semanticZonesProvider).activeZoneId, 'tiempo');

      notifier.goToNextZone();

      expect(container.read(semanticZonesProvider).activeZoneId, 'lugar');
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
