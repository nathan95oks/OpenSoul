import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/features/conversation/di/conversation_bindings.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/sign_preview_planner.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_preview_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/lsb_flow_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/gloss_row.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/sign_preview_overlay.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Las filas de respuesta dentro de Conversación (modo C: responder a un
/// turno del oyente).
///
/// Es el mismo módulo que fuera del chat: tocar elige y tocar otra vez
/// quita; deslizar enseña la seña en el avatar 3D. Elegir no envía nada al chat; lo compuesto solo
/// vuelve al turno al emitir, enlazado a la pregunta que se estaba leyendo.
class _SignRepo implements AudioTranslationRepository {
  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async => LsbTranslation(
    glosses: const ['TU', 'PASAR', 'QUE'],
    animationUrl: '',
    animationUrls: const [],
  );
}

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
      baseSentence: cards.join(' '),
      generatedText: cards.join(' '),
    );
  }
}

class _Red extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 503);
}

class _SinImagenes extends SignImagesNotifier {
  @override
  bool build() => false;
}

Finder _fila(String texto) =>
    find.ancestor(of: find.text(texto), matching: find.byType(GlossRow));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('responder en el chat: tocar compone sin enviar y lo '
      'compuesto vuelve al turno al emitir', (tester) async {
    final backend = _Backend();
    final planes = <SignPreviewPlan>[];
    final container = ProviderContainer(
      overrides: [
        lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
        audioTranslationRepositoryProvider.overrideWithValue(_SignRepo()),
        translationRepositoryProvider.overrideWithValue(backend),
        audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        httpClientProvider.overrideWithValue(_Red()),
        signImagesEnabledProvider.overrideWith(_SinImagenes.new),
        signPreviewPlayerProvider.overrideWithValue((_, plan, _) {
          planes.add(plan);
          return const SizedBox.expand();
        }),
        ...conversationOverrides(),
      ],
    );
    addTearDown(container.dispose);

    const pregunta = '¿Qué le pasó?';
    await tester.runAsync(() async {
      await container.read(lexiconEntriesProvider.future);
      await container
          .read(conversationProvider.notifier)
          .sendHearingMessage(pregunta);
    });
    final conversacion = container.read(conversationProvider).conversation;
    final turno = conversacion.lastHearingTurn!.message;
    container
        .read(cardsFlowLaunchProvider.notifier)
        .start(
          CardsFlowLaunch.reply(
            conversationId: conversacion.id,
            hearingTurnId: turno.id,
            hearingText: pregunta,
          ),
        );
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
          routerConfig: GoRouter(
            initialLocation: '/lsb',
            routes: [
              GoRoute(path: '/lsb', builder: (_, _) => const LsbFlowScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Se responde a esa frase, con las mismas filas que fuera del chat, y
    // las indicaciones en la primera pantalla con glosas.
    expect(find.text('«$pregunta»'), findsOneWidget);
    expect(find.byKey(const Key('indicaciones_filas')), findsOneWidget);
    final session = container.read(guidedFlowProvider).session!;
    expect(session.purpose, GuidedPurpose.reply);
    expect(session.hearingTurnId, turno.id);
    expect(find.byType(GlossRow), findsWidgets);
    final turnosAntes = conversacion.turns.length;

    Future<void> tocar(String texto) async {
      await tester.ensureVisible(_fila(texto));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: _fila(texto), matching: find.text(texto)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> deslizar(String texto) async {
      await tester.ensureVisible(_fila(texto));
      await tester.pumpAndSettle();
      final rect = tester.getRect(_fila(texto));
      await tester.dragFrom(
        Offset(rect.left + 40, rect.center.dy),
        Offset(rect.width * 0.6, 0),
      );
      await tester.pumpAndSettle();
    }

    await tocar('ROBAR');
    await tester.tap(find.byKey(const Key('siguiente_pregunta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('indicaciones_filas')), findsNothing);
    await tocar('CELULAR');
    await tocar('MOCHILA');

    // Deslizar enseña la seña y no elige ni quita (CELULAR sigue elegida).
    await deslizar('CELULAR');
    expect(find.byType(SignPreviewOverlay), findsOneWidget);
    expect(planes.last.glosses, ['CELULAR']);
    await tester.tap(find.byKey(const Key('cerrar_vista_previa')));
    await tester.pumpAndSettle();
    expect(find.byType(SignPreviewOverlay), findsNothing);

    // GORRA no tiene animación en el avatar: la fila lo dice y deslizarla
    // da el aviso de respaldo, sin visor y sin elegirla.
    expect(
      find.descendant(
        of: _fila('GORRA'),
        matching: find.byKey(const Key('sin_animacion')),
      ),
      findsOneWidget,
    );
    await deslizar('GORRA');
    expect(find.byType(SignPreviewOverlay), findsNothing);
    expect(find.text('Seña no disponible'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Tocar otra vez una elegida la quita.
    await tocar('MOCHILA');

    final compuesta = container.read(guidedFlowProvider).session!;
    expect(compuesta.answerOf('Q.HEC.QUE_OCURRIO')!.optionIds, ['robar']);
    expect(compuesta.answerOf('Q.ROB.QUE')!.optionIds, ['celular']);
    expect(container.read(guidedPreviewProvider), 'Me robaron el celular.');
    // Nada salió todavía: ni al chat ni al backend.
    expect(
      container.read(conversationProvider).conversation.turns,
      hasLength(turnosAntes),
    );
    expect(backend.llamadas, 0);

    await tester.tap(find.byKey(const Key('terminar_aqui')));
    await tester.pumpAndSettle();

    final turnos = container.read(conversationProvider).conversation.turns;
    expect(turnos, hasLength(turnosAntes + 1));
    final respuesta = turnos.last.message;
    expect(respuesta.speaker, SpeakerRole.deaf);
    expect(respuesta.replyToId, turno.id);
    expect(respuesta.text, 'Me robaron el celular.');
  });

  /// Monta el módulo respondiendo a [pregunta] del oyente, en denuncia_robo.
  Future<ProviderContainer> responderA(
    WidgetTester tester,
    String pregunta,
  ) async {
    final container = ProviderContainer(
      overrides: [
        lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
        audioTranslationRepositoryProvider.overrideWithValue(_SignRepo()),
        translationRepositoryProvider.overrideWithValue(_Backend()),
        audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        httpClientProvider.overrideWithValue(_Red()),
        signImagesEnabledProvider.overrideWith(_SinImagenes.new),
        ...conversationOverrides(),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(cardsFlowLaunchProvider.notifier)
        .start(
          CardsFlowLaunch.reply(
            conversationId: 'c',
            hearingTurnId: 't',
            hearingText: pregunta,
          ),
        );
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
          routerConfig: GoRouter(
            initialLocation: '/lsb',
            routes: [
              GoRoute(path: '/lsb', builder: (_, _) => const LsbFlowScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // «Me robaron» y a la pregunta de qué (según el turno, el recorrido
    // puede abrir antes otra pregunta).
    container
      ..read(guidedFlowProvider.notifier).select('Q.HEC.QUE_OCURRIO', 'robar')
      ..read(guidedFlowProvider.notifier).goTo('Q.ROB.QUE');
    await tester.pumpAndSettle();
    return container;
  }

  Finder sugerida(String texto) => find.descendant(
    of: _fila(texto),
    matching: find.byKey(const Key('fila_sugerida')),
  );

  testWidgets('lo que nombró el oyente se sugiere en su fila y se confirma '
      'tocándola', (tester) async {
    final container = await responderA(tester, '¿Le robaron su celular?');
    bool elegida(String o) =>
        container.read(guidedFlowProvider).session!.isSelected('Q.ROB.QUE', o);

    expect(sugerida('CELULAR'), findsOneWidget);
    expect(find.text('Mencionado por el oyente'), findsOneWidget);
    expect(sugerida('MOCHILA'), findsNothing);
    expect(elegida('celular'), isFalse, reason: 'sugerir no es elegir');

    await tester.ensureVisible(_fila('CELULAR'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: _fila('CELULAR'), matching: find.text('CELULAR')),
    );
    await tester.pumpAndSettle();

    expect(elegida('celular'), isTrue);
    expect(sugerida('CELULAR'), findsNothing, reason: 'ya está elegida');
    expect(container.read(guidedPreviewProvider), 'Me robaron el celular.');
  });

  testWidgets('una pregunta negada del oyente no sugiere nada', (tester) async {
    await responderA(tester, '¿No le robaron el celular?');
    expect(find.byKey(const Key('fila_sugerida')), findsNothing);
  });
}
