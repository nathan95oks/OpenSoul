import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/needs_screen.dart';

import 'helpers/business_catalog.dart';
import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Necesidad y acto comunicativo son dimensiones distintas.
///
/// Una intervención independiente puede ser una **pregunta**: es exactamente
/// lo que hace Consultas en modo personal. El nombre anterior del propósito
/// —`standaloneDeclaration`— empujaba a que toda salida fuera una afirmación,
/// y el borrador salía siempre como `statement` porque nadie llamaba a
/// `setSpeechAct`.
ProviderContainer _app() {
  final c = ProviderContainer(overrides: [
    lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
    audioOutputProvider.overrideWithValue(FakeAudioOutput()),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('cada necesidad produce su acto comunicativo', () {
    test('Consultas pregunta; Denuncias y Trámites declaran', () {
      expect(NeedsScreen.actFor(NeedId.inquiries), CommunicativeAct.question);
      expect(NeedsScreen.actFor(NeedId.complaints),
          CommunicativeAct.statement);
      expect(NeedsScreen.actFor(NeedId.procedures),
          CommunicativeAct.statement);
    });

    test('el acto viaja al backend con el nombre del contrato', () {
      expect(CommunicativeAct.question.wireName, 'question');
      expect(CommunicativeAct.statement.wireName, 'statement');
      expect(CommunicativeAct.request.wireName, 'request');
      expect(CommunicativeAct.answer.wireName, 'reply');
      expect(CommunicativeAct.instructionReceived.wireName, 'instruction');
    });

    test('propósito independiente admite acto de pregunta', () {
      const launch = CardsFlowLaunch.standalone(
        intendedAct: CommunicativeAct.question,
        need: NeedId.inquiries,
      );

      expect(launch.purpose, CardsFlowPurpose.standaloneIntervention);
      expect(launch.intendedAct, CommunicativeAct.question);
      expect(launch.purpose.servesConversation, isFalse);
    });

    test('responder siempre es responder, sea cual sea el turno entrante', () {
      const launch = CardsFlowLaunch.reply(
        conversationId: 'c1',
        hearingTurnId: 't1',
        hearingText: 'Su denuncia quedó registrada.',
      );
      expect(launch.intendedAct, CommunicativeAct.answer);
    });
  });

  group('el acto llega al borrador', () {
    test('elegir Consultas deja el borrador como pregunta', () {
      final c = _app();
      final notifier = c.read(declarationDraftProvider.notifier);

      notifier.setSpeechAct(
          NeedsScreen.actFor(NeedId.inquiries).wireName);

      expect(c.read(declarationDraftProvider).speechAct, 'question');
    });

    test('elegir Denuncias lo deja como declaración', () {
      final c = _app();
      c
          .read(declarationDraftProvider.notifier)
          .setSpeechAct(NeedsScreen.actFor(NeedId.complaints).wireName);

      expect(c.read(declarationDraftProvider).speechAct, 'statement');
    });

    test('el borrador lleva el acto al JSON que se envía', () {
      final c = _app();
      c.read(declarationDraftProvider.notifier).setSpeechAct('question');

      expect(c.read(declarationDraftProvider).toJson()['speechAct'],
          'question');
    });
  });

  group('cambiar de necesidad es cambiar de encargo', () {
    test('dos necesidades distintas no son el mismo encargo', () {
      const denuncias = CardsFlowLaunch.standalone(need: NeedId.complaints);
      const consultas = CardsFlowLaunch.standalone(need: NeedId.inquiries);

      expect(denuncias.sameErrand(consultas), isFalse,
          reason: 'Cambiar de necesidad tiene que pedir confirmación antes '
              'de descartar lo que se estaba armando.');
    });

    test('la misma necesidad sí es el mismo encargo', () {
      const a = CardsFlowLaunch.standalone(need: NeedId.complaints);
      const b = CardsFlowLaunch.standalone(need: NeedId.complaints);
      expect(a.sameErrand(b), isTrue);
    });
  });

  group('la pantalla de necesidades', () {
    testWidgets('muestra las tres, con texto además de icono', (tester) async {
      NeedId? elegida;

      await tester.pumpWidget(ProviderScope(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
          businessCatalogDataSourceProvider
              .overrideWithValue(FakeBusinessCatalogDataSource()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: NeedsScreen(onSelected: (n) => elegida = n),
          ),
        ),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Denuncias'), findsOneWidget);
      expect(find.text('Trámites y documentos'), findsOneWidget);
      expect(find.text('Consultas y asistencia'), findsOneWidget);

      await tester.tap(find.byKey(const Key('necesidad_consultas')));
      await tester.pump();

      expect(elegida, NeedId.inquiries);
    });

    testWidgets('cada necesidad dice de dónde arranca', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
          businessCatalogDataSourceProvider
              .overrideWithValue(FakeBusinessCatalogDataSource()),
        ],
        child: MaterialApp(
          home: Scaffold(body: NeedsScreen(onSelected: (_) {})),
        ),
      ));
      // Sin `pumpAndSettle`: el indicador de carga gira mientras el catálogo
      // llega y nunca queda todo quieto.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Descripciones distintas: no es el mismo recorrido con otro título.
      expect(find.textContaining('hecho sufrido'), findsOneWidget);
      expect(find.textContaining('una gestión o un documento'), findsOneWidget);
      expect(find.textContaining('orientación'), findsOneWidget);
    });
  });
}
