import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_composer.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_corpus.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_retriever.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';

/// Trámites profundizados (2026-10-14): `ESC-*-301`. Se prueban con el banco
/// real de la app, no con una copia: lo que el constructor generó es lo que
/// se recorre.
void main() {
  final corpusJson =
      jsonDecode(File('assets/rag/escenarios_cbba.json').readAsStringSync())
          as Map<String, dynamic>;
  final escenarios = [
    for (final e in corpusJson['escenarios'] as List<dynamic>)
      e as Map<String, dynamic>,
  ];
  final nuevos = [
    for (final e in escenarios)
      if (RegExp(r'^ESC-[A-Z]+-30\d$').hasMatch(e['id'] as String)) e,
  ];
  final bank = RagTramites.bankWithTramites();
  final rules = GuidedFlow(bank);
  final composer = GuidedComposer(bank);
  final corpus = RagCorpus.fromJsonString(
    File('assets/rag/escenarios_cbba.json').readAsStringSync(),
  );
  final retriever = RagRetriever(corpus);

  String contextOf(String id) =>
      'tramite_${id.toLowerCase().replaceFirst('esc-', '').replaceAll('-', '_')}';

  Set<String> visibles(GuidedSession s) => {
    for (final step in s.steps)
      if (rules.isReachable(s, step)) step.questionId,
  };

  test('hay escenarios profundizados', () {
    expect(nuevos.length, greaterThanOrEqualTo(12));
  });

  group('cada escenario nuevo es un recorrido de «Trámites»', () {
    for (final e in nuevos) {
      final id = e['id'] as String;
      test('$id está en su institución y abre su primera pregunta', () {
        final tramite = RagTramites.ofScenario(id);
        expect(tramite, isNotNull);
        expect(tramite!.isListed, isTrue);
        final seccion = RagTramites.sections.firstWhere(
          (s) => s.contextIds.contains(tramite.contextId),
        );
        expect(seccion.id, '${RagTramites.sectionPrefix}${tramite.area}');

        final s = rules.startJourney(contextOf(id));
        final primera = s.currentQuestionId;
        expect(primera, startsWith('R.$id.'));
        expect(visibles(s), contains(primera));
        // Al empezar no se ve ninguna pregunta que dependa de una respuesta.
        final recorrido =
            (bank.data['recorridos'] as Map<String, dynamic>)[contextOf(id)]
                as Map<String, dynamic>;
        final dependientes = {
          for (final p in recorrido['pasos'] as List<dynamic>)
            if ((p as Map<String, dynamic>)['cuando'] != null)
              p['pregunta'] as String,
        };
        expect(dependientes, isNotEmpty);
        expect(visibles(s).intersection(dependientes), isEmpty);
      });
    }
  });

  group('continuidad: cada respuesta abre lo que le toca', () {
    for (final e in nuevos) {
      final id = e['id'] as String;
      final recorrido =
          (bank.data['recorridos'] as Map<String, dynamic>)[contextOf(id)]
              as Map<String, dynamic>;
      final pasos = [
        for (final p in recorrido['pasos'] as List<dynamic>)
          p as Map<String, dynamic>,
      ];
      test('$id: un paso con condición aparece solo con esos estados', () {
        final conCondicion = [
          for (final p in pasos)
            if ((p['cuando'] as List<dynamic>?)?.length == 1) p,
        ];
        expect(conCondicion, isNotEmpty, reason: 'sin ramificaciones');
        for (final p in conCondicion) {
          final c =
              (p['cuando'] as List<dynamic>).single as Map<String, dynamic>;
          final padre = c['pregunta'] as String;
          final hijo = p['pregunta'] as String;
          // El padre no depende de otro: se responde de entrada.
          final padreOpciones = bank.question(padre)!.options;
          for (final o in padreOpciones) {
            var s = rules.startJourney(contextOf(id));
            // Si el padre es hijo de otro, se llega a él respondiendo hacia
            // atrás con el primer estado que lo abre.
            s = _llegarA(rules, s, padre, bank);
            final r = rules.select(s, padre, o.id);
            if (!r.accepted) continue;
            final abre = (c['estados'] as List<dynamic>).contains(
              o.state.wireName,
            );
            expect(
              visibles(r.session).contains(hijo),
              abre,
              reason: '$id: $padre = ${o.state.wireName} → $hijo',
            );
          }
        }
      });

      test('$id: cambiar una respuesta borra lo que dependía de ella', () {
        final hijos = [
          for (final p in pasos)
            if ((p['cuando'] as List<dynamic>?) != null) p,
        ];
        final p = hijos.first;
        final c = (p['cuando'] as List<dynamic>).first as Map<String, dynamic>;
        final padre = c['pregunta'] as String;
        final hijo = p['pregunta'] as String;
        final estado = (c['estados'] as List<dynamic>).first as String;
        var s = _llegarA(rules, rules.startJourney(contextOf(id)), padre, bank);
        final opcionQueAbre = bank
            .question(padre)!
            .options
            .firstWhere((o) => o.state.wireName == estado);
        s = rules.select(s, padre, opcionQueAbre.id).session;
        final q = bank.question(hijo)!;
        s = rules.select(s, hijo, q.options.first.id).session;
        expect(s.answers.keys, contains(hijo));
        final otra = bank
            .question(padre)!
            .options
            .firstWhere(
              (o) =>
                  !(c['estados'] as List<dynamic>).contains(o.state.wireName),
            );
        final cambio = rules.select(s, padre, otra.id);
        expect(cambio.prunedQuestionIds, contains(hijo));
        expect(cambio.session.answers.keys, isNot(contains(hijo)));
      });
    }
  });

  group('SÍ, NO y NO SÉ: una seña cada una, con frase propia', () {
    for (final e in nuevos) {
      final id = e['id'] as String;
      test(id, () {
        final preguntas = [
          for (final q in bank.data['preguntas'] as List<dynamic>)
            if ((q as Map<String, dynamic>)['origen']?['escenario'] == id &&
                q['control'] == 'polar3')
              q['id'] as String,
        ];
        expect(preguntas.length, greaterThanOrEqualTo(4));
        for (final qid in preguntas) {
          final q = bank.question(qid)!;
          expect([for (final o in q.options) o.id], ['si', 'no', 'no_se']);
          expect(
            [for (final o in q.options) o.glosses.single],
            ['SÍ', 'NO', 'NO_SABER'],
          );
          for (final o in q.options) {
            expect(
              o.phrase.split(' ').length,
              greaterThan(2),
              reason: '$qid ${o.id}',
            );
          }
        }
      });
    }
  });

  group('datos editables: el dato lo escribe la persona y es opcional', () {
    test('NUREJ y WebID en ESC-OJ-301', () {
      const nurej = 'R.ESC-OJ-301.2';
      final q = bank.question(nurej)!;
      final si = q.option('si')!;
      expect(si.editor, 'documento_numero');
      expect(si.editorOptional, isTrue);
      expect(si.phrase, 'Sí, mi NUREJ es {numero}.');
      expect(si.phraseWithoutValue, startsWith('Sí,'));

      var s = rules.startJourney(
        'tramite_oj_301',
        purpose: GuidedPurpose.reply,
      );
      // Sin dato: «Sí» dice lo de siempre.
      s = rules.select(s, nurej, 'si').session;
      expect(composer.compose(s.toIntervention()), si.phraseWithoutValue);
      // Con dato: lo escrito, tal como lo escribió.
      s = rules.select(s, nurej, 'si', values: {'numero': 'ABC-12345'}).session;
      expect(
        composer.compose(s.toIntervention()),
        'Sí, mi NUREJ es ABC-12345.',
      );
      // «No» no pide dato.
      expect(bank.question(nurej)!.option('no')!.editor, isNull);
    });

    test('número de caso en ESC-FIS-301', () {
      final q = bank.question('R.ESC-FIS-301.2')!;
      expect(q.option('si')!.editor, 'documento_numero');
      expect(q.option('si')!.phrase, contains('{numero}'));
    });

    test('un dato vacío no se acepta y no cambia la respuesta', () {
      var s = rules.startJourney('tramite_fis_301');
      s = rules.select(s, 'R.ESC-FIS-301.2', 'si').session;
      final r = rules.select(
        s,
        'R.ESC-FIS-301.2',
        'si',
        values: {'numero': '   '},
      );
      expect(r.accepted, isFalse);
      expect(r.session.answers['R.ESC-FIS-301.2']!.optionIds, ['si']);
    });
  });

  group('consolidados: no se listan dos veces pero siguen funcionando', () {
    final consolidados = [
      for (final e in escenarios)
        if (e['consolidadoEn'] != null) e,
    ];
    final conRecorrido = [
      for (final e in consolidados)
        if (RagTramites.ofScenario(e['id'] as String) != null) e,
    ];
    test('los trámites sin recorrido quedan cubiertos por uno profundo', () {
      expect(consolidados.length, greaterThanOrEqualTo(4));
      // Ninguno de los consolidados estaba en la lista: nada que se vea
      // desaparece.
      expect(conRecorrido, isEmpty);
    });
    for (final e in consolidados) {
      final id = e['id'] as String;
      final destino = e['consolidadoEn'] as String;
      test('$id → $destino', () {
        // El que lo reemplaza existe, es más profundo y se lista.
        final otro = escenarios.firstWhere((x) => x['id'] == destino);
        expect(
          (otro['turnos'] as List).length,
          greaterThan((e['turnos'] as List).length),
        );
        final t = RagTramites.ofScenario(id);
        if (t == null) return; // sin recorrido: nunca estuvo en la lista
        expect(t.isListed, isFalse);
        final listados = [
          for (final s in RagTramites.sections) ...s.contextIds,
        ];
        expect(listados, isNot(contains(t.contextId)));
        final reemplazo = RagTramites.ofScenario(destino);
        expect(reemplazo, isNotNull, reason: '$destino debe ser un recorrido');
        expect(listados, contains(reemplazo!.contextId));
        // El RAG puede sugerirlo y sus preguntas siguen en el banco.
        final preguntas = [
          for (final q in bank.data['preguntas'] as List<dynamic>)
            if ((q as Map<String, dynamic>)['origen']?['escenario'] == id)
              q['id'],
        ];
        expect(preguntas, isNotEmpty);
      });
    }
  });

  group('coherencia de TODOS los recorridos de «Trámites»', () {
    final recorridos = bank.data['recorridos'] as Map<String, dynamic>;
    final ids = {for (final c in RagTramites.all) c.contextId};

    test('cada trámite tiene su recorrido y cada recorrido su trámite', () {
      expect(ids, isNotEmpty);
      for (final id in ids) {
        expect(recorridos, contains(id));
      }
    });

    test('toda pregunta de un paso existe en el banco, con opciones', () {
      for (final id in ids) {
        for (final p
            in (recorridos[id] as Map<String, dynamic>)['pasos']
                as List<dynamic>) {
          final q = bank.question(
            (p as Map<String, dynamic>)['pregunta'] as String,
          );
          expect(q, isNotNull, reason: '$id: ${p['pregunta']}');
          expect(q!.options, isNotEmpty, reason: '$id: ${p['pregunta']}');
        }
      }
    });

    test('un paso solo depende de una pregunta anterior de su recorrido', () {
      for (final id in ids) {
        final vistas = <String>{};
        for (final p
            in (recorridos[id] as Map<String, dynamic>)['pasos']
                as List<dynamic>) {
          for (final c
              in ((p as Map<String, dynamic>)['cuando'] as List<dynamic>? ??
                  const [])) {
            expect(
              vistas,
              contains((c as Map<String, dynamic>)['pregunta']),
              reason: '$id: ${p['pregunta']}',
            );
          }
          vistas.add(p['pregunta'] as String);
        }
      }
    });

    test('todo recorrido abre y su primera pregunta se ve de entrada', () {
      for (final id in ids) {
        final s = rules.startJourney(id);
        expect(s.currentQuestionId, isNotEmpty, reason: id);
        expect(visibles(s), contains(s.currentQuestionId), reason: id);
      }
    });

    test('cada institución tiene su sección y ningún trámite está en dos', () {
      final vistos = <String>{};
      for (final sec in RagTramites.sections) {
        for (final c in sec.contextIds) {
          expect(vistos.add(c), isTrue, reason: 'repetido: $c');
          final t = RagTramites.all.firstWhere((x) => x.contextId == c);
          expect(sec.id, '${RagTramites.sectionPrefix}${t.area}');
        }
      }
    });
  });

  group('prevención de cruces entre instituciones', () {
    // Una derivación nombra y explica a la institución a la que manda.
    const derivaciones = {
      'SEPDEP': {'SEPDAVI'},
      'SEGIP': {'SERECI'},
      'FELCV': {'SLIM'},
    };
    for (final e in nuevos) {
      final id = e['id'] as String;
      final area = id.split('-')[1];
      test('$id: sus preguntas se enrutan a su institución', () {
        final permitidas = {area, ...?derivaciones[area]};
        var enrutadas = 0;
        for (final t in e['turnos'] as List<dynamic>) {
          final turno = t as Map<String, dynamic>;
          if (turno['rol'] != 'funcionario' ||
              !(turno['texto'] as String).contains('?')) {
            continue;
          }
          final texto = turno['texto'] as String;
          final top = retriever.suggest(texto, preferArea: area, limit: 3);
          // Con la institución preferida, el RAG nunca ofrece el trámite de
          // una que no sea la suya ni su derivación declarada.
          for (final s in top) {
            expect(
              permitidas.contains(s.scenarioId.split('-')[1]),
              isTrue,
              reason: '«$texto» sugiere ${s.scenarioId}',
            );
          }
          if (top.isNotEmpty) enrutadas++;
        }
        expect(
          enrutadas,
          greaterThanOrEqualTo(3),
          reason: 'el RAG los encuentra',
        );
      });

      test('$id: ningún hecho es de otra institución salvo su derivación', () {
        final hechos = corpusJson['hechos'] as Map<String, dynamic>;
        final permitidas = {area, ...?derivaciones[area]};
        for (final t in e['turnos'] as List<dynamic>) {
          for (final h
              in (t as Map<String, dynamic>)['hechos'] as List<dynamic>) {
            expect(hechos, contains(h));
            expect(
              permitidas,
              contains((h as String).split('-')[1]),
              reason: '$id cita $h',
            );
          }
        }
      });
    }

    test('SEPDEP no patrocina a la víctima: lo dice y la manda a SEPDAVI', () {
      final e = nuevos.firstWhere((x) => x['id'] == 'ESC-SEPDEP-301');
      final textos = [
        for (final t in e['turnos'] as List<dynamic>)
          (t as Map<String, dynamic>)['texto'] as String,
      ].join(' ');
      expect(textos, contains('defensa pública para el denunciado'));
      expect(textos, contains('no para la víctima'));
      expect(textos, contains('SEPDAVI'));
    });

    test(
      'la víctima que consulta no recibe la defensa de la persona denunciada',
      () {
        String preguntaCon(String fragmento) => [
          for (final q in bank.data['preguntas'] as List<dynamic>)
            if ((q as Map<String, dynamic>)['origen']?['escenario'] ==
                    'ESC-SEPDEP-301' &&
                (q['formulacion'] as String).contains(fragmento))
              q['id'] as String,
        ].single;
        final denunciado = preguntaCon('¿Alguien lo denunció');
        final abogado = preguntaCon('abogado de defensa en su');
        final competencia = preguntaCon('¿Entendió?');
        var s = rules.startJourney('tramite_sepdep_301');
        s = rules.select(s, denunciado, 'no').session;
        final vis = visibles(s);
        // Con «no me denunciaron» sale la aclaración de competencia, no la
        // pregunta por el abogado de la defensa.
        expect(vis, contains(competencia));
        expect(vis, isNot(contains(abogado)));
        // Con «sí me denunciaron», al revés.
        s = rules.select(s, denunciado, 'si').session;
        expect(visibles(s), contains(abogado));
        expect(visibles(s), isNot(contains(competencia)));
      },
    );
  });
}

/// Responde, con la primera opción que lo abre, las preguntas de las que
/// depende [objetivo] hasta que sea visible.
GuidedSession _llegarA(
  GuidedFlow rules,
  GuidedSession inicio,
  String objetivo,
  QuestionBank bank,
) {
  var s = inicio;
  for (var vuelta = 0; vuelta < 12; vuelta++) {
    final paso = s.steps.firstWhere((p) => p.questionId == objetivo);
    if (rules.isReachable(s, paso)) return s;
    // La condición que falta.
    final c = paso.conditions.first;
    final padreId = c.questionId!;
    final padre = bank.question(padreId)!;
    final opcion = padre.options.firstWhere(
      (o) => c.states.contains(o.state.wireName),
    );
    s = _llegarA(rules, s, padreId, bank);
    s = rules.select(s, padreId, opcion.id).session;
  }
  return s;
}
