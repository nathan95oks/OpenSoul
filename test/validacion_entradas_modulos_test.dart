import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/input_validator.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// El control de calidad de Voz a LSB ([InputValidator]) en los otros
/// lugares donde se escribe: el mensaje del oyente en Conversación.

class _SignRepo implements AudioTranslationRepository {
  final List<String> textos = [];

  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async {
    textos.add(text);
    return LsbTranslation(glosses: const ['HOLA'], animationUrl: '');
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
    Map<String, dynamic>? guided,
  }) async => TranslationResult(baseSentence: '...', generatedText: '...');
}

/// Nombres reales de Cochabamba: el modo para nombres propios los acepta
/// todos, aunque tengan palabras de otro idioma o pocas vocales.
const _nombres = [
  'Mercado Calatayud',
  'Calle San Martín',
  'Av. Blanco Galindo km 7',
  'Av. Heroínas esquina Ayacucho',
  'Plaza 14 de Septiembre',
  'Calle 25 de Mayo',
  'Queru Queru',
  "Ch'ojña",
  'Estadio The Strongest',
  'Burger King',
  'Françoise Dupont',
  'Wendy Schwarz',
  'Jhonny Ticona',
  'Wilfredo Quispe Choque',
  'Beige',
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('nombres propios (literal)', () {
    test('acepta calles, lugares y personas reales', () {
      for (final n in _nombres) {
        expect(InputValidator.validate(n, literal: true), isNull, reason: n);
      }
    });

    test('rechaza lo mismo que Voz a LSB, salvo el idioma', () {
      for (final (texto, motivo) in [
        ('ljalskalksjlakj', InputIssue.gibberish),
        ('asdfgh', InputIssue.gibberish),
        (r'#$%&/()', InputIssue.noWords),
        ('Москва', InputIssue.otherAlphabet),
      ]) {
        expect(
          InputValidator.validate(texto, literal: true),
          motivo,
          reason: texto,
        );
      }
      // Como mensaje, en cambio, una frase en inglés no se traduce.
      expect(
        InputValidator.validate('the house of my lawyer'),
        InputIssue.otherLanguage,
      );
      expect(
        InputValidator.validate('the house of my lawyer', literal: true),
        isNull,
      );
    });
  });

  group('Conversación: el mensaje del oyente', () {
    ProviderContainer app(_SignRepo repo) {
      final c = ProviderContainer(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioTranslationRepositoryProvider.overrideWithValue(repo),
          translationRepositoryProvider.overrideWithValue(_DeclRepo()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
          ...conversationOverrides(),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('un texto sin sentido, solo símbolos o en otro idioma no entra en '
        'la conversación ni llega al traductor, y se dice por qué', () async {
      final repo = _SignRepo();
      final c = app(repo);
      await c.read(lexiconEntriesProvider.future);
      final notifier = c.read(conversationProvider.notifier);
      final turnos = c.read(conversationProvider).conversation.turns.length;

      for (final (texto, motivo) in [
        ('ljalskalksjlakj(*\$)\$#()#)', InputIssue.gibberish),
        ('hello I need help', InputIssue.otherLanguage),
        ('???', InputIssue.noWords),
        ('a' * 301, InputIssue.tooLong),
      ]) {
        await notifier.sendHearingMessage(texto);
        final estado = c.read(conversationProvider);
        expect(estado.error, motivo.message, reason: texto);
        expect(estado.processing, isFalse);
        expect(estado.conversation.turns.length, turnos, reason: texto);
      }
      expect(repo.textos, isEmpty);
    });

    test('un mensaje bien escrito se traduce, limpio de espacios de más, y '
        'borra el aviso anterior', () async {
      final repo = _SignRepo();
      final c = app(repo);
      await c.read(lexiconEntriesProvider.future);
      final notifier = c.read(conversationProvider.notifier);

      await notifier.sendHearingMessage('asdfgh');
      expect(c.read(conversationProvider).error, isNotNull);

      await notifier.sendHearingMessage('  ¿Qué   ocurrió?\n');
      expect(repo.textos, ['¿Qué ocurrió?']);
      expect(c.read(conversationProvider).error, isNull);
    });
  });
}
