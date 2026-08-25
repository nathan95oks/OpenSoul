import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';

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

    test('con contexto, la zona de entrada filtra por su categoría y respeta el tope',
        () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('denuncia_robo'));
      // Forzar el build del estado de zonas (zona de entrada = "situacion").
      c.read(semanticZonesProvider);

      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards, isNotEmpty);
      // La zona activa solo ofrece tarjetas de las categorías que declara.
      // Se leen del propio catálogo en vez de fijar un nombre: así la prueba
      // sigue valiendo cuando el corpus reorganiza sus categorías.
      final zona =
          _ctx('denuncia_robo').zones.firstWhere((z) => z.id == 'situacion');
      expect(
        cards.every((x) => zona.cardCategories.contains(x.categoryId)),
        true,
        reason: 'esperadas ${zona.cardCategories}; '
            'recibidas ${cards.map((x) => x.categoryId).toSet()}',
      );
      expect(cards.length, lessThanOrEqualTo(12),
          reason: 'se respeta el tope _kMaxGuidedAnswers');
    });

    test('una zona estricta no rellena con tarjetas "general"', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('denuncia_robo'));
      c.read(semanticZonesProvider);
      // "personas" es strictContext: ¿Quién te robó? — no debe sugerir "MI HIJO".
      c.read(semanticZonesProvider.notifier).activateZone('personas');

      final cards = await c.read(dynamicCardsProvider.future);

      // En zona estricta, toda tarjeta ofrecida debe ser específica del
      // contexto (contener 'denuncia_robo'); ninguna 'general' se cuela.
      for (final card in cards) {
        expect(card.categoryId, 'Descripción');
        expect(card.contexts.contains('denuncia_robo'), true,
            reason: 'zona estricta no admite relleno "general": ${card.gloss}');
      }
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
      expect(resolveAssemblerContext('orientacion', ['FALTA', 'TELEFONO'], catOf),
          'perdida');
      expect(resolveAssemblerContext('orientacion', ['TELEFONO', 'CALLE'], catOf),
          'perdida');
    });

    test('documento / trámite → tramite_id', () {
      expect(resolveAssemblerContext('orientacion', ['PASAPORTE'], catOf), 'tramite_id');
      expect(
          resolveAssemblerContext('orientacion', ['INVESTIGACION', 'FISCAL'], catOf),
          'tramite_id');
    });

    test('consulta / derechos → orientacion', () {
      expect(
          resolveAssemblerContext('orientacion', ['INTERPRETE', 'INSTITUCION'], catOf),
          'orientacion');
    });

    test('preguntas se conserva como contexto propio', () {
      expect(resolveAssemblerContext('preguntas', ['QUE', 'PAPEL'], catOf),
          'preguntas');
    });

    test('la zona de institución no mezcla servicios como abogado', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('orientacion'));
      c.read(semanticZonesProvider);
      c.read(semanticZonesProvider.notifier).activateZone('donde');

      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards.isNotEmpty, true);
      expect(cards.any((x) => x.gloss == 'ABOGADO'), false,
          reason: 'ABOGADO debe vivir en apoyo, no en institución');
      expect(cards.every((x) => x.subcategoryId == 'institucion'), true,
          reason: 'solo instituciones reales deben aparecer aquí');
    });

    test('la zona de apoyo sí ofrece abogado e intérprete', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('orientacion'));
      c.read(semanticZonesProvider);
      c.read(semanticZonesProvider.notifier).activateZone('apoyo');

      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards.any((x) => x.gloss == 'ABOGADO'), true,
          reason: 'apoyo legal debe incluir abogado');
      expect(cards.any((x) => x.gloss == 'INTERPRETE'), true,
          reason: 'apoyo de accesibilidad debe incluir intérprete');
    });

    test('orientacion separa acción y trámite jurídico', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('orientacion'));
      c.read(semanticZonesProvider);

      c.read(semanticZonesProvider.notifier).activateZone('accion');
      final actionCards = await c.read(dynamicCardsProvider.future);
      expect(actionCards.any((x) => x.gloss == 'REQUISITO'), false,
          reason: 'accion solo debe mostrar acciones reales');
      expect(actionCards.any((x) => x.categoryId == 'Acciones'), true);

      c.read(semanticZonesProvider.notifier).activateZone('tramite');
      final tramiteCards = await c.read(dynamicCardsProvider.future);
      expect(tramiteCards.any((x) => x.gloss == 'EXPEDIENTE'), true,
          reason: 'tramite debe mostrar conceptos jurídicos');
      expect(tramiteCards.every((x) => x.categoryId == 'Conceptos jurídicos'),
          true);
    });

    test('documento separa documento formal y soporte físico', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('orientacion'));
      c.read(semanticZonesProvider);

      c.read(semanticZonesProvider.notifier).activateZone('documento');
      final documentCards = await c.read(dynamicCardsProvider.future);
      expect(documentCards.any((x) => x.gloss == 'CONSTANCIA'), true,
          reason: 'documento debe mostrar documentos formales');
      expect(documentCards.any((x) => x.gloss == 'PAPEL'), false,
          reason: 'documento no debe mezclar soporte físico');

      c.read(semanticZonesProvider.notifier).activateZone('soporte');
      final supportCards = await c.read(dynamicCardsProvider.future);
      expect(supportCards.any((x) => x.gloss == 'PAPEL'), true,
          reason: 'soporte debe mostrar papel');
      expect(supportCards.any((x) => x.gloss == 'CARPETA'), true,
          reason: 'soporte debe mostrar carpeta');
      expect(supportCards.any((x) => x.gloss == 'ARCHIVADOR'), true,
          reason: 'soporte debe mostrar archivador');
    });

    test('violencia y accidente no mezclan estado con urgencias', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('violencia'));
      c.read(semanticZonesProvider);

      c.read(semanticZonesProvider.notifier).activateZone('emocion');
      final violenceEmotion = await c.read(dynamicCardsProvider.future);
      expect(violenceEmotion.any((x) => x.gloss == 'AUXILIO'), false,
          reason: 'emocion no debe ofrecer urgencias');
      expect(violenceEmotion.any((x) => x.gloss == 'ASISTENCIA'), false,
          reason: 'emocion no debe ofrecer urgencias');

      c.read(contextProvider.notifier).setContext(_ctx('accidente'));
      c.read(semanticZonesProvider.notifier).reset();
      c.read(semanticZonesProvider.notifier).activateZone('estado');
      final accidentState = await c.read(dynamicCardsProvider.future);
      expect(accidentState.any((x) => x.gloss == 'AUXILIO'), false,
          reason: 'estado no debe ofrecer urgencias');
      expect(accidentState.any((x) => x.gloss == 'ASISTENCIA'), false,
          reason: 'estado no debe ofrecer urgencias');
    });

    test('salud expone hospital y centro de salud', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('accidente'));
      c.read(semanticZonesProvider);
      c.read(semanticZonesProvider.notifier).activateZone('salud');

      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards.any((x) => x.gloss == 'HOSPITAL'), true,
          reason: 'la zona de salud debe incluir hospital');
      expect(cards.any((x) => x.gloss == 'CENTRO_DE_SALUD'), true,
          reason: 'la zona de salud debe incluir centro de salud');
      expect(cards.every((x) => x.categoryId == 'Lugares'), true);
    });

    test('preguntas separa persona, institución y tema', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('preguntas'));
      c.read(semanticZonesProvider);

      c.read(semanticZonesProvider.notifier).activateZone('sobre_quien');
      final whoCards = await c.read(dynamicCardsProvider.future);
      expect(whoCards.any((x) => x.gloss == 'ABOGADO'), false,
          reason: 'sobre_quien solo debe ofrecer personas');
      expect(whoCards.any((x) => x.gloss == 'FISCAL'), true,
          reason: 'sobre_quien debe incluir cargos como fiscal');
      expect(whoCards.any((x) => x.gloss == 'AUTORIDAD'), true,
          reason: 'sobre_quien debe incluir autoridad como cargo');
      expect(whoCards.any((x) => x.gloss == 'POLICIA'), true,
          reason: 'sobre_quien debe incluir policía como cargo');
      expect(whoCards.every((x) =>
          x.categoryId == 'Identificación' ||
          x.categoryId == 'Preguntas' ||
          x.categoryId == 'Instituciones'),
          true);

      c.read(semanticZonesProvider.notifier).activateZone('institucion');
      final institutionCards = await c.read(dynamicCardsProvider.future);
      expect(institutionCards.any((x) => x.gloss == 'ABOGADO'), false,
          reason: 'ABOGADO sigue siendo servicio, no institución');
      expect(institutionCards.any((x) => x.gloss == 'FISCAL'), false,
          reason: 'FISCAL es un cargo/persona, no una institución pura');
      expect(institutionCards.any((x) => x.gloss == 'AUTORIDAD'), false,
          reason: 'AUTORIDAD es un cargo/persona, no una institución pura');
      expect(institutionCards.any((x) => x.gloss == 'POLICIA'), false,
          reason: 'POLICIA es un cargo/persona, no una institución pura');
      expect(institutionCards.every((x) => x.subcategoryId == 'institucion'),
          true,
          reason: 'la zona institucional solo debe mostrar instituciones');

      c.read(semanticZonesProvider.notifier).activateZone('tema');
      final topicCards = await c.read(dynamicCardsProvider.future);
      expect(topicCards.any((x) => x.categoryId == 'Instituciones'), false,
          reason: 'tema no debe mezclar instituciones cuando hay zona propia');
    });

    test('los contextos directos no se reenrutan', () {
      expect(resolveAssemblerContext('denuncia_robo', ['ROBAR'], catOf),
          'denuncia_robo');
      expect(resolveAssemblerContext('violencia', ['MALTRATAR'], catOf), 'violencia');
    });
  });
}
