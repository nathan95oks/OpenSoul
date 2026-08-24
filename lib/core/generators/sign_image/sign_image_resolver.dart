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
  String? urlFor(String gloss) => urlsFor(gloss).firstOrNull;

  /// Fotogramas de [gloss], en orden.
  ///
  /// Una seña con movimiento no cabe en una fotografía: el movimiento es uno
  /// de sus parámetros formacionales, y una sola imagen deja fuera justo lo
  /// que la distingue de otra con la misma configuración manual. Esas señas se
  /// fotografían por partes y el catálogo declara cuántas con [frames]; sus
  /// archivos se nombran `GLOSA_1.png`, `GLOSA_2.png`…
  ///
  /// Con [frames] igual a 1 —el caso normal— es un único `GLOSA.png`.
  List<String> urlsFor(String gloss, {int frames = 1}) {
    if (!isConfigured) return const [];
    final safe = _sanitize(gloss);
    if (safe == null || safe.isEmpty) return const [];
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    if (frames <= 1) return ['$base$safe.png'];
    return [for (var i = 1; i <= frames; i++) '$base${safe}_$i.png'];
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
