import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/network/endpoint_uri.dart';

/// Ruteo de conversación con el Bedrock de LSB→Texto/Audio (`action: route`).
///
/// No traduce el turno del oyente: recibe su [SemanticTurn] (lo que ya
/// entregó Audio/Texto→LSB) y las rutas reales candidatas, y devuelve la que
/// el modelo elige. Cualquier fallo —sin conexión, sin endpoint, respuesta
/// rara— devuelve `null` y queda la ruta determinista.
class RemoteGraphRouteDataSource implements GraphRouteModel {
  static const String _envUrl = String.fromEnvironment('LSB_API_URL');
  static const Duration requestTimeout = Duration(seconds: 6);

  final http.Client client;
  final String apiUrl;
  final ConversationGraphCatalog catalog;

  RemoteGraphRouteDataSource({
    required this.client,
    required this.catalog,
    this.apiUrl = _envUrl,
  });

  static final QuestionBank _lambdaBank = QuestionBank.generated();

  static bool _knownByLambda(ConversationRoute c) =>
      (c.targetContextId == null ||
          _lambdaBank.journey(c.targetContextId!) != null) &&
      c.targetQuestionIds.every((q) => _lambdaBank.question(q) != null);

  bool get isConfigured {
    final uri = Uri.tryParse(apiUrl);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  @override
  Future<ConversationRoute?> rank({
    required SemanticTurn turn,
    required List<ConversationRoute> candidates,
    String? activeContextId,
  }) async {
    // La Lambda valida cada candidata contra SU banco (el generado). Los
    // trámites del RAG viven solo en la app: una candidata suya hacía que
    // la Lambda rechazara todo el pedido (400) y el desempate se perdía.
    final enLaLambda = [
      for (final c in candidates)
        if (_knownByLambda(c)) c,
    ];
    if (!isConfigured || enLaLambda.isEmpty) return null;
    candidates = enLaLambda;
    try {
      final response = await client
          .post(
            requireAbsoluteUrl(apiUrl, 'LSB_API_URL'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': 'route',
              'routerVersion': ConversationGraphRouter.version,
              'semanticTurn': turn.toJson(),
              'activeContextId': ?activeContextId,
              'candidates': [
                for (final c in candidates) {...c.toJson(), 'label': _label(c)},
              ],
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map || body['generated'] != true) return null;
      return ConversationRoute.fromModelJson(Map<String, dynamic>.from(body));
    } catch (_) {
      return null;
    }
  }

  /// Descripción legible de la candidata para el prompt. Es solo contexto:
  /// el servidor y el validador deciden con los identificadores.
  String _label(ConversationRoute c) {
    final family = c.targetFamilyId == null
        ? null
        : catalog.family(c.targetFamilyId!)?.name;
    final context = c.targetContextId == null
        ? null
        : catalog.context(c.targetContextId!)?.name;
    final questions = [
      for (final id in c.targetQuestionIds)
        catalog.bank.question(id)?.formulation ?? id,
    ];
    return switch (c.type) {
      ConversationRouteType.contextSelector =>
        'Elegir de qué trata la atención (selector de contextos)',
      ConversationRouteType.noSafeRoute => 'Ninguna respuesta guiada',
      ConversationRouteType.directContext => 'Abrir ${context ?? family ?? ''}',
      _ => 'Responder: ${questions.join(' / ')} (${context ?? ''})',
    };
  }
}
