import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/services/audio_output.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/declaration_result_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/home_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/lsb_flow_screen.dart';
import 'package:lsb_legal_app/core/di/injection.dart';

import 'helpers/official_dictionary.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

/// Flujo completo del módulo LSB → texto/audio sobre la interfaz real:
/// responder las preguntas del banco, ver la vista previa y emitir.
///
/// El backend de prueba devuelve OTRA frase (con un dato inventado). El
/// resultado tiene que ser exactamente la frase de la vista previa: el
/// servidor no puede cambiar lo que la persona confirmó.
class _Backend implements TranslationRepository {
  _Backend(this._text);
  final String _text;
  Map<String, dynamic>? guided;

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
    BusinessSignals? business,
    Map<String, dynamic>? guided,
  }) async {
    this.guided = guided;
    return TranslationResult(
      baseSentence: _text,
      generatedText: _text,
      audioUrl: null,
      bedrockUsed: true,
    );
  }
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

class _SinImagenes extends SignImagesNotifier {
  @override
  bool build() => false;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(ProviderContainer, _Backend)> montar(WidgetTester tester) async {
    final backend = _Backend(
      'Un hombre me robó mi celular por WhatsApp en la calle.',
    );
    final router = GoRouter(
      initialLocation: '/lsb-to-audio',
      routes: [
        GoRoute(
          path: '/lsb-to-audio',
          builder: (_, _) => const LsbFlowScreen(),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        translationRepositoryProvider.overrideWithValue(backend),
        audioOutputProvider.overrideWithValue(_NoopAudio()),
        lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
        signImagesEnabledProvider.overrideWith(_SinImagenes.new),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(contextProvider.notifier)
        .setContext(
          availableContexts.firstWhere((c) => c.id == 'denuncia_robo'),
        );
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
    return (container, backend);
  }

  Future<void> tocar(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  String vistaPrevia(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('live-declaration-preview')))
      .data!;

  testWidgets(
    'responder, ver la vista previa y emitir: el resultado es esa frase',
    (tester) async {
      final (container, backend) = await montar(tester);

      int pasoVisible() => tester
          .widget<IndexedStack>(
            find.descendant(
              of: find.byType(LsbFlowScreen),
              matching: find.byType(IndexedStack),
            ),
          )
          .index!;

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(pasoVisible(), 0);
      expect(find.text('¿Qué ocurrió?'), findsNothing);
      // La tarjeta muestra solo la secuencia LSB utilizable del banco.
      final lsb = find.byKey(const Key('formulacion_lsb'));
      expect(lsb, findsOneWidget);
      for (final pieza in ['TÚ', 'NARRAR', '¿QUÉ?']) {
        expect(
          find.descendant(of: lsb, matching: find.text(pieza)),
          findsOneWidget,
        );
      }
      expect(find.text('LSB provisional'), findsNothing);

      for (final spanish in const [
        'Me robaron',
        'Me falta algo (lo perdí o no sé)',
        'Dañaron algo mío',
        'Alguien escapó',
      ]) {
        expect(find.text(spanish), findsNothing);
      }
      for (final option in const ['ROBAR', 'PERDER', 'DAÑAR', 'ESCAPAR']) {
        expect(find.text(option), findsOneWidget);
      }

      await tocar(tester, find.text('ROBAR'));
      expect(vistaPrevia(tester), 'Me robaron algo.');
      expect(
        container.read(sentenceProvider),
        ['ROBAR'],
        reason: 'el reflejo en glosas sale de la misma respuesta',
      );

      await tocar(tester, find.text('CONTINUAR'));
      expect(find.text('¿Qué le robaron?'), findsNothing);
      for (final pieza in ['ROBAR', '¿QUÉ?']) {
        expect(
          find.descendant(of: lsb, matching: find.text(pieza)),
          findsOneWidget,
        );
      }
      await tocar(tester, find.text('CELULAR'));
      expect(vistaPrevia(tester), 'Me robaron el celular.');

      // Suficiencia: ya se puede terminar sin recorrer lo opcional.
      await tocar(tester, find.byKey(const Key('terminar_aqui')));

      expect(pasoVisible(), 1);
      expect(find.byType(DeclarationResultScreen), findsOneWidget);
      expect(find.text('Me robaron el celular.'), findsWidgets);
      expect(
        find.textContaining('WhatsApp'),
        findsNothing,
        reason: 'la frase distinta del servidor se descarta',
      );
      expect(backend.guided, isNotNull);
      expect(backend.guided!['recorrido'], 'denuncia_robo');
      expect(find.bySemanticsLabel('Nueva declaración'), findsOneWidget);
    },
  );

  testWidgets('una pregunta obligatoria no se salta con CONTINUAR', (
    tester,
  ) async {
    final (container, _) = await montar(tester);

    await tocar(tester, find.text('ESCAPAR'));
    await tocar(tester, find.text('CONTINUAR'));
    final escapeLsb = find.byKey(const Key('formulacion_lsb'));
    for (final pieza in const ['¿QUIÉN?', 'ESCAPAR']) {
      expect(
        find.descendant(of: escapeLsb, matching: find.text(pieza)),
        findsOneWidget,
      );
    }
    expect(find.text('¿Quién escapó?'), findsNothing);

    await tocar(tester, find.text('CONTINUAR'));
    expect(
      escapeLsb,
      findsOneWidget,
      reason: 'sin saber quién escapó, «Alguien escapó» no se puede redactar',
    );
    expect(find.byKey(const Key('omitir_pregunta')), findsNothing);

    await tocar(tester, find.text('YO · ESCAPAR'));
    expect(vistaPrevia(tester), 'Logré escapar.');
    expect(
      container
          .read(guidedFlowProvider)
          .session!
          .answerOf('Q.HEC.ESCAPE_ACTOR')!
          .optionIds,
      ['yo'],
    );
    // Deja que el aviso se cierre solo.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets(
    'omitir una pregunta opcional no redacta nada y queda registrado',
    (tester) async {
      final (container, _) = await montar(tester);

      await tocar(tester, find.text('ROBAR'));
      await tocar(tester, find.text('CONTINUAR'));
      await tocar(tester, find.byKey(const Key('omitir_pregunta')));

      final session = container.read(guidedFlowProvider).session!;
      expect(session.answerOf('Q.ROB.QUE')!.isOmitted, isTrue);
      expect(vistaPrevia(tester), 'Me robaron algo.');
    },
  );

  testWidgets('el monto se escribe con su moneda y llega literal a la frase', (
    tester,
  ) async {
    await montar(tester);

    await tocar(tester, find.text('ROBAR'));
    await tocar(tester, find.text('CONTINUAR'));
    await tocar(tester, find.text('BILLETES'));

    // Editor opcional: la opción ya está elegida y se puede precisar.
    expect(find.byKey(const Key('editor_confirmar')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('editor_campo_monto')), '500');
    await tester.pumpAndSettle();
    final confirmar = tester.widget<FilledButton>(
      find.byKey(const Key('editor_confirmar')),
    );
    expect(
      confirmar.onPressed,
      isNull,
      reason: 'sin moneda elegida no hay monto: la moneda no se inventa',
    );

    await tocar(tester, find.byKey(const Key('editor_moneda_Bs')));
    await tocar(tester, find.byKey(const Key('editor_confirmar')));

    expect(vistaPrevia(tester), 'Me robaron Bs 500.');
    expect(find.text('BILLETES: Bs 500'), findsOneWidget);
  });

  testWidgets('la cabecera permanece visible, respeta SafeArea y no se mueve', (
    tester,
  ) async {
    await montar(tester);
    await tocar(tester, find.text('ROBAR'));
    await tocar(tester, find.text('CONTINUAR'));

    final header = find.byKey(const Key('guided_question_header'));
    final scroll = find.byKey(const Key('guided_options_scroll'));
    expect(header, findsOneWidget);
    expect(scroll, findsOneWidget);
    final safeArea = tester.widget<SafeArea>(header);
    expect(safeArea.top, isTrue);
    expect(safeArea.bottom, isFalse);

    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    final before = tester.getTopLeft(header);
    expect(before.dy, greaterThanOrEqualTo(appBarBottom));

    final scrollable = find
        .descendant(of: scroll, matching: find.byType(Scrollable))
        .first;
    final beforePixels = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pumpAndSettle();
    final afterPixels = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    expect(afterPixels, greaterThan(beforePixels));
    final after = tester.getTopLeft(header);
    expect(after.dy, closeTo(before.dy, 0.1));
    expect(find.byKey(const Key('formulacion_lsb')), findsOneWidget);
  });
}
