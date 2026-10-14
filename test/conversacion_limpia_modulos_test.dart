import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/app/surface_session.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/presentation/session/flow_surface.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_handoff.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Al responder desde Conversación, Tarjetas LSB y Voz a LSB se limpian: la
/// pregunta recomendada se abre directo, sin la última oración formal que el
/// módulo mostró antes.
class _Voz implements AudioTranslationRepository {
  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async => LsbTranslation(
    glosses: const ['TU', 'CELULAR', 'ROBAR'],
    animationUrl: '',
    animationUrls: const ['https://s3/ROBAR.glb'],
    animationGlosses: const ['TU', 'CELULAR', 'ROBAR'],
  );
}

class _Declaracion implements TranslationRepository {
  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
    Map<String, dynamic>? guided,
  }) async => TranslationResult(
    baseSentence: 'Me robaron el celular.',
    generatedText: 'Me robaron el celular.',
  );
}

ProviderContainer _app() {
  final c = ProviderContainer(
    overrides: [
      lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
      audioTranslationRepositoryProvider.overrideWithValue(_Voz()),
      translationRepositoryProvider.overrideWithValue(_Declaracion()),
      audioOutputProvider.overrideWithValue(FakeAudioOutput()),
      ...conversationOverrides(),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Deja los dos módulos autónomos "usados": una oración formal en pantalla en
/// Tarjetas LSB y una voz ya traducida en Voz a LSB.
Future<void> _usarLosDosModulos(ProviderContainer c) async {
  await c.read(lexiconEntriesProvider.future);
  await c.read(surfaceSessionProvider).enter(FlowSurface.standaloneCards);
  c.read(contextProvider.notifier).setContext(contextById('denuncia_robo')!);
  final guiado = c.read(guidedFlowProvider.notifier);
  final primera = c.read(guidedFlowProvider).session!.currentQuestionId!;
  guiado.select(
    primera,
    c.read(questionBankProvider).question(primera)!.options.first.id,
  );
  c.read(sentenceProvider.notifier).setWords(['CELULAR', 'ROBAR']);
  await c
      .read(translationControllerProvider.notifier)
      .translateGuided(
        intervention: guiado.intervention!,
        localText: 'Me robaron el celular.',
        glosses: const ['CELULAR', 'ROBAR'],
        speechAct: 'statement',
      );
  c.read(resultVisibleProvider.notifier).show();

  await c.read(surfaceSessionProvider).enter(FlowSurface.standaloneAvatar);
  c
      .read(audioTranslationControllerProvider.notifier)
      .processText('Me robaron el celular');
  await _settle();
  await _settle();
}

void main() {
  group('responder desde Conversación abre la pregunta, no lo anterior', () {
    test('la última oración formal de Tarjetas LSB ya no aparece', () async {
      final c = _app();
      await _usarLosDosModulos(c);
      expect(c.read(resultVisibleProvider), isTrue, reason: 'precondición');

      await c.read(surfaceSessionProvider).enter(FlowSurface.conversation);
      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');
      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());
      await _settle();

      expect(
        c.read(resultVisibleProvider),
        isFalse,
        reason: 'La oración formal anterior tapaba la pregunta recomendada.',
      );
      expect(c.read(translationControllerProvider).value, isNull);
      expect(c.read(sentenceProvider), isEmpty);
    });

    test('el recorrido arranca limpio en la pregunta recomendada', () async {
      final c = _app();
      await _usarLosDosModulos(c);
      // Respuestas a medias de un uso anterior del mismo contexto.
      final flow = c.read(guidedFlowProvider.notifier);
      final antes = c.read(guidedFlowProvider).session;
      expect(antes, isNotNull, reason: 'precondición: hay un recorrido');
      final primera = antes!.currentQuestionId!;
      final q = c.read(questionBankProvider).question(primera)!;
      flow.select(primera, q.options.first.id);
      expect(c.read(guidedFlowProvider).session!.answers, isNotEmpty);

      await c.read(surfaceSessionProvider).enter(FlowSurface.conversation);
      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');
      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());

      final session = c.read(guidedFlowProvider).session;
      if (session != null) {
        expect(
          session.answers,
          isEmpty,
          reason: 'Lo respondido en otro encargo no se arrastra.',
        );
      }
    });

    test('Voz a LSB también queda limpia', () async {
      final c = _app();
      await _usarLosDosModulos(c);
      expect(
        c.read(audioTranslationControllerProvider).status,
        AudioTranslationStatus.success,
        reason: 'precondición',
      );

      await c.read(surfaceSessionProvider).enter(FlowSurface.conversation);
      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');
      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());

      expect(
        c.read(audioTranslationControllerProvider).status,
        AudioTranslationStatus.idle,
      );
      expect(
        c.read(audioTranslationControllerProvider).translationResult,
        isNull,
      );
    });

    test('volver a abrir el MISMO encargo continúa donde se dejó', () async {
      final c = _app();
      await c.read(lexiconEntriesProvider.future);
      await c.read(surfaceSessionProvider).enter(FlowSurface.conversation);
      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');
      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());
      c.read(sentenceProvider.notifier).setWords(['CELULAR', 'ROBAR']);

      // Vuelve al chat a releer la pregunta y pulsa «Responder» otra vez.
      handoff.handBackToHearing();
      handoff.openCards(handoff.nextDeafLaunch());

      expect(
        c.read(sentenceProvider),
        isNotEmpty,
        reason: 'Mismo turno, mismo encargo: no se borra lo armado.',
      );
    });
  });
}
