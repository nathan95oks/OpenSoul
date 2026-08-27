import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:lsb_legal_app/core/domain/entities/dictionary_document.dart';

class LexiconLocalDataSource {
  static const String fileName = 'dictionary_cache.json';

  Future<File?> _file() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/$fileName');
    } catch (_) {
      return null;
    }
  }

  Future<DictionaryDocument?> read() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return null;
      return DictionaryDocument.fromJsonString(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void> write(DictionaryDocument document) async {
    try {
      final file = await _file();
      if (file == null) return;
      await file.writeAsString(document.toJsonString());
    } catch (_) {
    }
  }
}
