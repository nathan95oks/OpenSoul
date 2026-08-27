class AnimationUrlResolver {
  static const String defaultBaseUrl =
      String.fromEnvironment('LSB_ANIMATIONS_BASE_URL');

  static const String placeholderScheme = 'placeholder://';
  final String baseUrl;

  const AnimationUrlResolver({this.baseUrl = defaultBaseUrl});

  static const String compositeSeparator = '+';

  static const Set<String> available3DGlosses = {
    'HOLA', 'PERMISO', 'GRACIAS', 'SI', 'NO',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'Ñ', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'CERO', 'UNO', 'DOS', 'TRES', 'CUATRO', 'CINCO', 'SEIS', 'SIETE', 'OCHO', 'NUEVE', 'DIEZ'
  };

  static const Set<String> wordsToSpell = {
    'DENUNCIA', 'DENUNCIAR', 'DENUNCIANTE', 'DENUNCIADO', 'FISCALIA',
    'JUZGADO', 'COMISARIA', 'QUERELLA', 'IMPUTACION', 'IMPUTADO',
    'VICTIMA', 'SOSPECHOSO', 'DETENIDO', 'ACTA', 'CEDULA', 'CEDULA DE IDENTIDAD',
    'FIRMA', 'FIRMAR', 'DECLARACION', 'DECLARAR', 'MINISTERIO PUBLICO',
    'FELCC', 'FELCV'
  };

  String resolve({required String gloss, String? animationFile}) =>
      resolveAll(gloss: gloss, animationFile: animationFile).first;

  List<String> resolveAll({required String gloss, String? animationFile}) {
    final cleanGloss = gloss
        .toUpperCase()
        .trim()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U');

    if (available3DGlosses.contains(cleanGloss)) {
      return ['${baseUrl}avatar_test.glb'];
    }

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

    if (animationFile != null && animationFile.isNotEmpty) {
      if (animationFile.endsWith('.glb')) {
        return ['${baseUrl}avatar_test.glb'];
      }
    }

    return ['$placeholderScheme$cleanGloss'];
  }
}
