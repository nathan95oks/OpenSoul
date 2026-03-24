import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/cards_repository.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/datasources/local_cards_datasource.dart';

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
