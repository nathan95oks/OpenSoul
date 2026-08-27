import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:lsb_legal_app/core/domain/entities/dictionary_document.dart';

class AssetLexiconDataSource {
  static const String assetPath = 'assets/dictionary/official_dictionary.json';
  final AssetBundle bundle;

  AssetLexiconDataSource({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  Future<DictionaryDocument> load() async {
    final raw = await bundle.loadString(assetPath);
    return DictionaryDocument.fromJsonString(raw);
  }
}
