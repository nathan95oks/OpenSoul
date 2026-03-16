import '../entities/lsb_card.dart';
import '../repositories/cards_repository.dart';

class GetCardsByCategoryUseCase {
  final CardsRepository repository;

  GetCardsByCategoryUseCase(this.repository);

  Future<List<LsbCard>> call(String category) {
    return repository.getCardsByCategory(category);
  }
}
