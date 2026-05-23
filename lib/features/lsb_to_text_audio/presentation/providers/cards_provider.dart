import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/data/datasources/local_cards_datasource.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/repositories/cards_repository_impl.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/cards_repository.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/get_cards_by_category_usecase.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/get_categories_usecase.dart';
import 'context_provider.dart';
import 'guided_flow_provider.dart';
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

final currentCategoryProvider = NotifierProvider<CurrentCategoryNotifier, String>(CurrentCategoryNotifier.new);

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
  List<LsbCard> allCards = [];
  for (var cat in categories) {
    final cards = await useCase(cat);
    allCards.addAll(cards);
  }
  return allCards;
});

final dynamicCardsProvider = FutureProvider<List<LsbCard>>((ref) async {
  final category = ref.watch(currentCategoryProvider);
  final context = ref.watch(contextProvider);
  final currentStep = ref.read(guidedFlowProvider.notifier).currentStep;
  final sentence = ref.watch(sentenceProvider);

  if (category != 'Sugerencias') {
    final useCase = ref.watch(getCardsByCategoryUseCaseProvider);
    return useCase(category);
  }

  final allCards = await ref.watch(allCardsProvider.future);

  if (context == null || currentStep == null) {
    return allCards.where((c) => c.isFrequent).toList()..sort((a, b) => a.priority.compareTo(b.priority));
  }

  // Boosts semánticos según el contexto judicial/situacional
  const contextBoosts = {
    'denuncia_robo': ['ag01', 'ag06', 'ob06', 'ob01', 'ob02', 'ob03', 'de01', 'lu01', 'ti07', 'em01', 'in10'],
    'violencia': ['ag02', 'ag03', 'ag04', 'id04', 'lu02', 'em01', 'em02', 'eu05', 'in10', 'in11'],
    'accidente': ['ob07', 'ob08', 'ag04', 'em04', 'eu05', 'in07', 'sv07', 'in10'],
  };

  final boosts = contextBoosts[context.id] ?? [];

  List<LsbCard> suggested = allCards.where((c) => currentStep.targetCategories.contains(c.categoryId)).toList();

  if (sentence.isNotEmpty) {
    final lastWord = sentence.last;
    final lastCard = allCards.firstWhere((c) => c.id == lastWord || c.displayText == lastWord || c.gloss == lastWord, orElse: () => allCards.first);
    
    suggested.sort((a, b) {
      final aIsNext = lastCard.suggestedNextCardIds.contains(a.id) ? -1 : 1;
      final bIsNext = lastCard.suggestedNextCardIds.contains(b.id) ? -1 : 1;
      if (aIsNext != bIsNext) return aIsNext.compareTo(bIsNext);

      final aIsBoosted = boosts.contains(a.id) ? -1 : 1;
      final bIsBoosted = boosts.contains(b.id) ? -1 : 1;
      if (aIsBoosted != bIsBoosted) return aIsBoosted.compareTo(bIsBoosted);

      return a.priority.compareTo(b.priority);
    });
  } else {
    suggested.sort((a, b) {
      final aIsBoosted = boosts.contains(a.id) ? -1 : 1;
      final bIsBoosted = boosts.contains(b.id) ? -1 : 1;
      if (aIsBoosted != bIsBoosted) return aIsBoosted.compareTo(bIsBoosted);
      return a.priority.compareTo(b.priority);
    });
  }

  return suggested;
});

