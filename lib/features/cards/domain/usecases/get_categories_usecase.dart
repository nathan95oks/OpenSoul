import 'package:lsb_legal_app/features/cards/domain/repositories/cards_repository.dart';

class GetCategoriesUseCase {
  final CardsRepository repository;

  GetCategoriesUseCase(this.repository);

  Future<List<String>> call() {
    return repository.getCategories();
  }
}
