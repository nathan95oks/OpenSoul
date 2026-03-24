import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/cards_repository.dart';

class GetCategoriesUseCase {
  final CardsRepository repository;

  GetCategoriesUseCase(this.repository);

  Future<List<String>> call() {
    return repository.getCategories();
  }
}
