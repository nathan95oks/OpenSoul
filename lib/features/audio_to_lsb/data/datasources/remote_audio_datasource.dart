import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lsb_translation_model.dart';

abstract class RemoteAudioDataSource {
  Future<LsbTranslationModel> translateAudio(String audioPath);
  Future<LsbTranslationModel> translateText(String text);
}

class RemoteAudioDataSourceImpl implements RemoteAudioDataSource {
  final http.Client client;
  final String apiGatewayUrl;

  RemoteAudioDataSourceImpl({
    required this.client,
    this.apiGatewayUrl = 'https://mq5eeqtb50.execute-api.us-east-1.amazonaws.com/default/OpenSoul-TextToLSB',
  });

  @override
  Future<LsbTranslationModel> translateAudio(String audioPath) async {
    // Note: Pending implementation for real audio upload,
    // since the current flow uses SpeechToText on device.
    throw UnimplementedError('translateAudio is not used when using On-Device Speech-to-Text.');
  }
  
  @override
  Future<LsbTranslationModel> translateText(String text) async {
    try {
      final response = await client.post(
        Uri.parse(apiGatewayUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'context': 'legal',
        }),
      );

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        
        // Extraer los nombres de archivos de animación
        final glossDetails = decodedResponse['glossDetails'] as List<dynamic>? ?? [];
        final s3BaseUrl = 'https://opensoul-3d-animations.s3.us-east-1.amazonaws.com/';
        
        List<String> urls = [];
        for (var detail in glossDetails) {
          final file = detail['animationFile'];
          if (file != null && file.toString().isNotEmpty) {
            urls.add('\$s3BaseUrl\$file');
          }
        }
        
        // Decodificamos el JSON que viene de AWS Lambda (Bedrock)
        return LsbTranslationModel.fromJson({
          'glosses': decodedResponse['glosses'],
          'animationUrl': urls.isNotEmpty ? urls.first : '', 
          'animationUrls': urls,
        });
      } else {
        throw Exception('AWS API Error: \${response.statusCode} - \${response.body}');
      }
    } catch (e) {
      throw Exception('Network or Server error: \$e');
    }
  }
}
