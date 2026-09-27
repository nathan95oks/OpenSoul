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
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/semantic_node.dart';
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

  Future<(ProviderContainer, _Backend)> montar(
    WidgetTester tester, {
    bool conNavbar = false,
  }) async {
    final backend = _Backend(
      'Un hombre me robó mi celular por WhatsApp en la calle.',
    );
    final router = GoRouter(
      initialLocation: conNavbar ? '/home' : '/lsb-to-audio',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(
            body: LsbFlowScreen(),
            bottomNavigationBar: SizedBox(
              key: Key('navbar_prueba'),
              height: 56,
            ),
          ),
        ),
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

  String vistaPrevia(ProviderContainer container) =>
      container.read(guidedPreviewProvider);

  testWidgets(
    'responder, ver la vista previa y emitir: el resultado es esa frase',
    (tester) async {
      final (container, backend) = await montar(tester, conNavbar: true);

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
      expect(vistaPrevia(container), 'Me robaron algo.');
      expect(
        container.read(sentenceProvider),
        ['ROBAR'],
        reason: 'el reflejo en glosas sale de la misma respuesta',
      );

      await tocar(tester, find.byKey(const Key('siguiente_pregunta')));
      expect(find.text('¿Qué le robaron?'), findsNothing);
      for (final pieza in ['ROBAR', '¿QUÉ?']) {
        expect(
          find.descendant(of: lsb, matching: find.text(pieza)),
          findsOneWidget,
        );
      }
      await tocar(tester, find.text('CELULAR'));
      expect(vistaPrevia(container), 'Me robaron el celular.');

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

      // El AppBar de Declaración no tiene flecha hacia atrás a la par del título
      final appBars = tester.widgetList<AppBar>(find.byType(AppBar));
      final declarationAppBar = appBars.last;
      expect(declarationAppBar.leading, isNull);
      expect(declarationAppBar.automaticallyImplyLeading, isFalse);
      // Sin la frase de cambiar de contexto ni sus acciones asociadas: el
      // título queda solo y centrado, coherente con el resto de la app.
      expect(declarationAppBar.actions, anyOf(isNull, isEmpty));
      expect(find.text('Cambiar de contexto'), findsNothing);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);

      // «Volver a editar» regresa al lienzo conservando las glosas y respuestas
      await tocar(tester, find.bySemanticsLabel('Volver a editar'));
      expect(pasoVisible(), 0);
      expect(find.text('CELULAR'), findsOneWidget);

      // Volver a emitir para quedar en el resultado
      await tocar(tester, find.byKey(const Key('terminar_aqui')));
      expect(pasoVisible(), 1);

      // «Nueva declaración» limpia el contexto y redirige a la selección de contexto
      await tocar(tester, find.bySemanticsLabel('Nueva declaración'));
      expect(pasoVisible(), 0);
      expect(container.read(contextProvider), isNull);
      expect(find.text('Selecciona el contexto'), findsOneWidget);
      expect(
        find.byKey(const Key('navbar_prueba')),
        findsOneWidget,
        reason: 'reiniciar la declaracion debe permanecer dentro del shell',
      );
    },
  );

  testWidgets('una pregunta obligatoria no se salta con CONTINUAR', (
    tester,
  ) async {
    final (container, _) = await montar(tester);

    await tocar(tester, find.text('ESCAPAR'));
    await tocar(tester, find.byKey(const Key('siguiente_pregunta')));
    final escapeLsb = find.byKey(const Key('formulacion_lsb'));
    for (final pieza in const ['¿QUIÉN?', 'ESCAPAR']) {
      expect(
        find.descendant(of: escapeLsb, matching: find.text(pieza)),
        findsOneWidget,
      );
    }
    expect(find.text('¿Quién escapó?'), findsNothing);

    await tocar(tester, find.byKey(const Key('siguiente_pregunta')));
    expect(
      escapeLsb,
      findsOneWidget,
      reason: 'sin saber quién escapó, «Alguien escapó» no se puede redactar',
    );
    // Sin aviso aparte: la validación vive dentro de las propias tarjetas.
    expect(find.byKey(const Key('app_toast')), findsNothing);
    final hint = find.byKey(const Key('seleccion_obligatoria'));
    expect(hint, findsOneWidget);
    expect(find.text('Selecciona una opción'), findsOneWidget);
    final tarjetaYo = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.ancestor(
          of: find.text('YO · ESCAPAR'),
          matching: find.byType(SemanticNode),
        ),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoracion = tarjetaYo.decoration as BoxDecoration;
    expect(
      decoracion.border!.top.color,
      SemanticNode.requiredSelectionColor,
      reason: 'la tarjeta se resalta en vez de mostrar un aviso aparte',
    );
    expect(find.byKey(const Key('omitir_pregunta')), findsNothing);

    await tocar(tester, find.text('YO · ESCAPAR'));
    expect(vistaPrevia(container), 'Logré escapar.');
    expect(
      container
          .read(guidedFlowProvider)
          .session!
          .answerOf('Q.HEC.ESCAPE_ACTOR')!
          .optionIds,
      ['yo'],
    );
    // Elegida la respuesta, la indicación se retira sola.
    expect(hint, findsNothing);
  });

  testWidgets(
    'omitir una pregunta opcional no redacta nada y queda registrado',
    (tester) async {
      final (container, _) = await montar(tester);

      await tocar(tester, find.text('ROBAR'));
      await tocar(tester, find.byKey(const Key('siguiente_pregunta')));
      container.read(guidedFlowProvider.notifier).omit('Q.ROB.QUE');
      await tester.pumpAndSettle();

      final session = container.read(guidedFlowProvider).session!;
      expect(session.answerOf('Q.ROB.QUE')!.isOmitted, isTrue);
      expect(vistaPrevia(container), 'Me robaron algo.');
    },
  );

  testWidgets('el monto se escribe con su moneda y llega literal a la frase', (
    tester,
  ) async {
    final (container, _) = await montar(tester);

    await tocar(tester, find.text('ROBAR'));
    await tocar(tester, find.byKey(const Key('siguiente_pregunta')));
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

    expect(vistaPrevia(container), 'Me robaron Bs 500.');
    expect(find.text('BILLETES: Bs 500'), findsOneWidget);
  });

  testWidgets('la cabecera permanece visible, respeta SafeArea y no se mueve', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await montar(tester);
    await tocar(tester, find.text('ROBAR'));
    await tocar(tester, find.byKey(const Key('siguiente_pregunta')));

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

    // La cabecera de pregunta debe ser compacta: no puede acaparar media
    // pantalla ni desplazar las glosas hacia abajo.
    final headerHeight = tester.getRect(header).height;
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      headerHeight,
      lessThan(screenHeight * 0.3),
      reason: 'la cabecera no debe ocupar una fracción excesiva de la pantalla',
    );

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

  testWidgets(
    'en seleccion de glosas la flecha atras sale a la seleccion de contextos',
    (tester) async {
      final (container, _) = await montar(tester);

      // En selección de glosas la AppBar muestra la flecha hacia atrás y el título del contexto
      expect(find.byKey(const Key('volver_a_contextos')), findsOneWidget);
      expect(find.text('Denunciar robo'), findsOneWidget);
      expect(find.text('OpenSoul'), findsNothing);

      // Tocamos la flecha hacia atrás para salir a los contextos
      await tocar(tester, find.byKey(const Key('volver_a_contextos')));

      // Ahora el contexto es nulo y estamos en la pantalla de contextos con el logo y OpenSoul
      expect(container.read(contextProvider), isNull);
      expect(find.text('Selecciona el contexto'), findsOneWidget);
      expect(find.text('OpenSoul'), findsOneWidget);
      expect(find.byKey(const Key('volver_a_contextos')), findsNothing);
    },
  );
}
