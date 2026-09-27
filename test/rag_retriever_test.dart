import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/rag_suggestions_provider.dart';

void main() {
  final corpus = RagCorpus.fromJsonString(
    File('assets/rag/escenarios_cbba.json').readAsStringSync(),
  );
  final retriever = RagRetriever(corpus);

  group('separa instituciones', () {
    const cases = {
      'Me denunciaron y no puedo pagar abogado': 'SEPDEP',
      'Soy víctima y necesito abogado': 'SEPDAVI',
      'Me robaron mi celular': 'FELCC',
      'Mi pareja me amenaza y me golpea': 'FELCV',
      'Perdí mi cédula': 'SEGIP',
      'Perdí mi certificado de nacimiento': 'SERECI',
      '¿Cómo sigo mi denuncia en Fiscalía?': 'FIS',
    };

    for (final entry in cases.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(retriever.areaOf(entry.key), entry.value);
      });
    }

    test('Fiscalía no se mezcla con NUREJ/WebID del Órgano Judicial', () {
      final found = retriever.suggest(
        '¿Tiene acceso a Fiscalía ROMA?',
        preferArea: 'FIS',
        limit: 12,
      );
      expect(found, isNotEmpty);
      expect(found.every((s) => s.scenarioId.startsWith('ESC-FIS-')), isTrue);
      expect(
        found.any(
          (s) => RegExp(r'NUREJ|WebID', caseSensitive: false).hasMatch(s.text),
        ),
        isFalse,
      );
    });
  });

  group('datos en vivo y ficticios', () {
    for (final query in const [
      '¿Cuánto debo?',
      '¿Quién es mi fiscal?',
      '¿Cuándo es mi audiencia?',
      '¿Será virtual?',
    ]) {
      test('$query no inventa un valor', () {
        final found = retriever.suggest(query, limit: 12);
        for (final suggestion in found) {
          expect(suggestion.text, isNot(contains('[VERIFICAR]')));
          expect(
            suggestion.text,
            isNot(
              matches(
                RegExp(
                  r'\b(?:Bs\.?\s*)?\d{2,}(?:[.,]\d+)?\b|\b[A-Z]{2,}-?\d{3,}\b',
                  caseSensitive: false,
                ),
              ),
            ),
          );
        }
      });
    }

    test(
      'el corpus mostrable no expone identificadores ficticios conocidos',
      () {
        final texts = <String>[
          for (final s in corpus.scenarios) ...[
            for (final t in s.turns)
              if (t.showable) t.text,
            for (final v in s.variants)
              for (final r in v.replies)
                if (r.showable) r.text,
          ],
        ].join('\n');
        expect(texts, isNot(contains('[VERIFICAR]')));
        expect(texts, isNot(contains('Diego Flores Rojas')));
        expect(texts, isNot(contains('CBBA-2026-000123')));
        expect(
          texts,
          isNot(
            matches(
              RegExp(r'\b(?:NUREJ|WebID|placa)\s*[:#-]?\s*[A-Z0-9-]{4,}'),
            ),
          ),
        );
      },
    );
  });

  group('recupera la situación documentada', () {
    test('cada pregunta del funcionario encuentra su propio escenario', () {
      final fallas = <String>[];
      for (final s in corpus.scenarios) {
        for (final t in s.turns) {
          if (t.speaker != RagSpeaker.official || !t.showable) continue;
          final next = s.turn(t.n + 1);
          final hasReply =
              (next != null && next.isOfferableReply) ||
              s.variants.any(
                (v) =>
                    v.turn == t.n && v.replies.any((r) => r.isOfferableReply),
              );
          if (!hasReply) continue;
          final found = retriever.suggest(t.text, limit: 12);
          // Otra situación con la misma pregunta literal empata: vale igual.
          if (found.isEmpty || found.first.score < 0.99) {
            fallas.add('${s.id} turno ${t.n}: «${t.text}»');
          }
        }
      }
      expect(fallas, isEmpty, reason: fallas.join('\n'));
    });

    test('las otras formas de preguntar también encuentran respuestas', () {
      final fallas = <String>[];
      for (final s in corpus.scenarios) {
        for (final v in s.variants) {
          if (!v.replies.any((r) => r.isOfferableReply)) continue;
          for (final q in v.questions) {
            if (retriever.suggest(q).isEmpty) fallas.add('${s.id}: «$q»');
          }
        }
      }
      expect(fallas, isEmpty, reason: fallas.join('\n'));
    });

    test('las preguntas de ventanilla de las capturas encuentran su trámite', () {
      const casos = {
        '¿Trae el número de Matrícula de la casa o el Folio Real antiguo?':
            'DDRR',
        'Por favor, dígame el número de la placa del vehículo.': 'IMP',
        '¿Usted está en peligro ahorita? ¿El agresor está afuera o en su casa?':
            'FELCV',
        '¿Qué número de Juzgado de Familia es y cuál es el apellido del '
                'demandado?':
            'OJ',
        '¿Usted es el denunciado o acusado en el caso?': 'SEPDEP',
      };
      casos.forEach((texto, area) {
        final found = retriever.suggest(texto);
        expect(found, isNotEmpty, reason: texto);
        expect(found.first.scenarioId, startsWith('ESC-$area-'), reason: texto);
      });
    });

    test('media pregunta fuera del corpus: nada, o su trámite, nunca otro', () {
      // «nombre completo del denunciante» o «inquilino» no están en ningún
      // escenario y bajan el parecido; la búsqueda por significado de la
      // Lambda los recupera cuando el grafo tampoco sabe.
      const casos = {
        '¿Tiene el número de NUREJ o el nombre completo del denunciante?': 'OJ',
        '¿Traen el contrato impreso, sus carnets vigentes y están presentes '
                'el dueño y el inquilino?':
            'NOT',
      };
      casos.forEach((texto, area) {
        for (final s in retriever.suggest(texto)) {
          expect(s.scenarioId, startsWith('ESC-$area-'), reason: texto);
        }
      });
    });

    test('lo que no se parece a ninguna situación no sugiere nada', () {
      for (final texto in [
        '¿Le gusta el fútbol?',
        'Buenos días',
        'Vamos a llenar su ficha',
        '',
        // Charla de ventanilla sin trámite detrás: comparte «tiene», «tres»
        // o «seguro» con alguna pregunta documentada, pero habla de otra cosa.
        '¿Tiene mascota?',
        '¿Tiene seguro de salud?',
        '¿Tiene su licencia de conducir?',
        '¿Tiene algo más que agregar?',
        'Pase a la ventanilla tres.',
        'Le voy a pedir que firme aquí.',
        '¿Cuántos hijos tiene?',
        '¿Tiene número de celular para contactarlo?',
      ]) {
        expect(retriever.suggest(texto), isEmpty, reason: texto);
      }
    });
  });

  group('lo dicho de verdad en ventanilla', () {
    const nurej = '¿Tiene el número de NUREJ y el WebID?';

    test('un saludo antes de la pregunta no la diluye', () {
      final sola = retriever.suggest(nurej);
      final saludo = retriever.suggest(
        'Buenos días señor, bienvenido a la oficina. $nurej',
      );
      expect(saludo.first.scenarioId, sola.first.scenarioId);
      expect(saludo.first.score, sola.first.score);
    });

    test('dos preguntas en un mensaje: respuestas para cada una', () {
      final found = retriever.suggest(
        '¿Ya tiene abogado particular? ¿Y trajo su cédula de identidad?',
        limit: 12,
      );
      final areas = {for (final s in found) s.scenarioId.split('-')[1]};
      expect(areas, contains('SEPDEP'));
      expect(areas.length, greaterThan(1), reason: '$areas');
    });

    test('una pregunta genérica no salta a otra institución', () {
      final found = retriever.suggest(
        '¿Trae también su cédula de identidad?',
        preferArea: 'DDRR',
      );
      expect(found, isEmpty);
    });

    test('el tema no se impone a una coincidencia claramente mejor', () {
      final found = retriever.suggest(nurej, preferArea: 'DDRR');
      expect(found.first.scenarioId, startsWith('ESC-OJ-'));
    });
  });

  test('solo se ofrecen tarjetas aprobadas, con glosas y sin datos de '
      'ejemplo', () {
    for (final s in corpus.scenarios) {
      for (final t in s.turns.where((t) => t.speaker == RagSpeaker.official)) {
        for (final r in retriever.suggest(t.text, limit: 12)) {
          expect(r.glosses, isNotEmpty, reason: r.text);
          expect(RegExp(r'\d').hasMatch(r.text), isFalse, reason: r.text);
          expect(r.text, isNot(contains('[VERIFICAR]')));
        }
      }
    }
  });

  group('solo se consulta cuando el grafo no reconoce la pregunta', () {
    Conversation withHearing(
      String text, {
      ConversationRoute? route,
      bool pending = false,
    }) => Conversation(
      id: 'c',
      startedAt: DateTime(2026, 9, 27),
      turns: [
        ConversationTurn(
          pending: pending,
          route: route,
          message: SemanticMessage(
            id: 't1',
            speaker: SpeakerRole.hearing,
            source: MessageSource.text,
            glosses: const [],
            text: text,
          ),
          outputs: GeneratedOutputs(text: text),
        ),
      ],
    );

    const pregunta = '¿Usted es el denunciado o acusado en el caso?';

    test('sin ruta segura: situaciones parecidas', () {
      final found = ragSuggestionsFor(
        withHearing(pregunta, route: const ConversationRoute.noSafeRoute()),
        retriever,
      );
      expect(found.map((s) => s.text), contains('Soy denunciado.'));
    });

    test('un contexto directo determinista bloquea el RAG', () {
      // «denunciado» nombra Denuncias y el grafo abre ese contexto, pero la
      // pregunta es de SEPDEP.
      final found = ragSuggestionsFor(
        withHearing(
          pregunta,
          route: const ConversationRoute(
            type: ConversationRouteType.directContext,
            targetFamilyId: 'denuncias',
            confidence: 0.75,
          ),
        ),
        retriever,
      );
      expect(found, isEmpty);
    });

    test('el grafo eligió una pregunta con seguridad: manda el grafo', () {
      // Parecido alto pero no literal (0.84) contra un grafo seguro.
      const nurej = '¿Tiene el número de NUREJ y el WebID?';
      ConversationRoute graph(double confidence) => ConversationRoute(
        type: ConversationRouteType.directQuestion,
        targetContextId: 'seguimiento',
        targetQuestionIds: const ['Q.SEG.NUM_REFERENCIA'],
        confidence: confidence,
      );
      expect(
        ragSuggestionsFor(withHearing(nurej, route: graph(0.95)), retriever),
        isEmpty,
      );
      // Aunque la confianza sea menor, ya eligió una pregunta determinista.
      expect(
        ragSuggestionsFor(withHearing(nurej, route: graph(0.6)), retriever),
        isEmpty,
      );
    });

    test('el chat no contamina un trámite recordado sin respuesta segura', () {
      final conversation = Conversation(
        id: 'c',
        startedAt: DateTime(2026, 9, 27),
        turns: [
          for (final (id, text) in [
            ('t0', '¿Trae el número de matrícula o el Folio Real antiguo?'),
            ('t1', '¿Trae también su cédula de identidad?'),
          ])
            ConversationTurn(
              route: const ConversationRoute.noSafeRoute(),
              message: SemanticMessage(
                id: id,
                speaker: SpeakerRole.hearing,
                source: MessageSource.text,
                glosses: const [],
                text: text,
              ),
              outputs: GeneratedOutputs(text: text),
            ),
        ],
      );
      final found = ragSuggestionsFor(conversation, retriever);
      expect(found, isEmpty);
    });

    test('mientras se traduce, sin ruta todavía o sin corpus: nada', () {
      expect(
        ragSuggestionsFor(
          withHearing(
            pregunta,
            route: const ConversationRoute.noSafeRoute(),
            pending: true,
          ),
          retriever,
        ),
        isEmpty,
      );
      expect(ragSuggestionsFor(withHearing(pregunta), retriever), isEmpty);
      expect(
        ragSuggestionsFor(
          withHearing(pregunta, route: const ConversationRoute.noSafeRoute()),
          null,
        ),
        isEmpty,
      );
    });
  });

  test('cuándo pesa más el RAG que el grafo', () {
    const noSafe = ConversationRoute.noSafeRoute();
    const topic = ConversationRoute(
      type: ConversationRouteType.contextSelector,
      confidence: 0.6,
    );
    ConversationRoute question(double c) => ConversationRoute(
      type: ConversationRouteType.directQuestion,
      targetContextId: 'denuncia_robo',
      targetQuestionIds: const ['Q.LUG.DONDE'],
      confidence: c,
    );
    // El grafo no sabe: basta un parecido suficiente.
    expect(ragOutranksGraph(noSafe, RagRetriever.minScore), isTrue);
    expect(ragOutranksGraph(noSafe, RagRetriever.minScore - 0.01), isFalse);
    // Solo reconoció el tema: hace falta un parecido bueno.
    expect(ragOutranksGraph(topic, 0.6), isTrue);
    expect(ragOutranksGraph(topic, 0.59), isFalse);
    // Si ya eligió preguntas, el RAG nunca muestra tarjetas competidoras.
    expect(ragOutranksGraph(question(0.6), 0.8), isFalse);
    expect(ragOutranksGraph(question(0.6), 0.79), isFalse);
    expect(ragOutranksGraph(question(0.9), 0.95), isFalse);
    expect(ragOutranksGraph(question(1.0), 1.0), isFalse);
  });
}
