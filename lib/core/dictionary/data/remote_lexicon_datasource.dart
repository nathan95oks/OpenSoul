import 'package:http/http.dart' as http;

import '../domain/dictionary_document.dart';

/// Cliente HTTP del diccionario remoto (API Gateway → lambda_dictionary).
///
/// El endpoint se configura en compilación, igual que el resto de la
/// infraestructura (TD-01):
///   flutter run --dart-define=LSB_DICTIONARY_API_URL=https://.../dictionary
///
/// Si no se define, la app funciona en modo puramente local (asset + caché):
/// el repositorio simplemente omite la sincronización.
class RemoteLexiconDataSource {
  static const String defaultApiUrl =
      String.fromEnvironment('LSB_DICTIONARY_API_URL');

  static const Duration requestTimeout = Duration(seconds: 10);

  final http.Client client;
  final String apiUrl;

  RemoteLexiconDataSource({required this.client, this.apiUrl = defaultApiUrl});

  bool get isConfigured => apiUrl.isNotEmpty;

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
