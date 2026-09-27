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
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/sign_preview_planner.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_preview_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/home_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/lsb_flow_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/adaptive_node_layout.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/semantic_node.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/sign_preview_overlay.dart';

import 'helpers/official_dictionary.dart';
import 'support/fake_webview_platform.dart';

/// Vista previa de la seña al mantener una tarjeta del módulo LSB → texto/audio.
///
/// Un toque corto sigue eligiendo y quitando como siempre; mantener la
/// tarjeta 1,5 s llena la tarjeta de morado y enseña al avatar haciendo su
/// seña, sin tocar la selección, la navegación guiada ni la red.

/// Doble del avatar: registra lo que se le pide y termina cuando la prueba lo
/// decide, sin WebView ni modelo 3D.
class _AvatarFalso {
  final planes = <SignPreviewPlan>[];
  VoidCallback? _terminar;

  Widget build(
    BuildContext context,
    SignPreviewPlan plan,
    VoidCallback onFinished,
  ) {
    if (planes.isEmpty || !identical(planes.last, plan)) planes.add(plan);
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

const _relleno = Key('relleno_vista_previa');

Finder _tarjeta(String formulacion) => find.ancestor(
  of: find.text(formulacion),
  matching: find.byType(SemanticNode),
);

void main() {
  WebViewPlatform.instance = FakeWebViewPlatform();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_Arnes> montar(WidgetTester tester, {bool avatarReal = false}) async {
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

  double? progreso(WidgetTester tester, String formulacion) {
    final relleno = find.descendant(
      of: _tarjeta(formulacion),
      matching: find.byKey(_relleno),
    );
    if (relleno.evaluate().isEmpty) return null;
    return tester.widget<FractionallySizedBox>(relleno).heightFactor;
  }

  /// Mantiene [formulacion] hasta abrir la vista previa y levanta el dedo.
  Future<void> mantener(WidgetTester tester, String formulacion) async {
    final gesto = await tester.startGesture(
      tester.getCenter(_tarjeta(formulacion)),
    );
    await tester.pump();
    await tester.pump(SemanticNode.holdDuration);
    await tester.pump(const Duration(milliseconds: 50));
    await gesto.up();
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

  group('toque corto', () {
    testWidgets('1. un toque corto elige la tarjeta', (tester) async {
      final arnes = await montar(tester);
      expect(elegida(arnes.container, 'ROBAR'), isFalse);

      await tester.tap(_tarjeta('ROBAR'));
      await tester.pumpAndSettle();

      expect(elegida(arnes.container, 'ROBAR'), isTrue);
      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(arnes.avatar.planes, isEmpty);
    });

    testWidgets('2. un segundo toque corto la quita', (tester) async {
      final arnes = await montar(tester);
      await tester.tap(_tarjeta('ROBAR'));
      await tester.pumpAndSettle();
      expect(elegida(arnes.container, 'ROBAR'), isTrue);

      await tester.tap(_tarjeta('ROBAR'));
      await tester.pumpAndSettle();

      expect(elegida(arnes.container, 'ROBAR'), isFalse);
      expect(find.byType(SignPreviewOverlay), findsNothing);
    });

    testWidgets('un toque que tarda algo más sigue siendo un toque', (
      tester,
    ) async {
      final arnes = await montar(tester);
      final gesto = await tester.startGesture(
        tester.getCenter(_tarjeta('ROBAR')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await gesto.up();
      await tester.pumpAndSettle();

      expect(elegida(arnes.container, 'ROBAR'), isTrue);
      expect(find.byType(SignPreviewOverlay), findsNothing);
    });
  });

  group('llenado morado', () {
    testWidgets('3. apoyar el dedo empieza a llenar la tarjeta', (
      tester,
    ) async {
      final arnes = await montar(tester);
      expect(progreso(tester, 'ROBAR'), isNull);

      final gesto = await tester.startGesture(
        tester.getCenter(_tarjeta('ROBAR')),
      );
      await tester.pump();
      // Antes de que el sistema reconozca siquiera un toque (100 ms): el
      // relleno arranca con el dedo, no con la pulsación larga.
      await tester.pump(const Duration(milliseconds: 90));
      expect(progreso(tester, 'ROBAR'), closeTo(0.06, 0.02));

      await tester.pump(const Duration(milliseconds: 660));
      expect(progreso(tester, 'ROBAR'), closeTo(0.5, 0.02));
      expect(find.byType(SignPreviewOverlay), findsNothing);

      await gesto.up();
      await tester.pumpAndSettle();
      expect(elegida(arnes.container, 'ROBAR'), isFalse);
    });

    testWidgets('4. soltar antes de 1,5 s no abre el avatar ni elige', (
      tester,
    ) async {
      final arnes = await montar(tester);
      final gesto = await tester.startGesture(
        tester.getCenter(_tarjeta('ROBAR')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await gesto.up();
      await tester.pump();

      // El relleno vuelve a cero rápido.
      await tester.pump(const Duration(milliseconds: 250));
      expect(progreso(tester, 'ROBAR'), isNull);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(arnes.avatar.planes, isEmpty);
      expect(
        elegida(arnes.container, 'ROBAR'),
        isFalse,
        reason: 'mantener no es tocar, aunque se suelte antes de tiempo',
      );
    });

    testWidgets('desplazar la lista cancela el llenado sin elegir', (
      tester,
    ) async {
      final arnes = await montar(tester);
      final gesto = await tester.startGesture(
        tester.getCenter(_tarjeta('ROBAR')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(progreso(tester, 'ROBAR'), greaterThan(0));

      await gesto.moveBy(const Offset(0, -60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(progreso(tester, 'ROBAR'), isNull);

      await tester.pump(SemanticNode.holdDuration);
      await gesto.up();
      await tester.pumpAndSettle();
      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(elegida(arnes.container, 'ROBAR'), isFalse);
    });
  });

  group('vista previa', () {
    testWidgets('5-7. mantener 1,5 s abre el avatar y no cambia la selección', (
      tester,
    ) async {
      final arnes = await montar(tester);
      final gesto = await tester.startGesture(
        tester.getCenter(_tarjeta('ROBAR')),
      );
      await tester.pump();
      await tester.pump(SemanticNode.holdDuration);
      await tester.pump();

      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      expect(progreso(tester, 'ROBAR'), 1.0);
      final plan = arnes.avatar.planes.single;
      expect(plan.glosses, ['ROBAR']);
      expect(plan.animationGlosses, ['ROBAR']);
      expect(plan.isPlayable, isTrue);
      expect(elegida(arnes.container, 'ROBAR'), isFalse);

      // Soltar después de la vista previa no es un toque.
      await gesto.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(elegida(arnes.container, 'ROBAR'), isFalse);
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
    });

    testWidgets('8. una tarjeta elegida sigue elegida tras la vista previa', (
      tester,
    ) async {
      final arnes = await montar(tester);
      await tester.tap(_tarjeta('ROBAR'));
      await tester.pumpAndSettle();
      expect(elegida(arnes.container, 'ROBAR'), isTrue);

      await mantener(tester, 'ROBAR');
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      expect(elegida(arnes.container, 'ROBAR'), isTrue);

      await cerrarAlTerminar(tester, arnes.avatar);
      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(elegida(arnes.container, 'ROBAR'), isTrue);
      expect(progreso(tester, 'ROBAR'), isNull);
    });

    testWidgets('9. una tarjeta sin elegir sigue sin elegir tras la vista '
        'previa', (tester) async {
      final arnes = await montar(tester);

      await mantener(tester, 'PERDER');
      expect(arnes.avatar.planes.single.glosses, ['PERDER']);
      await cerrarAlTerminar(tester, arnes.avatar);

      expect(elegida(arnes.container, 'PERDER'), isFalse);
      expect(progreso(tester, 'PERDER'), isNull);

      // Y el toque corto sigue funcionando después.
      await tester.tap(_tarjeta('PERDER'));
      await tester.pumpAndSettle();
      expect(elegida(arnes.container, 'PERDER'), isTrue);
    });

    testWidgets('10. el fin de la seña cierra la capa sola', (tester) async {
      final arnes = await montar(tester);
      await mantener(tester, 'DAÑAR');
      expect(find.byType(SignPreviewOverlay), findsOneWidget);

      arnes.avatar.terminar();
      await tester.pump();
      // Un respiro para que el último gesto no se corte en seco.
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      await tester.pump(SignPreviewOverlay.closeDelay);
      await tester.pumpAndSettle();

      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('10b. con el avatar real, el fin de la secuencia cierra la '
        'capa', (tester) async {
      final arnes = await montar(tester, avatarReal: true);
      await mantener(tester, 'ROBAR');

      final visor = tester.widget<Avatar3DViewer>(find.byType(Avatar3DViewer));
      expect(visor.glosses, ['ROBAR']);
      expect(visor.animationUrls, [
        '${AnimationUrlResolver.defaultBaseUrl}'
            '${AnimationUrlResolver.bundledModelFileName}',
      ]);

      // Sin WebView real no llega 'finished': cierra el reloj de seguridad
      // del propio visor, como en un equipo donde el modelo no cargara.
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(SignPreviewOverlay.closeDelay);
      await tester.pumpAndSettle();

      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(find.byType(Avatar3DViewer), findsNothing);
      expect(elegida(arnes.container, 'ROBAR'), isFalse);
    });

    testWidgets('tocar fuera cierra la vista previa sin elegir', (
      tester,
    ) async {
      final arnes = await montar(tester);
      await mantener(tester, 'ROBAR');
      expect(find.byType(SignPreviewOverlay), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(elegida(arnes.container, 'ROBAR'), isFalse);
      expect(progreso(tester, 'ROBAR'), isNull);
    });

    testWidgets('11. una tarjeta de varias glosas se previsualiza entera y en '
        'orden', (tester) async {
      final arnes = await montar(tester);
      await tester.tap(_tarjeta('ROBAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('siguiente_pregunta')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_tarjeta('PAPEL · IDENTIDAD'));
      await tester.pumpAndSettle();

      await mantener(tester, 'PAPEL · IDENTIDAD');

      final plan = arnes.avatar.planes.single;
      expect(plan.glosses, ['PAPEL', 'IDENTIDAD']);
      expect(plan.animationGlosses, ['PAPEL', 'IDENTIDAD']);
      expect(elegida(arnes.container, 'PAPEL · IDENTIDAD'), isFalse);
      await cerrarAlTerminar(tester, arnes.avatar);
    });

    testWidgets('12. una glosa sin clip avisa y no abre nada ni llama a la '
        'red', (tester) async {
      final arnes = await montar(tester);
      await mantener(tester, 'ESCAPAR');

      expect(find.byType(SignPreviewOverlay), findsNothing);
      expect(arnes.avatar.planes, isEmpty);
      expect(find.text('Seña no disponible'), findsOneWidget);
      expect(elegida(arnes.container, 'ESCAPAR'), isFalse);
      await tester.pump(const Duration(milliseconds: 300));
      expect(progreso(tester, 'ESCAPAR'), isNull);
      expect(arnes.red.peticiones, isEmpty);
      expect(arnes.backend.llamadas, 0);

      // El aviso se retira solo.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Seña no disponible'), findsNothing);
    });

    testWidgets('13. dos dedos a la vez: una sola vista previa', (
      tester,
    ) async {
      final arnes = await montar(tester);
      final uno = await tester.startGesture(
        tester.getCenter(_tarjeta('ROBAR')),
        pointer: 1,
      );
      final dos = await tester.startGesture(
        tester.getCenter(_tarjeta('PERDER')),
        pointer: 2,
      );
      await tester.pump();
      await tester.pump(SemanticNode.holdDuration);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      expect(arnes.avatar.planes, hasLength(1));
      await uno.up();
      await dos.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(elegida(arnes.container, 'ROBAR'), isFalse);
      expect(elegida(arnes.container, 'PERDER'), isFalse);
      expect(progreso(tester, 'PERDER'), isNull);
      await cerrarAlTerminar(tester, arnes.avatar);
      expect(find.byType(SignPreviewOverlay), findsNothing);
    });

    testWidgets('13b. abrir otra vista previa cierra la anterior', (
      tester,
    ) async {
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

    testWidgets('14. desmontar a mitad del llenado no deja relojes vivos', (
      tester,
    ) async {
      await montar(tester);
      await tester.startGesture(tester.getCenter(_tarjeta('ROBAR')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(progreso(tester, 'ROBAR'), greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      // flutter_test falla por sí mismo si queda un Timer pendiente o un
      // Ticker activo tras desmontar el árbol.
    });

    testWidgets('14b. desmontar con la vista previa abierta no deja relojes '
        'vivos', (tester) async {
      final arnes = await montar(tester);
      await mantener(tester, 'ROBAR');
      arnes.avatar.terminar();
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('lo que no cambia', () {
    testWidgets('15. Atrás, Traducir y Adelante no se mueven ni cambian', (
      tester,
    ) async {
      final arnes = await montar(tester);
      await tester.tap(_tarjeta('ROBAR'));
      await tester.pumpAndSettle();

      const botones = [
        Key('anterior_pregunta'),
        Key('terminar_aqui'),
        Key('siguiente_pregunta'),
      ];
      Map<Key, Rect> rects() => {
        for (final k in botones) k: tester.getRect(find.byKey(k)),
      };
      final antes = rects();

      final gesto = await tester.startGesture(
        tester.getCenter(_tarjeta('PERDER')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(rects(), antes, reason: 'durante el llenado');
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(SignPreviewOverlay), findsOneWidget);
      expect(rects(), antes, reason: 'con el avatar abierto');
      await gesto.up();
      await cerrarAlTerminar(tester, arnes.avatar);
      expect(rects(), antes, reason: 'al cerrar');

      // Adelante sigue avanzando como siempre.
      final antesDeAvanzar = arnes.container
          .read(guidedFlowProvider)
          .session!
          .currentQuestionId;
      await tester.tap(find.byKey(const Key('siguiente_pregunta')));
      await tester.pumpAndSettle();
      expect(
        arnes.container.read(guidedFlowProvider).session!.currentQuestionId,
        isNot(antesDeAvanzar),
      );
      // Y Atrás vuelve.
      await tester.tap(find.byKey(const Key('anterior_pregunta')));
      await tester.pumpAndSettle();
      expect(
        arnes.container.read(guidedFlowProvider).session!.currentQuestionId,
        antesDeAvanzar,
      );
    });

    testWidgets('16. la vista previa no cambia la navegación guiada ni la '
        'declaración', (tester) async {
      final arnes = await montar(tester);
      await tester.tap(_tarjeta('ROBAR'));
      await tester.pumpAndSettle();
      final container = arnes.container;
      final pregunta = container
          .read(guidedFlowProvider)
          .session!
          .currentQuestionId;
      final vistaPrevia = container.read(guidedPreviewProvider);
      final glosas = container.read(sentenceProvider);

      await mantener(tester, 'PERDER');
      await cerrarAlTerminar(tester, arnes.avatar);
      await mantener(tester, 'ROBAR');
      await cerrarAlTerminar(tester, arnes.avatar);

      expect(
        container.read(guidedFlowProvider).session!.currentQuestionId,
        pregunta,
      );
      expect(container.read(guidedPreviewProvider), vistaPrevia);
      expect(container.read(sentenceProvider), glosas);
      expect(arnes.backend.llamadas, 0, reason: 'no se emite nada');
    });

    testWidgets('17. la vista previa no toca Conversation ni la red', (
      tester,
    ) async {
      final arnes = await montar(tester);
      final conversacion = arnes.container.read(conversationProvider);

      await mantener(tester, 'ROBAR');
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

  group('tarjeta aislada', () {
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

    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [signImagesEnabledProvider.overrideWith(_SinImagenes.new)],
          child: MaterialApp(home: Scaffold(body: child)),
        ),
      );
      await tester.pump();
    }

    testWidgets('sin onCardPreview mantener y soltar sigue siendo un toque', (
      tester,
    ) async {
      final tocadas = <String>[];
      await pump(
        tester,
        AdaptiveNodeLayout(
          cards: [card('A1')],
          onCardTap: (c) => tocadas.add(c.id),
        ),
      );
      final gesto = await tester.startGesture(
        tester.getCenter(find.byType(SemanticNode)),
      );
      await tester.pump(const Duration(seconds: 2));
      await gesto.up();
      await tester.pump();

      expect(tocadas, ['A1']);
      expect(find.byKey(_relleno), findsNothing);
    });

    testWidgets('si otro gesto se queda la arena, el relleno se vacía', (
      tester,
    ) async {
      final vistas = <String>[];
      final tocadas = <String>[];
      await pump(
        tester,
        RawGestureDetector(
          gestures: {
            EagerGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                  EagerGestureRecognizer.new,
                  (_) {},
                ),
          },
          child: AdaptiveNodeLayout(
            cards: [card('A1')],
            onCardTap: (c) => tocadas.add(c.id),
            onCardPreview: (c) async => vistas.add(c.id),
          ),
        ),
      );

      final gesto = await tester.startGesture(
        tester.getCenter(find.byType(SemanticNode)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_relleno), findsNothing);

      await tester.pump(SemanticNode.holdDuration);
      expect(find.byKey(_relleno), findsNothing);
      await gesto.up();
      await tester.pumpAndSettle();
      expect(vistas, isEmpty);
      expect(tocadas, isEmpty);
    });

    testWidgets('con el margen de arrastre de Android, desplazar vacía el '
        'relleno', (tester) async {
      final vistas = <String>[];
      final tocadas = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [signImagesEnabledProvider.overrideWith(_SinImagenes.new)],
          child: MaterialApp(
            home: MediaQuery(
              // En Android el margen de arrastre de la plataforma es menor
              // que el de la pulsación larga (18 px).
              data: const MediaQueryData(
                size: Size(800, 600),
                gestureSettings: DeviceGestureSettings(touchSlop: 4),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: AdaptiveNodeLayout(
                    cards: [for (var i = 0; i < 30; i++) card('C$i')],
                    onCardTap: (c) => tocadas.add(c.id),
                    onCardPreview: (c) async => vistas.add(c.id),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesto = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('C0'))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(_relleno), findsOneWidget);

      // Más que el margen del desplazamiento y menos que el de la pulsación:
      // la lista se queda el gesto sin que la pulsación se rechace sola.
      await gesto.moveBy(const Offset(0, -10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(_relleno), findsNothing);

      await tester.pump(SemanticNode.holdDuration);
      await gesto.up();
      await tester.pumpAndSettle();
      expect(vistas, isEmpty);
      expect(tocadas, isEmpty);
    });

    testWidgets('con vista previa, la accesibilidad ofrece tocar y mantener', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final tocadas = <String>[];
      final vistas = <String>[];
      await pump(
        tester,
        AdaptiveNodeLayout(
          cards: [card('A1')],
          onCardTap: (c) => tocadas.add(c.id),
          onCardPreview: (c) async => vistas.add(c.id),
        ),
      );

      final nodo = tester.getSemantics(find.byType(SemanticNode));
      final datos = nodo.getSemanticsData();
      expect(datos.label, contains('A1'));
      expect(datos.hasAction(SemanticsAction.tap), isTrue);
      expect(datos.hasAction(SemanticsAction.longPress), isTrue);
      expect(nodo.hintOverrides?.onLongPressHint, 'previsualizar la seña');

      tester.semantics.longPress(find.semantics.byLabel('A1'));
      await tester.pumpAndSettle();
      expect(vistas, ['A1']);
      expect(tocadas, isEmpty, reason: 'mantener no elige');

      // El toque de accesibilidad llega sin pulsación larga previa.
      tester.semantics.tap(find.semantics.byLabel('A1'));
      await tester.pumpAndSettle();
      expect(tocadas, ['A1']);
      semantics.dispose();
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
      expect(plan.animationUrls, [
        '${AnimationUrlResolver.placeholderScheme}ESCAPAR',
      ]);
      expect(plan.isPlayable, isFalse);
      expect(planner.plan(const []).isPlayable, isFalse);
    });

    test('una secuencia a medias se reproduce con su marcador en su sitio', () {
      final plan = planner.plan(const ['ESCAPAR', 'DÓNDE']);
      expect(plan.animationGlosses, ['ESCAPAR', 'DÓNDE']);
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
      final clips = _clipsDelGlb('assets/models/avatar_test.glb');
      expect(clips, hasLength(149));
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
