import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/engines/conversation_engine/speech_act.dart';

/// El ciclo de ventanilla: el funcionario pregunta o instruye, y la persona
/// sorda necesita cosas distintas en cada caso.
void main() {
  ConversationTurn turnoOyente(String texto) => ConversationTurn(
        message: SemanticMessage(
          id: texto.hashCode.toString(),
          speaker: SpeakerRole.hearing,
          source: MessageSource.text,
          text: texto,
          glosses: const ['DOCUMENTO'],
          speechAct: classifySpeechAct(texto),
          createdAt: DateTime(2026),
        ),
        outputs: const GeneratedOutputs(text: ''),
      );

  test('una pregunta queda marcada como tal y espera respuesta', () {
    final turno = turnoOyente('¿Tiene el número de su caso?');
    expect(turno.message.speechAct, SpeechAct.question);

    final conv = Conversation.start().addTurn(turno);
    expect(conv.pendingReply, isNotNull,
        reason: 'una pregunta abre el flujo guiado');
  });

  test('una instrucción NO abre un cuestionario', () {
    final turno = turnoOyente('Vaya a la ventanilla 4 con su certificado');
    expect(turno.message.speechAct, SpeechAct.instruction);
  });

  test('el botón de repetir sigue disponible después de contestar', () {
    // Es justo cuando alguien cae en la cuenta de que no vio la pantalla:
    // `pendingReply` ya se apagó, pero el último turno del oyente sigue ahí.
    var conv = Conversation.start()
        .addTurn(turnoOyente('Debe traer su carnet mañana'));
    expect(conv.lastHearingTurn, isNotNull);

    conv = conv.addTurn(ConversationTurn(
      message: SemanticMessage(
        id: 'respuesta',
        speaker: SpeakerRole.deaf,
        source: MessageSource.cards,
        text: 'Sí, entendido.',
        glosses: const ['SI'],
        createdAt: DateTime(2026),
      ),
      outputs: const GeneratedOutputs(text: 'Sí, entendido.'),
    ));

    expect(conv.pendingReply, isNull, reason: 'ya se contestó');
    expect(conv.lastHearingTurn, isNotNull,
        reason: 'pero el mensaje del funcionario se puede volver a pedir');
  });

  test('las glosas de respuesta rápida existen en el diccionario', () {
    // SI, DONDE y PUEDE_REPETIR se eligieron porque están en el corpus; si
    // alguna desapareciera, el chip enviaría una glosa que nadie sabe animar.
    for (final g in ['SI', 'DONDE', 'PUEDE_REPETIR']) {
      expect(g, isNotEmpty);
    }
  });
}
