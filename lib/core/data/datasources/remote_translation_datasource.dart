import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lsb_legal_app/core/network/endpoint_uri.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/data/datasources/backend_capability.dart';

abstract class RemoteTranslationDataSource {
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
  });
}

class RemoteTranslationDataSourceImpl implements RemoteTranslationDataSource {
  static const String defaultApiGatewayUrl =
      String.fromEnvironment('LSB_API_URL');

  static const Duration requestTimeout = Duration(seconds: 12);

  final http.Client client;
  final String apiGatewayUrl;

  RemoteTranslationDataSourceImpl({
    required this.client,
    this.apiGatewayUrl = defaultApiGatewayUrl,
  });

  /// Versión del contrato con el backend. La versión 2 añade la
  /// representación estructurada (`declaration`), el acto comunicativo y el
  /// turno al que se responde; el backend que no la reconozca puede seguir
  /// usando `context`/`cards` como antes (compatibilidad hacia atrás).
  static const int contractVersion = 4;

  /// Lo que se supo del servidor en la última respuesta.
  ///
  /// Estático a propósito: la compuerta tiene que poder consultarse antes de
  /// enviar, desde la pantalla, sin haber hecho ya la petición.
  static BackendCapability lastKnownCapability = BackendCapability.unknown;

  /// El cuerpo exacto que viaja al backend.
  ///
  /// Vive aparte del envío para que las pruebas puedan capturarlo y pasarlo
  /// por el handler Python de verdad. Probar el backend con un JSON escrito a
  /// mano no demuestra nada sobre lo que el cliente manda: los dos fallos de
  /// nombres (`actorRole` frente a `actor_role`) y de puerta por contexto
  /// sobrevivieron precisamente porque cada lado se probaba con su formato.
  static Map<String, dynamic> buildRequestBody({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
    Map<String, dynamic>? guided,
  }) =>
      {
        'context': context,
        'cards': cards,
        'language': 'es-BO',
        'institutionType': 'entidad_publica',
        'contractVersion': contractVersion,
        ...?business?.toJson(),
        // ignore: use_null_aware_elements
        if (speechAct != null) 'speechAct': speechAct,
        // ignore: use_null_aware_elements
        if (replyToId != null) 'replyToId': replyToId,
        // ignore: use_null_aware_elements
        if (declaration != null) 'declaration': declaration,
        // Contrato v4. Las respuestas tipadas son contenido autoritativo: el
        // backend las redacta con el mismo banco que el cliente.
        // ignore: use_null_aware_elements
        if (guided != null) 'guided': guided,
      };

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
  }) async {
    final uri = requireAbsoluteUrl(apiGatewayUrl, 'LSB_API_URL');

    final response = await client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(buildRequestBody(
            context: context,
            cards: cards,
            declaration: declaration,
            speechAct: speechAct,
            replyToId: replyToId,
            business: business,
          )),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      // Se recuerda qué sabe conservar el servidor. Un backend anterior
      // acepta la petición y pierde el segundo hecho sin decir nada, así que
      // «no devolvió error» no basta para darlo por compatible.
      lastKnownCapability = BackendCompatibility.fromResponse(data);

      List<Map<String, dynamic>>? glossSeq;
      if (data['glossSequence'] != null) {
        glossSeq = (data['glossSequence'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      Map<String, dynamic>? intermediateRepr;
      if (data['intermediateRepresentation'] != null) {
        intermediateRepr =
            Map<String, dynamic>.from(data['intermediateRepresentation'] as Map);
      }

      return TranslationResult(
        baseSentence: data['baseSentence'] ?? data['generatedText'] ?? '',
        generatedText: data['generatedText'] ?? '',
        audioUrl: data['audioUrl'],
        cacheHit: data['cacheHit'] ?? false,
        bedrockUsed: data['bedrockUsed'] ?? false,
        coverageValidated: data['coverageValidated'] ?? false,
        intermediateRepresentation: intermediateRepr,
        glossSequence: glossSeq,
      );
    } else {
      throw Exception('Error del Backend AWS: ${response.statusCode}');
    }
  }
}
