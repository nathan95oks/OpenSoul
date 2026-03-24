import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/repositories/translation_repository.dart';

abstract class RemoteTranslationDataSource {
  Future<TranslationResult> translateCards({required String context, required List<String> cards});
}

class RemoteTranslationDataSourceImpl implements RemoteTranslationDataSource {
  final http.Client client;
  final String apiGatewayUrl;

  RemoteTranslationDataSourceImpl({
    required this.client, 
    this.apiGatewayUrl = 'https://tudominio-aws-api-gateway.com/prod/translate', // Base placeholder
  });

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  }) async {
    final response = await client.post(
      Uri.parse(apiGatewayUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: jsonEncode({
        'context': context,
        'cards': cards,
        'language': 'es-BO',
        'institutionType': 'comisaria'
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return TranslationResult(
        generatedText: data['generatedText'] ?? '',
        audioUrl: data['audioUrl'],
        cacheHit: data['cacheHit'] ?? false,
      );
    } else {
      throw Exception('Error del Backend AWS: ${response.statusCode}');
    }
  }
}
