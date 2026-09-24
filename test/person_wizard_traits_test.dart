import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/audio_output.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/lsb_flow_screen.dart';

import 'helpers/official_dictionary.dart';

/// Paso 3 del asistente de persona (estatura/complexión): estatura y
/// complexión son ejes independientes (alguien puede ser alto Y flaco a la
/// vez), así que elegir una no debe avanzar de paso sola, y dentro de un
/// mismo eje elegir un extremo debe ocultar el otro (no tiene sentido
/// "alto y bajo" a la vez).
void main() {
  Future<ProviderContainer> abrirAsistenteEnPaso3(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/lsb-to-audio',
      routes: [
        GoRoute(path: '/lsb-to-audio', builder: (_, _) => const LsbFlowScreen()),
      ],
    );

    final container = ProviderContainer(overrides: [
      translationRepositoryProvider.overrideWithValue(_FakeRepo('...')),
      audioOutputProvider.overrideWithValue(_NoopAudio()),
      lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
    ]);
    addTearDown(container.dispose);

    container.read(contextProvider.notifier).setContext(
          availableContexts.firstWhere((c) => c.id == 'denuncia_robo'),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    container.read(semanticZonesProvider.notifier).activateZone('persona');
    await tester.pumpAndSettle();

    // Tocar HOMBRE ya trae el género resuelto, así que el asistente abre
    // directo en el paso 2 (edad).
    await tester.tap(find.text('HOMBRE').first);
    await tester.pumpAndSettle();
    expect(find.text('Paso 2: Rango de Edad'), findsOneWidget);

    await tester.tap(find.text('Joven'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 3: Complexión y Estatura'), findsOneWidget);

    return container;
  }

  testWidgets(
      'elegir estatura no avanza de paso y deja elegir también la complexión',
      (tester) async {
    final container = await abrirAsistenteEnPaso3(tester);

    expect(find.text('Alto / Alta'), findsOneWidget);
    expect(find.text('Bajo / Baja'), findsOneWidget);

    await tester.tap(find.text('Alto / Alta'));
    await tester.pumpAndSettle();

    // Sigue en el paso 3: elegir un eje no fuerza el otro ni avanza solo.
    expect(find.text('Paso 3: Complexión y Estatura'), findsOneWidget);
    // "Bajo" desaparece: no tiene sentido ofrecer lo contrario de lo ya
    // elegido en el mismo eje.
    expect(find.text('Bajo / Baja'), findsNothing);
    expect(find.textContaining('Alto / Alta'), findsOneWidget);
    // El otro eje (complexión) sigue intacto y disponible.
    expect(find.text('Delgado / Delgada'), findsOneWidget);
    expect(find.text('Robusto / Robusta'), findsOneWidget);

    await tester.tap(find.text('Robusto / Robusta'));
    await tester.pumpAndSettle();

    expect(find.text('Delgado / Delgada'), findsNothing);
    expect(find.textContaining('Robusto / Robusta'), findsOneWidget);

    final persona = container.read(declarationDraftProvider).persons.single;
    expect(persona.height, 'ALTO');
    expect(persona.build, 'GORDO');

    // Tocar la opción ya elegida la reabre para poder cambiarla.
    await tester.tap(find.textContaining('Alto / Alta'));
    await tester.pumpAndSettle();
    expect(find.text('Bajo / Baja'), findsOneWidget);

    // Avanzar es una acción explícita del usuario, no automática.
    await tester.tap(find.text('SIGUIENTE PASO'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 4: Vestimenta y Accesorios'), findsOneWidget);
    expect(find.text('FINALIZAR DESCRIPCIÓN'), findsOneWidget);

    // Los toasts de confirmación de cada selección se autodescartan a los 3
    // segundos con su propio temporizador; sin dejarlo vencer antes de que
    // termine la prueba, el binding de test lo reporta como fuga.
    await tester.pump(const Duration(seconds: 4));
  });
}

class _FakeRepo implements TranslationRepository {
  _FakeRepo(this._text);
  final String _text;

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
  }) async =>
      TranslationResult(
        baseSentence: _text,
        generatedText: _text,
        audioUrl: null,
        bedrockUsed: false,
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
