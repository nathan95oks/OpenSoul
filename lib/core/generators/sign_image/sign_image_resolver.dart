/// Resuelve la URL de la imagen de una seña LSB.
///
/// Las tarjetas del flujo guiado muestran la seña antes que la palabra: quien
/// construye la declaración se apoya en la imagen, y el español escrito es su
/// segunda lengua. El ícono de Material que había hasta ahora nombra la
/// *categoría* del concepto —una mano, un documento—, no la seña que hay que
/// hacer, así que no sustituye a la fotografía.
///
/// Comparte criterio con `AnimationUrlResolver`: el bucket se inyecta en
/// compilación y jamás se escribe en el código, y el nombre de archivo se
/// valida con lista blanca porque las glosas llegan del diccionario remoto.
class SignImageResolver {
  /// Base del almacén de imágenes. Se inyecta desde `.env` vía `run.sh` /
  /// `run.ps1`, igual que el resto de la infraestructura.
  ///
  /// Vacío es un estado válido y previsto: sin la variable no hay imágenes y
  /// las tarjetas se dibujan con su ícono, que es el comportamiento anterior.
  static const String defaultBaseUrl =
      String.fromEnvironment('LSB_SIGN_IMAGES_BASE_URL');

  final String baseUrl;

  const SignImageResolver({this.baseUrl = defaultBaseUrl});

  /// `true` si hay un almacén de imágenes utilizable.
  bool get isConfigured {
    final uri = Uri.tryParse(baseUrl);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  /// URL de la imagen de [gloss], o `null` si no se puede construir.
  ///
  /// `null` no es un error: es "esta seña no tiene imagen", y la tarjeta lo
  /// resuelve mostrando su ícono. Nunca devuelve una ruta inventada.
  String? urlFor(String gloss) {
    if (!isConfigured) return null;
    final safe = _sanitize(gloss);
    if (safe == null || safe.isEmpty) return null;
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '$base$safe.png';
  }

  /// Caracteres admitidos en el nombre del archivo.
  ///
  /// Lista blanca por el mismo motivo que en las animaciones: la glosa puede
  /// venir del diccionario remoto, y una lista negra de `..` y `/` se sortea
  /// con codificaciones dobles.
  static final RegExp _admitido = RegExp(r'^[A-Z0-9_-]+$');

  /// Los archivos se nombran sin tildes ni eñes; las glosas sí las llevan.
  static String? _sanitize(String gloss) {
    const equivalencias = {
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N',
    };
    var normalizada = gloss.trim().toUpperCase();
    equivalencias.forEach((con, sin) => normalizada = normalizada.replaceAll(con, sin));
    // Las glosas del corpus llegan con espacios ("POR FAVOR"); el archivo los
    // lleva como guion bajo.
    normalizada = normalizada.replaceAll(' ', '_');
    return _admitido.hasMatch(normalizada) ? normalizada : null;
  }
}
