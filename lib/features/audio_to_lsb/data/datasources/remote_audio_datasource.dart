import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lsb_translation_model.dart';

abstract class RemoteAudioDataSource {
  Future<LsbTranslationModel> translateAudio(String audioPath);
}

class RemoteAudioDataSourceImpl implements RemoteAudioDataSource {
  final http.Client client;
  final String apiGatewayUrl;

  RemoteAudioDataSourceImpl({
    required this.client,
    this.apiGatewayUrl = 'https://tudominio-aws-api-gateway.com/prod/audio-to-lsb', // Mock URL
  });

  @override
  Future<LsbTranslationModel> translateAudio(String audioPath) async {
    // Note: In a real implementation, you would probably upload the file via multipart request
    // or upload to S3 first and then send the S3 URL to the API Gateway.
    // Here we simulate the call with a simple POST request (e.g. sending the audio as base64 or assuming we send a path).
    
    // Simulating multipart request setup or similar:
    /*
    var request = http.MultipartRequest('POST', Uri.parse(apiGatewayUrl));
    request.files.add(await http.MultipartFile.fromPath('audio', audioPath));
    var response = await request.send();
    */

    // For this mock, we just wait a bit and return a mocked successful response.
    // This allows the frontend structure to be fully functional and ready to plug the real API.
    await Future.delayed(const Duration(seconds: 2)); // Simulate network latency

    final mockResponse = {
      'glosses': ['HOLA', 'NOMBRE', 'MIO', 'JUAN'],
      'animationUrl': 'https://mock-3d-avatar-anim.com/anim.gltf', // Placeholder
    };

    return LsbTranslationModel.fromJson(mockResponse);

    /* Real implementation logic later:
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LsbTranslationModel.fromJson(data);
    } else {
      throw Exception('Failed to translate audio: ${response.statusCode}');
    }
    */
  }
}
