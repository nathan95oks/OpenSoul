import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';
import 'package:lsb_legal_app/core/domain/session/cards_flow_purpose.dart';

/// Qué acto comunicativo es una intervención de la persona sorda: una regla
/// del dominio que usan la emisión guiada y la pantalla de necesidades.
abstract final class CommunicativeActPolicy {
  /// Acto comunicativo **de partida** de cada necesidad.
  ///
  /// Es una propuesta inicial, no una condena: elegir Consultas no convierte
  /// toda intervención en pregunta. Dentro de una consulta caben también
  /// respuestas y declaraciones —«sí, ya traje el papel»—, y el acto se
  /// recalcula por intervención en [forIntervention].
  static CommunicativeAct initialActFor(NeedId need) => switch (need) {
    NeedId.inquiries => CommunicativeAct.question,
    NeedId.complaints => CommunicativeAct.statement,
    NeedId.procedures => CommunicativeAct.statement,
  };

  /// El acto de **esta** intervención concreta.
  ///
  /// Manda el turno: responder a alguien es responder, aunque la necesidad
  /// elegida fuera Consultas. Y dentro de una consulta se puede declarar algo
  /// si las glosas elegidas no preguntan nada.
  static CommunicativeAct forIntervention({
    required CardsFlowPurpose purpose,
    NeedId? need,
    List<String> glosses = const [],
  }) {
    // Responder es responder, venga de donde venga el encargo.
    if (purpose == CardsFlowPurpose.conversationReply) {
      return CommunicativeAct.answer;
    }

    // Una interrogativa explícita hace pregunta cualquier intervención.
    const interrogativas = {
      'DONDE',
      'QUIEN',
      'QUE',
      'CUANDO',
      'COMO',
      'CUAL',
      'CUANTOS',
      'POR_QUE',
      'PARA_QUE',
      'PUEDO',
    };
    final norm = glosses.map((g) => g.toUpperCase()).toSet();
    if (norm.any(interrogativas.contains)) return CommunicativeAct.question;

    // Pedir algo es una solicitud, no una afirmación.
    const solicitudes = {'PEDIR', 'QUERER', 'NECESITAR', 'SOLICITAR'};
    if (norm.any(solicitudes.contains)) return CommunicativeAct.request;

    // Sin señales en las glosas, manda el punto de partida de la necesidad,
    // salvo en Consultas: ahí una intervención sin interrogativa es una
    // declaración dentro de la consulta, no una pregunta forzada.
    if (need == NeedId.inquiries && norm.isNotEmpty) {
      return CommunicativeAct.statement;
    }
    return need == null ? CommunicativeAct.statement : initialActFor(need);
  }
}
