import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/data/datasources/local_cards_datasource.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/repositories/cards_repository_impl.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/entities/lsb_card.dart';
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

/// Tope duro de tarjetas devueltas en modo guiado. Suficiente para que el
/// usuario sordo tenga opciones reales pero impide que el modo "Ver más"
/// muestre 30+ tarjetas y vuelva la experiencia confusa.
const int _kMaxGuidedAnswers = 8;

/// Opciones de respuesta para la pregunta guiada actual.
///
/// Filtro estricto modo guiado:
/// 1. La tarjeta debe pertenecer a alguna categoría de la **zona activa**.
/// 2. La tarjeta debe ser **relevante al contexto situacional**: primero
///    se prueba con tarjetas cuyo `contexts` incluye el id del contexto
///    activo; sólo si no se llega al tope se completan con tarjetas
///    `general` (familia, tiempo universal, etc.).
/// 3. Tope duro de [_kMaxGuidedAnswers] resultados.
/// 4. Si el usuario activó manualmente una categoría desde el filtro
///    avanzado, se respeta esa elección y se devuelve la categoría
///    completa (modo libre para usuarios avanzados).
final dynamicCardsProvider = FutureProvider<List<LsbCard>>((ref) async {
  final category = ref.watch(currentCategoryProvider);
  final context = ref.watch(contextProvider);
  final zonesState = ref.watch(semanticZonesProvider);
  final sentence = ref.watch(sentenceProvider);

  // Modo avanzado: el usuario eligió una categoría específica.
  if (category != 'Sugerencias') {
    final useCase = ref.watch(getCardsByCategoryUseCaseProvider);
    return useCase(category);
  }

  final allCards = await ref.watch(allCardsProvider.future);

  if (context == null) {
    return allCards.where((c) => c.isFrequent).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  final activeZone = zonesState.activeZone;
  if (activeZone == null) return const [];

  final zoneCategories = activeZone.cardCategories.toSet();
  final zoneSubcategories = activeZone.cardSubcategories.toSet();
  final hasSubcategoryFilter = zoneSubcategories.isNotEmpty;

  bool matchesZone(LsbCard c) {
    if (!zoneCategories.contains(c.categoryId)) return false;
    if (hasSubcategoryFilter && !zoneSubcategories.contains(c.subcategoryId)) {
      return false;
    }
    return true;
  }

  // Cadena semántica: ¿la última tarjeta sugiere a alguna de estas?
  LsbCard? lastCard;
  if (sentence.isNotEmpty) {
    final lastWord = sentence.last;
    for (final c in allCards) {
      if (c.id == lastWord ||
          c.displayText == lastWord ||
          c.gloss == lastWord) {
        lastCard = c;
        break;
      }
    }
  }

  int comparator(LsbCard a, LsbCard b) {
    // 1. Tarjetas que la última seleccionada sugiere específicamente.
    if (lastCard != null) {
      final aNext = lastCard.suggestedNextCardIds.contains(a.id) ? 0 : 1;
      final bNext = lastCard.suggestedNextCardIds.contains(b.id) ? 0 : 1;
      if (aNext != bNext) return aNext.compareTo(bNext);
    }
    // 2. Frecuencia de uso.
    if (a.isFrequent != b.isFrequent) {
      return a.isFrequent ? -1 : 1;
    }
    // 3. Prioridad estática.
    return a.priority.compareTo(b.priority);
  }

  // Primero: tarjetas específicas del contexto.
  final specific = allCards.where((c) {
    if (!matchesZone(c)) return false;
    return c.contexts.contains(context.id);
  }).toList()
    ..sort(comparator);

  if (specific.length >= _kMaxGuidedAnswers) {
    return specific.take(_kMaxGuidedAnswers).toList();
  }

  // Si la zona es estricta no rellenamos con cards 'general' — evita que
  // preguntas como "¿Quién te robó?" sugieran "MI HIJO" o "YO".
  if (activeZone.strictContext) {
    return specific;
  }

  // Si no llenamos el tope, completar con tarjetas 'general' de la zona.
  final fillers = allCards.where((c) {
    if (!matchesZone(c)) return false;
    if (c.contexts.contains(context.id)) return false; // ya están
    return c.contexts.contains('general');
  }).toList()
    ..sort(comparator);

  final combined = [...specific, ...fillers];

  // Red de seguridad: si ninguna tarjeta del contexto ni 'general' encaja en
  // la zona, no dejamos la pregunta vacía — mostramos las tarjetas de la
  // categoría. Es el caso del contexto 'otro' (declaración de testigo), que
  // reutiliza categorías de incidente (Agresión) no etiquetadas como
  // 'general'. Solo aplica a zonas NO estrictas.
  if (combined.isEmpty) {
    return (allCards.where(matchesZone).toList()..sort(comparator))
        .take(_kMaxGuidedAnswers)
        .toList();
  }

  return combined.take(_kMaxGuidedAnswers).toList();
});
