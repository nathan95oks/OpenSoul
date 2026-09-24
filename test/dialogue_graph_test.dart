import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/entities/dialogue_node.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';

import 'helpers/official_dictionary.dart';

/// Integridad del banco de nodos conversacionales y de su emparejamiento.
///
/// El grafo lo genera `tool/build_dialogue_graph.py` desde el corpus maestro,
/// así que esta prueba audita el artefacto que se empaqueta: que no haya ids
/// repetidos, que ninguna transición apunte al vacío, que ninguna opción
/// ofrecida como tarjeta invente una glosa que el catálogo no tiene, y que
/// cada nodo conserve de dónde salió. Un grafo sin procedencia es una lista
/// de frases que alguien escribió, no un corpus.
DialogueGraph _load() => DialogueGraph.fromJsonString(
      File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
    );

void main() {
  late DialogueGraph graph;
  late Set<String> catalogo;

  setUpAll(() {
    graph = _load();
    catalogo = loadOfficialEntries().map((e) => e.gloss).toSet();
  });

  group('integridad del grafo', () {
    test('trae los 209 ejemplos del corpus, sin perder ninguno', () {
      final raw = jsonDecode(
          File('assets/dialogue/dialogue_graph.json').readAsStringSync());
      final counts = Map<String, dynamic>.from(raw['counts'] as Map);

      expect(graph.nodes, hasLength(209));
      expect(counts['section6'], 98);
      expect(counts['section7'], 60);
      expect(counts['section8'], 51);
    });

    test('los identificadores son únicos', () {
      final ids = graph.nodes.map((n) => n.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('toda transición apunta a un nodo que existe', () {
      final ids = graph.nodes.map((n) => n.id).toSet();
      for (final node in graph.nodes) {
        for (final t in node.transitions) {
          expect(ids, contains(t.to),
              reason: '${node.id} apunta a ${t.to}, que no existe.');
          expect(t.to, isNot(node.id), reason: '${node.id} apunta a sí mismo.');
        }
      }
    });

    test('ningún nodo es un callejón sin salida dentro de su ámbito', () {
      // Se permite que un ámbito con un solo nodo no tenga salida; lo que no
      // se permite es que un ámbito poblado deje nodos aislados.
      final porAmbito = <String, List<DialogueNode>>{};
      for (final n in graph.nodes) {
        porAmbito.putIfAbsent(n.scope, () => []).add(n);
      }
      for (final entry in porAmbito.entries) {
        if (entry.value.length < 2) continue;
        final sinSalida =
            entry.value.where((n) => n.transitions.isEmpty).map((n) => n.id);
        expect(sinSalida, isEmpty,
            reason: 'En "${entry.key}" quedan nodos sin continuación.');
      }
    });

    test('cada nodo conserva su procedencia exacta en el corpus', () {
      for (final node in graph.nodes) {
        expect(node.provenance.section, inInclusiveRange(6, 8));
        expect(node.provenance.row, greaterThan(0));
        expect(node.provenance.subsection, isNotEmpty);
        expect(node.provenance.spanish, isNotEmpty);
        expect(node.phrase, node.provenance.spanish);
      }
    });

    test('cada nodo declara al menos una ranura y un modo', () {
      for (final node in graph.nodes) {
        expect(node.slots, isNotEmpty, reason: node.id);
        expect(node.modes, isNotEmpty, reason: node.id);
      }
    });

    test('lo que dice el oyente solo activa el modo respuesta', () {
      for (final node in graph.nodes.where((n) => n.provenance.section == 6)) {
        expect(node.modes, {CardsFlowPurpose.conversationReply},
            reason: '${node.id} es una intervención del oyente: no puede '
                'activarse como si la persona sorda abriera el turno.');
      }
    });
  });

  group('ninguna opción inventa vocabulario', () {
    test('toda tarjeta ofrecida existe en el catálogo que carga la app', () {
      for (final node in graph.nodes) {
        for (final o in node.options) {
          if (o.kind != OptionKind.card) continue;
          expect(o.gloss, isNotNull, reason: node.id);
          expect(catalogo, contains(o.gloss),
              reason: '${node.id} ofrece "${o.gloss}", que no está en '
                  'official_dictionary.json.');
        }
      }
    });

    test('lo no cubierto viaja aparte y con su motivo', () {
      for (final node in graph.nodes) {
        for (final p in node.pendingOptions) {
          expect(p.coverage.isOfferable, isFalse,
              reason: '${node.id}: "${p.concept}" está en pendientes pero se '
                  'declara ofrecible.');
          expect(p.reason, isNotEmpty,
              reason: '${node.id}: "${p.concept}" sin motivo.');
        }
      }
    });

    test('la dactilología se marca como tal y no como seña directa', () {
      final deletreadas = graph.nodes
          .expand((n) => n.options)
          .where((o) => o.kind == OptionKind.spelling);
      expect(deletreadas, isNotEmpty);
      for (final o in deletreadas) {
        expect(o.coverage, OptionCoverage.dactylology);
        expect(o.avatar, AvatarSupport.spelled);
      }
    });

    test('DENUNCIA no se convierte en seña directa', () {
      // Sección 4 del corpus: es un concepto pendiente, no una seña.
      final conDenuncia = graph.nodes.where(
          (n) => n.provenance.conceptsRaw.toUpperCase().contains('DENUNCIA'));
      expect(conDenuncia, isNotEmpty);
      for (final node in conDenuncia) {
        final directa = node.options.where((o) =>
            o.kind == OptionKind.card &&
            (o.gloss ?? '').toUpperCase() == 'DENUNCIA');
        expect(directa, isEmpty,
            reason: '${node.id} ofrece DENUNCIA como tarjeta directa.');
      }
    });
  });

  group('emparejamiento con el español libre', () {
    DialogueNode? matched(String text) => graph
        .match(text, mode: CardsFlowPurpose.conversationReply)
        ?.node;

    test('una frase del corpus encuentra su propio nodo', () {
      final node = matched('¿Le robaron el celular?');
      expect(node, isNotNull);
      expect(node!.provenance.spanish, contains('robaron'));
      expect(node.offerableGlosses, contains('CELULAR'));
    });

    test('frases distintas con la misma intención llegan a opciones útiles',
        () {
      // El corpus trae "¿Le robaron el celular?"; el oyente puede escribir
      // otra cosa que signifique lo mismo.
      final node = matched('¿Le robaron su teléfono celular esta mañana?');
      expect(node, isNotNull);
      expect(node!.offerableGlosses, contains('CELULAR'));
    });

    test('una pregunta cerrada ofrece sí y no, y una abierta no', () {
      final cerrada = matched('¿Le robaron el celular?')!;
      expect(cerrada.invitesPolarAnswer, isTrue);
      expect(cerrada.offerableGlosses.take(2), containsAll(['SÍ', 'NO']));

      final abierta = matched('¿Dónde ocurrió?')!;
      expect(abierta.invitesPolarAnswer, isFalse);
      expect(abierta.offerableGlosses, isNot(contains('SÍ')));
    });

    test('preguntar por fotos no propone testigos como respuesta principal',
        () {
      final node = matched('¿Tiene fotos de la pantalla?')!;
      expect(node.offerableGlosses, contains('FOTOS'));
      expect(node.offerableGlosses.first, anyOf('SÍ', 'NO', 'FOTOS'));
      expect(node.offerableGlosses.take(3), isNot(contains('TESTIGO')));
    });

    test('siempre se puede decir que no se sabe', () {
      for (final texto in [
        '¿Le robaron el celular?',
        '¿Dónde ocurrió?',
        '¿Conoce a la persona?',
      ]) {
        final node = matched(texto);
        expect(node, isNotNull, reason: texto);
        expect(node!.offerableGlosses, contains('NO_SABER'), reason: texto);
      }
    });

    test('el español que no encaja devuelve nada, no el nodo más parecido',
        () {
      expect(matched('El parqueo del edificio cierra a medianoche'), isNull);
      expect(matched(''), isNull);
    });

    test('cuando nada encaja se pueden proponer intenciones candidatas', () {
      final candidatos = graph.candidates(
        '¿Usted guardó algo de lo que pasó?',
        mode: CardsFlowPurpose.conversationReply,
      );
      expect(candidatos, isNotEmpty);
      expect(candidatos.map((n) => n.intent).toSet(),
          hasLength(candidatos.length),
          reason: 'Proponer dos veces la misma intención no ayuda a elegir.');
    });

    test('un nodo del banco del ciudadano no responde al oyente', () {
      // Sección 7 son preguntas que hace la persona sorda: sirven para abrir
      // su turno (B), no para ponerse en boca del oyente.
      final soloIniciativa = graph.nodes
          .where((n) => n.provenance.section == 7)
          .every((n) => !n.modes.contains(CardsFlowPurpose.conversationReply));
      expect(soloIniciativa, isTrue);
    });
  });

  group('continuaciones', () {
    test('la siguiente pregunta añade algo que aún no se respondió', () {
      final node = graph
          .match('¿Le robaron el celular?',
              mode: CardsFlowPurpose.conversationReply)!
          .node;

      final siguientes = graph.nextFrom(node);
      expect(siguientes, isNotEmpty);
      for (final s in siguientes) {
        expect(s.slots.toSet().difference(node.slots.toSet()), isNotEmpty,
            reason: '${s.id} no aporta ninguna ranura nueva.');
      }
    });

    test('lo ya respondido deja de proponerse', () {
      final node = graph
          .match('¿Le robaron el celular?',
              mode: CardsFlowPurpose.conversationReply)!
          .node;

      final todas = graph.nextFrom(node).map((n) => n.id).toSet();
      final respondidas = graph
          .nextFrom(node)
          .expand((n) => n.slots)
          .toSet();
      final tras = graph.nextFrom(node, answered: respondidas).map((n) => n.id);

      expect(tras.length, lessThan(todas.length));
    });
  });

  group('un grafo ausente no rompe nada', () {
    test('el grafo vacío no empareja ni propone', () {
      final vacio = DialogueGraph.empty;
      expect(vacio.isEmpty, isTrue);
      expect(
          vacio.match('¿Le robaron el celular?',
              mode: CardsFlowPurpose.conversationReply),
          isNull);
      expect(
          vacio.candidates('¿Le robaron el celular?',
              mode: CardsFlowPurpose.conversationReply),
          isEmpty);
    });
  });
}
