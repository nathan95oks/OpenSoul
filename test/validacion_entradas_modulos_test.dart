import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_values.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/input_validator.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/entity_editor_sheets.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// El control de calidad de Voz a LSB ([InputValidator]) en los otros
/// lugares donde se escribe: el mensaje del oyente en Conversación y los
/// campos de texto libre de LSB a Texto (una calle, un nombre, un detalle).

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

  group('LSB a Texto: editor del banco guiado', () {
    test(
      'un lugar o un nombre con letras sin sentido no se puede confirmar',
      () {
        for (final editor in ['lugar_literal', 'referencia', 'texto_nombre']) {
          final key = kEditorKeys[editor]!.single;
          final malo = GuidedValues.check(editor, {key: 'ljalskalksjlakj'});
          expect(malo.error, InputIssue.gibberish.message, reason: editor);
          for (final n in _nombres) {
            expect(
              GuidedValues.check(editor, {key: n}).isValid,
              isTrue,
              reason: '$editor «$n»',
            );
          }
        }
      },
    );

    test('un detalle se revisa como un mensaje: también el idioma', () {
      expect(
        GuidedValues.check('texto_detalle', {
          'texto': 'hello I need help',
        }).error,
        InputIssue.otherLanguage.message,
      );
      expect(
        GuidedValues.check('texto_detalle', {
          'texto': 'Tenía una mochila azul con documentos',
        }).isValid,
        isTrue,
      );
    });

    test('un número de documento es un código y no se revisa como texto', () {
      expect(
        GuidedValues.check('documento_numero', {
          'numero': '1234567 CBBA',
        }).isValid,
        isTrue,
      );
    });
  });

  group('LSB a Texto: teclado de texto libre (una calle, un color)', () {
    Future<List<String?>> abrir(WidgetTester tester) async {
      final devuelto = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => devuelto.add(
                  await mostrarTecladoTextoLibre(
                    context,
                    titulo: '¿Nombre o referencia de ese lugar? (opcional)',
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return devuelto;
    }

    testWidgets('con letras sin sentido avisa y no deja continuar', (
      tester,
    ) async {
      final devuelto = await abrir(tester);
      await tester.enterText(find.byType(TextField), 'ljalskalksjlakj');
      await tester.pump();
      expect(find.byKey(const Key('texto_libre_problema')), findsOneWidget);
      expect(find.text(InputIssue.gibberish.message), findsOneWidget);
      final boton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNull);

      // Enter tampoco lo acepta.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(devuelto, isEmpty);
    });

    testWidgets('una calle de verdad se acepta tal como se escribió', (
      tester,
    ) async {
      final devuelto = await abrir(tester);
      await tester.enterText(find.byType(TextField), 'Calle  San Martín ');
      await tester.pump();
      expect(find.byKey(const Key('texto_libre_problema')), findsNothing);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(devuelto, ['Calle San Martín']);
    });

    testWidgets('vacío sigue siendo «Omitir»', (tester) async {
      final devuelto = await abrir(tester);
      await tester.tap(find.text('Omitir'));
      await tester.pumpAndSettle();
      expect(devuelto, ['']);
    });
  });
}
