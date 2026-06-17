import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/datasources/local_cards_datasource.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';

/// Pruebas del filtrado guiado de tarjetas y del enrutado de contexto (TST-03).
///
/// `dynamicCardsProvider` concentra la lógica de UX central: qué tarjetas se
/// ofrecen en cada pregunta según la zona activa, el contexto y el tope.
SemanticContext _ctx(String id) =>
    availableContexts.firstWhere((c) => c.id == id);

void main() {
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
      // La zona "situacion" de denuncia_robo expone la categoría "Agresión".
      expect(cards.every((x) => x.categoryId == 'Agresión'), true,
          reason: 'la zona activa solo ofrece tarjetas de su categoría');
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
      final ds = LocalCardsDataSource();
      final all = <LsbCard>[];
      for (final cat in await ds.getCategories()) {
        all.addAll(await ds.getCardsByCategory(cat));
      }
      catOf = (g) {
        for (final card in all) {
          if (card.gloss == g) return card.categoryId;
        }
        return null;
      };
    });

    test('objeto / PERDER → perdida', () {
      expect(resolveAssemblerContext('orientacion', ['PERDER', 'CELULAR'], catOf),
          'perdida');
      expect(resolveAssemblerContext('orientacion', ['CELULAR', 'CALLE'], catOf),
          'perdida');
    });

    test('documento / trámite → tramite_id', () {
      expect(resolveAssemblerContext('orientacion', ['CARNET'], catOf), 'tramite_id');
      expect(
          resolveAssemblerContext('orientacion', ['ANTECEDENTES', 'FISCAL'], catOf),
          'tramite_id');
    });

    test('consulta / derechos → orientacion', () {
      expect(
          resolveAssemblerContext('orientacion', ['INTERPRETE', 'DEFENSORIA'], catOf),
          'orientacion');
    });

    test('los contextos directos no se reenrutan', () {
      expect(resolveAssemblerContext('denuncia_robo', ['ROBAR'], catOf),
          'denuncia_robo');
      expect(resolveAssemblerContext('violencia', ['PEGAR'], catOf), 'violencia');
    });
  });
}
