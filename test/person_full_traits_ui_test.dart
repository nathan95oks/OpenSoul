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
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/lsb_flow_screen.dart';

import 'helpers/official_dictionary.dart';

/// Reproduce exactamente lo que describió el usuario: "un hombre flaco alto
/// con ropa de color" (complexión + estatura + una prenda con color) debe
/// llegar completo a la declaración, no solo un rasgo suelto.
void main() {
  testWidgets(
      'complexión, estatura y prenda con color llegan juntos a la declaración',
      (tester) async {
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

    Future<void> tocar(Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    container.read(semanticZonesProvider.notifier).activateZone('persona');
    await tester.pumpAndSettle();

    await tocar(find.text('HOMBRE').first);
    expect(find.text('Paso 2: Rango de Edad'), findsOneWidget);

    await tocar(find.text('Adulto / Adulta'));
    expect(find.text('Paso 3: Complexión y Estatura'), findsOneWidget);

    // Complexión Y estatura: dos ejes distintos, ambos deben quedar.
    await tocar(find.text('Delgado / Delgada'));
    await tocar(find.text('Alto / Alta'));
    await tocar(find.text('SIGUIENTE PASO'));
    expect(find.text('Paso 4: Vestimenta y Accesorios'), findsOneWidget);

    // Una prenda con su color.
    await tocar(find.text('Polera'));
    await tester.pumpAndSettle();
    await tocar(find.text('Rojo'));

    await tocar(find.text('FINALIZAR DESCRIPCIÓN'));

    container.read(semanticZonesProvider.notifier).activateZone('hecho');
    await tester.pumpAndSettle();
    await tocar(find.text('ROBAR'));

    expect(
      find.textContaining('aunque todavía no completé los detalles'),
      findsNothing,
    );
    expect(find.textContaining('delgado'), findsWidgets,
        reason: 'la complexión elegida debe verse en la declaración');
    expect(find.textContaining('alto'), findsWidgets,
        reason: 'la estatura elegida debe verse en la declaración');
    expect(find.textContaining('polera'), findsWidgets,
        reason: 'la prenda elegida debe verse en la declaración');
    expect(find.textContaining('roja'), findsWidgets,
        reason: 'el color de la prenda debe verse en la declaración');

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
