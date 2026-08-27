import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/repositories/cards_repository_impl.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/cards_repository.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/get_cards_by_category_usecase.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/get_categories_usecase.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_suggestion_datasource.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  return CardsRepositoryImpl(ref.watch(lexiconRepositoryProvider));
});

final getCategoriesUseCaseProvider = Provider<GetCategoriesUseCase>((ref) {
  final repository = ref.watch(cardsRepositoryProvider);
  return GetCategoriesUseCase(repository);
});

final getCardsByCategoryUseCaseProvider = Provider<GetCardsByCategoryUseCase>((ref) {
  final repository = ref.watch(cardsRepositoryProvider);
  return GetCardsByCategoryUseCase(repository);
});

const String kSuggestionsCategory = 'Sugerencias';

class CurrentCategoryNotifier extends Notifier<String> {
  @override
  String build() => kSuggestionsCategory;

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

const int _kMaxGuidedAnswers = 12;

final generatedStepProvider = FutureProvider<GeneratedStep>((ref) async {
  final context = ref.watch(contextProvider);
  if (context == null) return GeneratedStep.vacio;

  final candidatas = await ref.watch(_localCandidatesProvider.future);
  if (candidatas.isEmpty) return GeneratedStep.vacio;

  final pendiente = ref.watch(pendingReplyProvider);

  return ref.read(suggestionDataSourceProvider).suggest(
        contextId: context.id,
        selected: ref.watch(sentenceProvider),
        candidates: [for (final c in candidatas) c.gloss],
        replyingTo: pendiente?.question,
      );
});

final dynamicCardsProvider = FutureProvider<List<LsbCard>>((ref) async {
  final locales = await ref.watch(_localCandidatesProvider.future);

  final generado = await ref.watch(generatedStepProvider.future);
  if (generado.isEmpty) return locales;

  final porGlosa = {for (final c in locales) c.gloss: c};
  final ordenadas = [
    for (final g in generado.options)
      if (porGlosa.containsKey(g)) porGlosa[g]!,
  ];
  return ordenadas.isEmpty ? locales : ordenadas;
});

final _localCandidatesProvider = FutureProvider<List<LsbCard>>((ref) async {
  final category = ref.watch(currentCategoryProvider);
  final context = ref.watch(contextProvider);
  final zonesState = ref.watch(semanticZonesProvider);
  final sentence = ref.watch(sentenceProvider);

  if (category != kSuggestionsCategory) {
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

  if (activeZone.glossAllowlist.isNotEmpty) {
    final porGlosa = {for (final c in allCards) c.gloss: c};
    return [
      for (final g in activeZone.glossAllowlist)
        if (porGlosa.containsKey(g)) porGlosa[g]!,
    ].take(_kMaxGuidedAnswers).toList();
  }

  final zoneCategories = activeZone.cardCategories.toSet();
  final zoneSubcategories = activeZone.cardSubcategories.toSet();
  final hasSubcategoryFilter = zoneSubcategories.isNotEmpty;

  final sourceContexts = cardSourceContexts(context.id);
  bool matchesContext(LsbCard c) => sourceContexts.any(c.contexts.contains);

  bool matchesZone(LsbCard c) {
    if (!zoneCategories.contains(c.categoryId)) return false;
    if (hasSubcategoryFilter && !zoneSubcategories.contains(c.subcategoryId)) {
      return false;
    }
    return true;
  }

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
    if (lastCard != null) {
      final aNext = lastCard.suggestedNextCardIds.contains(a.id) ? 0 : 1;
      final bNext = lastCard.suggestedNextCardIds.contains(b.id) ? 0 : 1;
      if (aNext != bNext) return aNext.compareTo(bNext);
    }
    if (a.isFrequent != b.isFrequent) {
      return a.isFrequent ? -1 : 1;
    }
    return a.priority.compareTo(b.priority);
  }

  final specific = allCards.where((c) {
    if (!matchesZone(c)) return false;
    return matchesContext(c);
  }).toList()
    ..sort(comparator);

  if (specific.length >= _kMaxGuidedAnswers) {
    return specific.take(_kMaxGuidedAnswers).toList();
  }

  if (activeZone.strictContext) {
    return specific;
  }

  final fillers = allCards.where((c) {
    if (!matchesZone(c)) return false;
    if (matchesContext(c)) return false;
    return c.contexts.contains('general');
  }).toList()
    ..sort(comparator);

  final combined = [...specific, ...fillers];

  if (combined.isEmpty) {
    return (allCards.where(matchesZone).toList()..sort(comparator))
        .take(_kMaxGuidedAnswers)
        .toList();
  }

  return combined.take(_kMaxGuidedAnswers).toList();
});
