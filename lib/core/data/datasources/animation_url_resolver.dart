class AnimationUrlResolver {
  static const String defaultBaseUrl =
      String.fromEnvironment('LSB_ANIMATIONS_BASE_URL');

  static const String placeholderScheme = 'placeholder://';
  final String baseUrl;

  const AnimationUrlResolver({this.baseUrl = defaultBaseUrl});

  static const String compositeSeparator = '+';

  String resolve({required String gloss, String? animationFile}) =>
      resolveAll(gloss: gloss, animationFile: animationFile).first;

  List<String> resolveAll({required String gloss, String? animationFile}) {
    if (animationFile == null || animationFile.isEmpty || animationFile == '$gloss.glb') {
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

  static final RegExp _allowedFileName = RegExp(r'^[A-Za-z0-9._-]+$');

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
