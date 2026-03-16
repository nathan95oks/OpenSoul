import 'package:lsb_legal_app/features/cards/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/cards/domain/repositories/cards_repository.dart';
import 'package:lsb_legal_app/features/cards/data/datasources/local_cards_datasource.dart';

class CardsRepositoryImpl implements CardsRepository {
  final LocalCardsDataSource localDataSource;

  CardsRepositoryImpl(this.localDataSource);

  @override
  Future<List<LsbCard>> getCardsByCategory(String category) async {
    return localDataSource.getCardsByCategory(category);
  }

  @override
  Future<List<String>> getCategories() async {
    return localDataSource.getCategories();
  }
}
