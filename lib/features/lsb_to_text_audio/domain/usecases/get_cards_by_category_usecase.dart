import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/cards_repository.dart';

class GetCardsByCategoryUseCase {
  final CardsRepository repository;

  GetCardsByCategoryUseCase(this.repository);

  Future<List<LsbCard>> call(String category) {
    return repository.getCardsByCategory(category);
  }
}
