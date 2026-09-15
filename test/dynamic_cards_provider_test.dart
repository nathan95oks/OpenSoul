import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

import 'helpers/official_dictionary.dart';

/// Pruebas del filtrado guiado de tarjetas y del enrutado de contexto (TST-03).
///
/// `dynamicCardsProvider` concentra la lógica de UX central: qué tarjetas se
/// ofrecen en cada pregunta según la zona activa, el contexto y el tope.
SemanticContext _ctx(String id) =>
    allSelectableContexts.firstWhere((c) => c.id == id);

void main() {
  // El diccionario se carga desde el asset empaquetado vía rootBundle:
  // requiere el binding de pruebas inicializado.
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('dynamicCardsProvider', () {
    test('sin contexto devuelve solo tarjetas frecuentes', () async {
      final c = makeContainer();
      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards, isNotEmpty);
      expect(cards.every((x) => x.isFrequent), true,
          reason: 'sin contexto solo deben venir tarjetas frecuentes');
    });

    test('la zona de entrada ofrece su lista blanca, en su orden', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('denuncia_robo'));
      // Forzar el build del estado de zonas (zona de entrada = "hecho").
      c.read(semanticZonesProvider);

      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards, isNotEmpty);
      final zona =
          _ctx('denuncia_robo').zones.firstWhere((z) => z.id == 'hecho');
      // La lista blanca manda: ni una tarjeta fuera de ella.
      expect(
        cards.every((x) => zona.glossAllowlist.contains(x.gloss)),
        true,
        reason: 'esperadas ${zona.glossAllowlist}; '
            'recibidas ${cards.map((x) => x.gloss).toList()}',
      );
      // Y el orden es el declarado: es una decisión de diseño, no alfabética.
      expect(cards.map((x) => x.gloss).toList(),
          zona.glossAllowlist.take(cards.length).toList());
      expect(cards.length, lessThanOrEqualTo(12),
          reason: 'se respeta el tope _kMaxGuidedAnswers');
    });

    test('una zona con lista blanca no se rellena con tarjetas "general"',
        () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('denuncia_robo'));
      c.read(semanticZonesProvider);
      // "¿Quién te robó?" — antes esta zona filtraba por subcategorías que ya
      // no existían (Género, Edad, Relación, Cantidad) y salía VACÍA.
      c.read(semanticZonesProvider.notifier).activateZone('persona');

      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards, isNotEmpty,
          reason: 'la pregunta se mostraba sin ninguna opción');
      final zona =
          _ctx('denuncia_robo').zones.firstWhere((z) => z.id == 'persona');
      for (final card in cards) {
        expect(zona.glossAllowlist.contains(card.gloss), true,
            reason: 'no admite relleno: ${card.gloss}');
      }
      // Ni el declarante ni el testigo responden "¿quién te robó?".
      expect(cards.any((x) => x.gloss == 'YO'), false);
      expect(cards.any((x) => x.gloss == 'NOMBRE'), false,
          reason: '"mi nombre me robó" era la frase que producía');
      expect(cards.any((x) => x.gloss == 'TESTIGO'), false);
    });

    test('al elegir una categoría manual se devuelve esa categoría completa',
        () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('denuncia_robo'));
      c.read(semanticZonesProvider);
      // Modo avanzado: el usuario fija una categoría desde el filtro.
      c.read(currentCategoryProvider.notifier).setCategory('Objetos');

      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards, isNotEmpty);
      expect(cards.every((x) => x.categoryId == 'Objetos'), true);
    });
  });

  group('resolveAssemblerContext (enrutado del contexto fusionado)', () {
    late String? Function(String) catOf;

    setUp(() async {
      final List<LsbCard> all = loadOfficialEntries();
      catOf = (g) {
        for (final card in all) {
          if (card.gloss == g) return card.categoryId;
        }
        return null;
      };
    });

    test('objeto / PERDER → perdida', () {
      expect(resolveAssemblerContext('tramite', ['PERDER', 'CARNET'], catOf),
          'perdida');
      expect(resolveAssemblerContext('tramite', ['TELEFONO', 'CALLE'], catOf),
          'perdida');
    });

    test('documento / trámite → tramite_id', () {
      expect(resolveAssemblerContext('tramite', ['PASAPORTE'], catOf), 'tramite_id');
      expect(
          resolveAssemblerContext('tramite', ['INVESTIGACION', 'FISCAL'], catOf),
          'tramite_id');
    });

    test('consulta usa el compositor de orientación', () {
      expect(
          resolveAssemblerContext('consulta', ['INTERPRETE', 'INSTITUCION'], catOf),
          'orientacion');
      expect(resolveAssemblerContext('consulta', ['NO_SABER', 'CASO'], catOf),
          'orientacion',
          reason: 'una consulta nunca se reenruta a trámite ni a pérdida');
    });

    test('preguntas se conserva como contexto propio', () {
      expect(resolveAssemblerContext('preguntas', ['QUE', 'PAPEL'], catOf),
          'preguntas');
    });

    // Las pruebas de zonas de 'tramite'/'consulta' (institución, apoyo,
    // acción/documento/caso, "¿para quién es el trámite?", pérdida,
    // identificador de consulta) usaban `_ctx('tramite')`/`_ctx('consulta')`:
    // esos ids de UI ya no están en `allSelectableContexts` (auditoría
    // 2026-09, sección 12.7), así que `_ctx` no encuentra nada y lanza antes
    // de llegar a ejercitar la zona. Se retiran con el mismo criterio que
    // las pruebas equivalentes en test_casos_corpus.py.

    test('la entrada de preguntas no ofrece pronombres', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('preguntas'));
      c.read(semanticZonesProvider);
      c.read(semanticZonesProvider.notifier).activateZone('interrogativa');

      final cards = await c.read(dynamicCardsProvider.future);
      expect(cards.isNotEmpty, true);
      for (final pronombre in ['YO', 'TU', 'EL', 'ELLA', 'ELLOS', 'NOSOTROS', 'USTEDES']) {
        expect(cards.any((x) => x.gloss == pronombre), false,
            reason: '$pronombre no es una interrogativa: al elegirlo '
                'r.question queda null y el compositor devuelve una '
                'declaración en vez de una pregunta');
      }
      // subcategoryId es un código de módulo del corpus ("M1"), no una
      // etiqueta semántica: lo que de verdad acota esta zona es su propia
      // lista blanca, ya comprobada arriba con cada pronombre.
      final zona = _ctx('preguntas').zones.firstWhere((z) => z.id == 'interrogativa');
      expect(cards.every((x) => zona.glossAllowlist.contains(x.gloss)), true);
    });

    test('violencia no mezcla estado con urgencias', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('violencia'));
      c.read(semanticZonesProvider);

      c.read(semanticZonesProvider.notifier).activateZone('emocion');
      final violenceEmotion = await c.read(dynamicCardsProvider.future);
      expect(violenceEmotion.any((x) => x.gloss == 'AUXILIO'), false,
          reason: 'emocion no debe ofrecer urgencias');
      expect(violenceEmotion.any((x) => x.gloss == 'ASISTENCIA'), false,
          reason: 'emocion no debe ofrecer urgencias');
    });

    // La mitad de "violencia y accidente no mezclan estado con urgencias" y
    // "salud expone hospital y centro de salud" usaban `_ctx('accidente')`,
    // otro id retirado del catálogo; mismo criterio.

    test('preguntas ramifica por interrogativa en vez de una zona de 74', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('preguntas'));
      c.read(semanticZonesProvider);

      // DONDE → solo destinos. Antes una zona única mostraba 74 tarjetas
      // —lugares, objetos robables, documentos y trámites— para cualquier
      // interrogativa.
      c.read(semanticZonesProvider.notifier).activateZone('lugar_pregunta');
      final lugares = await c.read(dynamicCardsProvider.future);
      expect(lugares.any((x) => x.gloss == 'FISCALIA'), true);
      expect(lugares.any((x) => x.gloss == 'MOCHILA'), false,
          reason: 'un objeto no responde "¿dónde está…?"');
      expect(lugares.length <= 12, true);

      // QUIEN → solo personas y cargos. El motor ya bloquea "¿Quién es mi
      // motocicleta?", pero la tarjeta no debe llegar a ofrecerse.
      c.read(semanticZonesProvider.notifier).activateZone('persona_pregunta');
      final personas = await c.read(dynamicCardsProvider.future);
      expect(personas.any((x) => x.gloss == 'JUEZ'), true);
      expect(personas.any((x) => x.gloss == 'MOTOCICLETA'), false,
          reason: 'una moto no responde "¿quién es…?"');
      expect(personas.any((x) => x.gloss == 'PASAPORTE'), false);

      // QUE / CUAL → documentos y trámites.
      c.read(semanticZonesProvider.notifier).activateZone('tema_pregunta');
      final temas = await c.read(dynamicCardsProvider.future);
      expect(temas.any((x) => x.gloss == 'TRÁMITE'), true);
      expect(temas.any((x) => x.categoryId == 'Lugares'), false,
          reason: 'los lugares tienen su propia ramificación');
    });

    test('al cambiar de DONDE a QUIEN tras retroceder, la siguiente zona cambia a persona_pregunta', () {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('preguntas'));
      final notifier = c.read(semanticZonesProvider.notifier);

      expect(c.read(semanticZonesProvider).activeZoneId, 'interrogativa');

      // 1. Elegir DONDE y avanzar
      notifier.toggleAnswer('DÓNDE');
      c.read(sentenceProvider.notifier).setWords(['DÓNDE']);
      notifier.goToNextZone();
      expect(c.read(semanticZonesProvider).activeZoneId, 'lugar_pregunta');
      expect(c.read(semanticZonesProvider).activeZone?.question, contains('Dónde'));

      // 2. Retroceder a interrogativa
      notifier.goToPreviousZone();
      expect(c.read(semanticZonesProvider).activeZoneId, 'interrogativa');

      // 3. Deseleccionar DONDE y seleccionar QUIÉN
      notifier.toggleAnswer('DÓNDE');
      notifier.toggleAnswer('QUIÉN');
      c.read(sentenceProvider.notifier).setWords(['QUIÉN']);

      // 4. Avanzar: debe ir a persona_pregunta, no quedarse en lugar_pregunta
      notifier.goToNextZone();
      expect(c.read(semanticZonesProvider).activeZoneId, 'persona_pregunta');
      expect(c.read(semanticZonesProvider).activeZone?.question, contains('hablar'));
    });

    test('los contextos directos no se reenrutan', () {
      expect(resolveAssemblerContext('denuncia_robo', ['ROBAR'], catOf),
          'denuncia_robo');
      expect(resolveAssemblerContext('violencia', ['MALTRATAR'], catOf), 'violencia');
    });
  });
}
