import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';

import 'package:lsb_legal_app/core/data/models/conversation_json.dart';

import 'helpers/official_dictionary.dart';

/// Quién abre la conversación no puede cambiar si queda registrada.
///
/// El caso normal es que la persona oyente hable primero y la sorda responda,
/// así que el turno de respuesta se enlaza con la pregunta pendiente. Pero la
/// persona sorda también puede llegar a la ventanilla y hablar ella primero
/// —"vengo a hacer una denuncia"—, y entonces no hay pregunta a la que
/// enlazarse. Ese turno vale exactamente igual y tiene que guardarse.
class _StubDeclaracion implements TranslationRepository {
  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  }) async =>
      TranslationResult(
        baseSentence: 'Quiero hacer una denuncia.',
        generatedText: 'Quiero hacer una denuncia.',
        audioUrl: null,
        bedrockUsed: true,
      );
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        ...conversationOverrides(),
        translationRepositoryProvider.overrideWithValue(_StubDeclaracion()),
        lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
      ],
    );
    addTearDown(container.dispose);
  });

  test('la persona sorda abre la conversación y su turno queda registrado',
      () {
    final conversacion = container.read(conversationProvider).conversation;
    expect(conversacion.turns, isEmpty,
        reason: 'se parte de una conversación vacía');
    expect(conversacion.pendingReply, isNull,
        reason: 'nadie ha preguntado todavía');

    container.read(conversationBridgeProvider).submitDeclaration(
          result: TranslationResult(
            baseSentence: 'Quiero hacer una denuncia.',
            generatedText: 'Quiero hacer una denuncia.',
            audioUrl: null,
            bedrockUsed: true,
          ),
          glosses: const ['YO', 'DENUNCIA', 'QUERER'],
          contextId: 'denuncia_robo',
        );

    final despues = container.read(conversationProvider).conversation;
    expect(despues.turns, hasLength(1),
        reason: 'abrir la conversación sin pregunta previa también cuenta');
    expect(despues.turns.single.outputs.text, 'Quiero hacer una denuncia.');
  });

  test('el turno de apertura no dice responder a ninguna pregunta', () {
    container.read(conversationBridgeProvider).submitDeclaration(
          result: TranslationResult(
            baseSentence: 'Quiero hacer una denuncia.',
            generatedText: 'Quiero hacer una denuncia.',
            audioUrl: null,
            bedrockUsed: true,
          ),
          glosses: const ['YO', 'DENUNCIA', 'QUERER'],
          contextId: 'denuncia_robo',
        );

    final turno = container.read(conversationProvider).conversation.turns.single;
    expect(turno.message.replyToId, isNull);
  });

  test('la conversación sobrevive a guardarla y volver a leerla', () {
    container.read(conversationBridgeProvider).submitDeclaration(
          result: TranslationResult(
            baseSentence: 'Quiero hacer una denuncia.',
            generatedText: 'Quiero hacer una denuncia.',
            audioUrl: null,
            bedrockUsed: true,
          ),
          glosses: const ['YO', 'DENUNCIA', 'QUERER'],
          contextId: 'denuncia_robo',
        );

    final original = container.read(conversationProvider).conversation;
    // Se serializa y se vuelve a leer, que es lo que ocurre cuando Android
    // mata el proceso y la persona vuelve a abrir la aplicacion.
    final revivida = ConversationJson.decode(ConversationJson.encode(original));

    expect(revivida, isNotNull);
    expect(revivida!.turns, hasLength(original.turns.length));
    expect(revivida.turns.single.outputs.text, original.turns.single.outputs.text);
    expect(revivida.turns.single.message.speaker,
        original.turns.single.message.speaker);
    expect(revivida.turns.single.message.glosses,
        original.turns.single.message.glosses);
    expect(revivida.turns.single.message.contextId, 'denuncia_robo');
    expect(revivida.id, original.id);
  });

  test('una conversación guardada corrupta no impide abrir la aplicación', () {
    expect(ConversationJson.decode({'turns': 'esto no es una lista'}), isNull);
    // Un turno ilegible se descarta sin arrastrar al resto.
    final parcial = ConversationJson.decode({
      'id': 'x',
      'startedAt': DateTime.now().toIso8601String(),
      'turns': [
        {'message': 'roto', 'outputs': 'roto'},
      ],
    });
    expect(parcial, isNotNull);
    expect(parcial!.turns, isEmpty);
  });
}
