import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/network/endpoint_uri.dart';

/// RAG por significado en la Lambda LSB→Texto/Audio (`action: "consulta"`).
///
/// La app busca primero por palabras, sin red; esto solo se pide cuando eso
/// no encontró nada. Cualquier fallo —sin endpoint, sin red, sin índice,
/// Bedrock caído— es una lista vacía: la conversación sigue como antes.
class RemoteRagDataSource {
  static const String _envUrl = String.fromEnvironment('LSB_API_URL');
  static const Duration requestTimeout = Duration(seconds: 6);

  final http.Client client;
  final String apiUrl;
  final Duration timeout;

  RemoteRagDataSource({
    required this.client,
    this.apiUrl = _envUrl,
    this.timeout = requestTimeout,
  });

  bool get isConfigured {
    final uri = Uri.tryParse(apiUrl);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  Future<List<RagSuggestion>> consult(
    String text, {
    String? preferArea,
    int limit = 4,
  }) async {
    if (!isConfigured || text.trim().isEmpty) return const [];
    try {
      final response = await client
          .post(
            requireAbsoluteUrl(apiUrl, 'LSB_API_URL'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': 'consulta',
              'text': text,
              'preferArea': ?preferArea,
              'limit': limit,
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body);
      if (body is! Map || body['generated'] != true) return const [];
      return [
        for (final raw in (body['suggestions'] as List? ?? const []))
          ?_parse(raw),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Una sugerencia sin texto o sin glosas no se puede ofrecer.
  static RagSuggestion? _parse(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    final glosses = [
      for (final g in (raw['glosses'] as List? ?? const []))
        if (g is String && g.isNotEmpty) g,
    ];
    if (text is! String || text.trim().isEmpty || glosses.isEmpty) {
      return null;
    }
    return RagSuggestion(
      text: text,
      glosses: glosses,
      scenarioId: (raw['scenarioId'] ?? '').toString(),
      institution: (raw['institution'] ?? '').toString(),
      procedure: (raw['procedure'] ?? '').toString(),
      score: (raw['score'] as num?)?.toDouble() ?? 0,
    );
  }
}
