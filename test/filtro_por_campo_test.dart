import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_function.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_zone.dart';
import 'package:lsb_legal_app/core/domain/services/candidate_engine.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/card_grid.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Pertinencia de las opciones, por campo de respuesta.
///
/// Pertenecer al corpus es necesario pero no basta: PLAZA está documentada y
/// no responde «¿quién escapó?». Antes el único filtro era la polaridad, así
/// que abrir el buscador o cambiar de categoría permitía insertar cualquier
/// tarjeta en cualquier pregunta.
ProviderContainer _container() {
  final c = ProviderContainer(overrides: [
    lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
    audioOutputProvider.overrideWithValue(FakeAudioOutput()),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('la función semántica sale del ensamblador, no de una tabla nueva', () {
    test('las glosas conocidas se clasifican', () {
      expect(LocalSentenceAssembler.functionOf('CELULAR'),
          SemanticFunction.object);
      expect(LocalSentenceAssembler.functionOf('CALLE'),
          SemanticFunction.place);
      expect(LocalSentenceAssembler.functionOf('AYER'),
          SemanticFunction.time);
      expect(LocalSentenceAssembler.functionOf('HOMBRE'),
          SemanticFunction.participant);
      expect(LocalSentenceAssembler.functionOf('ROBAR'),
          SemanticFunction.action);
      // FOTOS es objeto para el ensamblador y, por serlo, también sirve como
      // evidencia: las funciones no son casillas exclusivas.
      expect(LocalSentenceAssembler.functionOf('FOTOS'),
          SemanticFunction.object);
      expect(LocalSentenceAssembler.functionOf('PAPEL'),
          SemanticFunction.document);
    });

    test('las tildes y los guiones no la despistan', () {
      expect(LocalSentenceAssembler.functionOf('dañar'),
          LocalSentenceAssembler.functionOf('DAÑAR'));
      expect(LocalSentenceAssembler.functionOf('AL-LADO'),
          LocalSentenceAssembler.functionOf('AL_LADO'));
    });

    test('una glosa desconocida no se clasifica, y por eso no se filtra', () {
      expect(LocalSentenceAssembler.functionOf('PALABRA_INVENTADA'), isNull);
      expect(
          CandidateEngine.fitsField({'place'}, 'PALABRA_INVENTADA'), isTrue,
          reason: 'Si el sistema no sabe qué es, decide la persona.');
    });

    test('cubre prácticamente todo el catálogo', () {
      final entradas = loadOfficialEntries();
      final sinRol = [
        for (final e in entradas)
          if (LocalSentenceAssembler.functionOf(e.gloss) == null) e.gloss,
      ];
      expect(sinRol, isEmpty,
          reason: 'Una glosa sin rol no puede filtrarse ni redactarse bien.');
    });
  });

  group('cada pregunta admite lo que le corresponde', () {
    test('«¿dónde ocurrió?» quiere lugares, no objetos', () {
      expect(CandidateEngine.fitsField({'place'}, 'CALLE'), isTrue);
      expect(CandidateEngine.fitsField({'place'}, 'PLAZA'), isTrue);
      expect(CandidateEngine.fitsField({'place'}, 'MOCHILA'), isFalse);
      expect(CandidateEngine.fitsField({'place'}, 'AYER'), isFalse);
    });

    test('«¿quién escapó?» quiere participantes, no lugares', () {
      expect(CandidateEngine.fitsField({'person'}, 'HOMBRE'), isTrue);
      expect(CandidateEngine.fitsField({'person'}, 'TESTIGO'), isTrue);
      expect(CandidateEngine.fitsField({'person'}, 'PLAZA'), isFalse);
      expect(CandidateEngine.fitsField({'person'}, 'CELULAR'), isFalse);
    });

    test('«¿qué te quitaron?» quiere objetos, no tiempos', () {
      expect(CandidateEngine.fitsField({'object'}, 'CELULAR'), isTrue);
      expect(CandidateEngine.fitsField({'object'}, 'MOCHILA'), isTrue);
      expect(CandidateEngine.fitsField({'object'}, 'AYER'), isFalse);
      expect(CandidateEngine.fitsField({'object'}, 'CALLE'), isFalse);
    });

    test('«¿cuándo ocurrió?» quiere tiempos', () {
      expect(CandidateEngine.fitsField({'time'}, 'AYER'), isTrue);
      expect(CandidateEngine.fitsField({'time'}, 'HOY'), isTrue);
      expect(CandidateEngine.fitsField({'time'}, 'CELULAR'), isFalse);
      expect(CandidateEngine.fitsField({'time'}, 'HOMBRE'), isFalse);
    });

    test('la evidencia quiere documentos y objetos que la soporten', () {
      expect(CandidateEngine.fitsField({'evidence'}, 'FOTOS'), isTrue);
      expect(CandidateEngine.fitsField({'evidence'}, 'CELULAR'), isTrue,
          reason: 'Las fotos pueden estar en el celular.');
      expect(CandidateEngine.fitsField({'evidence'}, 'AYER'), isFalse);
    });

    test('la institución quiere instituciones', () {
      expect(CandidateEngine.fitsField({'institution'}, 'POLICIA'), isTrue);
      expect(CandidateEngine.fitsField({'institution'}, 'MOCHILA'), isFalse);
    });

    test('un texto libre no acota nada', () {
      for (final g in ['CELULAR', 'CALLE', 'AYER', 'HOMBRE', 'ROBAR']) {
        expect(CandidateEngine.fitsField({'free_text'}, g), isTrue, reason: g);
      }
    });
  });

  group('lo que el filtro nunca quita', () {
    test('decir que no se sabe cabe en cualquier pregunta', () {
      for (final campo in ['place', 'person', 'object', 'time', 'evidence']) {
        expect(CandidateEngine.fitsField({campo}, 'NO_SABER'), isTrue,
            reason: campo);
      }
    });

    test('una pregunta cerrada admite además el detalle que la matiza', () {
      // «¿Le robaron el celular?» puede responderse «sí» o «celular».
      expect(CandidateEngine.fitsField({'polarity'}, 'SÍ'), isTrue);
      expect(CandidateEngine.fitsField({'polarity'}, 'CELULAR'), isTrue);
    });

    test('la polaridad no cabe donde no se preguntó algo cerrado', () {
      expect(CandidateEngine.fitsField({'place'}, 'SÍ'), isFalse);
      expect(CandidateEngine.fitsField({'person'}, 'NO'), isFalse);
      expect(CandidateEngine.fitsField({'polarity', 'object'}, 'SÍ'), isTrue);
    });

    test('un marcador acompaña a otra respuesta, no ocupa campo', () {
      expect(SemanticFunction.marker.fields, isEmpty);
      expect(CandidateEngine.fitsField({'place'}, 'NUM_2'), isTrue);
    });
  });

  group('una zona curada manda sobre la clasificación', () {
    test('las zonas conocidas declaran su campo', () {
      expect(SemanticZone.answerFieldsByZoneId['lugar'], ['place']);
      expect(SemanticZone.answerFieldsByZoneId['objetos'], ['object']);
      expect(SemanticZone.answerFieldsByZoneId['tiempo'], ['time']);
      expect(SemanticZone.answerFieldsByZoneId['persona'], ['person']);
    });

    test('una zona sin campo declarado no filtra', () {
      const zona = SemanticZone(id: 'zona_nueva', label: 'x', hint: 'y');
      expect(zona.answerFields, isEmpty);
    });

    test('la lista blanca de la zona gana al filtro', () {
      const engine = CandidateEngine();
      // JUEZ responde «¿quién?» aunque el ensamblador lo trate como
      // institución; la zona lo lista a mano y esa decisión manda.
      final salida = engine.rank(
        available: [_card('JUEZ'), _card('MOCHILA')],
        zoneFields: {'person'},
        zoneAllowlist: {'JUEZ'},
      );
      final glosas = salida.map((c) => c.card.gloss);
      expect(glosas, contains('JUEZ'));
      expect(glosas, isNot(contains('MOCHILA')));
    });
  });

  group('las tarjetas renderizadas respetan el campo', () {
    Future<List<String>> _visibles(WidgetTester tester, WidgetRef ref,
        String contextId, String zoneId) async {
      ref.read(contextProvider.notifier).setContext(contextById(contextId)!);
      await tester.pump();
      ref.read(semanticZonesProvider.notifier).activateZone(zoneId);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
    }

    testWidgets('la zona de lugar no muestra objetos', (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(builder: (context, r, _) {
                ref = r;
                return const CardGrid();
              }),
            ),
          ),
        ),
      ));

      final textos = await _visibles(tester, ref, 'denuncia_robo', 'lugar');

      expect(textos, isNot(contains('MOCHILA')),
          reason: 'Un objeto no responde «¿dónde ocurrió?».');
      expect(textos, isNot(contains('AYER')));
    });

    testWidgets('la zona de tiempo no muestra lugares', (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(builder: (context, r, _) {
                ref = r;
                return const CardGrid();
              }),
            ),
          ),
        ),
      ));

      final textos = await _visibles(tester, ref, 'denuncia_robo', 'tiempo');

      expect(textos, isNot(contains('CALLE')));
      expect(textos, isNot(contains('MOCHILA')));
    });
  });

  group('cambiar de categoría no elude el filtro', () {
    test('la categoría se filtra por el campo de la zona activa', () async {
      final c = _container();
      c.read(contextProvider.notifier).setContext(contextById('denuncia_robo')!);
      c.read(semanticZonesProvider.notifier).activateZone('lugar');

      // Se cambia a una categoría llena de objetos.
      final categorias = await c.read(categoriesProvider.future);
      final conObjetos = categorias.firstWhere(
        (cat) => cat.toLowerCase().contains('objeto'),
        orElse: () => categorias.first,
      );
      c.read(currentCategoryProvider.notifier).setCategory(conObjetos);

      final tarjetas = await c.read(dynamicCardsProvider.future);
      final glosas = tarjetas.map((t) => t.gloss).toSet();

      for (final g in glosas) {
        final permitida = CandidateEngine.fitsField({'place'}, g) ||
            contextById('denuncia_robo')!
                .zoneById('lugar')!
                .glossAllowlist
                .contains(g);
        expect(permitida, isTrue,
            reason: '«$g» llegó por la categoría a una pregunta de lugar.');
      }
    });
  });

  group('el diccionario completo sigue siendo consultable', () {
    test('ninguna glosa se borra del catálogo por no encajar en un campo',
        () async {
      final c = _container();
      final todas = await c.read(allCardsProvider.future);
      final entradas = loadOfficialEntries();

      expect(todas.length, entradas.length,
          reason: 'Filtrar una respuesta no es quitar la palabra del '
              'diccionario: el catálogo se conserva entero para consulta.');
    });

    test('el catálogo de la app y el asset coinciden', () {
      final delAsset = File('assets/dictionary/official_dictionary.json')
          .readAsStringSync();
      expect(delAsset, isNotEmpty);
      expect(loadOfficialEntries(), hasLength(346));
    });
  });
}

LsbCard _card(String gloss) => LsbCard(
      id: 'id_$gloss',
      gloss: gloss,
      displayText: gloss,
      iconUrl: '',
      categoryId: 'X',
      subcategoryId: 'X',
      contexts: const ['denuncia_robo'],
      priority: 5,
      suggestedNextCardIds: const [],
      isFrequent: false,
      isEmergency: false,
    );
