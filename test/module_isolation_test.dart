import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/app/surface_session.dart';
import 'package:lsb_legal_app/core/presentation/session/flow_surface.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_flow_session.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

/// Aislamiento entre la conversación y los módulos autónomos.
///
/// La conversación es la unión de los dos módulos de traducción, pero cada
/// uno sigue existiendo por su cuenta como herramienta suelta. Que compartan
/// el mismo `ProviderScope` no puede significar que compartan sesión: quien
/// abre "Tarjetas LSB" o "Voz a LSB" desde la barra inferior debe encontrarlos
/// **como si nunca los hubiera tocado**, aunque acabe de usarlos dentro de una
/// conversación.
///
/// Sin esta frontera, la respuesta a medias de un turno reaparece en el módulo
/// autónomo y —peor— la pregunta del oyente enruta un flujo que no responde a
/// nadie.
class _StubSignRepository implements AudioTranslationRepository {
  @override
  Future<LsbTranslation> translateText(String text, {String? situation}) async {
    return LsbTranslation(
      glosses: const ['TU', 'CELULAR', 'ROBAR'],
      animationUrl: '',
      animationUrls: const ['https://s3/ROBAR.glb'],
    );
  }
}

class _StubDeclarationRepository implements TranslationRepository {
  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  }) async =>
      TranslationResult(
        baseSentence: 'Me robaron el celular.',
        generatedText: 'Me robaron el celular.',
      );
}

ProviderContainer _appContainer() {
  final container = ProviderContainer(
    overrides: [
      lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
      audioTranslationRepositoryProvider
          .overrideWithValue(_StubSignRepository()),
      translationRepositoryProvider
          .overrideWithValue(_StubDeclarationRepository()),
      audioOutputProvider.overrideWithValue(FakeAudioOutput()),
      // Misma composición que `main.dart`: es la app real la que se audita.
      ...conversationOverrides(),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Deja la conversación con una pregunta del oyente sin responder y una
/// respuesta a medio construir — el estado más contaminante posible.
Future<void> _conversationInProgress(ProviderContainer c) async {
  await c.read(lexiconEntriesProvider.future);
  await c
      .read(conversationProvider.notifier)
      .sendHearingMessage('¿Le robaron su celular?');
  c.read(contextProvider.notifier).setContext(contextById('denuncia_robo')!);
  c.read(sentenceProvider.notifier).setWords(['CELULAR', 'ROBAR']);
}

/// Cede el turno al event loop para que los `Notifier` asíncronos
/// (el controlador del avatar) apliquen su estado.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('la pestaña de tarjetas se abre limpia', () {
    test('no arrastra la respuesta a medias de la conversación', () async {
      final container = _appContainer();
      await _conversationInProgress(container);

      // Estado contaminado antes de salir de la conversación.
      expect(container.read(sentenceProvider), isNotEmpty);
      expect(container.read(contextProvider), isNotNull);

      await container
          .read(surfaceSessionProvider)
          .enter(FlowSurface.standaloneCards);

      expect(container.read(sentenceProvider), isEmpty,
          reason: 'La declaración a medias de la conversación reaparece en el '
              'módulo autónomo.');
      expect(container.read(contextProvider), isNull,
          reason: 'El módulo autónomo debe volver a preguntar el contexto.');
      expect(container.read(semanticZonesProvider).activeZoneId, isNull);
      expect(container.read(translationControllerProvider).value, isNull);
    });

    test('no hereda la pregunta del oyente', () async {
      final container = _appContainer();
      await _conversationInProgress(container);

      // Dentro de la conversación, la pregunta sí guía el flujo.
      expect(container.read(pendingReplyProvider), isNotNull);

      await container
          .read(surfaceSessionProvider)
          .enter(FlowSurface.standaloneCards);

      expect(container.read(pendingReplyProvider), isNull,
          reason: 'En uso autónomo el flujo no responde a nadie: mostrar la '
              'pregunta del oyente enruta un recorrido que nadie pidió.');
    });

    test('la conversación conserva su historial intacto', () async {
      final container = _appContainer();
      await _conversationInProgress(container);

      await container
          .read(surfaceSessionProvider)
          .enter(FlowSurface.standaloneCards);

      // Limpiar el módulo autónomo no puede borrar lo ya conversado.
      final conversation = container.read(conversationProvider).conversation;
      expect(conversation.turns, hasLength(1));
      expect(conversation.pendingReply, isNotNull);
    });
  });

  group('la fuga tampoco ocurre al revés', () {
    test('lo construido en la pestaña autónoma no llega a la conversación',
        () async {
      final container = _appContainer();
      await _conversationInProgress(container);

      await container
          .read(surfaceSessionProvider)
          .enter(FlowSurface.standaloneCards);
      // Trabajo hecho como herramienta suelta, ajeno al diálogo.
      container.read(contextProvider.notifier).setContext(contextById('otro')!);
      container.read(sentenceProvider.notifier).setWords(['HOMBRE', 'PEGAR']);

      await container
          .read(surfaceSessionProvider)
          .enter(FlowSurface.conversation);

      expect(container.read(sentenceProvider), isEmpty,
          reason: 'Una declaración construida fuera del diálogo no puede '
              'reaparecer como respuesta de un turno.');
      expect(container.read(contextProvider), isNull);
    });
  });

  group('la pestaña del avatar se abre limpia', () {
    test('descarta la traducción anterior', () async {
      final container = _appContainer();
      final avatar = container.read(audioTranslationControllerProvider.notifier);

      avatar.processText('Yo llamo al policía');
      await _settle();
      expect(container.read(audioTranslationControllerProvider).recognizedText,
          isNotEmpty);

      await container
          .read(surfaceSessionProvider)
          .enter(FlowSurface.standaloneAvatar);

      final state = container.read(audioTranslationControllerProvider);
      expect(state.status, AudioTranslationStatus.idle);
      expect(state.recognizedText, isNull);
      expect(state.translationResult, isNull);
    });
  });

  group('volver a la conversación la reanuda donde estaba', () {
    test('la pregunta pendiente vuelve a guiar el flujo de tarjetas', () async {
      final container = _appContainer();
      await _conversationInProgress(container);

      await container
          .read(surfaceSessionProvider)
          .enter(FlowSurface.standaloneCards);
      expect(container.read(pendingReplyProvider), isNull);

      await container
          .read(surfaceSessionProvider)
          .enter(FlowSurface.conversation);

      final pending = container.read(pendingReplyProvider);
      expect(pending, isNotNull);
      expect(pending!.question, '¿Le robaron su celular?');
    });
  });

  group('sin conversación, entrar al módulo autónomo no rompe nada', () {
    test('resetear un flujo ya vacío es inocuo', () async {
      final container = ProviderContainer(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(cardsFlowSessionProvider).reset(),
        completes,
      );
      expect(container.read(sentenceProvider), isEmpty);
      expect(container.read(pendingReplyProvider), isNull);
    });
  });
}
