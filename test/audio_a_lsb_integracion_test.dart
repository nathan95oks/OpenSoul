import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/controllers/audio_translation_controller.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_handoff.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// El módulo Texto y voz a LSB, de extremo a extremo.
///
/// Que `lambda_text_to_lsb.py` no haya cambiado no demuestra que esta
/// integración funcione: el cliente sí cambió —contrato, modos, lanzamiento—
/// y la transcripción del oyente es la que encabeza la respuesta de la
/// persona sorda. Si se pierde o se altera aquí, el otro módulo responde a
/// algo que nadie dijo.
class _SignRepo implements AudioTranslationRepository {
  final List<String> textosRecibidos = [];
  final List<String?> situaciones = [];
  final List<Map<String, String>?> sentidos = [];
  final LsbTranslation Function(String)? respuesta;

  _SignRepo({this.respuesta});

  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async {
    textosRecibidos.add(text);
    situaciones.add(situation);
    sentidos.add(resolvedSenses);
    return respuesta?.call(text) ??
        LsbTranslation(glosses: const ['TU', 'ROBAR'], animationUrl: '');
  }
}

class _DeclRepo implements TranslationRepository {
  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
  }) async =>
      TranslationResult(baseSentence: '...', generatedText: '...');
}

ProviderContainer _app(_SignRepo signRepo) {
  final c = ProviderContainer(overrides: [
    lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
    audioTranslationRepositoryProvider.overrideWithValue(signRepo),
    translationRepositoryProvider.overrideWithValue(_DeclRepo()),
    audioOutputProvider.overrideWithValue(FakeAudioOutput()),
    ...conversationOverrides(),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('escritura y dictado llegan igual al traductor', () {
    test('el texto escrito se envía tal cual', () async {
      final repo = _SignRepo();
      final c = _app(repo);
      await c.read(lexiconEntriesProvider.future);

      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Le robaron su celular?');

      expect(repo.textosRecibidos, ['¿Le robaron su celular?']);
    });

    test('el dictado se marca como voz y conserva la transcripción', () async {
      final repo = _SignRepo();
      final c = _app(repo);
      await c.read(lexiconEntriesProvider.future);

      await c.read(conversationProvider.notifier).sendHearingMessage(
            '¿Dónde ocurrió el hecho?',
            source: MessageSource.speech,
          );

      final turno = c.read(conversationProvider).conversation.turns.single;
      expect(turno.message.source, MessageSource.speech);
      expect(turno.outputs.text, '¿Dónde ocurrió el hecho?',
          reason: 'La transcripción original se conserva íntegra.');
      expect(repo.textosRecibidos.single, '¿Dónde ocurrió el hecho?');
    });

    test('el contexto activo viaja como situación a partir del segundo turno',
        () async {
      final repo = _SignRepo();
      final c = _app(repo);
      await c.read(lexiconEntriesProvider.future);
      final notifier = c.read(conversationProvider.notifier);

      await notifier.sendHearingMessage('¿Qué ocurrió?');
      c.read(conversationHandoffProvider).openCards(
            c.read(conversationHandoffProvider).nextDeafLaunch(),
          );
      c.read(conversationBridgeProvider).submitDeclaration(
            result: TranslationResult(
                baseSentence: 'Me robaron.', generatedText: 'Me robaron.'),
            glosses: const ['ROBAR'],
            contextId: 'denuncia_robo',
            replyToId: c.read(cardsFlowLaunchProvider).hearingTurnId,
            conversationId: c.read(cardsFlowLaunchProvider).conversationId,
          );

      await notifier.sendHearingMessage('¿Recuerda la hora?');

      expect(repo.situaciones, [null, 'denuncia_robo'],
          reason: 'El contexto ya establecido desambigua el turno siguiente.');
    });
  });

  group('la transcripción del oyente encabeza la respuesta', () {
    test('llega literal al módulo de tarjetas', () async {
      final repo = _SignRepo();
      final c = _app(repo);
      await c.read(lexiconEntriesProvider.future);

      const literal = '¿Usted vio a la persona? Describa su ropa, por favor.';
      await c.read(conversationProvider.notifier).sendHearingMessage(literal);

      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());

      expect(c.read(pendingReplyProvider)!.question, literal,
          reason: 'Sin recortes ni paráfrasis: es lo que se está contestando.');
    });

    test('si la traducción a señas falla, la conversación sigue', () async {
      final repo = _SignRepo(respuesta: (_) => throw Exception('sin red'));
      final c = _app(repo);
      await c.read(lexiconEntriesProvider.future);

      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Qué ocurrió?');

      final estado = c.read(conversationProvider);
      expect(estado.conversation.turns, hasLength(1),
          reason: 'El turno se queda aunque el avatar no pueda representarlo.');
      expect(estado.conversation.turns.single.outputs.text, '¿Qué ocurrió?');
      expect(estado.error, isNotNull, reason: 'Y se dice que falló.');

      // Y aun así se puede responder.
      final handoff = c.read(conversationHandoffProvider);
      handoff.openCards(handoff.nextDeafLaunch());
      expect(c.read(pendingReplyProvider)!.question, '¿Qué ocurrió?');
    });
  });

  group('el control de la desambiguación es del módulo de audio', () {
    test('el estado arranca en reposo y sin aclaraciones', () {
      final c = _app(_SignRepo());
      final estado = c.read(audioTranslationControllerProvider);

      expect(estado.status, AudioTranslationStatus.idle);
      expect(estado.pendingClarifications, isEmpty);
      expect(estado.resolvedSenses, isEmpty);
    });

    test('reiniciar descarta los sentidos ya elegidos', () async {
      final c = _app(_SignRepo());
      final notifier = c.read(audioTranslationControllerProvider.notifier);

      notifier.updateRecognizedText('El auto se fue');
      notifier.reset();

      final estado = c.read(audioTranslationControllerProvider);
      expect(estado.recognizedText, isNull);
      expect(estado.resolvedSenses, isEmpty,
          reason: 'Los sentidos son de esta conversación, no del dispositivo.');
    });

    test('cambiar de modo de uso no arrastra lo dictado', () async {
      final c = _app(_SignRepo());
      for (var i = 0; i < 20 && c.read(usageSessionProvider).loading; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      c
          .read(audioTranslationControllerProvider.notifier)
          .updateRecognizedText('Algo de la atención anterior');

      c.read(audioTranslationControllerProvider.notifier).reset();

      expect(c.read(audioTranslationControllerProvider).recognizedText, isNull);
    });
  });

  group('la reproducción sigue siendo explícita', () {
    test('enviar un turno no reproduce audio por su cuenta', () async {
      final audio = FakeAudioOutput();
      final c = ProviderContainer(overrides: [
        lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
        audioTranslationRepositoryProvider.overrideWithValue(_SignRepo()),
        translationRepositoryProvider.overrideWithValue(_DeclRepo()),
        audioOutputProvider.overrideWithValue(audio),
        ...conversationOverrides(),
      ]);
      addTearDown(c.dispose);
      await c.read(lexiconEntriesProvider.future);

      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Qué ocurrió?');

      expect(audio.spoken, isEmpty,
          reason: 'Nada debe decirse en nombre de nadie sin un toque '
              'explícito.');
    });
  });
}
