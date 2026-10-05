import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';

/// Carga qué es cada palabra sin seña, empaquetado con la app (sin red).
/// Un archivo ilegible no impide nada: la ventana dice solo que la palabra no
/// tiene seña.
class PendingSignInfoDataSource {
  static const String assetPath = 'assets/dictionary/senas_sin_sena.json';

  final AssetBundle bundle;

  PendingSignInfoDataSource({AssetBundle? bundle})
    : bundle = bundle ?? rootBundle;

  Future<PendingSignCatalog> load() async {
    try {
      return PendingSignCatalog.fromJsonString(
        await bundle.loadString(assetPath),
      );
    } catch (_) {
      return PendingSignCatalog.empty;
    }
  }
}
