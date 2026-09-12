import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';

void main() {
  const assembler = LocalSentenceAssembler();

  group('Person Entity State Machine & Strict Isolation', () {
    test('editing pants color does not modify jacket color or other garments', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(declarationDraftProvider.notifier);

      // Create a person with a jacket (black) and pants (blue)
      final personId = notifier.addPerson(role: 'suspect');
      notifier.updatePerson(personId, gender: 'hombre', build: 'alto');

      final jacketId = notifier.addClothingWithColor(personId, 'CHAMARRA', 'negro');
      final pantsId = notifier.addClothingWithColor(personId, 'PANTALON', 'azul');

      var state = container.read(declarationDraftProvider);
      expect(state.persons.length, 1);
      final person = state.persons.first;
      expect(person.clothing.length, 2);
      expect(person.clothing[0].concept, 'CHAMARRA');
      expect(person.clothing[0].color, 'negro');
      expect(person.clothing[1].concept, 'PANTALON');
      expect(person.clothing[1].color, 'azul');

      // Now update the pants color to 'rojo'
      notifier.setClothingColor(personId, pantsId, 'rojo');

      state = container.read(declarationDraftProvider);
      final updatedPerson = state.persons.first;
      expect(updatedPerson.clothing.length, 2);

      // Jacket color MUST remain strictly 'negro'
      final jacket = updatedPerson.clothing.firstWhere((c) => c.id == jacketId);
      expect(jacket.color, 'negro');

      // Pants color MUST be 'rojo'
      final pants = updatedPerson.clothing.firstWhere((c) => c.id == pantsId);
      expect(pants.color, 'rojo');
    });

    test('adding multiple distinct people maintains independent states', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(declarationDraftProvider.notifier);

      final p1Id = notifier.addPerson(role: 'suspect');
      notifier.updatePerson(p1Id, gender: 'hombre', build: 'alto');
      final p1Gorra = notifier.addClothingWithColor(p1Id, 'GORRA', 'rojo');

      final p2Id = notifier.addPerson(role: 'victim');
      notifier.updatePerson(p2Id, gender: 'mujer', height: 'bajo');
      notifier.addClothingWithColor(p2Id, 'POLERA', 'blanco');

      var state = container.read(declarationDraftProvider);
      expect(state.persons.length, 2);

      notifier.setClothingColor(p1Id, p1Gorra, 'negro');

      state = container.read(declarationDraftProvider);
      final p1 = state.persons.firstWhere((p) => p.id == p1Id);
      final p2 = state.persons.firstWhere((p) => p.id == p2Id);

      expect(p1.clothing.first.color, 'negro');
      expect(p2.clothing.first.color, 'blanco');
    });
  });

  group('Disambiguation & Object Role Invariants', () {
    test('PERDER generates a loss declaration without false theft accusation', () {
      final draft = const DeclarationDraft(
        contextId: 'denuncia_robo',
        fact: FactInfo(action: 'PERDER', lossType: 'loss'),
        objects: [
          ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'lost'),
          ObjectInvolved(id: 'o2', concept: 'IDENTIDAD', role: 'lost', docType: 'Cédula de Identidad'),
        ],
        location: LocationInfo(mainPlaceConcept: 'CALLE', mainPlaceDetail: 'Heroínas'),
      );

      final text = assembler.assembleStructured(draft);
      expect(text, contains('Perdí mi celular y mi Cédula de Identidad'));
      expect(text, contains('en la calle Heroínas'));
      expect(text, isNot(contains('sustrajo')));
      expect(text, isNot(contains('me robó')));
    });

    test('ESCAPAR disambiguation captures fleeing actor properly in robbery', () {
      final draft = const DeclarationDraft(
        contextId: 'denuncia_robo',
        fact: FactInfo(action: 'ESCAPAR', actorRole: 'suspect'),
        persons: [
          PersonEntity(
            id: 'p1',
            role: 'suspect',
            gender: 'hombre',
            build: 'alto',
            clothing: [ClothingItem(id: 'c1', personId: 'p1', concept: 'CHAMARRA', color: 'negro', colorState: ConfirmationState.confirmed)],
          ),
        ],
      );

      final text = assembler.assembleStructured(draft);
      expect(text, contains('Un hombre alto que llevaba una chamarra negra escapó.'));
    });

    test('MICRO disambiguation as crime scene vs stolen vehicle', () {
      // Scene of crime / transport
      final draftScene = const DeclarationDraft(
        contextId: 'denuncia_robo',
        fact: FactInfo(action: 'ROBAR'),
        objects: [ObjectInvolved(id: 'o1', concept: 'MOCHILA', role: 'stolen')],
        location: LocationInfo(mainPlaceConcept: 'MICRO', mainPlaceDetail: 'Línea 3B', isVehicleTransport: true),
      );

      final textScene = assembler.assembleStructured(draftScene);
      expect(textScene, contains('me robó mi mochila'));
      expect(textScene, contains('en el micro Línea 3B'));

      // Stolen vehicle / object
      final draftStolen = const DeclarationDraft(
        contextId: 'denuncia_robo',
        fact: FactInfo(action: 'ROBAR'),
        objects: [ObjectInvolved(id: 'o1', concept: 'MICRO', role: 'stolen', detail: 'Línea 3B')],
      );

      final textStolen = assembler.assembleStructured(draftStolen);
      expect(textStolen, contains('me robó un micro (Línea 3B)'));
    });

    test('CAJA / BOLSA as evidence vs stolen object', () {
      final draftEvidence = const DeclarationDraft(
        contextId: 'denuncia_robo',
        fact: FactInfo(action: 'ROBAR'),
        objects: [
          ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
        ],
        evidence: [
          EvidenceItem(id: 'e1', concept: 'CAJA', availability: ConfirmationState.confirmed),
        ],
      );

      final text = assembler.assembleStructured(draftEvidence);
      expect(text, contains('me robó mi celular.'));
      expect(text, contains('Cuento con la caja como prueba.'));
    });
  });

  group('Deterministic Sentence Assembly Across All 8 Contexts', () {
    test('1. Context: denuncia_robo', () {
      final draft = const DeclarationDraft(
        contextId: 'denuncia_robo',
        fact: FactInfo(action: 'ROBAR'),
        objects: [
          ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
          ObjectInvolved(id: 'o2', concept: 'BILLETES', role: 'stolen'),
        ],
        persons: [
          PersonEntity(
            id: 'p1',
            role: 'suspect',
            gender: 'hombre',
            build: 'alto',
            clothing: [ClothingItem(id: 'c1', personId: 'p1', concept: 'CHAMARRA', color: 'negro', colorState: ConfirmationState.confirmed)],
          ),
        ],
        location: LocationInfo(mainPlaceConcept: 'CALLE', mainPlaceDetail: 'San Martín'),
        time: TimeInfo(dateOrMoment: 'HOY'),
        evidence: [
          EvidenceItem(id: 'e1', concept: 'FOTOS', availability: ConfirmationState.confirmed),
          EvidenceItem(id: 'e2', concept: 'FACTURA', availability: ConfirmationState.confirmed),
        ],
      );

      final result = assembler.assembleStructured(draft);
      expect(result, contains('Hoy, un hombre alto que llevaba una chamarra negra me robó mi celular y billetes y dinero en la calle San Martín.'));
      expect(result, contains('Cuento con fotografías y la factura como prueba.'));
    });

    test('2. Context: violencia', () {
      final draft = const DeclarationDraft(
        contextId: 'violencia',
        violence: ViolenceDetails(
          aggressionType: 'agresión física',
          physicalInjury: true,
          medicalCareRequested: true,
          protectionRequested: true,
        ),
        location: LocationInfo(mainPlaceConcept: 'CASA'),
      );

      final result = assembler.assembleStructured(draft);
      expect(result, contains('El declarante denuncia haber sufrido agresión física en mi casa.'));
    });

    test('3. Context: amenaza_digital', () {
      final draft = const DeclarationDraft(
        contextId: 'amenaza_digital',
        digitalThreat: DigitalThreatDetails(
          channel: 'WhatsApp',
          hasSavedEvidence: true,
        ),
      );

      final result = assembler.assembleStructured(draft);
      expect(result, contains('El declarante refiere haber recibido amenazas a través de WhatsApp.'));
    });

    test('4. Context: engano_dinero', () {
      final draft = const DeclarationDraft(
        contextId: 'engano_dinero',
        fraud: FraudDetails(
          amount: '3500',
          currency: 'bolivianos',
          deliveryMethod: 'depósito bancario',
        ),
      );

      final result = assembler.assembleStructured(draft);
      expect(result, contains('El declarante denuncia haber sido víctima de engaño económico por el monto de 3500 bolivianos mediante depósito bancario.'));
    });

    test('5. Context: seguimiento', () {
      final draft = const DeclarationDraft(
        contextId: 'seguimiento',
        inquiry: InquiryDetails(isProcessInquiry: true),
      );

      final result = assembler.assembleStructured(draft);
      expect(result, contains('El ciudadano consulta el estado de su trámite o investigación.'));
    });

    test('6. Context: otro (testimonio)', () {
      final draft = const DeclarationDraft(
        contextId: 'otro',
        inquiry: InquiryDetails(isWitnessReport: true),
      );

      final result = assembler.assembleStructured(draft);
      expect(result, contains('El declarante se presenta en calidad de testigo presencial de los hechos.'));
    });

    test('7. Context: identificacion', () {
      final draft = const DeclarationDraft(
        contextId: 'identificacion',
        objects: [
          ObjectInvolved(
            id: 'o1',
            concept: 'IDENTIDAD',
            role: 'documento',
            docType: 'Cédula de Identidad',
          ),
        ],
      );

      final result = assembler.assembleStructured(draft);
      expect(result, contains('El declarante presenta su Cédula de Identidad.'));
    });

    test('8. Context: preguntas', () {
      final draft = const DeclarationDraft(
        contextId: 'preguntas',
      );

      final result = assembler.assembleStructured(draft);
      expect(result, contains('¿Dónde debo realizar esta consulta o presentar el trámite?'));
    });
  });

  group('Amount / Money Capture (AmountInputSheet & ObjectInvolved)', () {
    test('capturing monetary amounts in Bolivianos and Dollars properly updates draft', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(declarationDraftProvider.notifier);

      // Add 500 Bs. as stolen money
      final objId = notifier.addObject(
        concept: 'BILLETES',
        role: 'stolen',
        quantity: '500',
        unit: 'bolivianos',
      );

      var state = container.read(declarationDraftProvider);
      expect(state.objects.length, 1);
      final moneyObj = state.objects.first;
      expect(moneyObj.concept, 'BILLETES');
      expect(moneyObj.quantity, '500');
      expect(moneyObj.unit, 'bolivianos');
      expect(moneyObj.role, 'stolen');

      // Check deterministic sentence assembly for 500 Bs.
      final draftBs = DeclarationDraft(
        contextId: 'denuncia_robo',
        fact: const FactInfo(action: 'ROBAR'),
        objects: state.objects,
      );
      final sentenceBs = assembler.assembleStructured(draftBs);
      expect(sentenceBs, contains('500 bolivianos en billetes'));

      // Update to 2000 USD
      notifier.setObjectDetail(
        objId,
        quantity: '2000',
        unit: 'dólares',
      );

      state = container.read(declarationDraftProvider);
      final updatedMoney = state.objects.first;
      expect(updatedMoney.quantity, '2000');
      expect(updatedMoney.unit, 'dólares');

      final draftUsd = DeclarationDraft(
        contextId: 'denuncia_robo',
        fact: const FactInfo(action: 'ROBAR'),
        objects: state.objects,
      );
      final sentenceUsd = assembler.assembleStructured(draftUsd);
      expect(sentenceUsd, contains('2000 dólares en billetes'));
    });
  });

  group('Strict Sequential Persona Wizard State Progression (Steps 1 to 4)', () {
    test('Step 1 (Gender) -> Step 2 (Age) -> Step 3 (Build/Height) -> Step 4 (Clothing & Color)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(declarationDraftProvider.notifier);
      final personId = notifier.addPerson(role: 'suspect');

      // Step 1: Set Gender
      notifier.updatePerson(personId, gender: 'HOMBRE');
      var state = container.read(declarationDraftProvider);
      expect(state.persons.first.gender, 'HOMBRE');

      // Step 2: Set Age
      notifier.updatePerson(personId, ageApprox: 'JOVEN');
      state = container.read(declarationDraftProvider);
      expect(state.persons.first.ageApprox, 'JOVEN');

      // Step 3: Set Build & Height
      notifier.updatePerson(personId, height: 'ALTO', build: 'FLACO');
      state = container.read(declarationDraftProvider);
      expect(state.persons.first.height, 'ALTO');
      expect(state.persons.first.build, 'FLACO');

      // Step 4: Add Clothing with Isolated Color
      final poleraId = notifier.addClothing(personId, 'POLERA');
      notifier.setClothingColor(personId, poleraId, 'AZUL');
      state = container.read(declarationDraftProvider);

      expect(state.persons.first.clothing.length, 1);
      expect(state.persons.first.clothing.first.concept, 'POLERA');
      expect(state.persons.first.clothing.first.color, 'AZUL');

      // Assembled text matches complete sequential description
      final draft = DeclarationDraft(
        contextId: 'denuncia_robo',
        fact: const FactInfo(action: 'ROBAR'),
        persons: state.persons,
      );
      final text = assembler.assembleStructured(draft);
      expect(text, contains('Un hombre joven, delgado y alto que llevaba una polera azul'));
    });
  });
}
