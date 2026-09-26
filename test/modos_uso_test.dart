import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/app/session_restorer.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/session_snapshot.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/counter/domain/counter_session.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Los dos modos de uso y el ciclo de una atención.
///
/// El modo se elige, no se deduce: ni del tamaño de la pantalla, ni de una
/// discapacidad supuesta del propietario, ni de quién hable primero. Y en
/// ventanilla el dispositivo pasa de una persona a la siguiente, así que
/// terminar una atención tiene que borrar lo que dijo sin llevarse la
/// configuración de la institución.
class _SignRepo implements AudioTranslationRepository {
  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async =>
      LsbTranslation(glosses: const ['TU'], animationUrl: '');
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
    Map<String, dynamic>? guided,
  }) async =>
      TranslationResult(baseSentence: '...', generatedText: '...');
}

ProviderContainer _app() {
  final c = ProviderContainer(overrides: [
    lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
    audioTranslationRepositoryProvider.overrideWithValue(_SignRepo()),
    translationRepositoryProvider.overrideWithValue(_DeclRepo()),
    audioOutputProvider.overrideWithValue(FakeAudioOutput()),
    ...conversationOverrides(),
  ]);
  addTearDown(c.dispose);
  return c;
}

/// Espera a que el provider termine de leer la configuración del disco.
Future<UsageSession> _sesionCargada(ProviderContainer c) async {
  var estado = c.read(usageSessionProvider);
  for (var i = 0; i < 20 && estado.loading; i++) {
    await Future<void>.delayed(Duration.zero);
    estado = c.read(usageSessionProvider);
  }
  return estado;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('el modo al entrar', () {
    test('sin configuración guardada se usa el modo personal', () async {
      final c = _app();
      final estado = await _sesionCargada(c);

      expect(estado.loading, isFalse);
      expect(estado.isPersonal, isTrue);
    });

    test('se respeta el modo guardado', () async {
      SharedPreferences.setMockInitialValues({
        'device_config_v1': jsonEncode({'schemaVersion': 1, 'mode': 'counter'}),
      });
      final c = _app();
      final estado = await _sesionCargada(c);

      expect(estado.isCounter, isTrue);
    });

    test('elegir un modo lo deja guardado', () async {
      final c = _app();
      await _sesionCargada(c);

      await c.read(usageSessionProvider.notifier).choose(UsageMode.personal);

      expect(c.read(usageSessionProvider).isPersonal, isTrue);
      final config = await c.read(sessionRepositoryProvider).loadConfig();
      expect(config.mode, UsageMode.personal);
    });

    test('cambiar de modo no arrastra lo dicho en el anterior', () async {
      final c = _app();
      await _sesionCargada(c);
      final repo = c.read(sessionRepositoryProvider);

      await c.read(usageSessionProvider.notifier).choose(UsageMode.counter);
      await repo.saveContent(const SessionContent(
        contextId: 'denuncia_robo',
        sentence: ['ROBAR'],
      ));

      await c.read(usageSessionProvider.notifier).choose(UsageMode.personal);

      expect(await repo.loadContent(), isNull,
          reason: 'Lo declarado en una atención no sigue en el uso personal.');
      expect((await repo.loadConfig()).mode, UsageMode.personal);
    });
  });

  group('el perfil institucional es del dispositivo', () {
    test('se guarda y sobrevive a la atención', () async {
      final c = _app();
      await _sesionCargada(c);

      await c.read(usageSessionProvider.notifier).choose(
            UsageMode.counter,
            institutionProfileId: 'derechos_reales',
          );

      expect(c.read(usageSessionProvider).institutionProfileId,
          'derechos_reales');
      final config = await c.read(sessionRepositoryProvider).loadConfig();
      expect(config.institutionProfileId, 'derechos_reales');
    });

    test('se puede cambiar sin tocar el modo', () async {
      final c = _app();
      await _sesionCargada(c);
      await c.read(usageSessionProvider.notifier).choose(UsageMode.counter);

      await c.read(usageSessionProvider.notifier).setInstitution('policia');

      expect(c.read(usageSessionProvider).isCounter, isTrue);
      expect(c.read(usageSessionProvider).institutionProfileId, 'policia');
    });
  });

  group('finalizar una atención', () {
    test('borra lo del ciudadano y conserva la institución', () async {
      final c = _app();
      await _sesionCargada(c);
      final repo = c.read(sessionRepositoryProvider);

      await c.read(usageSessionProvider.notifier).choose(
            UsageMode.counter,
            institutionProfileId: 'derechos_reales',
          );

      // Una atención con contenido real.
      await c.read(lexiconEntriesProvider.future);
      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('¿Cuál es su nombre?');
      c.read(contextProvider.notifier).setContext(contextById('identificacion')!);
      c.read(sentenceProvider.notifier).setWords(['NOMBRE']);
      await repo.saveContent(const SessionContent(
        contextId: 'identificacion',
        sentence: ['NOMBRE'],
      ));

      await c.read(counterSessionProvider).endAttention();

      expect(c.read(conversationProvider).conversation.turns, isEmpty,
          reason: 'La siguiente persona no puede ver lo anterior.');
      expect(c.read(sentenceProvider), isEmpty);
      expect(c.read(contextProvider), isNull);
      expect(await repo.loadContent(), isNull);

      final config = await repo.loadConfig();
      expect(config.mode, UsageMode.counter);
      expect(config.institutionProfileId, 'derechos_reales',
          reason: 'El perfil es del dispositivo, no del ciudadano.');
    });

    test('empezar una atención parte de cero', () async {
      final c = _app();
      await _sesionCargada(c);
      await c.read(lexiconEntriesProvider.future);
      await c
          .read(conversationProvider.notifier)
          .sendHearingMessage('Mensaje de la atención anterior');

      await c.read(counterSessionProvider).startAttention();

      expect(c.read(conversationProvider).conversation.turns, isEmpty);
    });
  });

  group('restaurar la sesión respeta el modo', () {
    test('en ventanilla no se repone el contenido guardado', () async {
      SharedPreferences.setMockInitialValues({
        'device_config_v1': jsonEncode({
          'schemaVersion': 1,
          'mode': 'counter',
          'institutionProfileId': 'policia',
          'lastTabId': 'conversation',
        }),
        'session_content_v1': jsonEncode({
          'schemaVersion': 1,
          'contextId': 'denuncia_robo',
          'sentence': ['ROBAR'],
          'resultVisible': false,
          'conversation': null,
        }),
      });

      final c = _app();
      await c.read(sessionRestorerProvider).restore();

      expect(c.read(contextProvider), isNull,
          reason: 'Aunque el proceso muriera sin finalizar, esa atención '
              'terminó: reponerla sería enseñársela a la siguiente persona.');
      expect(c.read(sentenceProvider), isEmpty);
      expect(await c.read(sessionRepositoryProvider).loadContent(), isNull);
      expect((await c.read(sessionRepositoryProvider).loadConfig())
          .institutionProfileId, 'policia');
    });

    test('en personal sí se repone donde se dejó', () async {
      SharedPreferences.setMockInitialValues({
        'device_config_v1': jsonEncode({
          'schemaVersion': 1,
          'mode': 'personal',
          'lastTabId': 'cards',
        }),
        'session_content_v1': jsonEncode({
          'schemaVersion': 1,
          'contextId': 'denuncia_robo',
          'sentence': ['ROBAR', 'CELULAR'],
          'resultVisible': false,
          'conversation': null,
        }),
      });

      final c = _app();
      final tab = await c.read(sessionRestorerProvider).restore();

      expect(tab?.id, 'cards');
      expect(c.read(contextProvider)?.id, 'denuncia_robo');
      expect(c.read(sentenceProvider), ['ROBAR', 'CELULAR']);
    });
  });
}
