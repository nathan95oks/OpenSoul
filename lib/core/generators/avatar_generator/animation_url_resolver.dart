/// Resuelve la URL de animación 3D (S3) de una glosa LSB.
///
/// Conocimiento propio del generador de avatar: dónde viven los .glb y cómo
/// normalizar el nombre de archivo. Antes estaba incrustado en el datasource
/// HTTP, acoplando la capa de datos a detalles de presentación del avatar.
class AnimationUrlResolver {
  /// Bucket de animaciones. Se inyecta en compilación desde `.env` vía
  /// `run.ps1` / `run.sh`. Sin la variable el valor es `''`,
  /// `AnimationCache.defaultAllowedHosts()` queda vacío y toda descarga se
  /// rechaza — el visor cae al placeholder de texto.
  static const String defaultBaseUrl =
      String.fromEnvironment('LSB_ANIMATIONS_BASE_URL');

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
  /// Resuelve la URL del modelo 3D. En la arquitectura Multi-Action,
  /// si no hay un archivo específico o se pide una seña horneada en el avatar,
  /// apunta directamente al modelo activo en S3 (`avatar_test.glb`).
  List<String> resolveAll({required String gloss, String? animationFile}) {
    if (animationFile == null || animationFile.isEmpty || animationFile == '$gloss.glb') {
      // Mapea al contenedor 3D Multi-Action unificado en AWS S3
      return ['${baseUrl}avatar_test.glb'];
    }
    final urls = <String>[];
    for (final part in animationFile.split(compositeSeparator)) {
      final safe = _sanitizeFileName(part.trim());
      if (safe == null || safe.isEmpty) continue;
      urls.add('$baseUrl$safe');
    }
    return urls.isEmpty ? ['${baseUrl}avatar_test.glb'] : urls;
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
