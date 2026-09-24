import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/entities/dialogue_node.dart';
import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/services/candidate_engine.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';

/// El orden de las respuestas que se ofrecen.
///
/// Dos reglas que este motor existe para garantizar:
///
///   - Una opción **no se vuelve válida** porque el modelo la sugiera.
///   - Una respuesta correcta **no se elimina** por ser poco frecuente en esa
///     institución. El perfil ordena; no prohíbe.
const _engine = CandidateEngine();

LsbCard _card(String gloss, {int priority = 5}) => LsbCard(
      id: 'id_$gloss',
      gloss: gloss,
      displayText: gloss,
      iconUrl: '',
      categoryId: 'X',
      subcategoryId: 'X',
      contexts: const ['denuncia_robo'],
      priority: priority,
      suggestedNextCardIds: const [],
      isFrequent: false,
      isEmergency: false,
    );

DialogueGraph _graph() => DialogueGraph.fromJsonString(
      File('assets/dialogue/dialogue_graph.json').readAsStringSync(),
    );

BusinessCatalog _catalog() => BusinessCatalog.fromJsonString(
      File('assets/business/institution_profiles.json').readAsStringSync(),
    );

void main() {
  late DialogueGraph graph;
  late BusinessCatalog catalog;

  setUpAll(() {
    graph = _graph();
    catalog = _catalog();
  });

  DialogueNode nodo(String frase) => graph
      .match(frase, mode: CardsFlowPurpose.conversationReply)!
      .node;

  group('sin señales, el orden de entrada se conserva', () {
    test('el motor es aditivo, no reordena por su cuenta', () {
      final entrada = ['ROBAR', 'PERDER', 'ESCAPAR', 'DAÑAR'].map(_card).toList();
      final salida = _engine.rank(available: entrada);

      expect(salida.map((c) => c.card.gloss),
          ['ROBAR', 'PERDER', 'ESCAPAR', 'DAÑAR'],
          reason: 'La lista blanca de la zona está curada a mano.');
    });

    test('lo ya respondido no se vuelve a ofrecer', () {
      final salida = _engine.rank(
        available: ['ROBAR', 'CELULAR'].map(_card).toList(),
        alreadyAnswered: {'ROBAR'},
      );
      expect(salida.map((c) => c.card.gloss), ['CELULAR']);
    });
  });

  group('el corpus manda sobre el modelo', () {
    test('lo que responde la pregunta va primero', () {
      final n = nodo('¿Le robaron el celular?');
      final entrada = ['CELULAR', 'SÍ', 'ROBAR'].map(_card).toList();

      final salida = _engine.rank(available: entrada, node: n);
      final glosas = salida.map((c) => c.card.gloss).toList();

      expect(glosas.first, anyOf('SÍ', 'CELULAR', 'ROBAR'));
      expect(salida.first.reason, contains('corpus'));
    });

    test('lo que no responde la pregunta ni siquiera se ofrece', () {
      final n = nodo('¿Le robaron el celular?');
      final entrada = ['TESTIGO', 'CELULAR', 'SÍ'].map(_card).toList();

      final salida = _engine.rank(available: entrada, node: n);

      expect(salida.map((c) => c.card.gloss), isNot(contains('TESTIGO')),
          reason: 'TESTIGO es un participante: no responde qué le robaron. '
              'Bajarlo de posición no basta, porque el buscador y las '
              'categorías lo traerían igual.');
      expect(salida.map((c) => c.card.gloss), containsAll(['CELULAR', 'SÍ']));
    });

    test('una glosa sugerida por el modelo que no está disponible no entra',
        () {
      final salida = _engine.rank(
        available: ['CELULAR'].map(_card).toList(),
        remoteSuggestion: ['FOLIO', 'ESCRITURA', 'CELULAR'],
      );

      expect(salida.map((c) => c.card.gloss), ['CELULAR'],
          reason: 'Una opción no se vuelve válida porque el modelo la diga.');
    });

    test('la sugerencia del modelo ordena, no filtra', () {
      final salida = _engine.rank(
        available: ['ROBAR', 'CELULAR', 'DINERO'].map(_card).toList(),
        remoteSuggestion: ['DINERO'],
      );

      expect(salida.first.card.gloss, 'DINERO');
      expect(salida.map((c) => c.card.gloss).toSet(),
          {'ROBAR', 'CELULAR', 'DINERO'},
          reason: 'Ninguna respuesta correcta desaparece.');
    });
  });

  group('la polaridad solo cabe donde se preguntó algo cerrado', () {
    test('una pregunta abierta no ofrece sí ni no', () {
      final n = nodo('¿Dónde ocurrió?');
      final salida = _engine.rank(
        available: ['SÍ', 'NO', 'CALLE'].map(_card).toList(),
        node: n,
      );

      expect(salida.map((c) => c.card.gloss), isNot(contains('SÍ')));
      expect(salida.map((c) => c.card.gloss), contains('CALLE'));
    });

    test('una pregunta cerrada sí las ofrece', () {
      final n = nodo('¿Le robaron el celular?');
      final salida = _engine.rank(
        available: ['SÍ', 'NO', 'CELULAR'].map(_card).toList(),
        node: n,
      );

      expect(salida.map((c) => c.card.gloss), containsAll(['SÍ', 'NO']));
    });
  });

  group('decir que no se sabe siempre está disponible', () {
    test('sobrevive al filtro por campo', () {
      final n = nodo('¿Dónde ocurrió?');
      final salida = _engine.rank(
        available: ['CALLE', 'NO_SABER'].map(_card).toList(),
        node: n,
      );

      expect(salida.map((c) => c.card.gloss), contains('NO_SABER'));
    });

    test('pero no encabeza: es una salida, no la respuesta esperada', () {
      final n = nodo('¿Le robaron el celular?');
      final salida = _engine.rank(
        available: ['NO_SABER', 'SÍ', 'CELULAR'].map(_card).toList(),
        node: n,
      );

      expect(salida.last.card.gloss, 'NO_SABER');
    });
  });

  group('la institución prioriza, no prohíbe', () {
    test('una respuesta correcta poco frecuente en ese perfil sigue estando',
        () {
      final policia = catalog.profileById('policia');
      // Pregunta documental: el campo admite evidencia, así que CERTIFICADO
      // y FACTURA son respuestas legítimas aunque el perfil sea Policía.
      final n = nodo('¿Tiene fotos de la pantalla?');

      final salida = _engine.rank(
        available: ['FOTOS', 'CERTIFICADO', 'FACTURA'].map(_card).toList(),
        node: n,
        profile: policia,
      );

      expect(salida.map((c) => c.card.gloss),
          containsAll(['CERTIFICADO', 'FACTURA']),
          reason: 'Consultar por un documento en la Policía es legítimo: el '
              'perfil ordena, no prohíbe.');
    });

    test('el perfil sube las intenciones que prioriza, sin quitar nada', () {
      final policia = catalog.profileById('policia');
      final general = InstitutionProfile.unknown;
      final n = nodo('¿Le robaron el celular?');
      final entrada = ['CELULAR', 'PAPEL'].map(_card).toList();

      final conPerfil = _engine.rank(
          available: entrada, node: n, profile: policia);
      final sinPerfil = _engine.rank(
          available: entrada, node: n, profile: general);

      expect(conPerfil.map((c) => c.card.gloss).toSet(),
          sinPerfil.map((c) => c.card.gloss).toSet(),
          reason: 'El conjunto de opciones no cambia con la institución.');
    });

    test('un perfil desconocido no rompe nada', () {
      final salida = _engine.rank(
        available: ['CELULAR'].map(_card).toList(),
        profile: catalog.profileById('no_existe'),
      );
      expect(salida, hasLength(1));
    });
  });

  group('los perfiles con brechas se declaran, no se esconden', () {
    test('Derechos Reales expone sus intenciones sin vocabulario', () {
      final ddrr = catalog.profileById('derechos_reales');
      expect(ddrr.uncoveredIntents, isNotEmpty);

      final folio = ddrr.gapFor('DDRR_FOLIO_ACTUALIZADO');
      expect(folio, isNotNull);
      expect(folio!.lexicalGap, contains('FOLIO'));
    });

    test('una intención con cobertura no aparece como brecha', () {
      final ddrr = catalog.profileById('derechos_reales');
      expect(ddrr.prioritizes('IDENTIFICACION_NOMBRE'), isTrue);
      expect(ddrr.gapFor('IDENTIFICACION_NOMBRE'), isNull);
    });

    test('SEPDEP y SEPDAVI son perfiles distintos', () {
      final sepdep = catalog.profileById('sepdep');
      final sepdavi = catalog.profileById('sepdavi');

      expect(sepdep.id, isNot(sepdavi.id));
      expect(sepdep.serviceType, 'defensa_publica_penal');
      expect(sepdavi.serviceType, 'asistencia_victima');
      expect(sepdavi.name, 'SEPDAVI', reason: 'Nunca SEPDAV.');
    });
  });

  group('el catálogo de negocio llega entero a la app', () {
    test('once perfiles y tres necesidades', () {
      expect(catalog.profiles, hasLength(11));
      expect(catalog.needs, hasLength(3));
      expect(catalog.needs.map((n) => n.id).toSet(), NeedId.values.toSet());
    });

    test('cada necesidad declara de dónde arranca su recorrido', () {
      for (final n in catalog.needs) {
        expect(n.startingPoint, isNotEmpty,
            reason: 'Cambia el orden y los datos, no solo el título.');
      }
    });

    test('sin institución se atiende igual', () {
      final sin = catalog.profileById(null);
      expect(sin.priorityNeeds, NeedId.values,
          reason: 'La falta de institución no bloquea la comunicación.');
    });
  });
}
