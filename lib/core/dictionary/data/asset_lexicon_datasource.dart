import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/dictionary_document.dart';

/// Diccionario oficial empaquetado con la aplicación.
///
/// Garantiza que la app siempre tenga vocabulario aunque nunca haya
/// habido conexión: es el punto de partida del esquema offline-first.
class AssetLexiconDataSource {
  static const String assetPath = 'assets/dictionary/official_dictionary.json';

  final AssetBundle bundle;

  AssetLexiconDataSource({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  Future<DictionaryDocument> load() async {
    final raw = await bundle.loadString(assetPath);
    return DictionaryDocument.fromJsonString(raw);
  }
}
