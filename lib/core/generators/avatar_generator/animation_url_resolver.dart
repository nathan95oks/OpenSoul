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

  /// Catálogo completo de las 41 señas horneadas en 3D en avatar_test.glb
  static const Set<String> available3DGlosses = {
    // 1. Comunicación básica y control del diálogo (5 señas)
    'HOLA', 'PERMISO', 'GRACIAS', 'SI', 'NO',
    // 2. Abecedario Dactilológico LSB (27 letras)
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'Ñ', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    // 3. Números LSB (10 dígitos)
    'CERO', 'UNO', 'DOS', 'TRES', 'CUATRO', 'CINCO', 'SEIS', 'SIETE', 'OCHO', 'NUEVE', 'DIEZ'
  };

  /// Términos jurídicos o administrativos especializados que deben validarse y se deletrean dactilológicamente en LSB
  static const Set<String> wordsToSpell = {
    'DENUNCIA', 'DENUNCIAR', 'DENUNCIANTE', 'DENUNCIADO', 'FISCALIA',
    'JUZGADO', 'COMISARIA', 'QUERELLA', 'IMPUTACION', 'IMPUTADO',
    'VICTIMA', 'SOSPECHOSO', 'DETENIDO', 'ACTA', 'CEDULA', 'CEDULA DE IDENTIDAD',
    'FIRMA', 'FIRMAR', 'DECLARACION', 'DECLARAR', 'MINISTERIO PUBLICO',
    'FELCC', 'FELCV'
  };

  /// URL reproducible para [animationFile], o placeholder si no hay archivo.
  String resolve({required String gloss, String? animationFile}) =>
      resolveAll(gloss: gloss, animationFile: animationFile).first;

  /// Secuencia completa de URLs de [animationFile].
  ///
  /// Resuelve la URL del modelo 3D según la matriz de 3 estados:
  /// 1. Señas 3D disponibles en [available3DGlosses] -> `avatar_test.glb`.
  /// 2. Palabras no convencionales en [wordsToSpell] -> Deletreo dactilológico letra por letra en 3D.
  /// 3. Señas del corpus aún no animadas -> Placeholder de texto simulado.
  List<String> resolveAll({required String gloss, String? animationFile}) {
    final cleanGloss = gloss
        .toUpperCase()
        .trim()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U');

    // 1. Si está en el catálogo 3D disponible
    if (available3DGlosses.contains(cleanGloss)) {
      return ['${baseUrl}avatar_test.glb'];
    }

    // 2. Si es una palabra para deletrear letra por letra
    if (wordsToSpell.contains(cleanGloss) && cleanGloss.length > 1) {
      final validLetters = cleanGloss
          .split('')
          .where((char) => available3DGlosses.contains(char))
          .map((_) => '${baseUrl}avatar_test.glb')
          .toList();
      if (validLetters.isNotEmpty) {
        return validLetters;
      }
    }

    // 3. Si viene un archivo específico compatible con 3D
    if (animationFile != null && animationFile.isNotEmpty) {
      if (animationFile.endsWith('.glb')) {
        return ['${baseUrl}avatar_test.glb'];
      }
    }

    // 4. Si la seña existe en LSB pero aún no tiene animación 3D (Simulación por texto)
    return ['$placeholderScheme$cleanGloss'];
  }

}
