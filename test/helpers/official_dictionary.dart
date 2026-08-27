import 'dart:io';

import 'package:lsb_legal_app/core/domain/entities/dictionary_document.dart';
import 'package:lsb_legal_app/core/domain/repositories/lexicon_repository.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';

/// Carga síncrona del diccionario oficial canónico para pruebas y auditorías.
///
/// Lee directamente `assets/dictionary/official_dictionary.json` (la misma
/// fuente que empaqueta la app y que siembra DynamoDB), de modo que las
/// pruebas de cobertura auditan exactamente lo que ve el usuario.
DictionaryDocument loadOfficialDictionaryDocument() =>
    DictionaryDocument.fromJsonString(
      File('assets/dictionary/official_dictionary.json').readAsStringSync(),
    );

List<LsbCard> loadOfficialEntries() =>
    loadOfficialDictionaryDocument().entries;

/// Doble del diccionario para pruebas de widgets.
///
/// `rootBundle` no resuelve bajo el reloj falso de `testWidgets`
/// (pumpAndSettle se colgaría esperando el asset); este doble sirve el
/// mismo documento canónico con lectura síncrona de archivo. Se inyecta
/// sobreescribiendo `lexiconRepositoryProvider`.
class FakeLexiconRepository implements LexiconRepository {
  final DictionaryDocument _doc = loadOfficialDictionaryDocument();

  @override
  Future<DictionaryDocument> getDocument() async => _doc;

  @override
  Future<List<LsbCard>> getEntries() async => _doc.visibleEntries;

  @override
  Future<List<String>> getCategories() async {
    final present = _doc.visibleEntries.map((e) => e.categoryId).toSet();
    return _doc.categoryOrder.where(present.contains).toList();
  }

  @override
  Future<bool> refresh() async => false;

}
