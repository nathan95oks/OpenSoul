import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/data/models/lsb_translation_model.dart';
import 'package:lsb_legal_app/core/generators/avatar_generator/animation_url_resolver.dart';

abstract class RemoteAudioDataSource {
  Future<LsbTranslationModel> translateAudio(String audioPath);
  Future<LsbTranslationModel> translateText(String text);
}

class RemoteAudioDataSourceImpl implements RemoteAudioDataSource {
  /// Endpoint por defecto. Configurable en compilación sin tocar código
  /// (misma convención que el datasource de declaración, TD-01):
  ///   flutter run --dart-define=LSB_TEXT_API_URL=https://otra-url
  static const String defaultApiGatewayUrl = String.fromEnvironment(
    'LSB_TEXT_API_URL',
    defaultValue:
        'https://mq5eeqtb50.execute-api.us-east-1.amazonaws.com/default/OpenSoul-TextToLSB',
  );

  final http.Client client;
  final String apiGatewayUrl;
  final AnimationUrlResolver animationResolver;

  RemoteAudioDataSourceImpl({
    required this.client,
    this.apiGatewayUrl = defaultApiGatewayUrl,
    this.animationResolver = const AnimationUrlResolver(),
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

        final glossDetails = decodedResponse['glossDetails'] as List<dynamic>? ?? [];
        final urls = <String>[
          for (final detail in glossDetails)
            animationResolver.resolve(
              gloss: (detail['gloss'] ?? '').toString(),
              animationFile: detail['animationFile']?.toString(),
            ),
        ];

        // Decodificamos el JSON que viene de AWS Lambda (Bedrock)
        return LsbTranslationModel.fromJson({
          'glosses': decodedResponse['glosses'],
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
