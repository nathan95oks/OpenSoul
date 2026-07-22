import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/dictionary_document.dart';

/// Caché en disco de la última sincronización remota del diccionario.
///
/// Best-effort en ambos sentidos: cualquier fallo (plataforma sin
/// path_provider, JSON corrupto, disco lleno) se degrada a "sin caché",
/// nunca rompe el arranque — el asset empaquetado siempre respalda.
class LexiconCache {
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
      // La caché es un optimizador, no un requisito.
    }
  }
}
