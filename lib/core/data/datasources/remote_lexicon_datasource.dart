import 'package:http/http.dart' as http;

import 'package:lsb_legal_app/core/domain/entities/dictionary_document.dart';

class RemoteLexiconDataSource {
  static const String defaultApiUrl =
      String.fromEnvironment('LSB_DICTIONARY_API_URL');

  static const Duration requestTimeout = Duration(seconds: 10);

  final http.Client client;
  final String apiUrl;

  RemoteLexiconDataSource({required this.client, this.apiUrl = defaultApiUrl});

  bool get isConfigured {
    final uri = Uri.tryParse(apiUrl);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  Future<DictionaryDocument> fetch() async {
    final response = await client.get(
      Uri.parse(apiUrl),
      headers: {'Accept': 'application/json'},
    ).timeout(requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Dictionary API error: ${response.statusCode}');
    }
    return DictionaryDocument.fromJsonString(response.body);
  }
}
