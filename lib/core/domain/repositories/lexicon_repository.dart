import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/entities/dictionary_document.dart';

abstract class LexiconRepository {
  Future<DictionaryDocument> getDocument();

  Future<List<LsbCard>> getEntries();

  Future<List<String>> getCategories();

  Future<bool> refresh();
}
