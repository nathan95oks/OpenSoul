/// Resuelve la URL de animación 3D (S3) de una glosa LSB.
///
/// Conocimiento propio del generador de avatar: dónde viven los .glb y cómo
/// normalizar el nombre de archivo. Antes estaba incrustado en el datasource
/// HTTP, acoplando la capa de datos a detalles de presentación del avatar.
class AnimationUrlResolver {
  /// Bucket de animaciones. Configurable en compilación:
  ///   flutter run --dart-define=LSB_ANIMATIONS_BASE_URL=https://otro-bucket/
  static const String defaultBaseUrl = String.fromEnvironment(
    'LSB_ANIMATIONS_BASE_URL',
    defaultValue: 'https://opensoul-3d-animations.s3.us-east-1.amazonaws.com/',
  );

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
    return [
      for (final part in animationFile.split(compositeSeparator))
        if (part.trim().isNotEmpty) '$baseUrl${_sanitizeFileName(part.trim())}',
    ];
  }

  /// Los archivos en S3 se nombran sin tildes ni eñes; las glosas sí las
  /// llevan. Normaliza para que la URL siempre exista.
  String _sanitizeFileName(String file) => file
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ñ', 'N');
}
