import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';

/// Carga el catálogo de negocio empaquetado con la aplicación.
///
/// Es un asset local: los perfiles y las necesidades tienen que estar
/// disponibles en una ventanilla sin conexión, que es la situación normal.
class BusinessCatalogDataSource {
  static const String assetPath = 'assets/business/institution_profiles.json';

  final AssetBundle bundle;

  BusinessCatalogDataSource({AssetBundle? bundle})
      : bundle = bundle ?? rootBundle;

  Future<BusinessCatalog> load() async {
    // Un catálogo ilegible no puede impedir comunicarse: sin perfiles se
    // trabaja como atención general, que es un modo de uso válido.
    try {
      return BusinessCatalog.fromJsonString(await bundle.loadString(assetPath));
    } catch (_) {
      return BusinessCatalog.empty;
    }
  }
}
