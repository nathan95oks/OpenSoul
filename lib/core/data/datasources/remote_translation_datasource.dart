import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';

/// Contrato abstracto para el datasource remoto de traducción.
abstract class RemoteTranslationDataSource {
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  });
}

/// Implementación HTTP que se comunica con API Gateway → Lambda.
///
/// Envía las tarjetas LSB seleccionadas y recibe la respuesta completa
/// del sistema híbrido (motor propio + Bedrock + Polly + S3).
class RemoteTranslationDataSourceImpl implements RemoteTranslationDataSource {
  /// Endpoint del API Gateway. Se inyecta en compilación desde `.env` vía
  /// `run.ps1` / `run.sh`, que traducen las entradas del archivo a
  /// `--dart-define=LSB_API_URL=...`. Sin la variable el valor es `''` y
  /// el POST fallará al parsear el URI — es la señal de "endpoint no
  /// configurado", no un fallback silencioso a un endpoint publicado.
  static const String defaultApiGatewayUrl =
      String.fromEnvironment('LSB_API_URL');

  /// Tope de espera de la llamada remota. Si el backend no responde a tiempo
  /// (red lenta o caída), se lanza [TimeoutException] y el controlador cae al
  /// motor local — nunca se queda colgado en `loading` (RDS-01).
  static const Duration requestTimeout = Duration(seconds: 12);

  final http.Client client;
  final String apiGatewayUrl;

  RemoteTranslationDataSourceImpl({
    required this.client,
    this.apiGatewayUrl = defaultApiGatewayUrl,
  });

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  }) async {
    final response = await client
        .post(
          Uri.parse(apiGatewayUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'context': context,
            'cards': cards,
            'language': 'es-BO',
            'institutionType': 'entidad_publica',
          }),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      // Parsear glossSequence si existe
      List<Map<String, dynamic>>? glossSeq;
      if (data['glossSequence'] != null) {
        glossSeq = (data['glossSequence'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      // Parsear intermediateRepresentation si existe
      Map<String, dynamic>? intermediateRepr;
      if (data['intermediateRepresentation'] != null) {
        intermediateRepr =
            Map<String, dynamic>.from(data['intermediateRepresentation'] as Map);
      }

      return TranslationResult(
        baseSentence: data['baseSentence'] ?? data['generatedText'] ?? '',
        generatedText: data['generatedText'] ?? '',
        audioUrl: data['audioUrl'],
        cacheHit: data['cacheHit'] ?? false,
        bedrockUsed: data['bedrockUsed'] ?? false,
        intermediateRepresentation: intermediateRepr,
        glossSequence: glossSeq,
      );
    } else {
      throw Exception('Error del Backend AWS: ${response.statusCode}');
    }
  }
}
