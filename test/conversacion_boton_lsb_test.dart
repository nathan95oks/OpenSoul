import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/conversation/presentation/screens/conversation_screen.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// El botón de tarjetas LSB dice a la persona sorda cuándo le toca: invita a
/// empezar con el chat vacío y a responder cuando el oyente ya habló.
void main() {
  Future<ProviderContainer> abrir(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(
      overrides: [
        lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
        audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        ...conversationOverrides(),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MediaQuery(
          // Sin latido: la prueba mira estados, no la animación.
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: ConversationScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return c;
  }

  testWidgets('con el chat vacío invita a empezar, con un mensaje corto', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.text('Empiecen a conversar'), findsOneWidget);
    expect(find.text('Oyente: habla o escribe'), findsOneWidget);
    expect(find.text('Persona sorda: responde en LSB'), findsOneWidget);
    expect(find.text('Empezar en LSB'), findsOneWidget);
  });

  testWidgets('cuando el oyente habló, el botón llama a responder', (
    tester,
  ) async {
    final c = await abrir(tester);
    c.read(conversationProvider.notifier).state = ConversationState(
      conversation: Conversation.start().addTurn(
        ConversationTurn(
          message: SemanticMessage(
            id: 'p1',
            speaker: SpeakerRole.hearing,
            source: MessageSource.text,
            text: '¿Tiene testigos?',
            glosses: const ['TESTIGO', 'TENER'],
          ),
          outputs: const GeneratedOutputs(text: '¿Tiene testigos?'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // El texto anterior se va con la transición del cambio.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Responder en LSB'), findsOneWidget);
    expect(find.text('Empezar en LSB'), findsNothing);
  });
}
