import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/data/datasources/local_cards_datasource.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/repositories/cards_repository_impl.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/entities/semantic_zone.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/cards_repository.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/get_cards_by_category_usecase.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/get_categories_usecase.dart';
import 'context_provider.dart';
import 'semantic_zones_provider.dart';
import 'sentence_provider.dart';

final localCardsDataSourceProvider = Provider<LocalCardsDataSource>((ref) {
  return LocalCardsDataSource();
});

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  final dataSource = ref.watch(localCardsDataSourceProvider);
  return CardsRepositoryImpl(dataSource);
});

final getCategoriesUseCaseProvider = Provider<GetCategoriesUseCase>((ref) {
  final repository = ref.watch(cardsRepositoryProvider);
  return GetCategoriesUseCase(repository);
});

final getCardsByCategoryUseCaseProvider = Provider<GetCardsByCategoryUseCase>((ref) {
  final repository = ref.watch(cardsRepositoryProvider);
  return GetCardsByCategoryUseCase(repository);
});

class CurrentCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'Sugerencias';

  void setCategory(String category) {
    state = category;
  }
}

final currentCategoryProvider =
    NotifierProvider<CurrentCategoryNotifier, String>(CurrentCategoryNotifier.new);

final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final useCase = ref.watch(getCategoriesUseCaseProvider);
  return useCase();
});

final cardsByCategoryProvider = FutureProvider<List<LsbCard>>((ref) async {
  final category = ref.watch(currentCategoryProvider);
  final useCase = ref.watch(getCardsByCategoryUseCaseProvider);
  return useCase(category);
});

final allCardsProvider = FutureProvider<List<LsbCard>>((ref) async {
  final categories = await ref.watch(categoriesProvider.future);
  final useCase = ref.watch(getCardsByCategoryUseCaseProvider);
  final List<LsbCard> allCards = [];
  for (final cat in categories) {
    final cards = await useCase(cat);
    allCards.addAll(cards);
  }
  return allCards;
});

/// Sugerencias contextuales basadas en zona activa, urgencia detectada
/// y última glosa seleccionada.
///
/// Reemplaza la lógica indexada anterior (`currentStepIndex`) por consultas
/// a [semanticZonesProvider]. Las tarjetas marcadas `isEmergency` se
/// promueven automáticamente cuando el motor detecta urgencia.
final dynamicCardsProvider = FutureProvider<List<LsbCard>>((ref) async {
  final category = ref.watch(currentCategoryProvider);
  final context = ref.watch(contextProvider);
  final zonesState = ref.watch(semanticZonesProvider);
  final sentence = ref.watch(sentenceProvider);

  // Si el usuario eligió manualmente otra categoría, respetamos la elección.
  if (category != 'Sugerencias') {
    final useCase = ref.watch(getCardsByCategoryUseCaseProvider);
    return useCase(category);
  }

  final allCards = await ref.watch(allCardsProvider.future);

  // Sin contexto: solo las tarjetas frecuentes.
  if (context == null) {
    return allCards.where((c) => c.isFrequent).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  final activeZone = zonesState.activeZone;
  final activeTags = zonesState.snapshot.activeTags;
  final urgencyActive = zonesState.snapshot.dominantUrgency.index >=
      UrgencyLevel.high.index;

  // Conjunto de categorías visibles: las de la zona activa + categorías de
  // zonas sugeridas si la zona activa tiene relaciones, para que la
  // exploración libre no quede "encerrada".
  final visibleCategories = <String>{
    ...?activeZone?.cardCategories,
    for (final id in zonesState.snapshot.suggestedZoneIds)
      ...?context.zoneById(id)?.cardCategories,
  };

  // Si urgencia alta/crítica, garantizamos visibilidad de Estado/Urgencia.
  if (urgencyActive) {
    visibleCategories.add('Estado/Urgencia');
    visibleCategories.add('Servicios');
  }

  Iterable<LsbCard> filtered = allCards.where((c) {
    if (visibleCategories.isEmpty) return c.isFrequent;
    return visibleCategories.contains(c.categoryId);
  });

  // Si está bajo urgencia, no escondemos tarjetas Emergencia aunque no
  // estén en la zona activa.
  if (urgencyActive) {
    final emergencyExtras =
        allCards.where((c) => c.isEmergency && !filtered.contains(c));
    filtered = [...filtered, ...emergencyExtras];
  }

  final suggested = filtered.toList();

  // Última tarjeta seleccionada (para usar suggestedNextCardIds).
  LsbCard? lastCard;
  if (sentence.isNotEmpty) {
    final lastWord = sentence.last;
    for (final c in allCards) {
      if (c.id == lastWord || c.displayText == lastWord || c.gloss == lastWord) {
        lastCard = c;
        break;
      }
    }
  }

  suggested.sort((a, b) {
    // 1. Urgencia activa → tarjetas isEmergency primero.
    if (urgencyActive) {
      final ea = a.isEmergency ? 0 : 1;
      final eb = b.isEmergency ? 0 : 1;
      if (ea != eb) return ea.compareTo(eb);
    }

    // 2. Cadena semántica: si la última tarjeta sugiere a una de estas.
    if (lastCard != null) {
      final aNext = lastCard.suggestedNextCardIds.contains(a.id) ? 0 : 1;
      final bNext = lastCard.suggestedNextCardIds.contains(b.id) ? 0 : 1;
      if (aNext != bNext) return aNext.compareTo(bNext);
    }

    // 3. Tarjetas cuyas etiquetas de contexto coinciden con tags activas.
    if (activeTags.isNotEmpty) {
      final aCtx = a.contexts.any(activeTags.contains) ? 0 : 1;
      final bCtx = b.contexts.any(activeTags.contains) ? 0 : 1;
      if (aCtx != bCtx) return aCtx.compareTo(bCtx);
    }

    // 4. Coincidencia con el contexto situacional activo (id del contexto).
    final aMatch = a.contexts.contains(context.id) ? 0 : 1;
    final bMatch = b.contexts.contains(context.id) ? 0 : 1;
    if (aMatch != bMatch) return aMatch.compareTo(bMatch);

    // 5. Prioridad estática.
    return a.priority.compareTo(b.priority);
  });

  return suggested;
});
