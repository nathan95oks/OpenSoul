import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

abstract class TranslationRepository {
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    /// Representación estructurada (hechos, personas, objetos, lugar...)
    /// para contextos que ya la producen, como `denuncia_robo`. Contrato
    /// versión 2: preserva relaciones entre entidades que una lista plana
    /// de glosas no puede expresar.
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,

    /// Señales de negocio (contrato versión 3): cómo se está usando la
    /// aplicación, qué institución atiende, qué necesidad e intención se
    /// eligieron. Sirven para desambiguar y ordenar. **No son contenido**: el
    /// generador no puede escribirlas dentro de la declaración de nadie.
    BusinessSignals? business,
  });
}

/// Las dimensiones de negocio que viajan al backend.
class BusinessSignals {
  final String? usageMode;
  final String? institutionProfileId;
  final String? need;
  final String? intentId;
  final String? conversationId;
  final int messageVersion;

  const BusinessSignals({
    this.usageMode,
    this.institutionProfileId,
    this.need,
    this.intentId,
    this.conversationId,
    this.messageVersion = 1,
  });

  Map<String, dynamic> toJson() => {
        if (usageMode != null) 'usageMode': usageMode,
        if (institutionProfileId != null)
          'institutionProfileId': institutionProfileId,
        if (need != null) 'need': need,
        if (intentId != null) 'intentId': intentId,
        if (conversationId != null) 'conversationId': conversationId,
        'messageVersion': messageVersion,
      };
}
