import 'package:lsb_legal_app/core/domain/repositories/lexicon_repository.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/cards_repository.dart';

class CardsRepositoryImpl implements CardsRepository {
  final LexiconRepository lexicon;

  CardsRepositoryImpl(this.lexicon);

  @override
  Future<List<LsbCard>> getCardsByCategory(String category) async {
    final entries = await lexicon.getEntries();
    return entries.where((c) => c.categoryId == category).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  @override
  Future<List<String>> getCategories() => lexicon.getCategories();
}
