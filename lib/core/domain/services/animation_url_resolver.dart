class AnimationUrlResolver {
  static const String defaultBaseUrl =
      String.fromEnvironment('LSB_ANIMATIONS_BASE_URL');

  static const String placeholderScheme = 'placeholder://';
  final String baseUrl;

  const AnimationUrlResolver({this.baseUrl = defaultBaseUrl});

  static const String compositeSeparator = '+';

  /// Senas horneadas en `avatar_test.glb`, tomadas del propio modelo.
  ///
  /// No estan la 'I' ni la 'K': el modelo no las trae. Figuraban aqui y el
  /// visor pedia una animacion inexistente, que no emite 'finished' y dejaba
  /// la secuencia colgada en esa letra. Mientras no se horneen, se deletrean
  /// como placeholder, que al menos se ve.
  static const Set<String> available3DGlosses = {
    'HOLA', 'PERMISO', 'GRACIAS', 'SI', 'NO',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'L', 'M',
    'N', 'Ñ', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'CERO', 'UNO', 'DOS', 'TRES', 'CUATRO', 'CINCO', 'SEIS', 'SIETE', 'OCHO', 'NUEVE', 'DIEZ'
  };

  /// Glosas cuyo nombre de animacion dentro del .glb no coincide con la glosa.
  static const Map<String, String> animationNameOverrides = {
    'Ñ': 'ENE',
  };

  /// Nombre con el que hay que pedirle la sena al `model-viewer`.
  static String animationNameFor(String gloss) {
    final clean = stripAccents(gloss.toUpperCase().trim());
    return animationNameOverrides[clean] ?? clean;
  }

  static const Set<String> wordsToSpell = {
    'DENUNCIA', 'DENUNCIAR', 'DENUNCIANTE', 'DENUNCIADO', 'FISCALIA',
    'JUZGADO', 'COMISARIA', 'QUERELLA', 'IMPUTACION', 'IMPUTADO',
    'VICTIMA', 'SOSPECHOSO', 'DETENIDO', 'ACTA', 'CEDULA', 'CEDULA DE IDENTIDAD',
    'FIRMA', 'FIRMAR', 'DECLARACION', 'DECLARAR', 'MINISTERIO PUBLICO',
    'FELCC', 'FELCV'
  };

  /// Quita las tildes de una glosa conservando la N con virgulilla, que es una
  /// letra del alfabeto dactilologico y no un acento.
  static String stripAccents(String gloss) {
    const from = 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛ';
    const to = 'AAAAEEEEIIIIOOOOUUUU';
    var out = gloss;
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  /// Letras con las que se deletrea [gloss], o `null` si [gloss] no se
  /// deletrea. Incluye las que no tienen animacion: se representan con un
  /// placeholder, pero la palabra se deletrea entera.
  static List<String>? spelledLetters(String gloss) {
    final clean = stripAccents(gloss.toUpperCase().trim());
    if (!wordsToSpell.contains(clean) || clean.length <= 1) return null;
    return clean.split('');
  }

  String resolve({required String gloss, String? animationFile}) =>
      resolveAll(gloss: gloss, animationFile: animationFile).first;

  List<String> resolveAll({required String gloss, String? animationFile}) {
    final cleanGloss = stripAccents(gloss.toUpperCase().trim());

    if (available3DGlosses.contains(cleanGloss)) {
      return ['${baseUrl}avatar_test.glb'];
    }

    if (wordsToSpell.contains(cleanGloss) && cleanGloss.length > 1) {
      // Una letra sin animacion no se descarta: se deletrea como placeholder.
      // Descartarla cambiaba la palabra en silencio (FISCALIA se deletreaba
      // "FSCALA" al no estar la I).
      final letters = spelledLetters(cleanGloss)!
          .map((char) => available3DGlosses.contains(char)
              ? '${baseUrl}avatar_test.glb'
              : '$placeholderScheme$char')
          .toList();
      if (letters.isNotEmpty) {
        return letters;
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
