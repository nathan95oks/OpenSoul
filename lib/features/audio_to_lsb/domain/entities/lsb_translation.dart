class LsbTranslation {
  final List<String> glosses;
  final String animationUrl; // Legacy o para la primera animación
  final List<String> animationUrls; // Lista de todas las animaciones desde S3

  LsbTranslation({
    required this.glosses,
    required this.animationUrl,
    this.animationUrls = const [],
  });
}
