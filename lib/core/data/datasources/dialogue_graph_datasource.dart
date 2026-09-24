import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

/// Carga el grafo de diálogo empaquetado con la aplicación.
///
/// Es un asset local y no una llamada de red a propósito: el recorrido guiado
/// tiene que seguir siendo utilizable sin conexión, que es la situación
/// normal en una ventanilla.
class DialogueGraphDataSource {
  static const String assetPath = 'assets/dialogue/dialogue_graph.json';

  final AssetBundle bundle;

  DialogueGraphDataSource({AssetBundle? bundle})
      : bundle = bundle ?? rootBundle;

  Future<DialogueGraph> load() async {
    // Un grafo ilegible no puede impedir abrir la aplicación: sin él la
    // navegación por zonas del catálogo sigue funcionando como antes.
    try {
      return DialogueGraph.fromJsonString(await bundle.loadString(assetPath));
    } catch (_) {
      return DialogueGraph.empty;
    }
  }
}
