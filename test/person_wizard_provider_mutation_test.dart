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

/// Regresión: tocar una tarjeta en la zona "persona" abre la hoja modal del
/// asistente secuencial (`_PersonSequentialWizardSheet`), cuyo `initState`
/// mutaba `declarationDraftProvider` en pleno montaje del widget mientras
/// otros widgets que también lo observan (`ConfiguredEntityChips`,
/// `LiveDeclarationPreviewPanel`, `GuidedWizardStepper`) seguían montados en
/// el mismo árbol. Eso disparaba en un dispositivo real:
///   "Tried to modify a provider while the widget tree was building."
/// seguido de una aserción del framework. La creación de la persona y la
/// actualización de su primer atributo ahora se difieren al primer frame ya
/// renderizado (ver `entity_editor_sheets.dart`).
void main() {
  testWidgets(
      'tocar una tarjeta de persona no muta el provider durante el montaje',
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

    // Salta directo a la zona "persona": es la que abre el asistente
    // secuencial al tocar cualquiera de sus tarjetas.
    container.read(semanticZonesProvider.notifier).activateZone('persona');
    await tester.pumpAndSettle();

    final tarjetaHombre = find.text('HOMBRE');
    expect(tarjetaHombre, findsWidgets,
        reason: 'la zona persona debe ofrecer la tarjeta HOMBRE');

    await tester.tap(tarjetaHombre.first);
    // Un solo pump (no pumpAndSettle): el error original ocurría en el
    // mismo instante del montaje, antes de que ninguna animación termine.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'no debe lanzarse ninguna excepción al montar el asistente '
            'de persona');
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
