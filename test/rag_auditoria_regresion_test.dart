import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/rag_suggestions_provider.dart';

/// Regresiones de la auditoría RAG ↔ glosas del 2026-10-01
/// (`docs/negocio/rag/auditoria_rag_glosas_2026-10-01.md`). Cada caso es una
/// entrada que antes llevaba a una respuesta o a un trámite equivocados.
void main() {
  final corpus = RagCorpus.fromJsonString(
    File('assets/rag/escenarios_cbba.json').readAsStringSync(),
  );
  final retriever = RagRetriever(corpus);

  Set<String> areas(List<RagSuggestion> found) => {
    for (final s in found) s.scenarioId.split('-')[1],
  };

  group('H1 · no se cambia de institución sin que el oyente la nombre', () {
    test('«¿Trajo su cédula?» en Derechos Reales no abre SEPDAVI', () {
      final found = retriever.suggest(
        '¿Trajo su cédula de identidad?',
        preferArea: 'DDRR',
      );
      expect(areas(found), isNot(contains('SEPDAVI')));
      expect(areas(found), everyElement('DDRR'));
    });

    test('si otra institución encaja claramente mejor, tampoco se responde '
        'con la del tema', () {
      // «¿Su cédula ya venció?» es de SEGIP; el «¿Tiene su cédula?» de
      // Derechos Reales respondería «Sí, la tengo.», que no es lo preguntado.
      expect(
        retriever.suggest('¿Su cédula ya venció?', preferArea: 'DDRR'),
        isEmpty,
      );
    });

    test('nombrar la institución sí cambia', () {
      final found = retriever.suggest(
        '¿Tiene el número de NUREJ y el WebID?',
        preferArea: 'DDRR',
      );
      expect(found.first.scenarioId, startsWith('ESC-OJ-'));
    });
  });

  group('H2 · la negación cuenta', () {
    test('«¿No trajo su cédula?» no recibe las respuestas de «¿Trajo…?»', () {
      expect(retriever.suggest('¿No trajo su cédula?'), isEmpty);
      expect(
        retriever.suggest('¿No trajo su cédula?', preferArea: 'SEPDAVI'),
        isEmpty,
      );
    });

    test('una pregunta negativa documentada sí se encuentra', () {
      final mini = RagRetriever(_mini());
      final found = mini.suggest('¿No tiene la boleta de pago?');
      expect(found.map((s) => s.text), contains('No, no la traje.'));
      expect(mini.suggest('¿Tiene la boleta de pago?'), isEmpty);
    });
  });

  group('H3 · respuestas de la misma pregunta, no de otra', () {
    test('una pregunta de sí o no no recibe las respuestas de una abierta', () {
      // Antes: «¿Su trámite fue observado?» → «Compré una casa. Quiero
      // ponerla a mi nombre.» (respuesta a «¿Qué trámite viene a
      // registrar?»).
      final found = retriever.suggest('¿Su trámite fue observado?');
      expect(found.map((s) => s.text), isNot(contains(startsWith('Compré'))));
    });

    test('las respuestas no hablan de lo que el oyente no preguntó', () {
      final mini = RagRetriever(_mini());
      // «¿Tiene la matrícula del inmueble de la hipoteca?» → «Sí, conozco
      // la matrícula…» no responde si el inmueble tiene hipoteca.
      expect(mini.suggest('¿El inmueble tiene hipoteca?'), isEmpty);
      // Lo que sí pregunta por la matrícula la encuentra.
      expect(
        mini.suggest('¿Tiene la matrícula del inmueble?').map((s) => s.text),
        contains('Sí, conozco la matrícula de ese inmueble.'),
      );
    });

    test('en una pregunta abierta las respuestas aportan contenido', () {
      final found = retriever.suggest('¿Qué número de Juzgado de Familia es?');
      expect(found.first.scenarioId, 'ESC-OJ-03');
    });
  });

  group('H4 · sin tema, una pregunta genérica no elige institución', () {
    test('«¿Trajo su cédula?» y «¿Tiene algún documento?»', () {
      expect(retriever.suggest('¿Trajo su cédula de identidad?'), isEmpty);
      expect(retriever.suggest('¿Tiene algún documento?'), isEmpty);
      expect(retriever.suggest('¿Trae su carnet de identidad?'), isEmpty);
      expect(retriever.suggest('¿Tiene testigos?'), isEmpty);
    });

    test('lo que identifica un trámite se sigue encontrando', () {
      expect(
        retriever.suggest('¿Tiene la placa de su moto?').first.scenarioId,
        startsWith('ESC-IMP-'),
      );
      expect(
        retriever.suggest('¿Está en un lugar seguro?').first.scenarioId,
        'ESC-FELCV-01',
      );
    });

    test('lo que se pregunta en varias instituciones necesita el tema', () {
      // «¿Usted es la persona denunciada?» se pregunta en Fiscalía, SEPDEP y
      // SEPDAVI: sin saber dónde se está, no se elige; en SEPDEP, sí.
      const texto = '¿Usted es el denunciado o acusado en el caso?';
      expect(retriever.suggest(texto), isEmpty);
      expect(
        retriever.suggest(texto, preferArea: 'SEPDEP').first.scenarioId,
        startsWith('ESC-SEPDEP-'),
      );
    });

    test('la misma palabra con otro complemento es otra cosa', () {
      // «licencia de conducir» no es la «licencia de funcionamiento» de GAM.
      expect(retriever.suggest('¿Tiene su licencia de conducir?'), isEmpty);
      expect(
        retriever
            .suggest('¿Tiene una licencia de funcionamiento anterior?')
            .first
            .scenarioId,
        startsWith('ESC-GAM-'),
      );
    });
  });

  test('H5 · la pregunta que encontró el RAG va presupuesta', () {
    const texto = '¿Necesita un duplicado del certificado de matrimonio?';
    final conversation = Conversation(
      id: 'c',
      startedAt: DateTime(2026, 10, 1),
      turns: [
        ConversationTurn(
          route: const ConversationRoute.noSafeRoute(),
          message: SemanticMessage(
            id: 't1',
            speaker: SpeakerRole.hearing,
            source: MessageSource.text,
            glosses: const [],
            text: texto,
          ),
          outputs: GeneratedOutputs(text: texto),
        ),
      ],
    );
    final route = ragTramiteRoute(
      conversation,
      conversation.turns.single,
      const ConversationRoute.noSafeRoute(),
      retriever,
    )!;
    expect(route.pathQuestionIds, ['R.ESC-SERECI-02.1']);
    // Aunque en el recorrido dependiera de otra respuesta, se puede
    // contestar: el oyente ya la hizo.
    expect(route.presupposedQuestionIds, route.pathQuestionIds);
  });

  test('una coincidencia literal de SEGIP vence una pregunta genérica', () {
    const texto = '¿Perdió su cédula de identidad?';
    final pending = ConversationTurn(
      route: const ConversationRoute(
        type: ConversationRouteType.directQuestion,
        targetContextId: 'denuncia_robo',
        targetQuestionIds: ['Q.ROB.FALTA_CARNET'],
      ),
      message: SemanticMessage(
        id: 'segip',
        speaker: SpeakerRole.hearing,
        source: MessageSource.text,
        glosses: [],
        text: texto,
      ),
      outputs: const GeneratedOutputs(text: texto),
    );
    final conversation = Conversation(
      id: 'c-segip',
      startedAt: DateTime(2026, 10, 8),
      turns: [pending],
    );
    final route = ragTramiteRoute(
      conversation,
      pending,
      pending.route!,
      retriever,
      graphText: const {'Q.ROB.FALTA_CARNET': 0.86},
    );
    expect(route?.targetContextId, 'tramite_segip_103');
  });

  test('el RAG no saca una pregunta del contexto activo de violencia', () {
    const texto = '¿Está en peligro ahora mismo?';
    final previous = ConversationTurn(
      message: SemanticMessage(
        id: 'respuesta',
        speaker: SpeakerRole.deaf,
        source: MessageSource.cards,
        glosses: [],
        text: 'Me pegaron.',
        contextId: 'violencia',
      ),
      outputs: const GeneratedOutputs(text: 'Me pegaron.'),
    );
    final pending = ConversationTurn(
      route: const ConversationRoute.noSafeRoute(),
      message: SemanticMessage(
        id: 'riesgo',
        speaker: SpeakerRole.hearing,
        source: MessageSource.text,
        glosses: [],
        text: texto,
      ),
      outputs: const GeneratedOutputs(text: texto),
    );
    final conversation = Conversation(
      id: 'c-riesgo',
      startedAt: DateTime(2026, 10, 8),
      turns: [previous, pending],
    );
    expect(
      ragTramiteRoute(
        conversation,
        pending,
        pending.route!,
        retriever,
        graphText: const {'Q.RIE.AUXILIO': 0.5},
        graphSupportsActiveContext: true,
        remote: const [
          RagSuggestion(
            text: 'Sí, estoy en peligro ahora.',
            glosses: ['SI', 'PELIGRO', 'AHORA'],
            scenarioId: 'ESC-FIS-101',
            institution: 'Ministerio Público',
            procedure: 'Presentar denuncia y comunicar los hechos',
            score: 0.99,
            questionTurn: 6,
          ),
        ],
      ),
      isNull,
    );
  });
}

/// Un corpus mínimo para casos que el corpus activo no tiene.
RagCorpus _mini() => RagCorpus.fromJson({
  'escenarios': [
    _escenario('ESC-DDRR-97', [
      ('funcionario', '¿Tiene la matrícula del inmueble de la hipoteca?'),
      ('sordo', 'Sí, conozco la matrícula de ese inmueble.'),
    ]),
    _escenario('ESC-IMP-97', [
      ('funcionario', '¿No tiene la boleta de pago?'),
      ('sordo', 'No, no la traje.'),
    ]),
    _escenario('ESC-SEGIP-97', [
      ('funcionario', '¿Trae su cédula vigente?'),
      ('sordo', 'Sí, aquí está.'),
    ]),
  ],
});

Map<String, dynamic> _escenario(String id, List<(String, String)> turnos) => {
  'id': id,
  'titulo': id,
  'institucion': id,
  'tramite': id,
  'turnos': [
    for (final (i, (rol, texto)) in turnos.indexed)
      {
        'n': i + 1,
        'rol': rol,
        'texto': texto,
        'mostrable': true,
        'glosas': ['PRUEBA'],
      },
  ],
  'variantes': const [],
};
