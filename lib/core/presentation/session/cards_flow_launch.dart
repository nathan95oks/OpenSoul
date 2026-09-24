import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';
import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';

/// Qué se está haciendo con el mensaje.
///
/// Distinto del propósito de abrir las tarjetas y distinto de [SpeechAct],
/// que clasifica lo que **dijo el oyente**. Este describe lo que va a decir la
/// persona sorda, y decide cómo se redacta: una solicitud se escribe como
/// solicitud y una pregunta como pregunta. «Ventanilla» no autoriza a
/// convertirlo todo en «Denuncio…».
enum CommunicativeAct {
  statement,
  question,
  request,
  answer,
  instructionReceived;

  /// El `speechAct` que viaja al backend en el contrato.
  String get wireName => switch (this) {
        CommunicativeAct.statement => 'statement',
        CommunicativeAct.question => 'question',
        CommunicativeAct.request => 'request',
        CommunicativeAct.answer => 'reply',
        CommunicativeAct.instructionReceived => 'instruction',
      };
}

/// Para qué se abrió el módulo LSB → texto/audio.
///
/// Antes esto se deducía de dos señales indirectas —la pestaña abierta y si
/// había una pregunta pendiente en el chat— y las tres situaciones reales se
/// confundían entre sí: entrar a declarar por tu cuenta con un chat guardado
/// detrás mostraba la última frase del oyente como si fuera una pregunta de
/// esta pantalla, y abrir el chat uno mismo para empezar se anunciaba como
/// "responder". El propósito es dato del lanzamiento, no algo a inferir.
enum CardsFlowPurpose {
  /// A. La persona sorda entra al módulo por la pestaña, fuera del chat.
  ///
  /// Se llamaba `standaloneIntervention`, y el nombre arrastraba: una
  /// intervención independiente también puede ser una **pregunta** —es lo que
  /// hace Consultas en modo personal—. El propósito dice de dónde viene el
  /// turno; el acto comunicativo, qué se está haciendo. Son cosas distintas.
  standaloneIntervention,

  /// B. Dentro del chat, sin turno oyente al que responder: abre ella.
  conversationInitiative,

  /// C. Dentro del chat, respondiendo a un turno oyente concreto.
  conversationReply;

  bool get servesConversation =>
      this != CardsFlowPurpose.standaloneIntervention;

  /// Si el resultado debe enlazarse a un turno anterior del oyente.
  bool get linksToHearingTurn => this == CardsFlowPurpose.conversationReply;
}

/// El encargo con el que se abrió el módulo de tarjetas.
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
  });

  /// Modo A: intervención propia, sin nada del chat.
  const CardsFlowLaunch.standalone({
    this.intendedAct = CommunicativeAct.statement,
    this.need,
    this.intentId,
    this.institutionProfileId,
  })  : purpose = CardsFlowPurpose.standaloneIntervention,
        conversationId = null,
        hearingTurnId = null,
        hearingText = null,
        hearingSpeechAct = SpeechAct.statement,
        suggestion = null,
        activeContextId = null;

  /// Modo B: la persona sorda abre el turno dentro del chat.
  const CardsFlowLaunch.initiative({
    required String this.conversationId,
    this.activeContextId,
    this.intendedAct = CommunicativeAct.statement,
    this.need,
    this.intentId,
    this.institutionProfileId,
  })  : purpose = CardsFlowPurpose.conversationInitiative,
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
  })  : purpose = CardsFlowPurpose.conversationReply,
        // Responder es responder, sea cual sea el acto del turno entrante.
        intendedAct = CommunicativeAct.answer;

  /// El contexto que se propone al abrir. En A no se propone ninguno: lo
  /// elige la persona.
  String? get proposedContextId => purpose ==
          CardsFlowPurpose.standaloneIntervention
      ? null
      : (suggestion?.contextId ?? activeContextId);

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
  }) =>
      CardsFlowLaunch(
        purpose: purpose,
        intendedAct: intendedAct ?? this.intendedAct,
        need: need ?? this.need,
        intentId: intentId ?? this.intentId,
        institutionProfileId:
            institutionProfileId ?? this.institutionProfileId,
        conversationId: conversationId,
        hearingTurnId: hearingTurnId,
        hearingText: hearingText,
        hearingSpeechAct: hearingSpeechAct,
        suggestion: suggestion,
        activeContextId: activeContextId,
      );

  @override
  String toString() => 'CardsFlowLaunch(${purpose.name}, '
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
