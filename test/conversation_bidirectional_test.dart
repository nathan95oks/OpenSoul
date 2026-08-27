import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';

import 'helpers/official_dictionary.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

/// Pruebas del ciclo conversacional completo (Fase 4).
///
/// Lo que se audita aquí no es una traducción aislada, sino que **un turno
/// condicione al siguiente**: que la frase de la persona oyente proponga un
/// contexto para responder, que el contexto confirmado por la persona sorda
/// vuelva al motor remoto, y que los turnos queden enlazados entre sí. Es la
/// diferencia entre dos módulos que comparten pantalla y una conversación.

/// Registra el contexto situacional con el que se le llamó, para poder
/// afirmar que el contexto realmente viaja al backend.
class _SpySignRepository implements AudioTranslationRepository {
  final List<String?> receivedSituations = [];
  final Map<String, List<String>> glossesByText;
  final List<SemanticDisambiguation> disambiguations;

  _SpySignRepository({
    this.glossesByText = const {},
    this.disambiguations = const [],
  });

  @override
  Future<LsbTranslation> translateText(String text, {String? situation}) async {
    receivedSituations.add(situation);
    return LsbTranslation(
      glosses: glossesByText[text] ?? const [],
      animationUrl: '',
      animationUrls: const ['https://s3/ROBAR.glb'],
      disambiguations: disambiguations,
    );
  }
}

/// Declaración remota fija: el sentido sordo→oyente ya está cubierto por
/// otras pruebas, aquí solo importa que produzca un turno.
class _StubDeclarationRepository implements TranslationRepository {
  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  }) async =>
      TranslationResult(
        baseSentence: 'Ayer un hombre me robó el celular.',
        generatedText: 'Ayer un hombre me robó el celular.',
        audioUrl: 'https://polly/audio.mp3',
        bedrockUsed: true,
      );
}

ProviderContainer _containerWith(_SpySignRepository sign) {
  final container = ProviderContainer(
    overrides: [
      lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
      audioTranslationRepositoryProvider.overrideWithValue(sign),
      translationRepositoryProvider
          .overrideWithValue(_StubDeclarationRepository()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('el turno del oyente propone un contexto para responder', () async {
    final sign = _SpySignRepository(
      glossesByText: {'¿Le robaron su celular?': ['TU', 'CELULAR', 'ROBAR']},
    );
    final container = _containerWith(sign);
    // La inferencia se construye sobre el diccionario: hay que esperarlo.
    await container.read(lexiconEntriesProvider.future);

    await container
        .read(conversationProvider.notifier)
        .sendHearingMessage('¿Le robaron su celular?');

    final conversation = container.read(conversationProvider).conversation;
    final suggestion = conversation.lastHearingTurn?.message.contextSuggestion;

    expect(suggestion, isNotNull);
    expect(suggestion!.contextId, 'denuncia_robo');
    expect(suggestion.evidence, contains('ROBAR'));
    // La sugerencia NO es un contexto confirmado.
    expect(conversation.activeContextId, isNull);
    // Y es la que el flujo de tarjetas usará como preselección.
    expect(conversation.suggestedReplyContextId, 'denuncia_robo');
  });

  test('el contexto confirmado por la persona sorda vuelve al motor remoto',
      () async {
    final sign = _SpySignRepository(
      glossesByText: {'¿Le robaron su celular?': ['ROBAR']},
    );
    final container = _containerWith(sign);
    await container.read(lexiconEntriesProvider.future);
    final notifier = container.read(conversationProvider.notifier);

    // 1. Turno del oyente: todavía no hay contexto que enviar.
    await notifier.sendHearingMessage('¿Le robaron su celular?');
    expect(sign.receivedSituations, [null]);

    // 2. La persona sorda confirma el contexto y declara.
    notifier.addDeafDeclaration(
      result: await _StubDeclarationRepository()
          .translateCards(context: 'denuncia_robo', cards: const []),
      glosses: const ['AYER', 'HOMBRE', 'CELULAR', 'ROBAR'],
      contextId: 'denuncia_robo',
    );

    // 3. Segundo turno del oyente: ahora el contexto sí viaja al backend.
    await notifier.sendHearingMessage('¿Recuerda la hora?');
    expect(sign.receivedSituations, [null, 'denuncia_robo']);
  });

  test('los turnos quedan enlazados en ambos sentidos', () async {
    final sign = _SpySignRepository(
      glossesByText: {'¿Le robaron su celular?': ['ROBAR']},
    );
    final container = _containerWith(sign);
    await container.read(lexiconEntriesProvider.future);
    final notifier = container.read(conversationProvider.notifier);

    await notifier.sendHearingMessage('¿Le robaron su celular?');
    final hearingId = container
        .read(conversationProvider)
        .conversation
        .lastHearingTurn!
        .message
        .id;

    notifier.addDeafDeclaration(
      result: await _StubDeclarationRepository()
          .translateCards(context: 'denuncia_robo', cards: const []),
      glosses: const ['ROBAR'],
      contextId: 'denuncia_robo',
    );

    final turns = container.read(conversationProvider).conversation.turns;
    expect(turns, hasLength(2));
    // La declaración responde a la pregunta del oyente.
    expect(turns.last.message.replyToId, hearingId);
    expect(turns.last.message.contextId, 'denuncia_robo');

    // Y ya no queda ninguna pregunta pendiente de responder.
    expect(
      container.read(conversationProvider).conversation.pendingReply,
      isNull,
    );
  });

  test('la desambiguación del backend se conserva en el mensaje', () async {
    final sign = _SpySignRepository(
      glossesByText: {'Yo llamo al policía': ['YO', 'POLICIA', 'LLAMAR']},
      disambiguations: const [
        SemanticDisambiguation(
          original: 'llama',
          meaning: 'convocar',
          reason: 'Contexto jurídico: citar a una autoridad.',
        ),
      ],
    );
    final container = _containerWith(sign);
    await container.read(lexiconEntriesProvider.future);

    await container
        .read(conversationProvider.notifier)
        .sendHearingMessage('Yo llamo al policía');

    final message = container
        .read(conversationProvider)
        .conversation
        .lastHearingTurn!
        .message;

    expect(message.disambiguations, hasLength(1));
    expect(message.disambiguations.first.meaning, 'convocar');
  });

  test('sin evidencia suficiente no se propone ningún contexto', () async {
    final sign = _SpySignRepository(
      glossesByText: {'Buenos días, tome asiento': const []},
    );
    final container = _containerWith(sign);
    await container.read(lexiconEntriesProvider.future);

    await container
        .read(conversationProvider.notifier)
        .sendHearingMessage('Buenos días, tome asiento');

    final conversation = container.read(conversationProvider).conversation;
    expect(conversation.lastHearingTurn?.message.contextSuggestion, isNull);
    // La persona sorda elegirá el contexto como siempre.
    expect(conversation.suggestedReplyContextId, isNull);
  });
}
