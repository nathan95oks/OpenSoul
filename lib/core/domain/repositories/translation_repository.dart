/// Resultado de la traducción LSB → texto → audio.
///
/// Incluye tanto la oración generada por el motor propio ([baseSentence])
/// como la versión refinada por Bedrock ([generatedText]).
class TranslationResult {
  /// Oración generada por el motor inteligente propio (reglas + lexicón).
  final String baseSentence;

  /// Oración final (refinada por Bedrock si estuvo habilitado,
  /// o igual a [baseSentence] si no).
  final String generatedText;

  /// URL del archivo MP3 generado por Amazon Polly y almacenado en S3.
  final String? audioUrl;

  /// Indica si la respuesta provino de caché (DynamoDB futuro).
  final bool cacheHit;

  /// Indica si Amazon Bedrock fue utilizado para refinar la oración.
  final bool bedrockUsed;

  /// Representación intermedia generada por el motor de análisis semántico.
  /// Contiene roles (sujeto, verbo, objeto…), tipo de evento y metadatos.
  final Map<String, dynamic>? intermediateRepresentation;

  /// Secuencia ordenada de glosas con sus claves de video/animación.
  /// Ejemplo: [{"gloss": "YO", "videoKey": "lsb-videos/YO.mp4"}, …]
  final List<Map<String, dynamic>>? glossSequence;

  TranslationResult({
    required this.baseSentence,
    required this.generatedText,
    this.audioUrl,
    this.cacheHit = false,
    this.bedrockUsed = false,
    this.intermediateRepresentation,
    this.glossSequence,
  });
}

/// Contrato abstracto del repositorio de traducción.
///
/// La capa de dominio depende de este contrato, no de la implementación
/// concreta (Clean Architecture — Dependency Inversion).
abstract class TranslationRepository {
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  });
}
