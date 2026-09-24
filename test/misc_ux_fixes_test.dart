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

void main() {
  group('catálogo: opciones sin sentido retiradas', () {
    test('VER ya no se ofrece como respuesta a "¿conoce a esa persona?"', () {
      final zona = contextById('denuncia_robo')!.zoneById('conocimiento')!;
      expect(zona.glossAllowlist.contains('VER'), false);
      // Sigue siendo una respuesta válida en otros lados (p. ej. testigo).
      expect(zona.glossAllowlist, containsAll(['SÍ', 'NO', 'AMIGO', 'PAREJA']));
    });

    test('la evidencia ofrece fotos, video, factura y "escribir otro"', () {
      final zona = contextById('denuncia_robo')!.zoneById('evidencia')!;
      expect(zona.glossAllowlist, ['FOTOS', 'VIDEO', 'FACTURA', 'ESCRIBIR']);
    });
  });

  Future<ProviderContainer> montar(WidgetTester tester) async {
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
    return container;
  }

  Future<void> tocar(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'escribir el nombre de la calle cambia el botón de Omitir a Continuar',
      (tester) async {
    await montar(tester);

    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .context; // sanity: widget tree montado

    final container = ProviderScope.containerOf(
        tester.element(find.byType(LsbFlowScreen)));
    container.read(semanticZonesProvider.notifier).activateZone('lugar');
    await tester.pumpAndSettle();

    await tocar(tester, find.text('CALLE'));

    expect(find.text('Omitir'), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Calle San Martín');
    await tester.pumpAndSettle();

    expect(find.text('Continuar'), findsOneWidget,
        reason: 'con texto escrito el botón ya no debe decir "Omitir"');
    expect(find.text('Omitir'), findsNothing);
  });

  testWidgets(
      'la cantidad de tiempo admite números de dos cifras sin romper la declaración',
      (tester) async {
    final container = await montar(tester);

    container.read(semanticZonesProvider.notifier).activateZone('hecho');
    await tester.pumpAndSettle();
    await tocar(tester, find.text('ROBAR'));

    container.read(semanticZonesProvider.notifier).activateZone('tiempo');
    await tester.pumpAndSettle();
    await tocar(tester, find.text('DÍA'));

    // El teclado nativo admite cualquier cifra, no solo 1-9.
    await tester.enterText(find.byType(TextField), '15');
    await tester.pumpAndSettle();
    expect(find.textContaining('Hace 15 días'), findsOneWidget);

    await tocar(tester, find.text('Confirmar'));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Hace 15 días'), findsWidgets,
        reason: 'la cifra de dos dígitos debe llegar completa a la declaración');
  });

  testWidgets('"escribir otro" registra el texto libre como la prueba, no la palabra ESCRIBIR',
      (tester) async {
    final container = await montar(tester);

    container.read(semanticZonesProvider.notifier).activateZone('evidencia');
    await tester.pumpAndSettle();

    await tocar(tester, find.text('ESCRIBIR'));
    await tester.enterText(find.byType(TextField), 'un recibo firmado');
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Continuar'));

    container.read(semanticZonesProvider.notifier).activateZone('hecho');
    await tester.pumpAndSettle();
    await tocar(tester, find.text('ROBAR'));

    expect(find.textContaining('un recibo firmado'), findsWidgets);
    expect(find.textContaining('escribir'), findsNothing,
        reason: 'la palabra "escribir" no debe quedar como si fuera la prueba misma');

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
