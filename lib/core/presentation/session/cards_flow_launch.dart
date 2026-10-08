import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';
import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/session/cards_flow_purpose.dart';

export 'package:lsb_legal_app/core/domain/session/cards_flow_purpose.dart';

/// El encargo con el que se abrió el módulo de tarjetas.
///
/// Con propósito de conversación es la solicitud de respuesta de
/// Conversation (`ConversationReplyRequest`): hilo, turno de origen, texto
/// congelado y [route], la parte del grafo que se abre para responder. La
/// vuelta es un `ConversationReplyResult` al mismo hilo y turno.
///
/// Es inmutable a propósito: el `hearingTurnId` se congela al abrir, así que
/// si llega otro turno del oyente mientras la persona sorda arma su respuesta,
/// esa respuesta sigue enlazada a la pregunta que estaba leyendo y no a la que
/// entró después. Lo mismo con [hearingText]: es el texto exacto que se le
/// mostró, no una relectura del estado vivo del chat.
class CardsFlowLaunch {
  final CardsFlowPurpose purpose;

  /// Qué se está haciendo: declarar, preguntar, pedir, responder o acusar
  /// recibo de una instrucción. Va aparte del propósito porque una
  /// intervención independiente puede ser perfectamente una pregunta.
  final CommunicativeAct intendedAct;

  /// Necesidad elegida en el modo personal, si se eligió.
  final NeedId? need;

  /// Intención concreta del banco, cuando ya se conoce.
  final String? intentId;

  /// Institución que atiende. Ordena prioridades; **no es contenido**: nada
  /// de lo que diga el perfil entra en la declaración de nadie.
  final String? institutionProfileId;

  final String? conversationId;
  final String? hearingTurnId;
  final String? hearingText;
  final SpeechAct hearingSpeechAct;
  final ContextSuggestion? suggestion;
  final String? activeContextId;

  /// Qué parte del grafo se abre para responder, validada. Solo existe en
  /// los modos de conversación y es derivada del turno: no forma parte de
  /// la identidad del encargo ([sameErrand]).
  final ConversationRoute? route;

  const CardsFlowLaunch({
    required this.purpose,
    this.intendedAct = CommunicativeAct.statement,
    this.need,
    this.intentId,
    this.institutionProfileId,
    this.conversationId,
    this.hearingTurnId,
    this.hearingText,
    this.hearingSpeechAct = SpeechAct.statement,
    this.suggestion,
    this.activeContextId,
    this.route,
  });

  /// Modo A: intervención propia, sin nada del chat.
  const CardsFlowLaunch.standalone({
    this.intendedAct = CommunicativeAct.statement,
    this.need,
    this.intentId,
    this.institutionProfileId,
  }) : purpose = CardsFlowPurpose.standaloneIntervention,
       conversationId = null,
       hearingTurnId = null,
       hearingText = null,
       hearingSpeechAct = SpeechAct.statement,
       suggestion = null,
       activeContextId = null,
       route = null;

  /// Modo B: la persona sorda abre el turno dentro del chat.
  const CardsFlowLaunch.initiative({
    required String this.conversationId,
    this.activeContextId,
    this.intendedAct = CommunicativeAct.statement,
    this.need,
    this.intentId,
    this.institutionProfileId,
    this.route,
  }) : purpose = CardsFlowPurpose.conversationInitiative,
       hearingTurnId = null,
       hearingText = null,
       hearingSpeechAct = SpeechAct.statement,
       suggestion = null;

  /// Modo C: respuesta a un turno oyente concreto, congelado al abrir.
  const CardsFlowLaunch.reply({
    required String this.conversationId,
    required String this.hearingTurnId,
    required String this.hearingText,
    this.hearingSpeechAct = SpeechAct.statement,
    this.suggestion,
    this.activeContextId,
    this.need,
    this.intentId,
    this.institutionProfileId,
    this.route,
  }) : purpose = CardsFlowPurpose.conversationReply,
       // Responder es responder, sea cual sea el acto del turno entrante.
       intendedAct = CommunicativeAct.answer;

  /// El contexto que se propone al abrir. En A no se propone ninguno: lo
  /// elige la persona. Con ruta, manda la ruta: `null` abre el selector.
  String? get proposedContextId {
    if (purpose == CardsFlowPurpose.standaloneIntervention) return null;
    final route = this.route;
    if (route != null) return route.targetContextId;
    return suggestion?.contextId ?? activeContextId;
  }

  /// Familia que el selector abre desplegada: la ruta nombró una familia
  /// con varios contextos («¿Quiere denunciar algo?»).
  String? get focusedFamilyId {
    final route = this.route;
    if (route == null || route.targetContextId != null) return null;
    return route.type == ConversationRouteType.directContext
        ? route.targetFamilyId
        : null;
  }

  /// Al terminar, la respuesta vuelve al hilo de Conversation en vez de
  /// quedarse en la pantalla de resultado.
  bool get returnToConversation => purpose.servesConversation;

  /// Dos lanzamientos son el mismo encargo si apuntan al mismo turno del mismo
  /// chat con el mismo propósito. Sirve para decidir si hay que descartar un
  /// borrador al cambiar de modo.
  bool sameErrand(CardsFlowLaunch other) =>
      purpose == other.purpose &&
      conversationId == other.conversationId &&
      hearingTurnId == other.hearingTurnId &&
      need == other.need &&
      intentId == other.intentId;

  CardsFlowLaunch withBusiness({
    NeedId? need,
    String? intentId,
    String? institutionProfileId,
    CommunicativeAct? intendedAct,
  }) => CardsFlowLaunch(
    purpose: purpose,
    intendedAct: intendedAct ?? this.intendedAct,
    need: need ?? this.need,
    intentId: intentId ?? this.intentId,
    institutionProfileId: institutionProfileId ?? this.institutionProfileId,
    conversationId: conversationId,
    hearingTurnId: hearingTurnId,
    hearingText: hearingText,
    hearingSpeechAct: hearingSpeechAct,
    suggestion: suggestion,
    activeContextId: activeContextId,
    route: route,
  );

  @override
  String toString() =>
      'CardsFlowLaunch(${purpose.name}, '
      'conversation: $conversationId, hearingTurn: $hearingTurnId)';
}

class CardsFlowLaunchNotifier extends Notifier<CardsFlowLaunch> {
  @override
  CardsFlowLaunch build() => const CardsFlowLaunch.standalone();

  void start(CardsFlowLaunch launch) => state = launch;
}

final cardsFlowLaunchProvider =
    NotifierProvider<CardsFlowLaunchNotifier, CardsFlowLaunch>(
      CardsFlowLaunchNotifier.new,
    );
