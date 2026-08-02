import 'semantic_message.dart';

class LsbTranslation {
  final List<String> glosses;
  final String animationUrl; // Legacy o para la primera animación
  final List<String> animationUrls; // Lista de todas las animaciones desde S3

  /// Etiqueta de cada animación, alineada con [animationUrls].
  ///
  /// No coincide con [glosses] cuando hay señas compuestas: FISCAL se ejecuta
  /// como `F.glb + ABOGADO.glb`, o sea **dos animaciones de una sola glosa**.
  /// El visor avanza por índice y necesita saber qué glosa rotular en cada
  /// paso; la lista semántica, en cambio, debe seguir teniendo una entrada por
  /// glosa —si no, la inferencia de contexto contaría FISCAL dos veces—.
  final List<String> animationGlosses;

  /// Ambigüedades que el motor resolvió al interpretar la frase. El backend
  /// ya las venía calculando; se conservan para poder mostrarlas.
  final List<SemanticDisambiguation> disambiguations;

  LsbTranslation({
    required this.glosses,
    required this.animationUrl,
    this.animationUrls = const [],
    this.animationGlosses = const [],
    this.disambiguations = const [],
  });
}
