import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/services/audio_output.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/declaration_result_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/home_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/lsb_flow_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/gloss_row.dart';
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
  final List<String> spoken = [];
  int pauses = 0;
  int resumes = 0;

  @override
  Future<void> playUrl(String url) async {}
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> resume() async => resumes++;
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

  /// Elige la opción que se ve como [texto] tocando su fila.
  Future<void> elegir(WidgetTester tester, String texto) async {
    final fila = find.ancestor(
      of: find.text(texto),
      matching: find.byType(GlossRow),
    );
    await tester.ensureVisible(fila);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: fila, matching: find.text(texto)));
    await tester.pumpAndSettle();
  }

  Finder enFilas(String texto) =>
      find.descendant(of: find.byType(GlossRow), matching: find.text(texto));

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
        'Perdí algo',
        'Dañaron algo mío',
        'Alguien escapó',
      ]) {
        expect(find.text(spanish), findsNothing);
      }
      for (final option in const ['ROBAR', 'PERDER', 'DAÑAR', 'ESCAPAR']) {
        expect(find.text(option), findsOneWidget);
      }

      await elegir(tester, 'ROBAR');
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
      await elegir(tester, 'CELULAR');
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
      expect(enFilas('CELULAR'), findsOneWidget);
      // Lo elegido sigue marcado en su fila.
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('CELULAR'),
            matching: find.byType(GlossRow),
          ),
          matching: find.byKey(const Key('fila_elegida')),
        ),
        findsOneWidget,
      );

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

    await elegir(tester, 'ESCAPAR');
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
    final marcaYo = tester.widget<Container>(
      find.descendant(
        of: find.ancestor(
          of: find.text('YO · ESCAPAR'),
          matching: find.byType(GlossRow),
        ),
        matching: find.byKey(const Key('marca_fila')),
      ),
    );
    expect(
      marcaYo.color,
      GlossRow.requiredSelectionColor,
      reason: 'la fila se resalta en vez de mostrar un aviso aparte',
    );
    expect(find.byKey(const Key('omitir_pregunta')), findsNothing);

    await elegir(tester, 'YO · ESCAPAR');
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

      await elegir(tester, 'ROBAR');
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

    await elegir(tester, 'ROBAR');
    await tocar(tester, find.byKey(const Key('siguiente_pregunta')));
    await elegir(tester, 'BILLETES');

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
    expect(enFilas('BILLETES: Bs 500'), findsOneWidget);
  });

  testWidgets('la cabecera permanece visible, respeta SafeArea y no se mueve', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await montar(tester);
    await elegir(tester, 'ROBAR');
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

      // Ahora el contexto es nulo y estamos en la pantalla de contextos con
      // el título propio del módulo, sin repetir el branding de OpenSoul.
      expect(container.read(contextProvider), isNull);
      expect(find.text('Selecciona el contexto'), findsOneWidget);
      expect(find.text('Expresión en LSB'), findsOneWidget);
      expect(find.text('OpenSoul'), findsNothing);
      expect(find.byKey(const Key('volver_a_contextos')), findsNothing);
    },
  );

  testWidgets(
    'respondiendo: la flecha siempre arriba a la izquierda, una por pantalla',
    (tester) async {
      final (container, _) = await montar(tester);
      container
          .read(cardsFlowLaunchProvider.notifier)
          .start(
            const CardsFlowLaunch.reply(
              conversationId: 'c',
              hearingTurnId: 't',
              hearingText: 'hola',
            ),
          );
      container.read(contextProvider.notifier).clearContext();
      await tester.pumpAndSettle();

      // Primera pantalla: la flecha lleva de vuelta a la conversación.
      expect(find.byTooltip('Volver a la conversación'), findsOneWidget);

      await tocar(tester, find.text('Denuncias'));
      // Dentro de la familia: la flecha de arriba vuelve al menú, y no hay
      // otro «Volver» en la pantalla.
      expect(find.byKey(const Key('volver_a_familias')), findsOneWidget);
      expect(find.text('Volver'), findsNothing);
      expect(find.byTooltip('Volver a la conversación'), findsNothing);

      await tocar(tester, find.byKey(const Key('volver_a_familias')));
      expect(find.byTooltip('Volver a la conversación'), findsOneWidget);
    },
  );

  testWidgets(
    'Trámites: la flecha de una institución vuelve a Trámites y de ahí al '
    'menú',
    (tester) async {
      final (container, _) = await montar(tester);
      container.read(contextProvider.notifier).clearContext();
      await tester.pumpAndSettle();

      await tocar(tester, find.text('Trámites'));
      await tocar(tester, find.text('SERECI'));
      expect(find.text('Registrar una defunción'), findsOneWidget);
      expect(find.byKey(const Key('volver_a_secciones')), findsOneWidget);
      expect(find.byKey(const Key('volver_a_familias')), findsNothing);

      await tocar(tester, find.byKey(const Key('volver_a_secciones')));
      expect(find.text('Registrar una defunción'), findsNothing);
      expect(find.text('SEGIP'), findsOneWidget);
      expect(find.byKey(const Key('volver_a_familias')), findsOneWidget);

      await tocar(tester, find.byKey(const Key('volver_a_familias')));
      expect(find.text('Denuncias'), findsOneWidget);
      expect(find.text('SEGIP'), findsNothing);
    },
  );

  testWidgets(
    'ir a la declaración la hace sonar sola, y el reproductor es una nota '
    'de voz sin copiar ni etiquetas de origen',
    (tester) async {
      final (container, _) = await montar(tester);
      final audio = container.read(audioOutputProvider) as _NoopAudio;

      await elegir(tester, 'ROBAR');
      await tocar(tester, find.byKey(const Key('siguiente_pregunta')));
      await elegir(tester, 'CELULAR');
      expect(audio.spoken, isEmpty, reason: 'nada suena antes de emitir');

      await tocar(tester, find.byKey(const Key('terminar_aqui')));
      expect(find.byType(DeclarationResultScreen), findsOneWidget);

      // Suena una sola vez, la frase del resultado.
      expect(audio.spoken, [
        container.read(translationControllerProvider).value!.generatedText,
      ]);
      expect(container.read(audioPlaybackProvider), AudioPlaybackState.playing);

      for (final quitado in const [
        'Copiar al portapapeles',
        'Refinado por IA',
        'Motor local',
        'Audio listo (Polly)',
        'Audio listo (local)',
      ]) {
        expect(find.text(quitado), findsNothing, reason: quitado);
      }
      expect(find.byIcon(Icons.copy_outlined), findsNothing);

      // La caja de la declaración es morada: no se confunde con un botón.
      final caja = tester.widget<Container>(
        find.byKey(const Key('tarjeta_declaracion')),
      );
      expect((caja.decoration! as BoxDecoration).color, AppTheme.lsbViolet);

      // Mientras suena, el botón redondo es pausa.
      final boton = find.byKey(const Key('reproducir_declaracion'));
      expect(boton, findsOneWidget);
      expect(find.bySemanticsLabel('Pausar'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tocar(tester, boton);
      expect(audio.pauses, 1);
      expect(container.read(audioPlaybackProvider), AudioPlaybackState.paused);
      expect(find.bySemanticsLabel('Reproducir'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Reanudar sigue donde quedó (sin audio remoto, vuelve a decirla).
      await tocar(tester, boton);
      expect(container.read(audioPlaybackProvider), AudioPlaybackState.playing);
    },
  );
}
