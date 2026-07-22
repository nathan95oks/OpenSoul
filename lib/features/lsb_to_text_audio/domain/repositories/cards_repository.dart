import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';

abstract class CardsRepository {
  Future<List<LsbCard>> getCardsByCategory(String category);
  Future<List<String>> getCategories();
}
