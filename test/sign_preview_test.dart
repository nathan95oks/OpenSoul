import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/audio_output.dart';
import 'package:lsb_legal_app/core/presentation/widgets/avatar_3d_viewer.dart';
import 'package:lsb_legal_app/core/presentation/widgets/shared_avatar.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/sign_preview_planner.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_preview_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/home_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/lsb_flow_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/gloss_row.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/live_declaration_preview_panel.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/sign_preview_overlay.dart';

import 'helpers/official_dictionary.dart';
import 'support/fake_webview_platform.dart';

/// Filas de respuesta del módulo LSB → texto/audio: tocar y deslizar.
///
/// Tocar una fila la elige con la lógica de siempre y tocarla otra vez la
/// quita. Deslizarla a la derecha más allá del umbral y soltar enseña al
/// avatar 3D haciendo su seña, sin elegir; no hay botón aparte. Un gesto incompleto no abre nada y desplazar la lista no hace
/// nada. Encima de los botones hay dos indicaciones animadas, no lo elegido.
/// Nada de esto avanza de pregunta, emite ni toca la red.

/// Doble del avatar: registra lo que se le pide y termina cuando la prueba lo
/// decide, sin WebView ni modelo 3D.
class _AvatarFalso {
  /// Las señas que se le pidieron. Cargarse invisible (plan vacío mientras
  /// se desliza la fila) no es hacer una seña.
  final planes = <SignPreviewPlan>[];
  int cargas = 0;
  VoidCallback? _terminar;

  Widget build(
    BuildContext context,
    SignPreviewPlan plan,
    VoidCallback onFinished,
  ) {
    cargas++;
    if (plan.glosses.isNotEmpty &&
        (planes.isEmpty || !identical(planes.last, plan))) {
      planes.add(plan);
    }
    _terminar = onFinished;
    return const ColoredBox(
      key: Key('avatar_falso'),
      color: Colors.black,
      child: SizedBox.expand(),
    );
  }

  void terminar() => _terminar?.call();
}

/// Backend de LSB → texto: cuenta las llamadas, que aquí deben ser cero.
class _Backend implements TranslationRepository {
  int llamadas = 0;

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
    llamadas++;
    return TranslationResult(
      baseSentence: '',
      generatedText: '',
      audioUrl: null,
      bedrockUsed: false,
    );
  }
}

/// Cliente HTTP compartido (Lambda de texto → LSB, léxico, sugerencias):
/// cualquier petición queda registrada.
class _Red extends http.BaseClient {
  final peticiones = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    peticiones.add(request);
    return http.StreamedResponse(const Stream.empty(), 503);
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

class _Arnes {
  final ProviderContainer container;
  final _AvatarFalso avatar;
  final _Backend backend;
  final _Red red;

  _Arnes(this.container, this.avatar, this.backend, this.red);
}

/// Si hay una vista previa a la vista (la que se carga mientras se desliza
/// es invisible).
bool _vistaPreviaVisible(WidgetTester tester) => tester
    .widgetList<Opacity>(
      find.descendant(
        of: find.byType(SignPreviewOverlay),
        matching: find.byType(Opacity),
      ),
    )
    .any((o) => o.opacity > 0);

Finder _fila(String formulacion) =>
    find.ancestor(of: find.text(formulacion), matching: find.byType(GlossRow));

Finder _enFila(String formulacion, Finder f) =>
    find.descendant(of: _fila(formulacion), matching: f);

/// Cuánto está desplazada la fila, como fracción de su ancho.
double _desplazamiento(WidgetTester tester, String formulacion) => tester
    .widget<FractionalTranslation>(
      _enFila(formulacion, find.byType(FractionalTranslation)),
    )
    .translation
    .dx;

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_Arnes> montar(
    WidgetTester tester, {
    bool avatarReal = false,
    Size? tamano,
  }) async {
    if (tamano != null) {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final avatar = _AvatarFalso();
    final backend = _Backend();
    final red = _Red();
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
        httpClientProvider.overrideWithValue(red),
        audioOutputProvider.overrideWithValue(_NoopAudio()),
        lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
        signImagesEnabledProvider.overrideWith(_SinImagenes.new),
        if (!avatarReal)
          signPreviewPlayerProvider.overrideWithValue(avatar.build),
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
          // Con el avatar real, como en la app: uno solo, en la raíz.
          builder: avatarReal
              ? (context, child) => SharedAvatarHost(child: child!)
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _Arnes(container, avatar, backend, red);
  }

  /// Si la opción que se ve como [formulacion] está elegida en la pregunta
  /// activa.
  bool elegida(ProviderContainer container, String formulacion) {
    final session = container.read(guidedFlowProvider).session!;
    final questionId = session.currentQuestionId!;
    final option = container
        .read(questionBankProvider)
        .question(questionId)!
        .options
        .firstWhere((o) => o.displayFormulation == formulacion);
    return session.isSelected(questionId, option.id);
  }

  String? preguntaActual(ProviderContainer c) =>
      c.read(guidedFlowProvider).session!.currentQuestionId;

  /// Toca la fila: elige o quita.
  Future<void> tocar(WidgetTester tester, String formulacion) async {
    await tester.ensureVisible(_fila(formulacion));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: _fila(formulacion), matching: find.text(formulacion)),
    );
    await tester.pumpAndSettle();
  }

  /// Apoya el dedo en la fila y lo arrastra en horizontal [fraccion] de su
  /// ancho, en pasos. Devuelve el gesto sin soltar.
  Future<TestGesture> arrastrar(
    WidgetTester tester,
    String formulacion,
    double fraccion,
  ) async {
    final rect = tester.getRect(_fila(formulacion));
    final gesto = await tester.startGesture(
      Offset(rect.left + 40, rect.center.dy),
    );
    await tester.pump();
    const pasos = 12;
    for (var i = 0; i < pasos; i++) {
      await gesto.moveBy(Offset(rect.width * fraccion / pasos, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    return gesto;
  }

  /// Desliza la fila entera: el avatar 3D.
  Future<void> ver(
    WidgetTester tester,
    String formulacion, [
    double fraccion = 0.6,
  ]) async {
    await tester.ensureVisible(_fila(formulacion));
    await tester.pumpAndSettle();
    final gesto = await arrastrar(tester, formulacion, fraccion);
    await gesto.up();
    await tester.pumpAndSettle();
  }

  /// Desliza la fila sin esperar a que todo se quede quieto: con el avatar
  /// real, «Cargando avatar…» gira hasta que el modelo carga.
  Future<void> verConAvatarReal(WidgetTester tester, String formulacion) async {
    await tester.ensureVisible(_fila(formulacion));
    await tester.pumpAndSettle();
    final gesto = await arrastrar(tester, formulacion, 0.6);
    await gesto.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> cerrarAlTerminar(
    WidgetTester tester,
    _AvatarFalso avatar,
  ) async {
    avatar.terminar();
    await tester.pump(SignPreviewOverlay.closeDelay);
    await tester.pumpAndSettle();
  }

  group('tocar: elegir y quitar', () {
    testWidgets('tocar elige y la fila queda marcada, sin abrir el avatar', (
      tester,
    ) async {
      final arnes = await montar(tester);
      await tocar(tester, 'ROBAR');

      expect(elegida(arnes.container, 'ROBAR'), isTrue);
      expect(
        _enFila('ROBAR', find.byKey(const Key('fila_elegida'))),
        findsOneWidget,
      );
      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(arnes.avatar.planes, isEmpty);
      // Sin botón de flecha en la fila: el avatar se abre deslizando.
      expect(_enFila('ROBAR', find.byType(IconButton)), findsNothing);
      expect(find.byKey(const Key('flecha_avatar')), findsNothing);
    });

    testWidgets('tocar otra vez una fila elegida la quita', (tester) async {
      final arnes = await montar(tester);
      await tocar(tester, 'ROBAR');
      expect(elegida(arnes.container, 'ROBAR'), isTrue);

      await tocar(tester, 'ROBAR');
      expect(elegida(arnes.container, 'ROBAR'), isFalse);
      expect(
        _enFila('ROBAR', find.byKey(const Key('fila_elegida'))),
        findsNothing,
      );
      expect(
        arnes.container.read(guidedFlowProvider).session!.answers,
        isEmpty,
      );
    });

    testWidgets('en selección múltiple se eligen y se quitan de una en una', (
      tester,
    ) async {
      final arnes = await montar(tester);
      await tocar(tester, 'ROBAR');
      await tester.tap(find.byKey(const Key('siguiente_pregunta')));
      await tester.pumpAndSettle();
      await tocar(tester, 'CELULAR');
      await tocar(tester, 'MOCHILA');
      final session = arnes.container.read(guidedFlowProvider).session!;
      expect(session.answerOf('Q.ROB.QUE')!.optionIds, ['celular', 'mochila']);

      await tocar(tester, 'CELULAR');
      final despues = arnes.container.read(guidedFlowProvider).session!;
      expect(despues.answerOf('Q.ROB.QUE')!.optionIds, ['mochila']);
      expect(despues.answerOf('Q.HEC.QUE_OCURRIO')!.optionIds, ['robar']);
      expect(despues.currentQuestionId, 'Q.ROB.QUE', reason: 'no navega');
      expect(arnes.backend.llamadas, 0);
    });

    testWidgets('quitar una respuesta borra lo que dependía de ella y lo '
        'avisa', (tester) async {
      final arnes = await montar(tester);
      await tocar(tester, 'ROBAR');
      await tester.tap(find.byKey(const Key('siguiente_pregunta')));
      await tester.pumpAndSettle();
      await tocar(tester, 'CELULAR');
      await tester.tap(find.byKey(const Key('anterior_pregunta')));
      await tester.pumpAndSettle();

      await tocar(tester, 'ROBAR');

      expect(
        arnes.container.read(guidedFlowProvider).session!.answers,
        isEmpty,
      );
      expect(
        find.text('Se borraron respuestas que dependían de lo que cambiaste.'),
        findsOneWidget,
      );
      // El aviso se retira solo.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('elegir no avanza de pregunta ni emite; lo obligatorio sigue '
        'pidiéndose', (tester) async {
      final arnes = await montar(tester);
      final pregunta = preguntaActual(arnes.container);

      await tocar(tester, 'ESCAPAR');
      expect(elegida(arnes.container, 'ESCAPAR'), isTrue);
      expect(preguntaActual(arnes.container), pregunta);
      expect(arnes.backend.llamadas, 0);
      expect(arnes.container.read(sentenceProvider), ['ESCAPAR']);
      // «Alguien escapó» exige «¿quién?»: no se puede terminar todavía.
      expect(
        arnes.container
            .read(guidedFlowRulesProvider)
            .canFinish(arnes.container.read(guidedFlowProvider).session!),
        isFalse,
      );
      await tester.tap(find.byKey(const Key('terminar_aqui')));
      await tester.pumpAndSettle();
      expect(arnes.backend.llamadas, 0);
    });

    testWidgets('lo elegido se conserva al ir y volver entre preguntas', (
      tester,
    ) async {
      final arnes = await montar(tester);
      await tocar(tester, 'ROBAR');
      await tester.tap(find.byKey(const Key('siguiente_pregunta')));
      await tester.pumpAndSettle();
      await tocar(tester, 'CELULAR');
      final vistaPrevia = arnes.container.read(guidedPreviewProvider);
      expect(vistaPrevia, 'Me robaron el celular.');

      await tester.tap(find.byKey(const Key('anterior_pregunta')));
      await tester.pumpAndSettle();
      expect(elegida(arnes.container, 'ROBAR'), isTrue);
      await tester.tap(find.byKey(const Key('siguiente_pregunta')));
      await tester.pumpAndSettle();
      expect(elegida(arnes.container, 'CELULAR'), isTrue);
      expect(arnes.container.read(guidedPreviewProvider), vistaPrevia);
    });

    testWidgets('desplazar la lista en vertical no elige ni abre el avatar', (
      tester,
    ) async {
      final arnes = await montar(tester, tamano: const Size(400, 640));
      await tocar(tester, 'ROBAR');
      await tester.tap(find.byKey(const Key('siguiente_pregunta')));
      await tester.pumpAndSettle();
      expect(preguntaActual(arnes.container), 'Q.ROB.QUE');

      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('guided_options_scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));

      // Vertical puro y diagonal con más recorrido vertical.
      for (final paso in const [Offset(0, -12), Offset(5, -12)]) {
        final gesto = await tester.startGesture(
          tester.getCenter(_fila('CELULAR')),
        );
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          await gesto.moveBy(paso);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesto.up();
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, greaterThan(0), reason: '$paso');
        scroll.position.jumpTo(0);
        await tester.pumpAndSettle();
      }

      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(arnes.avatar.planes, isEmpty);
      expect(
        arnes.container.read(guidedFlowProvider).session!.answerOf('Q.ROB.QUE'),
        isNull,
        reason: 'desplazar no elige ninguna fila',
      );
    });
  });

  group('deslizar: avatar 3D', () {
    testWidgets('pasar el umbral y soltar abre el avatar con su seña, no '
        'elige y la fila vuelve a su sitio', (tester) async {
      final arnes = await montar(tester);
      final antes = tester.getRect(_fila('ROBAR'));

      final gesto = await arrastrar(tester, 'ROBAR', 0.5);
      // Durante el gesto se ve el avance y que soltar ya abre el avatar.
      expect(_desplazamiento(tester, 'ROBAR'), greaterThan(0.35));
      expect(find.byKey(const Key('pista_avatar')), findsOneWidget);
      expect(find.text('Suelta para ver el avatar'), findsOneWidget);
      expect(_vistaPreviaVisible(tester), isFalse, reason: 'aún no se ve');

      await gesto.up();
      await tester.pumpAndSettle();
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      final plan = arnes.avatar.planes.single;
      expect(plan.glosses, ['ROBAR']);
      expect(plan.animationGlosses, ['ROBAR']);
      expect(plan.missingGlosses, isEmpty);
      expect(elegida(arnes.container, 'ROBAR'), isFalse);
      expect(_desplazamiento(tester, 'ROBAR'), 0);
      expect(tester.getRect(_fila('ROBAR')), antes);
      expect(find.byKey(const Key('pista_avatar')), findsNothing);
    });

    testWidgets('al empezar a deslizar el avatar se carga invisible y, al '
        'pasar el umbral, es ese mismo el que hace la seña', (tester) async {
      final arnes = await montar(tester);
      final gesto = await arrastrar(tester, 'ROBAR', 0.2);
      // Cargándose, sin verse ni hacer ninguna seña.
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      expect(_vistaPreviaVisible(tester), isFalse);
      expect(arnes.avatar.planes, isEmpty);
      expect(arnes.avatar.cargas, greaterThan(0));
      final visor = tester.element(find.byKey(const Key('avatar_falso')));

      final rect = tester.getRect(_fila('ROBAR'));
      for (var i = 0; i < 6; i++) {
        await gesto.moveBy(Offset(rect.width * 0.05, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesto.up();
      await tester.pumpAndSettle();

      expect(_vistaPreviaVisible(tester), isTrue);
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      expect(arnes.avatar.planes.single.glosses, ['ROBAR']);
      expect(
        tester.element(find.byKey(const Key('avatar_falso'))),
        same(visor),
        reason: 'no se vuelve a crear el visor: ya estaba cargado',
      );
      expect(elegida(arnes.container, 'ROBAR'), isFalse);
    });

    testWidgets('soltar antes del umbral descarta lo que se estaba cargando', (
      tester,
    ) async {
      final arnes = await montar(tester);
      final gesto = await arrastrar(tester, 'PERDER', 0.2);
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      await gesto.up();
      await tester.pumpAndSettle();
      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(arnes.avatar.planes, isEmpty);
      expect(
        arnes.container.read(signPreviewControllerProvider).isShowing,
        isFalse,
      );
    });

    testWidgets('desplazar la lista mientras se cargaba descarta la carga', (
      tester,
    ) async {
      final arnes = await montar(tester);
      final gesto = await arrastrar(tester, 'PERDER', 0.2);
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await gesto.up();
      expect(arnes.avatar.planes, isEmpty);
    });

    testWidgets('un deslizamiento incompleto no abre nada', (tester) async {
      final arnes = await montar(tester);
      final gesto = await arrastrar(tester, 'PERDER', 0.2);
      expect(_desplazamiento(tester, 'PERDER'), greaterThan(0));
      expect(find.text('Avatar 3D'), findsOneWidget, reason: 'avance visible');
      expect(find.text('Suelta para ver el avatar'), findsNothing);

      await gesto.up();
      await tester.pumpAndSettle();
      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(elegida(arnes.container, 'PERDER'), isFalse);
      expect(_desplazamiento(tester, 'PERDER'), 0);
    });

    testWidgets('pasar el umbral y volver antes de soltar no abre nada', (
      tester,
    ) async {
      final arnes = await montar(tester);
      final rect = tester.getRect(_fila('PERDER'));
      final gesto = await arrastrar(tester, 'PERDER', 0.55);
      expect(find.text('Suelta para ver el avatar'), findsOneWidget);
      for (var i = 0; i < 10; i++) {
        await gesto.moveBy(Offset(-rect.width * 0.05, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Suelta para ver el avatar'), findsNothing);
      await gesto.up();
      await tester.pumpAndSettle();
      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(arnes.avatar.planes, isEmpty);
    });

    testWidgets('deslizar a la izquierda no mueve ni abre nada', (
      tester,
    ) async {
      final arnes = await montar(tester);
      await ver(tester, 'DAÑAR', -0.6);
      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(elegida(arnes.container, 'DAÑAR'), isFalse);
      expect(_desplazamiento(tester, 'DAÑAR'), 0);
    });

    testWidgets('deslizar una fila elegida no la quita', (tester) async {
      final arnes = await montar(tester);
      await tocar(tester, 'ROBAR');
      await ver(tester, 'ROBAR');
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      await cerrarAlTerminar(tester, arnes.avatar);
      expect(elegida(arnes.container, 'ROBAR'), isTrue);
    });

    testWidgets('la cruz cierra la vista previa sin elegir', (tester) async {
      final arnes = await montar(tester);
      await ver(tester, 'PERDER');
      expect(find.byType(SignPreviewOverlay), findsOneWidget);

      await tester.tap(find.byKey(const Key('cerrar_vista_previa')));
      await tester.pumpAndSettle();

      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(elegida(arnes.container, 'PERDER'), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('tocar fuera cierra la vista previa sin elegir', (
      tester,
    ) async {
      final arnes = await montar(tester);
      await ver(tester, 'ROBAR');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(elegida(arnes.container, 'ROBAR'), isFalse);
    });

    testWidgets('el fin de la seña cierra la capa sola', (tester) async {
      final arnes = await montar(tester);
      await ver(tester, 'DAÑAR');
      expect(find.byType(SignPreviewOverlay), findsOneWidget);

      arnes.avatar.terminar();
      await tester.pump();
      // Un respiro para que el último gesto no se corte en seco.
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      await tester.pump(SignPreviewOverlay.closeDelay);
      await tester.pumpAndSettle();
      expect(find.byType(SignPreviewOverlay), findsNothing);
    });

    testWidgets('con el avatar real, el fin de la secuencia cierra la capa', (
      tester,
    ) async {
      final arnes = await montar(tester, avatarReal: true);
      await verConAvatarReal(tester, 'ROBAR');

      final visor = tester.widget<Avatar3DViewer>(find.byType(Avatar3DViewer));
      expect(visor.glosses, ['ROBAR']);
      expect(visor.showControls, isFalse, reason: 'sin volver ni repetir');
      expect(visor.animationUrls, [
        '${AnimationUrlResolver.defaultBaseUrl}'
            '${AnimationUrlResolver.bundledModelFileName}',
      ]);

      // Sin WebView real el modelo nunca termina de cargar: la seña espera
      // diciéndolo, en vez de perderse a los 6 s con el visor vacío.
      await tester.pump();
      expect(find.text('Cargando avatar…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      expect(_vistaPreviaVisible(tester), isTrue, reason: 'la seña espera');
      expect(find.text('Cargando avatar…'), findsOneWidget);

      // Si no carga nunca (un equipo sin WebView), el reloj de carga cierra.
      await tester.pump(const Duration(seconds: 19));
      await tester.pump(SignPreviewOverlay.closeDelay);
      await tester.pumpAndSettle();

      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(elegida(arnes.container, 'ROBAR'), isFalse);
    });

    testWidgets('una opción de varias glosas se previsualiza entera y en '
        'orden', (tester) async {
      final arnes = await montar(tester);
      await tocar(tester, 'ROBAR');
      await tester.tap(find.byKey(const Key('siguiente_pregunta')));
      await tester.pumpAndSettle();

      await ver(tester, 'PAPEL · IDENTIDAD');

      final plan = arnes.avatar.planes.single;
      expect(plan.glosses, ['PAPEL', 'IDENTIDAD']);
      expect(plan.animationGlosses, ['PAPEL', 'IDENTIDAD']);
      expect(elegida(arnes.container, 'PAPEL · IDENTIDAD'), isFalse);
      await cerrarAlTerminar(tester, arnes.avatar);
    });

    testWidgets('una seña sin animación lo dice en la fila y al deslizarla '
        'avisa sin abrir nada ni llamar a la red', (tester) async {
      final arnes = await montar(tester);
      expect(
        _enFila('ESCAPAR', find.byKey(const Key('sin_animacion'))),
        findsOneWidget,
      );
      expect(
        _enFila('ROBAR', find.byKey(const Key('sin_animacion'))),
        findsNothing,
      );

      await ver(tester, 'ESCAPAR');
      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(arnes.avatar.planes, isEmpty);
      expect(find.text('Seña no disponible'), findsOneWidget);
      expect(elegida(arnes.container, 'ESCAPAR'), isFalse);
      expect(arnes.red.peticiones, isEmpty);
      expect(arnes.backend.llamadas, 0);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Seña no disponible'), findsNothing);
    });

    testWidgets('una secuencia a medias se reproduce con su respaldo y dice '
        'qué falta', (tester) async {
      final arnes = await montar(tester);
      final controller = arnes.container.read(signPreviewControllerProvider);
      controller.show(tester.element(find.byType(HomeScreen)), const [
        'ESCAPAR',
        'DÓNDE',
      ]);
      await tester.pumpAndSettle();

      final plan = arnes.avatar.planes.single;
      expect(plan.animationGlosses, ['ESCAPAR', 'DÓNDE']);
      expect(plan.missingGlosses, ['ESCAPAR']);
      expect(find.text('Sin animación en el avatar: ESCAPAR'), findsOneWidget);
      await cerrarAlTerminar(tester, arnes.avatar);
    });

    testWidgets('abrir otra vista previa cierra la anterior', (tester) async {
      final arnes = await montar(tester);
      final controller = arnes.container.read(signPreviewControllerProvider);
      final context = tester.element(find.byType(HomeScreen));

      var primeraCerrada = false;
      controller.show(context, const ['ROBAR']).then((_) {
        primeraCerrada = true;
      });
      await tester.pumpAndSettle();
      expect(controller.isShowing, isTrue);

      controller.show(context, const ['PERDER']);
      await tester.pumpAndSettle();

      expect(primeraCerrada, isTrue);
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      expect(
        tester
            .widget<SignPreviewOverlay>(find.byType(SignPreviewOverlay))
            .plan
            .glosses,
        ['PERDER'],
      );
      await cerrarAlTerminar(tester, arnes.avatar);
      expect(controller.isShowing, isFalse);
    });

    testWidgets('desmontar con la vista previa abierta no deja relojes '
        'vivos', (tester) async {
      final arnes = await montar(tester);
      await ver(tester, 'ROBAR');
      arnes.avatar.terminar();
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('avatar compartido', () {
    Avatar3DViewer visor(WidgetTester tester) =>
        tester.widget<Avatar3DViewer>(find.byType(Avatar3DViewer));

    testWidgets('hay un solo avatar en toda la app, cargado desde el '
        'principio y quieto mientras nadie lo usa', (tester) async {
      await montar(tester, avatarReal: true);
      expect(find.byType(Avatar3DViewer), findsOneWidget);
      expect(visor(tester).glosses, isNull);
      expect(visor(tester).isUserComposing, isTrue, reason: 'sin reposo');
    });

    testWidgets('cada vista previa usa ese mismo avatar, en esta pantalla y '
        'en la siguiente, sin volver a cargarlo', (tester) async {
      final arnes = await montar(tester, avatarReal: true);
      final cargado = tester.element(find.byType(Avatar3DViewer));

      await verConAvatarReal(tester, 'ROBAR');
      expect(visor(tester).glosses, ['ROBAR']);
      expect(visor(tester).isUserComposing, isFalse);
      expect(visor(tester).showControls, isFalse);
      expect(find.byType(Avatar3DViewer), findsOneWidget);
      expect(tester.element(find.byType(Avatar3DViewer)), same(cargado));

      await tester.tap(find.byKey(const Key('cerrar_vista_previa')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(visor(tester).glosses, isNull, reason: 'escondido otra vez');
      expect(tester.element(find.byType(Avatar3DViewer)), same(cargado));

      arnes.container
        ..read(guidedFlowProvider.notifier).select('Q.HEC.QUE_OCURRIO', 'robar')
        ..read(guidedFlowProvider.notifier).goNext();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await verConAvatarReal(tester, 'CELULAR');
      expect(visor(tester).glosses, ['CELULAR']);
      expect(tester.element(find.byType(Avatar3DViewer)), same(cargado));
    });

    testWidgets('el avatar sigue a su lugar y lo tiene el último lugar '
        'visible', (tester) async {
      final pedidos = <String>[];
      Widget lugar(String nombre, {bool activo = true}) => SizedBox(
        width: 200,
        height: 150,
        child: SharedAvatarSlot(
          key: ValueKey(nombre),
          active: activo,
          expandToFit: true,
          request: AvatarRequest(
            glosses: [nombre],
            animationUrls: ['${AnimationUrlResolver.placeholderScheme}$nombre'],
            onPlaybackStateChanged: (p) => pedidos.add('$nombre:$p'),
          ),
        ),
      );
      Future<void> pintar(Widget cuerpo) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => SharedAvatarHost(child: child!),
              home: Scaffold(body: cuerpo),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      await pintar(Column(children: [lugar('UNO'), lugar('DOS')]));
      expect(visor(tester).glosses, ['DOS'], reason: 'el último visible');
      // El avatar se dibuja encima de su lugar, con su tamaño.
      expect(
        tester.getTopLeft(find.byType(Avatar3DViewer)),
        tester.getTopLeft(find.byKey(const ValueKey('DOS'))),
      );
      expect(tester.getSize(find.byType(Avatar3DViewer)), const Size(200, 150));

      // Si DOS deja de estar a la vista, UNO lo recupera.
      await pintar(
        Column(children: [lugar('UNO'), lugar('DOS', activo: false)]),
      );
      expect(visor(tester).glosses, ['UNO']);
      expect(
        tester.getTopLeft(find.byType(Avatar3DViewer)),
        tester.getTopLeft(find.byKey(const ValueKey('UNO'))),
      );

      // Una pestaña oculta de un IndexedStack no lo pide.
      await pintar(
        IndexedStack(
          index: 0,
          children: [lugar('UNO', activo: false), lugar('DOS')],
        ),
      );
      expect(visor(tester).glosses, isNull);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('sin anfitrión en la app, el lugar dibuja su propio avatar', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SharedAvatarSlot(
                request: AvatarRequest(
                  glosses: const ['HOLA'],
                  animationUrls: const [
                    '${AnimationUrlResolver.placeholderScheme}HOLA',
                  ],
                  animationDuration: const Duration(milliseconds: 1),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(visor(tester).glosses, ['HOLA']);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('indicaciones sobre los botones', () {
    testWidgets('en lugar de lo elegido, dos indicaciones animadas', (
      tester,
    ) async {
      final arnes = await montar(tester);
      await tocar(tester, 'ROBAR');
      expect(elegida(arnes.container, 'ROBAR'), isTrue);

      // Lo elegido ya no se repite encima de los botones.
      expect(find.byKey(const Key('resumen_composicion')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(LiveDeclarationPreviewPanel),
          matching: find.text('ROBAR'),
        ),
        findsNothing,
      );
      expect(find.text('Presiona para seleccionar'), findsOneWidget);
      expect(find.text('Desliza para avatar 3D'), findsOneWidget);
      final indicaciones = tester.getRect(
        find.byKey(const Key('indicaciones_filas')),
      );
      final siguiente = tester.getRect(
        find.byKey(const Key('siguiente_pregunta')),
      );
      expect(indicaciones.bottom, lessThanOrEqualTo(siguiente.top));
    });

    testWidgets('solo en la primera pantalla con glosas de la declaración', (
      tester,
    ) async {
      final arnes = await montar(tester);
      final indicaciones = find.byKey(const Key('indicaciones_filas'));
      expect(indicaciones, findsOneWidget, reason: 'primera pantalla');

      await tocar(tester, 'ROBAR');
      await tester.tap(find.byKey(const Key('siguiente_pregunta')));
      await tester.pumpAndSettle();
      expect(preguntaActual(arnes.container), 'Q.ROB.QUE');
      expect(indicaciones, findsNothing, reason: 'segunda pantalla');

      await tocar(tester, 'CELULAR');
      await tester.tap(find.byKey(const Key('siguiente_pregunta')));
      await tester.pumpAndSettle();
      expect(indicaciones, findsNothing, reason: 'tercera pantalla');

      // Una declaración nueva vuelve a enseñarlas en su primera pantalla.
      arnes.container.read(guidedFlowProvider.notifier).reset();
      await tester.pumpAndSettle();
      expect(indicaciones, findsOneWidget);
    });
  });

  group('lo que no cambia', () {
    testWidgets('Atrás, Traducir y Adelante no se mueven con la vista previa', (
      tester,
    ) async {
      final arnes = await montar(tester);
      await tocar(tester, 'ROBAR');

      const botones = [
        Key('anterior_pregunta'),
        Key('terminar_aqui'),
        Key('siguiente_pregunta'),
      ];
      Map<Key, Rect> rects() => {
        for (final k in botones) k: tester.getRect(find.byKey(k)),
      };
      final antes = rects();

      await ver(tester, 'PERDER');
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      expect(rects(), antes, reason: 'con el avatar abierto');
      await cerrarAlTerminar(tester, arnes.avatar);
      expect(rects(), antes, reason: 'al cerrar');

      final antesDeAvanzar = preguntaActual(arnes.container);
      await tester.tap(find.byKey(const Key('siguiente_pregunta')));
      await tester.pumpAndSettle();
      expect(preguntaActual(arnes.container), isNot(antesDeAvanzar));
      await tester.tap(find.byKey(const Key('anterior_pregunta')));
      await tester.pumpAndSettle();
      expect(preguntaActual(arnes.container), antesDeAvanzar);
    });

    testWidgets('la vista previa no cambia la navegación guiada ni la '
        'declaración', (tester) async {
      final arnes = await montar(tester);
      await tocar(tester, 'ROBAR');
      final container = arnes.container;
      final pregunta = preguntaActual(container);
      final vistaPrevia = container.read(guidedPreviewProvider);
      final glosas = container.read(sentenceProvider);

      await ver(tester, 'PERDER');
      await cerrarAlTerminar(tester, arnes.avatar);
      await ver(tester, 'ROBAR');
      await cerrarAlTerminar(tester, arnes.avatar);

      expect(preguntaActual(container), pregunta);
      expect(container.read(guidedPreviewProvider), vistaPrevia);
      expect(container.read(sentenceProvider), glosas);
      expect(arnes.backend.llamadas, 0, reason: 'no se emite nada');
    });

    testWidgets('la vista previa no toca Conversation ni la red', (
      tester,
    ) async {
      final arnes = await montar(tester);
      final conversacion = arnes.container.read(conversationProvider);

      await ver(tester, 'ROBAR');
      await cerrarAlTerminar(tester, arnes.avatar);

      expect(
        identical(arnes.container.read(conversationProvider), conversacion),
        isTrue,
      );
      expect(arnes.container.read(pendingReplyProvider), isNull);
      expect(arnes.red.peticiones, isEmpty);
      expect(arnes.backend.llamadas, 0);
    });
  });

  group('fila aislada', () {
    LsbCard card(String id) => LsbCard(
      id: id,
      gloss: id,
      displayText: id,
      iconUrl: '',
      categoryId: '',
      subcategoryId: '',
      contexts: const [],
      priority: 0,
      suggestedNextCardIds: const [],
      isFrequent: false,
      isEmergency: false,
    );

    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      MediaQueryData? media,
    }) async {
      Widget cuerpo = Scaffold(body: child);
      if (media != null) cuerpo = MediaQuery(data: media, child: cuerpo);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [signImagesEnabledProvider.overrideWith(_SinImagenes.new)],
          child: MaterialApp(home: cuerpo),
        ),
      );
      await tester.pump();
    }

    testWidgets('un mismo deslizamiento abre el avatar una sola vez y no '
        'elige', (tester) async {
      var elecciones = 0;
      final vistas = <String>[];
      await pump(
        tester,
        GlossRowList(
          cards: [card('A1')],
          onToggle: (_) async {
            elecciones++;
            return true;
          },
          onPreview: (c) => vistas.add(c.id),
        ),
      );
      final rect = tester.getRect(find.byType(GlossRow));
      final gesto = await tester.startGesture(
        Offset(rect.left + 40, rect.center.dy),
      );
      await tester.pump();
      // Cruza el umbral varias veces en el mismo gesto.
      for (final dx in const [0.5, -0.3, 0.3, -0.3, 0.4]) {
        for (var i = 0; i < 6; i++) {
          await gesto.moveBy(Offset(rect.width * dx / 6, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      await gesto.up();
      await tester.pumpAndSettle();
      expect(vistas, ['A1']);
      expect(elecciones, 0);
    });

    testWidgets('mientras una elección está en curso, otro toque no la '
        'cambia', (tester) async {
      final pendiente = Completer<bool>();
      var elecciones = 0;
      await pump(
        tester,
        GlossRowList(
          cards: [card('A1')],
          onToggle: (_) {
            elecciones++;
            return pendiente.future;
          },
        ),
      );
      await tester.tap(find.text('A1'));
      await tester.pump();
      await tester.tap(find.text('A1'));
      await tester.pump();
      expect(elecciones, 1);

      pendiente.complete(true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('A1'));
      await tester.pumpAndSettle();
      expect(elecciones, 2, reason: 'terminada la anterior, se puede otra');
    });

    testWidgets('con el margen de arrastre de Android, desplazar no elige ni '
        'abre el avatar', (tester) async {
      final vistas = <String>[];
      final elegidas = <String>[];
      await pump(
        tester,
        SingleChildScrollView(
          child: GlossRowList(
            cards: [for (var i = 0; i < 30; i++) card('C$i')],
            onToggle: (c) async {
              elegidas.add(c.id);
              return true;
            },
            onPreview: (c) => vistas.add(c.id),
          ),
        ),
        // En Android el margen de arrastre de la plataforma es menor que el
        // del toque (18 px).
        media: const MediaQueryData(
          size: Size(800, 600),
          gestureSettings: DeviceGestureSettings(touchSlop: 4),
        ),
      );

      final gesto = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('C3'))),
      );
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await gesto.moveBy(const Offset(1, -8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesto.up();
      await tester.pumpAndSettle();

      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(0),
      );
      expect(vistas, isEmpty);
      expect(elegidas, isEmpty);
    });

    testWidgets(
      'accesibilidad: tocar elige y «Ver en avatar 3D» previsualiza',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final elegidas = <String>[];
        final vistas = <String>[];
        await pump(
          tester,
          GlossRowList(
            cards: [card('A1')],
            onToggle: (c) async {
              elegidas.add(c.id);
              return true;
            },
            onPreview: (c) => vistas.add(c.id),
          ),
        );

        final nodo = tester.getSemantics(find.byType(GlossRow));
        final datos = nodo.getSemanticsData();
        expect(datos.label, 'A1');
        expect(datos.hasAction(SemanticsAction.tap), isTrue);
        expect(datos.hasAction(SemanticsAction.customAction), isTrue);
        expect(
          datos.hasAction(SemanticsAction.scrollRight),
          isFalse,
          reason: 'deslizar no se anuncia como desplazar',
        );
        expect(nodo.hintOverrides?.onTapHint, 'elegir');

        tester.semantics.tap(find.semantics.byLabel('A1'));
        await tester.pumpAndSettle();
        expect(elegidas, ['A1']);
        expect(vistas, isEmpty, reason: 'tocar no abre el avatar');

        tester.semantics.customAction(
          find.semantics.byLabel('A1'),
          const CustomSemanticsAction(label: 'Ver en avatar 3D'),
        );
        await tester.pumpAndSettle();
        expect(vistas, ['A1']);
        expect(elegidas, ['A1']);
        semantics.dispose();
      },
    );

    /// Dónde está ahora el icono de «Desliza para avatar 3D».
    double posicionDeslizar(WidgetTester tester) => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byKey(const Key('pista_deslizar')),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .getTranslation()
        .x;

    testWidgets('las indicaciones se animan unas veces y se quedan quietas', (
      tester,
    ) async {
      await pump(tester, const GlossGestureHints());
      final inicio = posicionDeslizar(tester);
      await tester.pump(GlossGestureHints.cycleDuration * 0.4);
      expect(posicionDeslizar(tester), isNot(inicio), reason: 'se mueve');

      // Cuadro a cuadro: cada vuelta arranca al terminar la anterior.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final quieta = posicionDeslizar(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(posicionDeslizar(tester), quieta, reason: 'ya no se mueve');
      expect(find.text('Presiona para seleccionar'), findsOneWidget);
      expect(find.text('Desliza para avatar 3D'), findsOneWidget);
    });

    testWidgets('sin animaciones del sistema, las indicaciones no se mueven', (
      tester,
    ) async {
      await pump(
        tester,
        const GlossGestureHints(),
        media: const MediaQueryData(
          size: Size(800, 600),
          disableAnimations: true,
        ),
      );
      final inicio = posicionDeslizar(tester);
      await tester.pump(GlossGestureHints.cycleDuration * 0.4);
      expect(posicionDeslizar(tester), inicio);
      expect(find.text('Desliza para avatar 3D'), findsOneWidget);
    });
  });

  group('planificador', () {
    const planner = SignPreviewPlanner();

    test(
      'una secuencia conserva su orden y deletrea lo que ya se deletrea',
      () {
        final plan = planner.plan(const ['YO', 'AUDIENCIA', 'SABER', 'QUERER']);
        expect(plan.glosses, ['YO', 'AUDIENCIA', 'SABER', 'QUERER']);
        expect(plan.animationGlosses, [
          'YO',
          ...'AUDIENCIA'.split(''),
          'SABER',
          'QUERER',
        ]);
        expect(plan.animationUrls, hasLength(plan.animationGlosses.length));
        expect(plan.isPlayable, isTrue);
      },
    );

    test('una glosa sin clip no se inventa: queda como marcador', () {
      final plan = planner.plan(const ['ESCAPAR']);
      expect(plan.missingGlosses, ['ESCAPAR']);
      expect(plan.animationUrls, [
        '${AnimationUrlResolver.placeholderScheme}ESCAPAR',
      ]);
      expect(plan.isPlayable, isFalse);
      expect(planner.plan(const []).isPlayable, isFalse);
    });

    test('una secuencia a medias se reproduce con su marcador en su sitio', () {
      final plan = planner.plan(const ['ESCAPAR', 'DÓNDE']);
      expect(plan.animationGlosses, ['ESCAPAR', 'DÓNDE']);
      expect(plan.missingGlosses, ['ESCAPAR']);
      expect(
        plan.animationUrls.first,
        startsWith(AnimationUrlResolver.placeholderScheme),
      );
      expect(plan.isPlayable, isTrue);
    });

    test('tildes, eñes y dígitos usan el clip horneado', () {
      for (final g in ['SÍ', 'DAÑAR', '1', 'CUÁNDO']) {
        expect(planner.plan([g]).isPlayable, isTrue, reason: g);
      }
      expect(AnimationUrlResolver.animationNameFor('DAÑAR'), 'DANAR');
    });
  });

  test(
    'la lista del resolutor coincide con los clips del .glb empaquetado',
    () {
      // Los movimientos de reposo (NEUTRO1..3) no son señas.
      final clips = _clipsDelGlb(
        'assets/models/avatar_test.glb',
      ).where((c) => !c.startsWith('NEUTRO')).toList();
      expect(clips, hasLength(154));
      for (final clip in clips) {
        expect(
          AnimationUrlResolver.available3DGlosses,
          contains(clip),
          reason: '$clip está horneado y el cliente no lo sabe',
        );
      }
      for (final glosa in AnimationUrlResolver.available3DGlosses) {
        expect(
          clips,
          contains(AnimationUrlResolver.animationNameFor(glosa)),
          reason: '$glosa no tiene clip en el modelo',
        );
      }
    },
  );
}

/// Nombres de las animaciones de un .glb: cabecera de 12 bytes y primer
/// chunk JSON con la escena.
Set<String> _clipsDelGlb(String path) {
  final file = File(path).openSync();
  try {
    final cabecera = file.readSync(20);
    final datos = ByteData.sublistView(cabecera);
    expect(utf8.decode(cabecera.sublist(0, 4)), 'glTF');
    final largo = datos.getUint32(12, Endian.little);
    final json = jsonDecode(utf8.decode(file.readSync(largo)));
    return {
      for (final a in (json['animations'] as List))
        (a as Map)['name'] as String,
    };
  } finally {
    file.closeSync();
  }
}
