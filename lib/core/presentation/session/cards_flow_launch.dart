import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';

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
  standaloneDeclaration,

  /// B. Dentro del chat, sin turno oyente al que responder: abre ella.
  conversationInitiative,

  /// C. Dentro del chat, respondiendo a un turno oyente concreto.
  conversationReply;

  bool get servesConversation => this != CardsFlowPurpose.standaloneDeclaration;

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
  final String? conversationId;
  final String? hearingTurnId;
  final String? hearingText;
  final SpeechAct hearingSpeechAct;
  final ContextSuggestion? suggestion;
  final String? activeContextId;

  const CardsFlowLaunch({
    required this.purpose,
    this.conversationId,
    this.hearingTurnId,
    this.hearingText,
    this.hearingSpeechAct = SpeechAct.statement,
    this.suggestion,
    this.activeContextId,
  });

  /// Modo A: declaración propia, sin nada del chat.
  const CardsFlowLaunch.standalone()
      : purpose = CardsFlowPurpose.standaloneDeclaration,
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
  }) : purpose = CardsFlowPurpose.conversationReply;

  /// El contexto que se propone al abrir. En A no se propone ninguno: lo
  /// elige la persona.
  String? get proposedContextId => purpose ==
          CardsFlowPurpose.standaloneDeclaration
      ? null
      : (suggestion?.contextId ?? activeContextId);

  /// Dos lanzamientos son el mismo encargo si apuntan al mismo turno del mismo
  /// chat con el mismo propósito. Sirve para decidir si hay que descartar un
  /// borrador al cambiar de modo.
  bool sameErrand(CardsFlowLaunch other) =>
      purpose == other.purpose &&
      conversationId == other.conversationId &&
      hearingTurnId == other.hearingTurnId;

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
