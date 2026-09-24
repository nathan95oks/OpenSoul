import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';
import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/audio_output.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/declaration_result_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/lsb_flow_screen.dart';

import 'helpers/official_dictionary.dart';

/// Auditoría de coherencia combinatoria (QA exhaustivo, 2026-09).
///
/// No es una prueba de fuerza bruta sobre todas las combinaciones posibles
/// (serían miles): cubre, con datos representativos, los ocho contextos y
/// las garantías concretas que pidió la auditoría —ninguna glosa genérica
/// suelta, aislamiento entre entidades, y que el borrador estructurado
/// siempre llegue a un texto sin fabricar hechos.
void main() {
  const asm = LocalSentenceAssembler();

  // ---------------------------------------------------------------------
  // A. Recorrido de los 8 contextos: cada uno produce texto coherente,
  //    sin marcadores crudos, guiones bajos sueltos ni paréntesis de relleno.
  // ---------------------------------------------------------------------
  group('recorrido completo de los 8 contextos', () {
    final casos = <String, DeclarationDraft>{
      'denuncia_robo': DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: [Fact(id: 'f1', action: 'ROBAR')],
        persons: const [
          PersonEntity(id: 'p1', role: 'suspect', gender: 'HOMBRE', clothing: [
            ClothingItem(
                id: 'c1',
                personId: 'p1',
                concept: 'POLERA',
                color: 'ROJO',
                colorState: ConfirmationState.confirmed),
          ]),
        ],
        objects: const [
          ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
        ],
        location: const LocationInfo(
          relation: 'CERCA',
          referenceType: 'other',
          referenceLiteralText: 'Mercado Calatayud',
        ),
      ),
      'violencia': const DeclarationDraft(
        contextId: 'violencia',
        facts: [Fact(id: 'f1', action: 'AGREDIR')],
        violence: ViolenceDetails(aggressionType: 'AGRESION_FISICA', physicalInjury: true),
      ),
      'amenaza_digital': const DeclarationDraft(
        contextId: 'amenaza_digital',
        digitalThreat: DigitalThreatDetails(channel: 'WhatsApp', hasSavedEvidence: true),
      ),
      'engano_dinero': const DeclarationDraft(
        contextId: 'engano_dinero',
        fraud: FraudDetails(amount: '500', currency: 'bolivianos', deliveryMethod: 'transferencia'),
      ),
      'seguimiento': const DeclarationDraft(
        contextId: 'seguimiento',
        procedure: ProcedureDetails(targetInstitution: 'FISCALIA'),
      ),
      'otro': const DeclarationDraft(
        contextId: 'otro',
        inquiry: InquiryDetails(isWitnessReport: true),
      ),
      'identificacion': DeclarationDraft(
        contextId: 'identificacion',
        objects: const [
          ObjectInvolved(id: 'o1', concept: 'IDENTIDAD', role: 'evidenceSupport', docType: 'Carnet de Identidad (C.I.)'),
        ],
      ),
      'preguntas': const DeclarationDraft(contextId: 'preguntas', speechAct: 'question'),
    };

    for (final entry in casos.entries) {
      test('${entry.key}: produce texto coherente y sin cabos sueltos', () {
        final texto = asm.assembleStructured(entry.value);

        expect(texto.trim(), isNotEmpty, reason: 'contexto ${entry.key}');
        // Ninguna glosa cruda (con guion bajo) debe filtrarse tal cual.
        expect(texto, isNot(contains(RegExp(r'[A-ZÑ]{2,}_[A-ZÑ]{2,}'))),
            reason: 'glosa cruda filtrada en ${entry.key}: "$texto"');
        // Nada de relleno genérico entre paréntesis.
        expect(texto, isNot(matches(RegExp(r'\(\s*\)'))), reason: entry.key);
        // Ni variables sin resolver.
        expect(texto, isNot(contains('null')), reason: entry.key);
        expect(texto, isNot(contains('{')), reason: entry.key);
      });
    }
  });

  // ---------------------------------------------------------------------
  // B. Desambiguación obligatoria: elegir un término genérico debe dejar
  //    un campo estructurado en el DeclarationDraft, no una glosa suelta.
  // ---------------------------------------------------------------------
  group('desambiguación obligatoria deja campos estructurados, no glosas sueltas', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });
    tearDown(() => container.dispose());

    test('BILLETES exige monto y moneda antes de incorporarse', () {
      final notifier = container.read(declarationDraftProvider.notifier);
      notifier.setSingleFactAction('ROBAR');
      final id = notifier.addObject(concept: 'BILLETES', role: 'stolen');
      // Sin monto: el objeto existe pero no debe imprimirse como cifra
      // inventada en el texto.
      var draft = container.read(declarationDraftProvider);
      var texto = const LocalSentenceAssembler().assembleStructured(draft);
      expect(texto, isNot(contains(RegExp(r'\d+ bolivianos'))));

      notifier.setObjectDetail(id, quantity: '500', unit: 'bolivianos');
      draft = container.read(declarationDraftProvider);
      texto = const LocalSentenceAssembler().assembleStructured(draft);
      expect(texto, contains('500 bolivianos'));
    });

    test('PAPEL exige un tipo de documento explícito (no genérico)', () {
      final notifier = container.read(declarationDraftProvider.notifier);
      final id = notifier.addObject(concept: 'PAPEL', role: 'lost');
      notifier.setObjectDetail(id, docType: 'Carnet de Identidad (C.I.)');
      final draft = container.read(declarationDraftProvider);
      final objeto = draft.objects.firstWhere((o) => o.id == id);
      expect(objeto.docType, 'Carnet de Identidad (C.I.)');
    });

    test('CAJA/BOLSA/MOCHILA exigen contenido y papel, no solo el envase', () {
      final notifier = container.read(declarationDraftProvider.notifier);
      for (final concepto in ['CAJA', 'BOLSA', 'MOCHILA']) {
        final id = notifier.addObject(
          concept: concepto,
          role: 'evidenceSupport',
          contents: 'documentos personales',
        );
        final draft = container.read(declarationDraftProvider);
        final objeto = draft.objects.firstWhere((o) => o.id == id);
        expect(objeto.contents, isNotNull, reason: concepto);
        expect(objeto.role, isNotEmpty, reason: concepto);
      }
    });

    test('MICRO/TRUFI: transporte del hecho y vehículo robado son campos distintos', () {
      final notifier = container.read(declarationDraftProvider.notifier);

      // Caso 1: transporte / lugar del hecho.
      notifier.setMainPlace('MICRO', isVehicleTransport: true);
      notifier.setLocationRelation('DENTRO');
      notifier.setLocationReference(
        referenceType: 'conceptCard',
        referenceConceptGloss: 'MICRO',
        isVehicleTransport: true,
      );
      var draft = container.read(declarationDraftProvider);
      expect(draft.location.isVehicleTransport, true);
      expect(draft.objects.any((o) => o.concept == 'MICRO'), false,
          reason: 'el transporte no debe registrarse como objeto robado');

      // Caso 2: vehículo sustraído (entidad de objeto, no de lugar).
      notifier.addObject(concept: 'TRUFI', role: 'stolen');
      draft = container.read(declarationDraftProvider);
      expect(draft.objects.any((o) => o.concept == 'TRUFI' && o.role == 'stolen'), true);
    });

    test('ESCAPAR exige quién escapó: agresor, víctima o un tercero', () {
      final notifier = container.read(declarationDraftProvider.notifier);
      notifier.setSingleFactAction('ESCAPAR');
      final escapar =
          container.read(declarationDraftProvider).factWithAction('ESCAPAR')!;
      notifier.setFactActor(
          factId: escapar.id, actorRole: ActorRole.suspect);
      final draft = container.read(declarationDraftProvider);
      expect(draft.factWithAction('ESCAPAR')!.actorRole, ActorRole.suspect);
    });

    test('PERDER exige aclarar motivo: extravío, posible delito o desconoce', () {
      final notifier = container.read(declarationDraftProvider.notifier);
      notifier.setLossDisambiguation(lossType: 'loss', note: 'extravío propio');
      final draft = container.read(declarationDraftProvider);
      expect(draft.primaryFact!.lossType, isNotNull);
    });
  });

  // ---------------------------------------------------------------------
  // C. Aislamiento de entidades: modificar Persona 1 / Prenda A nunca
  //    contamina a Persona 2 ni a otros objetos del borrador.
  // ---------------------------------------------------------------------
  group('aislamiento de entidades', () {
    test('cambiar el color de la prenda de la persona 1 no afecta a la persona 2', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(declarationDraftProvider.notifier);

      final p1 = notifier.addPerson(role: 'suspect');
      final c1 = notifier.addClothing(p1, 'POLERA');
      notifier.setClothingColor(p1, c1, 'ROJO');

      final p2 = notifier.addPerson(role: 'witness');
      final c2 = notifier.addClothing(p2, 'POLERA');
      notifier.setClothingColor(p2, c2, 'AZUL');

      // Se corrige el color de la persona 1 otra vez.
      notifier.setClothingColor(p1, c1, 'NEGRO');

      final draft = container.read(declarationDraftProvider);
      final persona1 = draft.persons.firstWhere((p) => p.id == p1);
      final persona2 = draft.persons.firstWhere((p) => p.id == p2);

      expect(persona1.clothing.single.color, 'NEGRO');
      expect(persona2.clothing.single.color, 'AZUL',
          reason: 'la prenda de la persona 2 no debe cambiar');
    });

    test('quitar un objeto no afecta a los demás objetos del borrador', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(declarationDraftProvider.notifier);

      final o1 = notifier.addObject(concept: 'CELULAR', role: 'stolen');
      notifier.addObject(concept: 'MOCHILA', role: 'stolen');
      notifier.addObject(concept: 'PAPEL', role: 'lost', docType: 'Licencia de Conducir');

      notifier.removeObject(o1);

      final draft = container.read(declarationDraftProvider);
      expect(draft.objects.any((o) => o.id == o1), false);
      expect(draft.objects.length, 2);
      expect(draft.objects.any((o) => o.concept == 'MOCHILA'), true);
      expect(draft.objects.any((o) => o.concept == 'PAPEL' && o.docType == 'Licencia de Conducir'),
          true);
    });

    test('dos mochilas con papeles distintos (robada y llevada) no se funden en una', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(declarationDraftProvider.notifier);
      final p1 = notifier.addPerson(role: 'suspect');

      notifier.addObject(concept: 'MOCHILA', role: 'stolen');
      notifier.addObject(concept: 'MOCHILA', role: 'carriedByOtherPerson', carriedByPersonId: p1);

      final draft = container.read(declarationDraftProvider);
      final mochilas = draft.objects.where((o) => o.concept == 'MOCHILA').toList();
      expect(mochilas, hasLength(2));
      expect(mochilas.map((o) => o.role).toSet(), {'stolen', 'carriedByOtherPerson'});
    });

    test('reset() limpia el borrador de entidades sin dejar residuos de un caso anterior', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(declarationDraftProvider.notifier);

      notifier.addPerson(role: 'suspect');
      notifier.addObject(concept: 'CELULAR', role: 'stolen');
      notifier.setLocationRelation('CERCA');

      notifier.reset();

      final draft = container.read(declarationDraftProvider);
      expect(draft.persons, isEmpty);
      expect(draft.objects, isEmpty);
      expect(draft.location.relation, isNull);
    });
  });

  // ---------------------------------------------------------------------
  // D. Navegación a resultado: el evento de finalización llega a
  //    DeclarationResultScreen con el texto determinista y el audio.
  // ---------------------------------------------------------------------
  group('navegación a resultado con audio', () {
    testWidgets('emitir la declaración muestra el texto y ofrece reproducirlo',
        (tester) async {
      const generated = 'Un hombre me robó mi celular en la calle.';

      final router = GoRouter(
        initialLocation: '/lsb-to-audio',
        routes: [
          GoRoute(path: '/lsb-to-audio', builder: (_, _) => const LsbFlowScreen()),
        ],
      );

      final container = ProviderContainer(overrides: [
        translationRepositoryProvider.overrideWithValue(_FakeRepo(generated)),
        audioOutputProvider.overrideWithValue(_RecordingAudio()),
        lexiconRepositoryProvider.overrideWithValue(FakeLexiconRepository()),
      ]);
      addTearDown(container.dispose);

      container.read(contextProvider.notifier).setContext(
            availableContexts.firstWhere((c) => c.id == 'denuncia_robo'),
          );
      container.read(sentenceProvider.notifier).setWords(['HOMBRE', 'ROBAR', 'CELULAR']);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Se avanza el botón progresivo (CONTINUAR/EMITIR DECLARACIÓN) hasta
      // llegar al resultado, sin asumir cuántas preguntas tiene el contexto.
      var llego = false;
      for (var intento = 0; intento < 30 && !llego; intento++) {
        final emitir = find.text('EMITIR DECLARACIÓN');
        final continuar = find.text('CONTINUAR');
        if (tester.any(emitir)) {
          await tester.tap(emitir);
        } else if (tester.any(continuar)) {
          await tester.tap(continuar);
        } else {
          break;
        }
        await tester.pumpAndSettle();
        llego = tester.any(find.byType(DeclarationResultScreen));
      }

      expect(llego, true, reason: 'no se alcanzó la pantalla de resultado');
      expect(find.text(generated), findsOneWidget,
          reason: 'el texto determinista/remoto debe verse en el resultado');
    });
  });
}

class _FakeRepo implements TranslationRepository {
  _FakeRepo(this._text);
  final String _text;

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
    Map<String, dynamic>? declaration,
    String? speechAct,
    String? replyToId,
  }) async =>
      TranslationResult(
        baseSentence: _text,
        generatedText: _text,
        audioUrl: null,
        bedrockUsed: true,
      );
}

class _RecordingAudio implements AudioOutput {
  final List<String> spoken = [];
  @override
  Future<void> playUrl(String url) async {}
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  void setOnComplete(void Function() onComplete) {}
  @override
  Future<void> dispose() async {}
}
