/// Resuelve la URL de animación 3D (S3) de una glosa LSB.
///
/// Conocimiento propio del generador de avatar: dónde viven los .glb y cómo
/// normalizar el nombre de archivo. Antes estaba incrustado en el datasource
/// HTTP, acoplando la capa de datos a detalles de presentación del avatar.
class AnimationUrlResolver {
  /// Bucket de animaciones. Configurable en compilación:
  ///   flutter run --dart-define=LSB_ANIMATIONS_BASE_URL=https://otro-bucket/
  static const String _envBaseUrl =
      String.fromEnvironment('LSB_ANIMATIONS_BASE_URL');

  static const String _fallbackBaseUrl =
      'https://opensoul-3d-animations.s3.us-east-1.amazonaws.com/';

  /// Igual que en los datasources HTTP: una variable definida pero vacía
  /// anularía el bucket por defecto y el visor intentaría cargar los `.glb`
  /// desde una ruta relativa, quedándose en negro sin error visible.
  static const String defaultBaseUrl =
      _envBaseUrl.length == 0 ? _fallbackBaseUrl : _envBaseUrl;

  /// Esquema para glosas sin animación disponible; el visor las muestra
  /// como texto en lugar de intentar cargar un modelo.
  static const String placeholderScheme = 'placeholder://';

  final String baseUrl;

  const AnimationUrlResolver({this.baseUrl = defaultBaseUrl});

  /// Separador de señas compuestas en el `animationFile` del backend.
  ///
  /// Algunas señas no tienen un modelo propio y se ejecutan encadenando
  /// varios: FISCAL es la letra F deletreada seguida del rol
  /// (`F.glb+ABOGADO.glb`). Para el avatar son varias animaciones; para la
  /// conversación siguen siendo **una sola glosa**.
  static const String compositeSeparator = '+';

  /// URL reproducible para [animationFile], o placeholder si no hay archivo.
  ///
  /// Con una seña compuesta devuelve la primera de la secuencia; usa
  /// [resolveAll] para reproducirla entera.
  String resolve({required String gloss, String? animationFile}) =>
      resolveAll(gloss: gloss, animationFile: animationFile).first;

  /// Secuencia completa de URLs de [animationFile].
  ///
  /// Siempre devuelve al menos un elemento: sin archivo, el placeholder que
  /// el visor muestra como texto.
  List<String> resolveAll({required String gloss, String? animationFile}) {
    if (animationFile == null || animationFile.isEmpty) {
      return ['$placeholderScheme$gloss'];
    }
    final urls = <String>[];
    for (final part in animationFile.split(compositeSeparator)) {
      final safe = _sanitizeFileName(part.trim());
      if (safe == null || safe.isEmpty) continue;
      urls.add('$baseUrl$safe');
    }
    // Un `animationFile` entero rechazado equivale a no tener animación: la
    // glosa se rotula como texto en vez de apuntar a una ruta inventada.
    return urls.isEmpty ? ['$placeholderScheme$gloss'] : urls;
  }

  /// Caracteres admitidos en un nombre de archivo de animación.
  ///
  /// **Lista blanca, no negra.** El `animationFile` llega en la respuesta del
  /// backend y en el diccionario remoto, así que es entrada no confiable: una
  /// lista negra de `..` y `/` se sortea con `%2E%2E%2F`, con `\` o con
  /// codificaciones dobles. Enumerar lo permitido no tiene esa clase de
  /// agujero, y el conjunto real de nombres —`ABOGADO.glb`, `F.glb`,
  /// `PARTIDA_NACIMIENTO.glb`— cabe de sobra aquí.
  static final RegExp _allowedFileName = RegExp(r'^[A-Za-z0-9._-]+$');

  /// Los archivos en S3 se nombran sin tildes ni eñes; las glosas sí las
  /// llevan. Normaliza para que la URL siempre exista, y descarta el nombre
  /// entero si contiene algo que no sea un nombre de archivo llano.
  ///
  /// Devuelve `null` cuando el nombre no es admisible: quien llama lo trata
  /// como "sin animación" y la glosa cae a su placeholder, que es
  /// exactamente el comportamiento que ya existía para una seña sin modelo.
  String? _sanitizeFileName(String file) {
    final normalized = file
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N');
    return _allowedFileName.hasMatch(normalized) ? normalized : null;
  }
}
