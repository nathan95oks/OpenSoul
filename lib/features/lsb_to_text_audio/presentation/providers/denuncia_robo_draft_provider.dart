import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';

/// Estado estructurado universal para declaraciones en todos los 8 contextos:
/// personas, prendas con color aislado, objetos con papel/contenido, lugar con
/// ancla espacial y detalles transversales (violencia, fraude, digital, trámites).
class DeclarationDraftNotifier extends Notifier<DeclarationDraft> {
  int _idCounter = 0;
  String _uniqueId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${++_idCounter}';

  @override
  DeclarationDraft build() {
    final ctx = ref.watch(contextProvider);
    final contextId = ctx?.id ?? 'denuncia_robo';
    return DeclarationDraft(contextId: contextId);
  }

  void reset([String? contextId]) {
    final effectiveContext =
        contextId ?? ref.read(contextProvider)?.id ?? 'denuncia_robo';
    state = DeclarationDraft(contextId: effectiveContext);
  }

  void setSpeechAct(String speechAct) {
    state = _copy(speechAct: speechAct);
  }

  // ---- Hecho y Desambiguación -------------------------------------------

  /// Acciones que admite un relato. La misma constante que usa la zona
  /// «hecho» del catálogo, para que no puedan separarse.
  static const int maxFacts = DeclarationDraftLimits.maxFacts;

  /// Anade o quita el hecho de [action], sin tocar los demas.
  ///
  /// Volver a tocar la misma tarjeta lo quita, y quitar un hecho deja intacto
  /// el otro con su protagonista y sus detalles.
  void toggleFactAction(String action) {
    final clave = action.toUpperCase();
    final actuales = [...state.facts];
    final indice = actuales.indexWhere((f) => f.action.toUpperCase() == clave);

    if (indice >= 0) {
      actuales.removeAt(indice);
    } else {
      if (actuales.length >= maxFacts) return;
      actuales.add(Fact(id: _newFactId(clave), action: clave));
    }
    state = _copy(facts: actuales);
  }

  /// Deja el relato con un unico hecho [action], descartando los demas.
  ///
  /// Es lo que hace elegir una accion cuando la pregunta solo admite una.
  void setSingleFactAction(String? action) {
    if (action == null || action.isEmpty) {
      state = _copy(facts: const []);
      return;
    }
    final clave = action.toUpperCase();
    final existente = state.factWithAction(clave);
    state = _copy(facts: [
      existente ?? Fact(id: _newFactId(clave), action: clave),
    ]);
  }

  /// Protagonista y detalle de UN hecho concreto.
  ///
  /// Sin el id no se podia distinguir "me robaron y yo escape" de "me robaron
  /// y el ladron escapo": el papel se guardaba una sola vez para todo el
  /// relato.
  void setFactActor({
    required String factId,
    ActorRole? actorRole,
    String? actorDetail,
    String? lossType,
    bool? negated,
    Certainty? certainty,
  }) {
    final actuales = [
      for (final f in state.facts)
        if (f.id == factId)
          f.copyWith(
            actorRole: actorRole,
            actorDetail: actorDetail,
            lossType: lossType,
            negated: negated,
            certainty: certainty,
          )
        else
          f,
    ];
    state = _copy(facts: actuales);
  }

  void removeFact(String factId) {
    state = _copy(facts: [
      for (final f in state.facts)
        if (f.id != factId) f,
    ]);
  }

  /// Resuelve si lo ocurrido fue robo o perdida.
  ///
  /// Toca el hecho de sustraccion; si no hay ninguno, lo crea. No convierte
  /// en robo un relato que solo dijo ESCAPAR.
  void setLossDisambiguation({required String lossType, String? note}) {
    final accion = lossType == 'loss' ? 'PERDER' : 'ROBAR';
    final sustraccion = state.factWithAction('PERDER') ??
        state.factWithAction('ROBAR');

    if (sustraccion == null) {
      final actuales = [...state.facts];
      if (actuales.length >= maxFacts) actuales.removeAt(0);
      actuales.insert(
        0,
        Fact(
          id: _newFactId(accion),
          action: accion,
          lossType: lossType,
          actorDetail: note,
        ),
      );
      state = _copy(facts: actuales);
      return;
    }

    state = _copy(facts: [
      for (final f in state.facts)
        if (f.id == sustraccion.id)
          f.copyWith(action: accion, lossType: lossType, actorDetail: note)
        else
          f,
    ]);
  }

  String _newFactId(String action) =>
      'f_${action.toLowerCase()}_${DateTime.now().microsecondsSinceEpoch}';

  // ---- Personas y Atributos Anidados (Máquina de Estados) ---------------

  String addPerson({required String role, String? id}) {
    // Permite al llamador fijar el id: cuando la creación se difiere al
    // primer frame (para no mutar el provider en pleno montaje del widget),
    // la UI ya necesitó ese id de forma síncrona para su primer render.
    final personId = id ?? _uniqueId('p');
    final person = PersonEntity(id: personId, role: role);
    state = _copy(persons: [...state.persons, person]);
    return personId;
  }

  void removePerson(String personId) {
    state = _copy(
      persons: state.persons.where((p) => p.id != personId).toList(),
      objects: [
        for (final o in state.objects)
          if (o.carriedByPersonId == personId)
            o.copyWith(carriedByPersonId: null)
          else
            o,
      ],
    );
  }

  void updatePerson(
    String personId, {
    String? role,
    String? gender,
    String? ageApprox,
    String? build,
    String? height,
    ConfirmationState? identityState,
  }) {
    state = _copy(persons: [
      for (final p in state.persons)
        if (p.id == personId)
          p.copyWith(
            role: role,
            gender: gender,
            ageApprox: ageApprox,
            build: build,
            height: height,
            identityState: identityState,
          )
        else
          p,
    ]);
  }

  String addClothing(String personId, String concept) {
    final id = _uniqueId('c');
    state = _copy(persons: [
      for (final p in state.persons)
        if (p.id == personId)
          p.copyWith(clothing: [
            ...p.clothing,
            ClothingItem(id: id, personId: personId, concept: concept),
          ])
        else
          p,
    ]);
    return id;
  }

  String addClothingWithColor(String personId, String concept, String? color) {
    final id = _uniqueId('c');
    state = _copy(persons: [
      for (final p in state.persons)
        if (p.id == personId)
          p.copyWith(clothing: [
            ...p.clothing,
            ClothingItem(
              id: id,
              personId: personId,
              concept: concept,
              color: color,
              colorState: color != null
                  ? ConfirmationState.confirmed
                  : ConfirmationState.pending,
            ),
          ])
        else
          p,
    ]);
    return id;
  }

  void setClothingColor(
    String personId,
    String clothingId,
    String? color, {
    ConfirmationState state1 = ConfirmationState.confirmed,
  }) {
    state = _copy(persons: [
      for (final p in state.persons)
        if (p.id == personId)
          p.copyWith(clothing: [
            for (final c in p.clothing)
              if (c.id == clothingId)
                c.copyWith(color: color, colorState: state1)
              else
                c,
          ])
        else
          p,
    ]);
  }

  void removeClothing(String personId, String clothingId) {
    state = _copy(persons: [
      for (final p in state.persons)
        if (p.id == personId)
          p.copyWith(
            clothing: p.clothing.where((c) => c.id != clothingId).toList(),
          )
        else
          p,
    ]);
  }

  // ---- Objetos y Especificaciones Categoriales ---------------------------

  String addObject({
    required String concept,
    required String role,
    String? carriedByPersonId,
    String? quantity,
    String? unit,
    String? detail,
    String? docType,
    String? contents,
    String? bank,
    String? platform,
  }) {
    final id = _uniqueId('o');
    state = _copy(objects: [
      ...state.objects,
      ObjectInvolved(
        id: id,
        concept: concept,
        role: role,
        carriedByPersonId: carriedByPersonId,
        quantity: quantity,
        unit: unit,
        detail: detail,
        docType: docType,
        contents: contents,
        bank: bank,
        platform: platform,
      ),
    ]);
    return id;
  }

  void removeObject(String id) {
    state = _copy(objects: state.objects.where((o) => o.id != id).toList());
  }

  void setObjectDetail(
    String id, {
    String? quantity,
    String? unit,
    String? detail,
    String? docType,
    String? contents,
    String? bank,
    String? platform,
    String? role,
  }) {
    state = _copy(objects: [
      for (final o in state.objects)
        if (o.id == id)
          o.copyWith(
            quantity: quantity,
            unit: unit,
            detail: detail,
            docType: docType,
            contents: contents,
            bank: bank,
            platform: platform,
            role: role,
          )
        else
          o,
    ]);
  }

  // ---- Lugar y Relaciones Espaciales -----------------------------------

  void setMainPlace(
    String? concept, {
    String? detail,
    bool isVehicleTransport = false,
  }) {
    state = _copy(
      location: state.location.copyWith(
        mainPlaceConcept: concept,
        mainPlaceDetail: detail,
        isVehicleTransport: isVehicleTransport,
      ),
    );
  }

  void setLocationRelation(String? relation) {
    state = _copy(
      location: LocationInfo(
        mainPlaceConcept: state.location.mainPlaceConcept,
        mainPlaceDetail: state.location.mainPlaceDetail,
        relation: relation,
        isVehicleTransport: state.location.isVehicleTransport,
      ),
    );
  }

  void setLocationReference({
    String? referenceType,
    String? referenceLiteralText,
    String? referenceConceptGloss,
    bool? isVehicleTransport,
  }) {
    state = _copy(
      location: LocationInfo(
        mainPlaceConcept: state.location.mainPlaceConcept,
        mainPlaceDetail: state.location.mainPlaceDetail,
        relation: state.location.relation,
        referenceType: referenceType,
        referenceLiteralText: referenceLiteralText,
        referenceConceptGloss: referenceConceptGloss,
        isVehicleTransport:
            isVehicleTransport ?? state.location.isVehicleTransport,
      ),
    );
  }

  void clearLocationReference() {
    state = _copy(
      location: LocationInfo(
        mainPlaceConcept: state.location.mainPlaceConcept,
        mainPlaceDetail: state.location.mainPlaceDetail,
        relation: state.location.relation,
        isVehicleTransport: state.location.isVehicleTransport,
      ),
    );
  }

  // ---- Tiempo, testigos, evidencia, trámite ----------------------------

  void setTime(TimeInfo time) => state = _copy(time: time);

  void setWitnesses(WitnessInfo witnesses) =>
      state = _copy(witnesses: witnesses);

  String addEvidence(
    String concept, {
    ConfirmationState availability = ConfirmationState.confirmed,
    bool offeredToShow = false,
  }) {
    final id = _uniqueId('e');
    state = _copy(evidence: [
      ...state.evidence,
      EvidenceItem(
        id: id,
        concept: concept,
        availability: availability,
        offeredToShow: offeredToShow,
      ),
    ]);
    return id;
  }

  void removeEvidence(String id) {
    state = _copy(evidence: state.evidence.where((e) => e.id != id).toList());
  }

  void setInjured(bool injured) => state = _copy(injured: injured);
  void setMedicalHelpRequested(bool v) =>
      state = _copy(medicalHelpRequested: v);
  void setWillFileComplaint(ConfirmationState v) =>
      state = _copy(willFileComplaint: v);
  void setNeedsLegalSupport(bool v) => state = _copy(needsLegalSupport: v);
  void setReceivingInstitution(String? v) =>
      state = _copy(receivingInstitution: v);

  // ---- Extensiones transversales ---------------------------------------

  void setViolenceDetails(ViolenceDetails v) => state = _copy(violence: v);
  void setFraudDetails(FraudDetails f) => state = _copy(fraud: f);
  void setDigitalThreatDetails(DigitalThreatDetails d) =>
      state = _copy(digitalThreat: d);
  void setProcedureDetails(ProcedureDetails p) => state = _copy(procedure: p);
  void setInquiryDetails(InquiryDetails i) => state = _copy(inquiry: i);

  DeclarationDraft _copy({
    String? contextId,
    String? speechAct,
    String? replyToId,
    List<Fact>? facts,
    List<PersonEntity>? persons,
    List<ObjectInvolved>? objects,
    LocationInfo? location,
    TimeInfo? time,
    WitnessInfo? witnesses,
    List<EvidenceItem>? evidence,
    bool? injured,
    bool? medicalHelpRequested,
    ConfirmationState? willFileComplaint,
    bool? needsLegalSupport,
    String? receivingInstitution,
    ViolenceDetails? violence,
    FraudDetails? fraud,
    DigitalThreatDetails? digitalThreat,
    ProcedureDetails? procedure,
    InquiryDetails? inquiry,
  }) =>
      DeclarationDraft(
        contextId: contextId ?? state.contextId,
        speechAct: speechAct ?? state.speechAct,
        replyToId: replyToId ?? state.replyToId,
        facts: facts ?? state.facts,
        persons: persons ?? state.persons,
        objects: objects ?? state.objects,
        location: location ?? state.location,
        time: time ?? state.time,
        witnesses: witnesses ?? state.witnesses,
        evidence: evidence ?? state.evidence,
        injured: injured ?? state.injured,
        medicalHelpRequested:
            medicalHelpRequested ?? state.medicalHelpRequested,
        willFileComplaint: willFileComplaint ?? state.willFileComplaint,
        needsLegalSupport: needsLegalSupport ?? state.needsLegalSupport,
        receivingInstitution:
            receivingInstitution ?? state.receivingInstitution,
        violence: violence ?? state.violence,
        fraud: fraud ?? state.fraud,
        digitalThreat: digitalThreat ?? state.digitalThreat,
        procedure: procedure ?? state.procedure,
        inquiry: inquiry ?? state.inquiry,
      );
}

final declarationDraftProvider =
    NotifierProvider<DeclarationDraftNotifier, DeclarationDraft>(
  DeclarationDraftNotifier.new,
);

/// Alias para compatibilidad con código existente.
final denunciaRoboDraftProvider = declarationDraftProvider;

const _unidadesTiempo = {'HORA', 'MINUTO', 'DÍA', 'DIA', 'SEMANA', 'MES'};

/// Combina el borrador de entidades (persona, objetos, lugar) con las
/// respuestas simples de las demás zonas en un único [DeclarationDraft]
/// listo para generar texto determinista o enviarse al backend.
DeclarationDraft buildFullDeclarationDraft(dynamic ref) {
  final SemanticZonesState zonesState = ref.read(semanticZonesProvider);
  final DeclarationDraft entityDraft = ref.read(declarationDraftProvider);
  final currentContextId =
      ref.read(contextProvider)?.id ?? entityDraft.contextId;

  List<String> answersOf(String zoneId) =>
      zonesState.zoneAnswers[zoneId] ?? const [];
  List<String>? qualifiersOf(String zoneId, String gloss) =>
      zonesState.zoneQualifiers[zoneId]?[gloss];

  final hechoAns = answersOf('hecho');
  // Los hechos que ya tienen protagonista o detalle mandan: reconstruirlos
  // desde las glosas perderia lo que la persona aclaro despues. Las glosas de
  // la zona solo anaden los que aun no estan.
  final facts = <Fact>[...entityDraft.facts];
  if (hechoAns.contains('NO_SABER')) {
    if (facts.isEmpty) {
      facts.add(const Fact(
        id: 'f_unknown',
        action: 'unknown',
        certainty: Certainty.unknown,
      ));
    }
  } else {
    for (final gloss in hechoAns) {
      if (facts.length >= DeclarationDraftNotifier.maxFacts) break;
      final clave = gloss.toUpperCase();
      if (facts.any((f) => f.action.toUpperCase() == clave)) continue;
      facts.add(Fact(id: 'f_${clave.toLowerCase()}', action: clave));
    }
    // Un hecho que ya no esta seleccionado deja de contarse, pero solo si la
    // zona llego a responderse: una zona vacia no borra lo ya declarado.
    if (hechoAns.isNotEmpty) {
      final elegidas = hechoAns.map((g) => g.toUpperCase()).toSet();
      facts.retainWhere((f) => elegidas.contains(f.action.toUpperCase()));
    }
  }

  final tiempoAns = answersOf('tiempo');
  var time = entityDraft.time;
  if (tiempoAns.contains('NO_SABER')) {
    time = const TimeInfo(unknown: true);
  } else if (tiempoAns.isNotEmpty) {
    final unit = tiempoAns
        .where((g) => _unidadesTiempo.contains(g.toUpperCase()))
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    if (unit != null) {
      final cantidad = qualifiersOf('tiempo', unit);
      time = TimeInfo(
        elapsedUnit: unit,
        elapsedCount:
            (cantidad != null && cantidad.isNotEmpty) ? cantidad.first : null,
      );
    } else {
      time = TimeInfo(dateOrMoment: tiempoAns.first);
    }
  }

  final testigosAns = answersOf('testigos');
  var witnesses = entityDraft.witnesses;
  if (testigosAns.contains('SÍ') || testigosAns.contains('SI')) {
    final cantidad = qualifiersOf('testigos', 'SÍ') ?? qualifiersOf('testigos', 'SI');
    witnesses = WitnessInfo(
      existence: ConfirmationState.confirmed,
      count: (cantidad != null && cantidad.isNotEmpty) ? cantidad.first : null,
    );
  } else if (testigosAns.contains('NO')) {
    witnesses = const WitnessInfo(existence: ConfirmationState.negated);
  } else if (testigosAns.contains('NO_SABER')) {
    witnesses = const WitnessInfo(existence: ConfirmationState.uncertain);
  }

  final evidenciaAns = answersOf('evidencia');
  const ofrecimiento = {'MOSTRAR', 'PUEDO'};
  final ofreceMostrar = evidenciaAns.any(ofrecimiento.contains);
  final existingEvidence = [...entityDraft.evidence];
  for (final g in evidenciaAns) {
    if (ofrecimiento.contains(g)) continue;
    // ESCRIBIR es el "otro": lo que describe la prueba es el texto libre
    // que se tecleó, no la palabra "escribir" en sí.
    final concepto = g == 'ESCRIBIR'
        ? (qualifiersOf('evidencia', 'ESCRIBIR')?.firstOrNull ?? g)
        : g;
    if (!existingEvidence.any((e) => e.concept == concepto)) {
      existingEvidence.add(
        EvidenceItem(
          id: 'ev_$concepto',
          concept: concepto,
          availability: ConfirmationState.confirmed,
          offeredToShow: ofreceMostrar,
        ),
      );
    }
  }

  final emergenciaAns = answersOf('emergencia');
  const heridaGlosas = {'HERIDA', 'DOLOR'};
  const ayudaGlosas = {'HOSPITAL', 'DOCTOR', 'AUXILIO', 'CERTIFICADO'};
  final injured = entityDraft.injured || emergenciaAns.any(heridaGlosas.contains);
  final medicalHelp = entityDraft.medicalHelpRequested ||
      emergenciaAns.any(ayudaGlosas.contains);

  final denunciaAns = answersOf('denuncia');
  var willFile = entityDraft.willFileComplaint;
  if (denunciaAns.contains('SÍ') ||
      denunciaAns.contains('SI') ||
      denunciaAns.contains('AHORA')) {
    willFile = ConfirmationState.confirmed;
  } else if (denunciaAns.contains('NO')) {
    willFile = ConfirmationState.negated;
  } else if (denunciaAns.contains('NO_SABER')) {
    willFile = ConfirmationState.uncertain;
  }

  final apoyoAns = answersOf('apoyo_legal');
  const apoyoPositivo = {
    'ABOGADO',
    'INTÉRPRETE',
    'SEPDAVI',
    'SEPDEP',
    'AYUDAR',
    'SÍ',
    'SI',
  };
  final needsLegal = entityDraft.needsLegalSupport ||
      (apoyoAns.any(apoyoPositivo.contains) && !apoyoAns.contains('NO'));

  final institucionAns = answersOf('institucion');
  final institution = institucionAns.isNotEmpty
      ? institucionAns.first
      : entityDraft.receivingInstitution;

  final conocimientoAns = answersOf('conocimiento');
  var persons = entityDraft.persons;
  if (conocimientoAns.isNotEmpty && persons.isNotEmpty) {
    final last = persons.last;
    var idState = last.identityState;
    if (conocimientoAns.contains('SÍ') || conocimientoAns.contains('SI')) {
      idState = ConfirmationState.confirmed;
    } else if (conocimientoAns.contains('NO')) {
      idState = ConfirmationState.negated;
    } else if (conocimientoAns.contains('NO_SABER')) {
      idState = ConfirmationState.uncertain;
    }
    persons = [
      for (final p in persons)
        if (p.id == last.id) p.copyWith(identityState: idState) else p,
    ];
  }

  // Transversal details synthesis
  ViolenceDetails? violence = entityDraft.violence;
  if (currentContextId == 'violencia') {
    final saludAns = answersOf('salud_urgencia');
    final riesgoAns = answersOf('emocion_riesgo');
    violence = ViolenceDetails(
      aggressionType: hechoAns.isNotEmpty ? hechoAns.first : null,
      physicalInjury: injured || saludAns.any(heridaGlosas.contains),
      medicalCareRequested: medicalHelp || saludAns.any(ayudaGlosas.contains),
      protectionRequested:
          riesgoAns.contains('PROTEGER') || riesgoAns.contains('AUXILIO'),
    );
  }

  FraudDetails? fraud = entityDraft.fraud;
  if (currentContextId == 'engano_dinero') {
    final medioAns = answersOf('medio_banco');
    // La moneda no se supone: si nadie la eligió, no hay moneda.
    fraud = FraudDetails(
      amount: fraud?.amount,
      currency: fraud?.currency,
      deliveryMethod: medioAns.isNotEmpty ? medioAns.first.toLowerCase() : null,
      recipientName: fraud?.recipientName,
      receiptDoc: fraud?.receiptDoc,
    );
  }

  DigitalThreatDetails? digital = entityDraft.digitalThreat;
  if (currentContextId == 'amenaza_digital') {
    // CELULAR dice «por celular», no «por WhatsApp»: la aplicación ni el
    // tipo de mensaje se deducen.
    digital = DigitalThreatDetails(
      channel: digital?.channel ??
          (hechoAns.contains('CELULAR')
              ? 'celular'
              : (hechoAns.contains('INTERNET') ? 'internet' : null)),
      messageType: digital?.messageType,
      hasSavedEvidence: existingEvidence.isNotEmpty ||
          answersOf('evidencia').contains('GUARDAR'),
    );
  }

  return DeclarationDraft(
    contextId: currentContextId,
    speechAct: entityDraft.speechAct,
    replyToId: entityDraft.replyToId,
    facts: facts,
    persons: persons,
    objects: entityDraft.objects,
    location: entityDraft.location,
    time: time,
    witnesses: witnesses,
    evidence: existingEvidence,
    injured: injured,
    medicalHelpRequested: medicalHelp,
    willFileComplaint: willFile,
    needsLegalSupport: needsLegal,
    receivingInstitution: institution,
    violence: violence,
    fraud: fraud,
    digitalThreat: digital,
    procedure: entityDraft.procedure,
    inquiry: entityDraft.inquiry,
  );
}
