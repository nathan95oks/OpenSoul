import 'semantic_message.dart';

class LsbTranslation {
  final List<String> glosses;
  final String animationUrl; // Legacy o para la primera animación
  final List<String> animationUrls; // Lista de todas las animaciones desde S3

  /// Ambigüedades que el motor resolvió al interpretar la frase. El backend
  /// ya las venía calculando; se conservan para poder mostrarlas.
  final List<SemanticDisambiguation> disambiguations;

  LsbTranslation({
    required this.glosses,
    required this.animationUrl,
    this.animationUrls = const [],
    this.disambiguations = const [],
  });
}
