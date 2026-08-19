import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/data/datasources/endpoint_uri.dart';
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
  /// Endpoint por defecto. Configurable en compilación sin tocar código:
  ///   flutter run --dart-define=LSB_API_URL=https://otra-url/translate
  /// (TD-01) — evita acoplar el binario a un endpoint concreto.
  static const String _envApiGatewayUrl =
      String.fromEnvironment('LSB_API_URL');

  static const String _fallbackApiGatewayUrl =
      'https://5kc2fwqb49.execute-api.us-east-1.amazonaws.com/translate';

  /// Ver la nota equivalente en `remote_audio_datasource.dart`: una variable
  /// definida pero vacía anula el `defaultValue` de `String.fromEnvironment`
  /// y deja la app sin endpoint. `.length == 0` en lugar de `isEmpty` por la
  /// restricción del contexto constante.
  static const String defaultApiGatewayUrl =
      _envApiGatewayUrl.length == 0 ? _fallbackApiGatewayUrl : _envApiGatewayUrl;

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
    final uri = requireAbsoluteUrl(apiGatewayUrl, 'LSB_API_URL');

    final response = await client
        .post(
          uri,
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
