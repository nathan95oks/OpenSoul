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

    test('la zona de entrada ofrece su lista blanca, en su orden', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('denuncia_robo'));
      // Forzar el build del estado de zonas (zona de entrada = "situacion").
      c.read(semanticZonesProvider);

      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards, isNotEmpty);
      final zona =
          _ctx('denuncia_robo').zones.firstWhere((z) => z.id == 'situacion');
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
      c.read(semanticZonesProvider.notifier).activateZone('personas');

      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards, isNotEmpty,
          reason: 'la pregunta se mostraba sin ninguna opción');
      final zona =
          _ctx('denuncia_robo').zones.firstWhere((z) => z.id == 'personas');
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

    test('la zona de institución no mezcla servicios como abogado', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('tramite'));
      c.read(semanticZonesProvider);
      c.read(semanticZonesProvider.notifier).activateZone('donde');

      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards.isNotEmpty, true);
      expect(cards.any((x) => x.gloss == 'ABOGADO'), false,
          reason: 'ABOGADO debe vivir en apoyo, no en institución');
      // POLICIA y FISCAL entran pese a su subcategoría `cargo`: sus formas en
      // español son institucionales. Es el caso que justifica la lista blanca.
      expect(cards.any((x) => x.gloss == 'POLICIA'), true,
          reason: 'la policía es un destino institucional válido');
      expect(cards.any((x) => x.gloss == 'FISCAL'), true,
          reason: '"en la fiscalía" es una institución, no solo un cargo');
    });

    test('la zona de apoyo sí ofrece abogado e intérprete', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('tramite'));
      c.read(semanticZonesProvider);
      c.read(semanticZonesProvider.notifier).activateZone('apoyo');

      final cards = await c.read(dynamicCardsProvider.future);

      expect(cards.any((x) => x.gloss == 'ABOGADO'), true,
          reason: 'apoyo legal debe incluir abogado');
      expect(cards.any((x) => x.gloss == 'INTERPRETE'), true,
          reason: 'apoyo de accesibilidad debe incluir intérprete');
    });

    test('trámite separa gestión, documento y caso', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('tramite'));
      c.read(semanticZonesProvider);

      c.read(semanticZonesProvider.notifier).activateZone('accion');
      final accion = await c.read(dynamicCardsProvider.future);
      expect(accion.any((x) => x.gloss == 'REQUISITO'), false,
          reason: 'accion solo debe mostrar gestiones reales');
      expect(accion.any((x) => x.gloss == 'PRESENTAR'), true);
      expect(accion.any((x) => x.gloss == 'CONFESAR'), false,
          reason: 'confesar es un acto declarativo, no un trámite');

      c.read(semanticZonesProvider.notifier).activateZone('caso');
      final caso = await c.read(dynamicCardsProvider.future);
      expect(caso.any((x) => x.gloss == 'EXPEDIENTE'), true);
      expect(caso.any((x) => x.gloss == 'LEY'), false,
          reason: 'una ley se consulta, no se tramita');
    });

    test('el documento de trámite excluye soporte y correspondencia', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('tramite'));
      c.read(semanticZonesProvider);

      c.read(semanticZonesProvider.notifier).activateZone('documento');
      final docs = await c.read(dynamicCardsProvider.future);
      expect(docs.any((x) => x.gloss == 'CONSTANCIA'), true);
      expect(docs.any((x) => x.gloss == 'CARNET'), true,
          reason: 'la cédula es el documento más pedido en ventanilla');
      expect(docs.any((x) => x.gloss == 'PAPEL'), false,
          reason: 'el soporte físico no es un documento oficial');
      expect(docs.any((x) => x.gloss == 'TEXTO'), false,
          reason: 'un texto no es un documento gubernamental');
      expect(docs.any((x) => x.gloss == 'CARTA'), false,
          reason: 'la correspondencia privada no se tramita');
    });

    test('"¿Para quién es el trámite?" ofrece YO', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('tramite'));
      c.read(semanticZonesProvider);
      c.read(semanticZonesProvider.notifier).activateZone('quien');

      final cards = await c.read(dynamicCardsProvider.future);
      expect(cards.any((x) => x.gloss == 'YO'), true,
          reason: 'la respuesta más frecuente quedaba fuera por su categoría');
      expect(cards.length > 1, true,
          reason: 'antes esta zona devolvía una sola tarjeta');
    });

    test('la pérdida vuelve a ser alcanzable', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('tramite'));
      c.read(semanticZonesProvider);
      c.read(semanticZonesProvider.notifier).activateZone('perdida');

      final cards = await c.read(dynamicCardsProvider.future);
      expect(cards.any((x) => x.gloss == 'PERDER'), true,
          reason: 'la glosa que enruta a _composeLoss debe poder elegirse');
      expect(cards.any((x) => x.gloss == 'CARNET'), true);
    });

    test('consulta pregunta por el número de caso y admite no saberlo', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('consulta'));
      c.read(semanticZonesProvider);
      c.read(semanticZonesProvider.notifier).activateZone('identificador');

      final cards = await c.read(dynamicCardsProvider.future);
      expect(cards.any((x) => x.gloss == 'NUREJ'), true);
      expect(cards.any((x) => x.gloss == 'NO_SABER'), true,
          reason: 'el corpus §3.1 permite "No tengo el código conmigo"');
    });

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
      expect(cards.every((x) => x.subcategoryId == 'interrogativa'), true);
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

    test('preguntas ramifica por interrogativa en vez de una zona de 74', () async {
      final c = makeContainer();
      c.read(contextProvider.notifier).setContext(_ctx('preguntas'));
      c.read(semanticZonesProvider);

      // DONDE → solo destinos. Antes una zona única mostraba 74 tarjetas
      // —lugares, objetos robables, documentos y trámites— para cualquier
      // interrogativa.
      c.read(semanticZonesProvider.notifier).activateZone('lugar_pregunta');
      final lugares = await c.read(dynamicCardsProvider.future);
      expect(lugares.any((x) => x.gloss == 'FISCAL'), true);
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
      expect(temas.any((x) => x.gloss == 'TRAMITE'), true);
      expect(temas.any((x) => x.categoryId == 'Lugares'), false,
          reason: 'los lugares tienen su propia ramificación');
    });

    test('los contextos directos no se reenrutan', () {
      expect(resolveAssemblerContext('denuncia_robo', ['ROBAR'], catOf),
          'denuncia_robo');
      expect(resolveAssemblerContext('violencia', ['MALTRATAR'], catOf), 'violencia');
    });
  });
}
