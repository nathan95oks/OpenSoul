import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';

/// Estado estructurado propio de `denuncia_robo`: personas, objetos y lugar.
///
/// La navegación (qué pregunta está activa, avanzar/retroceder) sigue
/// viviendo en `semanticZonesProvider`, que ya modela bien "una pregunta a la
/// vez". Lo que ese provider NO puede modelar es que una zona contenga varias
/// entidades independientes con sus propios atributos (dos personas, cada
/// una con su propia ropa y color; dos objetos con papeles distintos aunque
/// compartan concepto léxico). Por eso las zonas de entidades (persona,
/// objetos, lugar) escriben aquí en vez de en la lista plana de glosas.
class DenunciaRoboDraftNotifier extends Notifier<DeclarationDraft> {
  @override
  DeclarationDraft build() =>
      const DeclarationDraft(contextId: 'denuncia_robo');

  void reset() => state = const DeclarationDraft(contextId: 'denuncia_robo');

  // ---- Hecho ----------------------------------------------------------

  void setFactAction(String? action, {bool motiveConfirmed = true}) {
    state = _copy(fact: FactInfo(action: action, motiveConfirmed: motiveConfirmed));
  }

  // ---- Personas ---------------------------------------------------------

  String addPerson({required String role}) {
    final id = 'p${state.persons.length + 1}_${DateTime.now().microsecondsSinceEpoch}';
    final person = PersonEntity(id: id, role: role);
    state = _copy(persons: [...state.persons, person]);
    return id;
  }

  void removePerson(String personId) {
    state = _copy(
      persons: state.persons.where((p) => p.id != personId).toList(),
      objects: [
        for (final o in state.objects)
          if (o.carriedByPersonId == personId)
            ObjectInvolved(
              id: o.id,
              concept: o.concept,
              role: o.role,
              quantity: o.quantity,
              unit: o.unit,
              detail: o.detail,
            )
          else
            o,
      ],
    );
  }

  void updatePerson(
    String personId, {
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
    final id = 'c_${DateTime.now().microsecondsSinceEpoch}_${state.persons.length}';
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

  void setClothingColor(String personId, String clothingId, String? color,
      {ConfirmationState state1 = ConfirmationState.confirmed}) {
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

  // ---- Objetos ------------------------------------------------------------

  String addObject({
    required String concept,
    required String role,
    String? carriedByPersonId,
    String? quantity,
    String? unit,
    String? detail,
  }) {
    final id = 'o_${DateTime.now().microsecondsSinceEpoch}_${state.objects.length}';
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
      ),
    ]);
    return id;
  }

  void removeObject(String id) {
    state = _copy(objects: state.objects.where((o) => o.id != id).toList());
  }

  void setObjectDetail(String id, {String? quantity, String? unit, String? detail}) {
    state = _copy(objects: [
      for (final o in state.objects)
        if (o.id == id)
          ObjectInvolved(
            id: o.id,
            concept: o.concept,
            role: o.role,
            carriedByPersonId: o.carriedByPersonId,
            quantity: quantity ?? o.quantity,
            unit: unit ?? o.unit,
            detail: detail ?? o.detail,
          )
        else
          o,
    ]);
  }

  // ---- Lugar ----------------------------------------------------------

  void setMainPlace(String? concept, {String? detail}) {
    state = _copy(
      location: state.location.copyWith(
        mainPlaceConcept: concept,
        mainPlaceDetail: detail,
      ),
    );
  }

  void setLocationRelation(String? relation) {
    state = _copy(
      location: LocationInfo(
        mainPlaceConcept: state.location.mainPlaceConcept,
        mainPlaceDetail: state.location.mainPlaceDetail,
        relation: relation,
      ),
    );
  }

  void setLocationReference({
    String? referenceType,
    String? referenceLiteralText,
    String? referenceConceptGloss,
  }) {
    state = _copy(
      location: LocationInfo(
        mainPlaceConcept: state.location.mainPlaceConcept,
        mainPlaceDetail: state.location.mainPlaceDetail,
        relation: state.location.relation,
        referenceType: referenceType,
        referenceLiteralText: referenceLiteralText,
        referenceConceptGloss: referenceConceptGloss,
      ),
    );
  }

  void clearLocationReference() {
    state = _copy(
      location: LocationInfo(
        mainPlaceConcept: state.location.mainPlaceConcept,
        mainPlaceDetail: state.location.mainPlaceDetail,
        relation: state.location.relation,
      ),
    );
  }

  // ---- Tiempo, testigos, evidencia, trámite --------------------------------

  void setTime(TimeInfo time) => state = _copy(time: time);

  void setWitnesses(WitnessInfo witnesses) => state = _copy(witnesses: witnesses);

  String addEvidence(String concept,
      {ConfirmationState availability = ConfirmationState.confirmed, bool offeredToShow = false}) {
    final id = 'e_${DateTime.now().microsecondsSinceEpoch}_${state.evidence.length}';
    state = _copy(evidence: [
      ...state.evidence,
      EvidenceItem(id: id, concept: concept, availability: availability, offeredToShow: offeredToShow),
    ]);
    return id;
  }

  void removeEvidence(String id) {
    state = _copy(evidence: state.evidence.where((e) => e.id != id).toList());
  }

  void setInjured(bool injured) => state = _copy(injured: injured);
  void setMedicalHelpRequested(bool v) => state = _copy(medicalHelpRequested: v);
  void setWillFileComplaint(ConfirmationState v) => state = _copy(willFileComplaint: v);
  void setNeedsLegalSupport(bool v) => state = _copy(needsLegalSupport: v);
  void setReceivingInstitution(String? v) => state = _copy(receivingInstitution: v);

  DeclarationDraft _copy({
    FactInfo? fact,
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
  }) =>
      DeclarationDraft(
        contextId: state.contextId,
        speechAct: state.speechAct,
        replyToId: state.replyToId,
        fact: fact ?? state.fact,
        persons: persons ?? state.persons,
        objects: objects ?? state.objects,
        location: location ?? state.location,
        time: time ?? state.time,
        witnesses: witnesses ?? state.witnesses,
        evidence: evidence ?? state.evidence,
        injured: injured ?? state.injured,
        medicalHelpRequested: medicalHelpRequested ?? state.medicalHelpRequested,
        willFileComplaint: willFileComplaint ?? state.willFileComplaint,
        needsLegalSupport: needsLegalSupport ?? state.needsLegalSupport,
        receivingInstitution: receivingInstitution ?? state.receivingInstitution,
      );
}

final denunciaRoboDraftProvider =
    NotifierProvider<DenunciaRoboDraftNotifier, DeclarationDraft>(
  DenunciaRoboDraftNotifier.new,
);

const _unidadesTiempo = {'HORA', 'MINUTO', 'DÍA', 'SEMANA', 'MES'};

/// Combina el borrador de entidades (persona, objetos, lugar) con las
/// respuestas simples de las demás zonas de `denuncia_robo` (hecho, tiempo,
/// testigos, evidencia, emergencia, denuncia, apoyo legal, institución) en
/// un único [DeclarationDraft] listo para generar texto o enviarse al
/// backend. Vive aquí, y no en el ensamblador, porque necesita leer dos
/// providers de presentación a la vez.
DeclarationDraft buildFullDeclarationDraft(WidgetRef ref) {
  final zonesState = ref.read(semanticZonesProvider);
  final entityDraft = ref.read(denunciaRoboDraftProvider);

  List<String> answersOf(String zoneId) => zonesState.zoneAnswers[zoneId] ?? const [];
  List<String>? qualifiersOf(String zoneId, String gloss) =>
      zonesState.zoneQualifiers[zoneId]?[gloss];

  final hechoAns = answersOf('hecho');
  String? factAction;
  if (hechoAns.contains('NO_SABER')) {
    factAction = 'unknown';
  } else if (hechoAns.isNotEmpty) {
    factAction = hechoAns.first;
  }

  final tiempoAns = answersOf('tiempo');
  var time = const TimeInfo();
  if (tiempoAns.contains('NO_SABER')) {
    time = const TimeInfo(unknown: true);
  } else {
    final unit = tiempoAns.where(_unidadesTiempo.contains).cast<String?>().firstWhere(
          (_) => true,
          orElse: () => null,
        );
    if (unit != null) {
      final cantidad = qualifiersOf('tiempo', unit);
      time = TimeInfo(
        elapsedUnit: unit,
        elapsedCount: (cantidad != null && cantidad.isNotEmpty) ? cantidad.first : null,
      );
    } else if (tiempoAns.isNotEmpty) {
      time = TimeInfo(dateOrMoment: tiempoAns.first);
    }
  }

  final testigosAns = answersOf('testigos');
  var witnesses = const WitnessInfo();
  if (testigosAns.contains('SÍ')) {
    final cantidad = qualifiersOf('testigos', 'SÍ');
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
  final evidence = [
    for (final g in evidenciaAns)
      if (!ofrecimiento.contains(g))
        EvidenceItem(
          id: 'ev_$g',
          concept: g,
          availability: ConfirmationState.confirmed,
          offeredToShow: ofreceMostrar,
        ),
  ];

  final emergenciaAns = answersOf('emergencia');
  const heridaGlosas = {'HERIDA', 'DOLOR'};
  const ayudaGlosas = {'HOSPITAL', 'DOCTOR', 'AUXILIO', 'CERTIFICADO'};
  final injured = emergenciaAns.any(heridaGlosas.contains);
  final medicalHelp = emergenciaAns.any(ayudaGlosas.contains);

  final denunciaAns = answersOf('denuncia');
  var willFile = ConfirmationState.pending;
  if (denunciaAns.contains('SÍ') || denunciaAns.contains('AHORA')) {
    willFile = ConfirmationState.confirmed;
  } else if (denunciaAns.contains('NO')) {
    willFile = ConfirmationState.negated;
  } else if (denunciaAns.contains('NO_SABER')) {
    willFile = ConfirmationState.uncertain;
  }

  final apoyoAns = answersOf('apoyo_legal');
  const apoyoPositivo = {'ABOGADO', 'INTÉRPRETE', 'SEPDAVI', 'SEPDEP', 'AYUDAR', 'SÍ'};
  final needsLegal = apoyoAns.any(apoyoPositivo.contains) && !apoyoAns.contains('NO');

  final institucionAns = answersOf('institucion');
  final institution = institucionAns.isEmpty ? null : institucionAns.first;

  final conocimientoAns = answersOf('conocimiento');
  var persons = entityDraft.persons;
  if (conocimientoAns.isNotEmpty && persons.isNotEmpty) {
    final last = persons.last;
    var idState = last.identityState;
    if (conocimientoAns.contains('SÍ')) {
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

  return DeclarationDraft(
    contextId: 'denuncia_robo',
    fact: FactInfo(action: factAction),
    persons: persons,
    objects: entityDraft.objects,
    location: entityDraft.location,
    time: time,
    witnesses: witnesses,
    evidence: evidence,
    injured: injured,
    medicalHelpRequested: medicalHelp,
    willFileComplaint: willFile,
    needsLegalSupport: needsLegal,
    receivingInstitution: institution,
  );
}
