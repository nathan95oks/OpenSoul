import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lsb_legal_app/app/theme.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/services/audio_output.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/translation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/declaration_result_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/home_screen.dart';

/// Prueba de widget del flujo completo (TST-04): seleccionar contexto + glosas,
/// pulsar TRADUCIR y verificar la navegación a la pantalla de resultado con la
/// declaración generada visible.

class _FakeRepository implements TranslationRepository {
  _FakeRepository(this._text);
  final String _text;

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  }) async =>
      TranslationResult(
        baseSentence: _text,
        generatedText: _text,
        audioUrl: null,
        bedrockUsed: true,
      );
}

class _NoopAudio implements AudioOutput {
  @override
  Future<void> playUrl(String url) async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  void setOnComplete(void Function() onComplete) {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('seleccionar glosas, traducir y ver el resultado', (tester) async {
    const generated = 'Un hombre me robó mi celular en la calle.';

    final router = GoRouter(
      initialLocation: '/lsb-to-audio',
      routes: [
        GoRoute(
          path: '/lsb-to-audio',
          builder: (_, _) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'result',
              builder: (_, _) => const DeclarationResultScreen(),
            ),
          ],
        ),
      ],
    );

    final container = ProviderContainer(overrides: [
      translationRepositoryProvider.overrideWithValue(_FakeRepository(generated)),
      audioOutputProvider.overrideWithValue(_NoopAudio()),
    ]);
    addTearDown(container.dispose);

    // Estado previo: contexto elegido y glosas seleccionadas (como si el
    // usuario hubiera recorrido el flujo guiado).
    container.read(contextProvider.notifier).setContext(
          availableContexts.firstWhere((c) => c.id == 'denuncia_robo'),
        );
    container
        .read(sentenceProvider.notifier)
        .setWords(['HOMBRE', 'ROBAR', 'CELULAR']);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Estamos en Home con el botón de traducir disponible.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('TRADUCIR'), findsOneWidget);
    // A11Y-01: el botón principal se anuncia como tal a lectores de pantalla.
    expect(find.bySemanticsLabel('Traducir'), findsOneWidget);

    // Pulsar TRADUCIR dispara la traducción y navega al resultado.
    await tester.tap(find.text('TRADUCIR'));
    await tester.pumpAndSettle();

    expect(find.byType(DeclarationResultScreen), findsOneWidget);
    expect(find.text(generated), findsOneWidget,
        reason: 'la declaración generada debe mostrarse en el resultado');
    // El chip de origen refleja que vino de la IA (bedrockUsed = true).
    expect(find.text('Refinado por IA'), findsOneWidget);
    // A11Y-01: las acciones del resultado son botones accesibles.
    expect(find.bySemanticsLabel('Nueva declaración'), findsOneWidget);
  });
}
