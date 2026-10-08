import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';

/// El borrador de la declaración se guarda en el teléfono como JSON y se
/// restaura al volver: ningún dato puede perderse en la ida y vuelta.
void main() {
  const completo = DeclarationDraft(
    contextId: 'denuncia_robo',
    speechAct: 'reply',
    replyToId: 'turno-7',
    facts: [
      Fact(
        id: 'f1',
        action: 'ROBAR',
        actorRole: ActorRole.suspect,
        actorDetail: 'un hombre',
        objectEntityIds: ['o1'],
        certainty: Certainty.uncertain,
        lossType: 'robo',
      ),
      Fact(id: 'f2', action: 'PEGAR', negated: true),
    ],
    persons: [
      PersonEntity(
        id: 'p1',
        role: 'suspect',
        gender: 'HOMBRE',
        ageApprox: 'JOVEN',
        build: 'DELGADO',
        height: 'ALTO',
        identityState: ConfirmationState.uncertain,
        clothing: [
          ClothingItem(
            id: 'c1',
            personId: 'p1',
            concept: 'POLERA',
            color: 'NEGRO',
            colorState: ConfirmationState.confirmed,
          ),
        ],
      ),
    ],
    objects: [
      ObjectInvolved(
        id: 'o1',
        concept: 'CELULAR',
        role: 'stolen',
        carriedByPersonId: 'p1',
        quantity: '1',
        unit: 'unidad',
        detail: 'Samsung',
        docType: 'Factura',
        contents: 'fotos',
        bank: 'BNB',
        platform: 'QR',
      ),
    ],
    location: LocationInfo(
      mainPlaceConcept: 'CALLE',
      mainPlaceDetail: 'Heroínas',
      relation: 'CERCA',
      referenceType: 'concepto',
      referenceLiteralText: 'la plaza',
      referenceConceptGloss: 'PLAZA',
      isVehicleTransport: true,
    ),
    time: TimeInfo(
      dateOrMoment: 'AYER',
      elapsedUnit: 'HORA',
      elapsedCount: '2',
    ),
    witnesses: WitnessInfo(
      existence: ConfirmationState.confirmed,
      count: '2',
      willIdentify: true,
    ),
    evidence: [
      EvidenceItem(
        id: 'e1',
        concept: 'FOTOS',
        availability: ConfirmationState.confirmed,
        offeredToShow: true,
      ),
    ],
    injured: true,
    medicalHelpRequested: true,
    willFileComplaint: ConfirmationState.confirmed,
    needsLegalSupport: true,
    receivingInstitution: 'FELCC',
    violence: ViolenceDetails(
      aggressionType: 'PEGAR',
      physicalInjury: true,
      medicalCareRequested: true,
      protectionRequested: true,
    ),
    fraud: FraudDetails(
      amount: '500',
      currency: 'dólares',
      deliveryMethod: 'transferencia',
      recipientName: 'Juan',
      receiptDoc: 'comprobante',
    ),
    digitalThreat: DigitalThreatDetails(
      channel: 'WhatsApp',
      messageType: 'audio',
      hasSavedEvidence: true,
    ),
    procedure: ProcedureDetails(
      docType: 'Pasaporte',
      procedureType: 'renovación',
      targetInstitution: 'SEGIP',
    ),
    inquiry: InquiryDetails(
      isWitnessReport: true,
      isProcessInquiry: true,
      caseOrProcessReference: 'FIS-123',
    ),
  );

  test('un borrador completo vuelve igual de su JSON', () {
    final vuelta = DeclarationDraft.fromJson(completo.toJson());
    expect(vuelta.toJson(), completo.toJson());
  });

  test('copyWith cambia solo lo pedido', () {
    final otro = completo.copyWith(contextId: 'violencia', injured: false);
    expect(otro.contextId, 'violencia');
    expect(otro.injured, isFalse);
    final resto = otro.toJson()
      ..remove('contextId')
      ..remove('injured');
    final antes = completo.toJson()
      ..remove('contextId')
      ..remove('injured');
    expect(resto, antes);
  });

  test('un borrador guardado con datos faltantes se restaura vacío', () {
    final vacio = DeclarationDraft.fromJson(const {'contextId': 'otro'});
    expect(vacio.contextId, 'otro');
    expect(vacio.persons, isEmpty);
    expect(vacio.fraud, isNull);
  });
}
