import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:lsb_legal_app/core/domain/entities/generated_step.dart';
import 'package:lsb_legal_app/core/network/endpoint_uri.dart';

class RemoteSuggestionDataSource {
  static const String _envUrl = String.fromEnvironment('LSB_API_URL');
  static const String defaultApiUrl = _envUrl;

  static const Duration requestTimeout = Duration(seconds: 6);

  final http.Client client;
  final String apiUrl;

  RemoteSuggestionDataSource({required this.client, this.apiUrl = defaultApiUrl});

  bool get isConfigured {
    final uri = Uri.tryParse(apiUrl);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  Future<GeneratedStep> suggest({
    required String contextId,
    required List<String> selected,
    required List<String> candidates,
    String? replyingTo,
  }) async {
    if (!isConfigured || candidates.isEmpty) return GeneratedStep.vacio;

    try {
      final response = await client
          .post(
            requireAbsoluteUrl(apiUrl, 'LSB_API_URL'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': 'suggest',
              'context': contextId,
              'selected': selected,
              'candidates': candidates,
              if (replyingTo != null && replyingTo.isNotEmpty)
                'question': replyingTo,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) return GeneratedStep.vacio;

      final cuerpo = jsonDecode(response.body);
      if (cuerpo is! Map || cuerpo['generated'] != true) {
        return GeneratedStep.vacio;
      }

      final permitidas = candidates.toSet();
      final opciones = [
        for (final o in (cuerpo['options'] as List? ?? const []))
          if (o is String && permitidas.contains(o)) o,
      ];
      if (opciones.isEmpty) return GeneratedStep.vacio;

      return GeneratedStep(
        question: (cuerpo['question'] as String? ?? '').trim(),
        options: opciones,
      );
    } catch (_) {
      return GeneratedStep.vacio;
    }
  }
}
