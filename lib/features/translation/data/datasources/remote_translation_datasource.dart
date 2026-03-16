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
    final generatedText = cards.join(" ");

    /*
    final response = await client.post(
      Uri.parse(apiGatewayUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'context': context,
        'cards': cards,
        'target_language': 'es-ES',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TranslationResult(
        generatedText: data['text'],
        audioUrl: data['audio_url'], 
      );
    } else {
      throw Exception('Failed to connect to AWS Bedrock API');
    }
    */

    await Future.delayed(const Duration(seconds: 2)); 
    return TranslationResult(
      generatedText: generatedText,
    );
  }
}
