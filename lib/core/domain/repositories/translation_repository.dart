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
  });
}
