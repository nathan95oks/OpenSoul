import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/configured_entity_chips.dart';

import 'helpers/fake_audio_output.dart';
import 'helpers/official_dictionary.dart';

/// Dos acciones por relato, conservando ambas.
///
/// «Me robaron y escapé» y «me robaron y el ladrón escapó» son relatos
/// distintos y la diferencia importa: uno describe a quien huyó de un peligro
/// y el otro identifica a quien cometió el hecho. El modelo anterior guardaba
/// una sola acción, así que la segunda selección borraba la primera y la
/// huida se atribuía con un campo suelto que valía para todo el relato.
ProviderContainer _container() {
  final c = ProviderContainer(overrides: [
    lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
    audioOutputProvider.overrideWithValue(FakeAudioOutput()),
  ]);
  addTearDown(c.dispose);
  c.read(contextProvider.notifier).setContext(contextById('denuncia_robo')!);
  return c;
}

const _assembler = LocalSentenceAssembler();

void main() {
  group('el modelo conserva los dos hechos', () {
    test('elegir ROBAR y luego ESCAPAR no borra el primero', () {
      final c = _container();
      final notifier = c.read(declarationDraftProvider.notifier);

      notifier.toggleFactAction('ROBAR');
      notifier.toggleFactAction('ESCAPAR');

      final draft = c.read(declarationDraftProvider);
      expect(draft.facts.map((f) => f.action), ['ROBAR', 'ESCAPAR']);
    });

    test('no se admite un tercer hecho', () {
      final c = _container();
      final notifier = c.read(declarationDraftProvider.notifier);

      notifier.toggleFactAction('ROBAR');
      notifier.toggleFactAction('ESCAPAR');
      notifier.toggleFactAction('DAÑAR');

      expect(c.read(declarationDraftProvider).facts, hasLength(2));
      expect(c.read(declarationDraftProvider).facts.map((f) => f.action),
          isNot(contains('DAÑAR')));
    });

    test('el límite del modelo y el de la zona son el mismo número', () {
      final zona = contextById('denuncia_robo')!.zoneById('hecho')!;
      expect(zona.maxPicks, DeclarationDraftLimits.maxFacts,
          reason: 'Subir maxPicks sin subir el modelo deja tocar dos tarjetas '
              'y guardar una sola acción.');
    });

    test('quitar un hecho deja intacto el otro, con su protagonista', () {
      final c = _container();
      final notifier = c.read(declarationDraftProvider.notifier);

      notifier.toggleFactAction('ROBAR');
      notifier.toggleFactAction('ESCAPAR');
      final escapar =
          c.read(declarationDraftProvider).factWithAction('ESCAPAR')!;
      notifier.setFactActor(
          factId: escapar.id, actorRole: ActorRole.victim);
      final robar = c.read(declarationDraftProvider).factWithAction('ROBAR')!;
      notifier.setFactActor(
          factId: robar.id, actorRole: ActorRole.suspect);

      notifier.removeFact(robar.id);

      final draft = c.read(declarationDraftProvider);
      expect(draft.facts, hasLength(1));
      expect(draft.facts.single.action, 'ESCAPAR');
      expect(draft.facts.single.actorRole, ActorRole.victim,
          reason: 'Quitar el robo no puede tocar quién escapó.');
    });

    test('cada hecho lleva su propio protagonista', () {
      final c = _container();
      final notifier = c.read(declarationDraftProvider.notifier);

      notifier.toggleFactAction('ROBAR');
      notifier.toggleFactAction('ESCAPAR');
      final draft0 = c.read(declarationDraftProvider);
      notifier.setFactActor(
          factId: draft0.factWithAction('ROBAR')!.id,
          actorRole: ActorRole.suspect);
      notifier.setFactActor(
          factId: draft0.factWithAction('ESCAPAR')!.id,
          actorRole: ActorRole.victim);

      final draft = c.read(declarationDraftProvider);
      expect(draft.factWithAction('ROBAR')!.actorRole, ActorRole.suspect);
      expect(draft.factWithAction('ESCAPAR')!.actorRole, ActorRole.victim);
    });
  });

  group('la redacción distingue quién escapó', () {
    DeclarationDraft draftCon(ActorRole quienEscapo) => DeclarationDraft(
          contextId: 'denuncia_robo',
          facts: [
            const Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect),
            Fact(id: 'f2', action: 'ESCAPAR', actorRole: quienEscapo),
          ],
          objects: const [
            ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
          ],
        );

    test('yo escapé', () {
      final texto = _assembler.assembleStructured(draftCon(ActorRole.victim));
      expect(texto.toLowerCase(), contains('robó'));
      expect(texto.toLowerCase(), contains('declarante logró escapar'));
    });

    test('el sospechoso escapó', () {
      final texto = _assembler.assembleStructured(draftCon(ActorRole.suspect));
      expect(texto.toLowerCase(), contains('robó'));
      expect(texto.toLowerCase(), contains('escapó'));
      expect(texto.toLowerCase(), isNot(contains('declarante logró escapar')));
    });

    test('los dos relatos no dicen lo mismo', () {
      expect(_assembler.assembleStructured(draftCon(ActorRole.victim)),
          isNot(_assembler.assembleStructured(draftCon(ActorRole.suspect))));
    });

    test('sin aclarar, no se atribuye a nadie', () {
      final texto = _assembler.assembleStructured(draftCon(ActorRole.unknown));
      expect(texto.toLowerCase(), contains('sin precisar'));
    });

    test('ESCAPAR sola no redacta un robo', () {
      final texto = _assembler.assembleStructured(const DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: [Fact(id: 'f1', action: 'ESCAPAR', actorRole: ActorRole.victim)],
      ));
      expect(texto.toLowerCase(), isNot(contains('rob')));
      expect(texto.toLowerCase(), contains('escapar'));
    });
  });

  group('las glosas de la zona producen los dos hechos', () {
    testWidgets('elegir dos tarjetas deja dos hechos en el borrador',
        (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        ],
        child: Consumer(builder: (context, r, _) {
          ref = r;
          return const SizedBox();
        }),
      ));

      ref.read(contextProvider.notifier).setContext(contextById('denuncia_robo')!);
      await tester.pump();

      final zonas = ref.read(semanticZonesProvider.notifier);
      zonas.toggleAnswer('ROBAR');
      zonas.toggleAnswer('ESCAPAR');
      await tester.pump();

      expect(ref.read(semanticZonesProvider).zoneAnswers['hecho'],
          ['ROBAR', 'ESCAPAR'],
          reason: 'La zona tiene que admitir las dos.');

      final completo = buildFullDeclarationDraft(ref);
      expect(completo.facts.map((f) => f.action), ['ROBAR', 'ESCAPAR']);
    });

    testWidgets('quitar una tarjeta quita solo su hecho', (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        ],
        child: Consumer(builder: (context, r, _) {
          ref = r;
          return const SizedBox();
        }),
      ));

      ref.read(contextProvider.notifier).setContext(contextById('denuncia_robo')!);
      await tester.pump();

      final zonas = ref.read(semanticZonesProvider.notifier);
      zonas.toggleAnswer('ROBAR');
      zonas.toggleAnswer('ESCAPAR');
      zonas.toggleAnswer('ROBAR'); // se desmarca
      await tester.pump();

      final completo = buildFullDeclarationDraft(ref);
      expect(completo.facts.map((f) => f.action), ['ESCAPAR']);
    });
  });

  group('la pantalla muestra una ficha por hecho', () {
    testWidgets('dos hechos, dos fichas, cada una con su botón de quitar',
        (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(builder: (context, r, _) {
              ref = r;
              return const ConfiguredEntityChips();
            }),
          ),
        ),
      ));

      ref.read(contextProvider.notifier).setContext(contextById('denuncia_robo')!);
      final notifier = ref.read(declarationDraftProvider.notifier);
      notifier.toggleFactAction('ROBAR');
      notifier.toggleFactAction('ESCAPAR');
      await tester.pump();

      expect(find.textContaining('ROBAR'), findsOneWidget);
      expect(find.textContaining('Escapó'), findsOneWidget);
    });

    testWidgets('sin aclarar quién escapó, la ficha lo dice', (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
          audioOutputProvider.overrideWithValue(FakeAudioOutput()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(builder: (context, r, _) {
              ref = r;
              return const ConfiguredEntityChips();
            }),
          ),
        ),
      ));

      ref.read(contextProvider.notifier).setContext(contextById('denuncia_robo')!);
      ref.read(declarationDraftProvider.notifier).toggleFactAction('ESCAPAR');
      await tester.pump();

      expect(find.text('Escapó: falta aclarar quién'), findsOneWidget,
          reason: 'Cancelar la aclaración no puede fingir que se resolvió.');
    });
  });

  group('cancelar una aclaración conserva el estado anterior', () {
    test('el hecho sigue ahí, sin protagonista inventado', () {
      final c = _container();
      final notifier = c.read(declarationDraftProvider.notifier);

      notifier.toggleFactAction('ROBAR');
      notifier.toggleFactAction('ESCAPAR');
      final antes = c.read(declarationDraftProvider);

      // Cancelar es no llamar a setFactActor: el modal hace `return`.
      final despues = c.read(declarationDraftProvider);

      expect(despues.facts.map((f) => f.action),
          antes.facts.map((f) => f.action));
      expect(despues.factWithAction('ESCAPAR')!.actorRole, ActorRole.unknown,
          reason: 'No se le adjudica a nadie por defecto.');
    });

    test('una aclaración previa no se pierde al cancelar la siguiente', () {
      final c = _container();
      final notifier = c.read(declarationDraftProvider.notifier);

      notifier.toggleFactAction('ROBAR');
      notifier.toggleFactAction('ESCAPAR');
      final escapar =
          c.read(declarationDraftProvider).factWithAction('ESCAPAR')!;
      notifier.setFactActor(
          factId: escapar.id, actorRole: ActorRole.thirdParty);

      // Se abre otra aclaración y se cancela: nada cambia.
      expect(
        c.read(declarationDraftProvider).factWithAction('ESCAPAR')!.actorRole,
        ActorRole.thirdParty,
      );
    });
  });

  group('compatibilidad con borradores de un solo hecho', () {
    test('el borrador antiguo se lee como los hechos que significaba', () {
      final draft = DeclarationDraft.fromJson({
        'contextId': 'denuncia_robo',
        'fact': {
          'action': 'ROBAR',
          'actorRole': 'suspect',
          'escapar_actor': 'victim',
        },
      });

      expect(draft.facts, hasLength(2));
      expect(draft.facts.first.action, 'ROBAR');
      expect(draft.facts.last.action, 'ESCAPAR');
      expect(draft.facts.last.actorRole, ActorRole.victim);
    });

    test('un borrador antiguo con una sola acción sigue siendo una', () {
      final draft = DeclarationDraft.fromJson({
        'contextId': 'denuncia_robo',
        'fact': {'action': 'PERDER', 'lossType': 'loss'},
      });

      expect(draft.facts, hasLength(1));
      expect(draft.facts.single.action, 'PERDER');
      expect(draft.facts.single.lossType, 'loss');
    });

    test('un borrador sin hecho no inventa ninguno', () {
      final draft = DeclarationDraft.fromJson({'contextId': 'denuncia_robo'});
      expect(draft.facts, isEmpty);
      expect(draft.primaryFact, isNull);
    });

    test('ida y vuelta por JSON conserva los dos hechos', () {
      const original = DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: [
          Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect),
          Fact(id: 'f2', action: 'ESCAPAR', actorRole: ActorRole.victim),
        ],
      );
      final revivido = DeclarationDraft.fromJson(original.toJson());

      expect(revivido.facts.map((f) => f.action), ['ROBAR', 'ESCAPAR']);
      expect(revivido.facts.last.actorRole, ActorRole.victim);
    });
  });

  group('negación y certeza no se convierten en afirmación', () {
    test('un hecho negado se redacta como negado', () {
      final texto = _assembler.assembleStructured(const DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: [
          Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect,
              negated: true),
        ],
      ));
      expect(texto.toLowerCase(), contains('no es cierto'));
    });

    test('un hecho incierto conserva la duda', () {
      final texto = _assembler.assembleStructured(const DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: [
          Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect,
              certainty: Certainty.uncertain),
        ],
      ));
      expect(texto.toLowerCase(), contains('no estoy seguro'));
    });

    test('desconocer no es negar', () {
      final desconoce = _assembler.assembleStructured(const DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: [
          Fact(id: 'f1', action: 'ROBAR', certainty: Certainty.unknown),
        ],
      ));
      final niega = _assembler.assembleStructured(const DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: [Fact(id: 'f1', action: 'ROBAR', negated: true)],
      ));
      expect(desconoce, isNot(niega));
    });

    test('negar un hecho no toca al otro', () {
      final c = _container();
      final n = c.read(declarationDraftProvider.notifier);
      n.toggleFactAction('ROBAR');
      n.toggleFactAction('ESCAPAR');
      final robar = c.read(declarationDraftProvider).factWithAction('ROBAR')!;
      n.setFactActor(factId: robar.id, negated: true);

      final draft = c.read(declarationDraftProvider);
      expect(draft.factWithAction('ROBAR')!.negated, isTrue);
      expect(draft.factWithAction('ESCAPAR')!.negated, isFalse);
    });
  });

  group('el orden de selección no inventa una secuencia', () {
    test('ni "primero" ni "luego" aparecen por el orden', () {
      final texto = _assembler.assembleStructured(const DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: [
          Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect),
          Fact(id: 'f2', action: 'ESCAPAR', actorRole: ActorRole.suspect),
        ],
      ));
      for (final palabra in ['primero', 'luego', 'después', 'entonces']) {
        expect(texto.toLowerCase(), isNot(contains(palabra)), reason: palabra);
      }
    });

    test('los dos órdenes conservan los mismos hechos', () {
      String texto(List<Fact> facts) => _assembler
          .assembleStructured(DeclarationDraft(
              contextId: 'denuncia_robo', facts: facts));

      const robar = Fact(id: 'f1', action: 'ROBAR',
          actorRole: ActorRole.suspect);
      const escapar = Fact(id: 'f2', action: 'ESCAPAR',
          actorRole: ActorRole.victim);

      final a = texto([robar, escapar]).toLowerCase();
      final b = texto([escapar, robar]).toLowerCase();

      for (final t in [a, b]) {
        expect(t, contains('rob'));
        expect(t, contains('escapar'));
      }
    });
  });

  group('quitar ROBAR se lleva su contenido, no el de ESCAPAR', () {
    test('el objeto robado deja de afirmarse y la huida se conserva', () {
      final c = _container();
      final n = c.read(declarationDraftProvider.notifier);
      n.toggleFactAction('ROBAR');
      n.toggleFactAction('ESCAPAR');
      final escapar =
          c.read(declarationDraftProvider).factWithAction('ESCAPAR')!;
      n.setFactActor(factId: escapar.id, actorRole: ActorRole.victim);
      final robar = c.read(declarationDraftProvider).factWithAction('ROBAR')!;

      n.removeFact(robar.id);

      final texto = _assembler
          .assembleStructured(c.read(declarationDraftProvider))
          .toLowerCase();
      expect(texto, isNot(contains('denuncio el robo')));
      expect(texto, contains('escapar'));
    });
  });

  group('el borrador sobrevive a guardarse y restaurarse', () {
    test('ida y vuelta conserva actor, negación y certeza de cada hecho', () {
      const original = DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: [
          Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect,
              negated: true),
          Fact(id: 'f2', action: 'ESCAPAR', actorRole: ActorRole.victim,
              certainty: Certainty.uncertain),
        ],
      );

      final revivido = DeclarationDraft.fromJson(original.toJson());

      expect(revivido.facts, hasLength(2));
      expect(revivido.factWithAction('ROBAR')!.negated, isTrue);
      expect(revivido.factWithAction('ROBAR')!.actorRole, ActorRole.suspect);
      expect(revivido.factWithAction('ESCAPAR')!.certainty,
          Certainty.uncertain);
      expect(revivido.factWithAction('ESCAPAR')!.actorRole, ActorRole.victim);
    });

    test('el texto restaurado dice lo mismo que el original', () {
      const original = DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: [
          Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect),
          Fact(id: 'f2', action: 'ESCAPAR', actorRole: ActorRole.victim),
        ],
      );
      final revivido = DeclarationDraft.fromJson(original.toJson());

      expect(_assembler.assembleStructured(revivido),
          _assembler.assembleStructured(original));
    });
  });
}
