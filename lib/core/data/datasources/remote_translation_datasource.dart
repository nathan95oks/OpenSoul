import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/network/endpoint_uri.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

abstract class RemoteTranslationDataSource {
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
  });
}

class RemoteTranslationDataSourceImpl implements RemoteTranslationDataSource {
  static const String defaultApiGatewayUrl =
      String.fromEnvironment('LSB_API_URL');

  static const Duration requestTimeout = Duration(seconds: 12);

  final http.Client client;
  final String apiGatewayUrl;

  RemoteTranslationDataSourceImpl({
    required this.client,
    this.apiGatewayUrl = defaultApiGatewayUrl,
  });

  /// Versión del contrato con el backend. La versión 2 añade la
  /// representación estructurada (`declaration`), el acto comunicativo y el
  /// turno al que se responde; el backend que no la reconozca puede seguir
  /// usando `context`/`cards` como antes (compatibilidad hacia atrás).
  static const int contractVersion = 2;

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
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
            'contractVersion': contractVersion,
            // ignore: use_null_aware_elements
            if (speechAct != null) 'speechAct': speechAct,
            // ignore: use_null_aware_elements
            if (replyToId != null) 'replyToId': replyToId,
            // ignore: use_null_aware_elements
            if (declaration != null) 'declaration': declaration,
          }),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      List<Map<String, dynamic>>? glossSeq;
      if (data['glossSequence'] != null) {
        glossSeq = (data['glossSequence'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

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
        coverageValidated: data['coverageValidated'] ?? false,
        intermediateRepresentation: intermediateRepr,
        glossSequence: glossSeq,
      );
    } else {
      throw Exception('Error del Backend AWS: ${response.statusCode}');
    }
  }
}
