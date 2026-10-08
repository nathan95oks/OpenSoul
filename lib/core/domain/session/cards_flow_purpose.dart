/// Qué hace la persona sorda con su mensaje y para qué se abrió el módulo
/// de tarjetas: conceptos del dominio, que también usan el grafo y el router.
library;

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
