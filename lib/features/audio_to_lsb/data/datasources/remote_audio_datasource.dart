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
        List<String> expandedGlosses = [];
        
        for (var detail in glossDetails) {
          final file = detail['animationFile'];
          final gloss = detail['gloss'] ?? '';
          
          if (file != null && file.toString().isNotEmpty) {
            final fileStr = file.toString();
            if (fileStr.contains('+')) {
              // Es una seña compuesta (ej: F.glb+ABOGADO.glb)
              final parts = fileStr.split('+');
              for (var part in parts) {
                String cleanFile = part.trim()
                    .replaceAll('Á', 'A').replaceAll('É', 'E')
                    .replaceAll('Í', 'I').replaceAll('Ó', 'O')
                    .replaceAll('Ú', 'U').replaceAll('Ñ', 'N');
                urls.add('$s3BaseUrl$cleanFile');
                expandedGlosses.add(gloss); // Duplicar la glosa original
              }
            } else {
              String cleanFile = fileStr
                  .replaceAll('Á', 'A').replaceAll('É', 'E')
                  .replaceAll('Í', 'I').replaceAll('Ó', 'O')
                  .replaceAll('Ú', 'U').replaceAll('Ñ', 'N');
              urls.add('$s3BaseUrl$cleanFile');
              expandedGlosses.add(gloss);
            }
          } else {
            // Es una glosa no disponible, agregamos un placeholder
            urls.add('placeholder://$gloss');
            expandedGlosses.add(gloss);
          }
        }
        
        // Decodificamos el JSON que viene de AWS Lambda (Bedrock)
        return LsbTranslationModel.fromJson({
          'glosses': expandedGlosses,
          'animationUrl': urls.isNotEmpty ? urls.first : '', 
          'animationUrls': urls,
        });
      } else {
        throw Exception('AWS API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network or Server error: $e');
    }
  }
}
