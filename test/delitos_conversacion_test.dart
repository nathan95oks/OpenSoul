import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_router.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn_builder.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';
import 'package:lsb_legal_app/features/conversation/presentation/widgets/gloss_line.dart';

void main() {
  final pendingCatalog = PendingSignCatalog.fromJsonString(
    File('assets/dictionary/senas_sin_sena.json').readAsStringSync(),
  );

  group('homicidio, violación y fraude/estafa', () {
    test('solo quedan en azul las palabras que no tienen seña propia', () {
      final lexicon =
          jsonDecode(File('aws/lexico_lsb.json').readAsStringSync())
              as Map<String, dynamic>;
      final knownSigns = lexicon['glosas'] as Map<String, dynamic>;

      expect(knownSigns, contains('VIOLACIÓN'));
      expect(pendingCatalog.describedGloss('violación'), isNull);
      expect(
        pendingCatalog.describedGloss('homicidio'),
        '${PendingSign.prefix}HOMICIDIO',
      );
      expect(
        pendingCatalog.describedGloss('fraude'),
        '${PendingSign.prefix}FRAUDE',
      );
      expect(pendingCatalog.equivalentSigns('estafa'), ['ENGAÑAR']);
    });

    for (final word in const ['HOMICIDIO', 'FRAUDE']) {
      test('$word tiene una descripción directa en LSB', () {
        final info = pendingCatalog.infoOf('${PendingSign.prefix}$word');
        expect(info.description, isNotEmpty);
        expect(info.lsbDescription, isNotEmpty);
        expect(info.lsbDescription.where(PendingSign.isPending), isEmpty);
      });
    }

    testWidgets('homicidio y fraude se pintan azules; violación no', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GlossLine(
                glosses: [
                  'SENA_PENDIENTE:HOMICIDIO',
                  'VIOLACIÓN',
                  'SENA_PENDIENTE:FRAUDE',
                ],
                style: TextStyle(color: Colors.black),
                pendingColor: AppTheme.pendingSign,
              ),
            ),
          ),
        ),
      );

      expect(
        tester.widget<Text>(find.text('HOMICIDIO')).style?.color,
        AppTheme.pendingSign,
      );
      expect(
        tester.widget<Text>(find.text('FRAUDE')).style?.color,
        AppTheme.pendingSign,
      );
      expect(
        tester.widget<RichText>(find.byType(RichText).first).text.toPlainText(),
        contains('VIOLACIÓN'),
      );
      expect(find.textContaining('En azul:'), findsOneWidget);
    });

    // Lo que la Lambda Texto→LSB lee de cada pregunta (SITUATION_CUES):
    // «denunciar» (QUEJAR) nombra todas las denuncias; la pista propia del
    // delito, solo su contexto. Manda el contexto con pista propia.
    final catalog = ConversationGraphCatalog(
      bank: QuestionBank.generated(),
      graph: DialogueGraph.fromJsonString(
        File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
      ),
    );
    final router = ConversationGraphRouter(catalog);

    Map<String, List<String>> denuncias([String? own, String? cue]) => {
      for (final c in const [
        'denuncia_robo',
        'violencia',
        'amenaza_digital',
        'engano_dinero',
        'homicidio',
        'otro',
      ])
        c: ['QUEJAR', 'denunci', if (c == own && cue != null) cue],
    };

    ConversationRoute routeFor(
      String text,
      List<String> glosses,
      Map<String, List<String>> mentioned,
    ) => router.routeDeterministic(
      SemanticTurn.fromBackend(
        turnId: text,
        text: text,
        speechAct: SpeechAct.question,
        glosses: glosses,
        backend: BackendSemanticTurn(
          version: 1,
          intent: SemanticIntent.mentionContext,
          mentionedContexts: [
            for (final e in mentioned.entries)
              ContextMention(id: e.key, isFamily: false, evidence: e.value),
          ],
          confidence: 0.8,
        ),
      ),
    );

    test('fraude, estafa y violación abren su contexto', () {
      expect(
        routeFor(
          '¿Fue víctima de fraude?',
          const ['TU', 'SENA_PENDIENTE:FRAUDE'],
          const {
            'engano_dinero': ['fraud'],
          },
        ).targetContextId,
        'engano_dinero',
      );
      expect(
        routeFor(
          '¿Fue víctima de una estafa?',
          const ['TU', 'ENGAÑAR'],
          const {
            'engano_dinero': ['ENGANAR', 'estaf'],
          },
        ).targetContextId,
        'engano_dinero',
      );
      expect(
        routeFor('¿Quiere denunciar una violación?', const [
          'TU',
          'QUERER',
          'QUEJAR',
          'VIOLACIÓN',
        ], denuncias('violencia', 'violaci')).targetContextId,
        'violencia',
      );
    });

    test('homicidio abre su propio contexto', () {
      // El recorrido «Homicidio» se declara en el banco: la pista propia
      // («homicid») manda sobre «denunciar», que nombra a toda la familia.
      final route = routeFor('¿Quiere denunciar un homicidio?', const [
        'TU',
        'QUERER',
        'QUEJAR',
        'SENA_PENDIENTE:HOMICIDIO',
      ], denuncias('homicidio', 'homicid'));
      expect(route.targetContextId, 'homicidio');
    });

    test('sus variantes también nombran Homicidio, sin la Lambda', () {
      // Lectura del cliente (sin backend): las `pistas` del banco.
      final builder = SemanticTurnBuilder(catalog);
      for (final text in const [
        '¿Quiere denunciar un homicidio?',
        '¿Vio al homicida?',
        '¿Fue un asesinato?',
        '¿Quién lo asesinó?',
        '¿Lo mataron?',
        '¿Quién lo mató?',
        '¿Fue un feminicidio?',
        '¿Fue un infanticidio?',
        '¿Es un parricidio?',
        '¿Cómo fue la muerte?',
        '¿Cuándo murió?',
      ]) {
        final turn = builder.build(turnId: text, text: text, glosses: const []);
        expect(
          turn.mentionedContexts.map((m) => m.id),
          contains('homicidio'),
          reason: text,
        );
      }
    });

    test('«¿Tiene la factura o la caja?» abre las dos respuestas', () {
      // Pregunta compuesta del banco (derivación): se responde con sus
      // partes, FACTURA y CAJA, cada una con su sí / no / no sé.
      final route = router.routeDeterministic(
        SemanticTurnBuilder(catalog).build(
          turnId: 'factura-caja',
          text: '¿Tiene la factura o la caja del celular?',
          glosses: const ['TU', 'TENER', 'FACTURA', 'CAJA', 'CELULAR'],
        ),
        activeContextId: 'denuncia_robo',
      );
      expect(route.targetContextId, 'denuncia_robo');
      expect(route.targetQuestionIds, ['Q.EVI.FACTURA', 'Q.EVI.CAJA']);
    });
  });
}
