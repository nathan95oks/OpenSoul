import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';

/// Carga el corpus RAG de trámites de Cochabamba empaquetado con la app.
///
/// Es un asset local, no una llamada de red: la ventanilla puede no tener
/// conexión. Un corpus ilegible no impide nada: Conversation sigue como
/// antes, sin situaciones parecidas.
class RagCorpusDataSource {
  static const String assetPath = 'assets/rag/escenarios_cbba.json';

  final AssetBundle bundle;

  RagCorpusDataSource({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  Future<RagCorpus> load() async {
    try {
      return RagCorpus.fromJsonString(await bundle.loadString(assetPath));
    } catch (_) {
      return RagCorpus.empty;
    }
  }
}
