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

import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';

import 'helpers/official_dictionary.dart';

/// Regresión: la integración del borrador leía solo `declarationDraftProvider`,
/// el borrador de ENTIDADES (persona, objeto, lugar) editado directamente por
/// sus wizards. Pero la zona "hecho" (ROBAR/DAÑAR/ENGAÑAR — a diferencia de
/// PERDER/ESCAPAR, que sí pasan por un modal de desambiguación que llama a
/// `setFactAction`) solo queda registrada como respuesta simple de zona, y
/// únicamente `buildFullDeclarationDraft` la fusiona en `fact.action`.
void main() {
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

  testWidgets('elegir ENGAÑAR en "qué le ocurrió" redacta el hecho, no el texto de respaldo',
      (tester) async {
    final container = await montar(tester);

    container.read(semanticZonesProvider.notifier).activateZone('hecho');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ENGAÑAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENGAÑAR'));
    await tester.pumpAndSettle();

    final draft = buildFullDeclarationDraft(container);
    final texto = const LocalSentenceAssembler().assembleStructured(draft);
    expect(
      texto.contains('aunque todavía no completé los detalles'),
      isFalse,
      reason: 'ENGAÑAR sí describe el hecho: no debe caer al texto de respaldo',
    );
    expect(texto.contains('engañaron'), isTrue);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'los rasgos de la persona descrita aparecen en la declaración al elegir ROBAR',
      (tester) async {
    final container = await montar(tester);

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

    await tocar(find.text('Alto / Alta'));
    await tocar(find.text('SIGUIENTE PASO'));
    expect(find.text('Paso 4: Vestimenta y Accesorios'), findsOneWidget);

    await tocar(find.text('FINALIZAR DESCRIPCIÓN'));

    container.read(semanticZonesProvider.notifier).activateZone('hecho');
    await tester.pumpAndSettle();
    await tocar(find.text('ROBAR'));

    final draft = buildFullDeclarationDraft(container);
    final texto = const LocalSentenceAssembler().assembleStructured(draft);
    expect(
      texto.contains('aunque todavía no completé los detalles'),
      isFalse,
    );
    // "un hombre adulto alto" — los rasgos elegidos no deben saltarse.
    expect(texto.contains('alto'), isTrue,
        reason: 'la estatura elegida para la persona debe verse en la declaración');

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
