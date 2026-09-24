import 'dart:io';

import 'package:lsb_legal_app/core/data/datasources/business_catalog_datasource.dart';
import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';

/// Doble del catálogo de negocio para pruebas de widgets.
///
/// `rootBundle` no resuelve bajo el reloj falso de `testWidgets`, así que el
/// indicador de carga gira para siempre y `pumpAndSettle` nunca vuelve. Este
/// doble sirve el mismo asset leyendo el archivo de forma síncrona, igual que
/// hace `FakeLexiconRepository` con el diccionario.
class FakeBusinessCatalogDataSource extends BusinessCatalogDataSource {
  final BusinessCatalog _catalogo = BusinessCatalog.fromJsonString(
    File(BusinessCatalogDataSource.assetPath).readAsStringSync(),
  );

  @override
  Future<BusinessCatalog> load() async => _catalogo;
}
