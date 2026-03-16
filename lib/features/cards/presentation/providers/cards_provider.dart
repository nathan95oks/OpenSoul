import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/cards/data/datasources/local_cards_datasource.dart';
import 'package:lsb_legal_app/features/cards/data/repositories/cards_repository_impl.dart';
import 'package:lsb_legal_app/features/cards/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/cards/domain/repositories/cards_repository.dart';
import 'package:lsb_legal_app/features/cards/domain/usecases/get_cards_by_category_usecase.dart';
import 'package:lsb_legal_app/features/cards/domain/usecases/get_categories_usecase.dart';

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
  String build() => 'Sujetos';
  
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
