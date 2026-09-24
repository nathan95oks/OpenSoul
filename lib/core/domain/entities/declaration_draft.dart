/// Modelo estructurado de hechos y entidades para una declaración.
///
/// Sustituye la dependencia de una bolsa de palabras por relaciones explícitas:
/// quién es cada persona, qué prenda y color le pertenecen, qué objeto tiene
/// qué papel y contenido, y qué lugar es referencia de qué. Cada campo conserva
/// su procedencia y su estado de confirmación para todos los 8 contextos.
library;

/// Cómo se obtuvo el valor de una respuesta.
enum AnswerValueType {
  /// Un concepto del diccionario (una tarjeta/gloss).
  concept,

  /// Texto escrito literalmente por la persona (p. ej. el nombre de un
  /// lugar), que debe conservar espacios y tildes.
  literalText,

  /// Un número con su unidad.
  number,

  /// Una relación entre dos entidades ya capturadas (p. ej. "el hombre que
  /// llevaba la polera roja").
  relation,

  /// La persona indicó explícitamente que no lo sabe o no lo recuerda.
  unknown,

  /// La persona prefirió omitir este dato.
  omission,
}

/// Estado de confirmación de un dato. La ausencia de respuesta NUNCA se
/// equipara a [negated]: son estados distintos y deben poder distinguirse en
/// el texto final.
enum ConfirmationState { confirmed, uncertain, negated, pending }

/// Una persona descrita dentro del relato, con un papel explícito.
class PersonEntity {
  final String id;

  /// 'suspect' (autor del hecho), 'victim', 'witness', 'receiver' o 'other'.
  final String role;
  final String? gender;
  final String? ageApprox;
  final String? build;
  final String? height;
  final ConfirmationState identityState;
  final List<ClothingItem> clothing;

  const PersonEntity({
    required this.id,
    required this.role,
    this.gender,
    this.ageApprox,
    this.build,
    this.height,
    this.identityState = ConfirmationState.pending,
    this.clothing = const [],
  });

  bool get hasAnyTrait =>
      gender != null || ageApprox != null || build != null || height != null;

  PersonEntity copyWith({
    String? role,
    String? gender,
    String? ageApprox,
    String? build,
    String? height,
    ConfirmationState? identityState,
    List<ClothingItem>? clothing,
  }) =>
      PersonEntity(
        id: id,
        role: role ?? this.role,
        gender: gender ?? this.gender,
        ageApprox: ageApprox ?? this.ageApprox,
        build: build ?? this.build,
        height: height ?? this.height,
        identityState: identityState ?? this.identityState,
        clothing: clothing ?? this.clothing,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        if (gender != null) 'gender': gender,
        if (ageApprox != null) 'ageApprox': ageApprox,
        if (build != null) 'build': build,
        if (height != null) 'height': height,
        'identityState': identityState.name,
        'clothing': [for (final c in clothing) c.toJson()],
      };

  factory PersonEntity.fromJson(Map<String, dynamic> json) => PersonEntity(
        id: json['id'] as String? ?? 'p_${DateTime.now().millisecondsSinceEpoch}',
        role: json['role'] as String? ?? 'suspect',
        gender: json['gender'] as String?,
        ageApprox: json['ageApprox'] as String?,
        build: json['build'] as String?,
        height: json['height'] as String?,
        identityState: ConfirmationState.values.firstWhere(
          (e) => e.name == json['identityState'],
          orElse: () => ConfirmationState.pending,
        ),
        clothing: (json['clothing'] as List<dynamic>?)
                ?.map((c) => ClothingItem.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Una prenda o accesorio de una persona concreta, con su color propio.
///
/// Cada prenda pertenece a una sola persona: cambiar el color de una no
/// afecta a las prendas de otra persona ni a otras prendas de la misma.
class ClothingItem {
  final String id;
  final String personId;
  final String concept; // POLERA, PANTALON, GORRA, CHAMARRA, LENTES...
  final String? color;
  final ConfirmationState colorState;

  const ClothingItem({
    required this.id,
    required this.personId,
    required this.concept,
    this.color,
    this.colorState = ConfirmationState.pending,
  });

  ClothingItem copyWith({
    String? concept,
    String? color,
    ConfirmationState? colorState,
  }) =>
      ClothingItem(
        id: id,
        personId: personId,
        concept: concept ?? this.concept,
        color: color ?? this.color,
        colorState: colorState ?? this.colorState,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'concept': concept,
        if (color != null) 'color': color,
        'colorState': colorState.name,
      };

  factory ClothingItem.fromJson(Map<String, dynamic> json) => ClothingItem(
        id: json['id'] as String? ?? 'c_${DateTime.now().millisecondsSinceEpoch}',
        personId: json['personId'] as String? ?? '',
        concept: json['concept'] as String? ?? '',
        color: json['color'] as String?,
        colorState: ConfirmationState.values.firstWhere(
          (e) => e.name == json['colorState'],
          orElse: () => ConfirmationState.pending,
        ),
      );
}

/// Un objeto mencionado en el relato, con el papel y detalle que cumple.
class ObjectInvolved {
  final String id;
  final String concept;

  /// 'stolen' | 'lost' | 'carriedByOtherPerson' | 'evidenceSupport' | 'transferred' | 'fraudulentProduct'
  final String role;

  /// Si el objeto era de otra persona descrita (p. ej. la mochila que llevaba el hombre).
  final String? carriedByPersonId;
  final String? quantity;
  final String? unit;
  final String? detail;

  /// Tipo de documento específico (ej: 'C.I.', 'Licencia', 'Factura', 'Trámite').
  final String? docType;

  /// Contenido interior (para CAJA / BOLSA).
  final String? contents;

  /// Entidad bancaria o plataforma (para DINERO / FRAUDE).
  final String? bank;
  final String? platform;

  const ObjectInvolved({
    required this.id,
    required this.concept,
    required this.role,
    this.carriedByPersonId,
    this.quantity,
    this.unit,
    this.detail,
    this.docType,
    this.contents,
    this.bank,
    this.platform,
  });

  ObjectInvolved copyWith({
    String? concept,
    String? role,
    String? carriedByPersonId,
    String? quantity,
    String? unit,
    String? detail,
    String? docType,
    String? contents,
    String? bank,
    String? platform,
  }) =>
      ObjectInvolved(
        id: id,
        concept: concept ?? this.concept,
        role: role ?? this.role,
        carriedByPersonId: carriedByPersonId ?? this.carriedByPersonId,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        detail: detail ?? this.detail,
        docType: docType ?? this.docType,
        contents: contents ?? this.contents,
        bank: bank ?? this.bank,
        platform: platform ?? this.platform,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'concept': concept,
        'role': role,
        if (carriedByPersonId != null) 'carriedByPersonId': carriedByPersonId,
        if (quantity != null) 'quantity': quantity,
        if (unit != null) 'unit': unit,
        if (detail != null) 'detail': detail,
        if (docType != null) 'docType': docType,
        if (contents != null) 'contents': contents,
        if (bank != null) 'bank': bank,
        if (platform != null) 'platform': platform,
      };

  factory ObjectInvolved.fromJson(Map<String, dynamic> json) => ObjectInvolved(
        id: json['id'] as String? ?? 'o_${DateTime.now().millisecondsSinceEpoch}',
        concept: json['concept'] as String? ?? '',
        role: json['role'] as String? ?? 'stolen',
        carriedByPersonId: json['carriedByPersonId'] as String?,
        quantity: json['quantity'] as String?,
        unit: json['unit'] as String?,
        detail: json['detail'] as String?,
        docType: json['docType'] as String?,
        contents: json['contents'] as String?,
        bank: json['bank'] as String?,
        platform: json['platform'] as String?,
      );
}

/// Relación espacial de un hecho con un lugar de referencia.
class LocationInfo {
  final String? mainPlaceConcept; // CALLE, AVENIDA, PLAZA, MERCADO... (gloss)
  final String? mainPlaceDetail; // texto literal del lugar principal

  final String? relation; // CERCA, LEJOS, DENTRO, FUERA, AL_LADO (gloss)

  /// 'home' (mi casa) | 'knownPlace' | 'other' (texto libre) | 'conceptCard' (MICRO / TRUFI).
  final String? referenceType;
  final String? referenceLiteralText;
  final String? referenceConceptGloss;

  /// Si MICRO / TRUFI actuó como transporte / lugar del hecho o fue el bien robado.
  final bool isVehicleTransport;

  const LocationInfo({
    this.mainPlaceConcept,
    this.mainPlaceDetail,
    this.relation,
    this.referenceType,
    this.referenceLiteralText,
    this.referenceConceptGloss,
    this.isVehicleTransport = false,
  });

  bool get isEmpty =>
      mainPlaceConcept == null && relation == null;

  bool get pending =>
      relation != null &&
      referenceType == null &&
      referenceLiteralText == null &&
      referenceConceptGloss == null;

  LocationInfo copyWith({
    String? mainPlaceConcept,
    String? mainPlaceDetail,
    String? relation,
    String? referenceType,
    String? referenceLiteralText,
    String? referenceConceptGloss,
    bool? isVehicleTransport,
  }) =>
      LocationInfo(
        mainPlaceConcept: mainPlaceConcept ?? this.mainPlaceConcept,
        mainPlaceDetail: mainPlaceDetail ?? this.mainPlaceDetail,
        relation: relation ?? this.relation,
        referenceType: referenceType ?? this.referenceType,
        referenceLiteralText: referenceLiteralText ?? this.referenceLiteralText,
        referenceConceptGloss: referenceConceptGloss ?? this.referenceConceptGloss,
        isVehicleTransport: isVehicleTransport ?? this.isVehicleTransport,
      );

  Map<String, dynamic> toJson() => {
        if (mainPlaceConcept != null) 'mainPlaceConcept': mainPlaceConcept,
        if (mainPlaceDetail != null) 'mainPlaceDetail': mainPlaceDetail,
        if (relation != null) 'relation': relation,
        if (referenceType != null) 'referenceType': referenceType,
        if (referenceLiteralText != null) 'referenceLiteralText': referenceLiteralText,
        if (referenceConceptGloss != null) 'referenceConceptGloss': referenceConceptGloss,
        'isVehicleTransport': isVehicleTransport,
        'pending': pending,
      };

  factory LocationInfo.fromJson(Map<String, dynamic> json) => LocationInfo(
        mainPlaceConcept: json['mainPlaceConcept'] as String?,
        mainPlaceDetail: json['mainPlaceDetail'] as String?,
        relation: json['relation'] as String?,
        referenceType: json['referenceType'] as String?,
        referenceLiteralText: json['referenceLiteralText'] as String?,
        referenceConceptGloss: json['referenceConceptGloss'] as String?,
        isVehicleTransport: json['isVehicleTransport'] as bool? ?? false,
      );
}

/// Fecha, momento del día o tiempo transcurrido.
class TimeInfo {
  final String? dateOrMoment; // AHORA, HOY, AYER, ANTEAYER, TARDE, TEMPRANO...
  final String? elapsedUnit; // HORA, MINUTO, DIA, SEMANA, MES
  final String? elapsedCount;
  final bool unknown;

  const TimeInfo({
    this.dateOrMoment,
    this.elapsedUnit,
    this.elapsedCount,
    this.unknown = false,
  });

  bool get isEmpty =>
      dateOrMoment == null && elapsedUnit == null && !unknown;

  Map<String, dynamic> toJson() => {
        if (dateOrMoment != null) 'dateOrMoment': dateOrMoment,
        if (elapsedUnit != null) 'elapsedUnit': elapsedUnit,
        if (elapsedCount != null) 'elapsedCount': elapsedCount,
        'unknown': unknown,
      };

  factory TimeInfo.fromJson(Map<String, dynamic> json) => TimeInfo(
        dateOrMoment: json['dateOrMoment'] as String?,
        elapsedUnit: json['elapsedUnit'] as String?,
        elapsedCount: json['elapsedCount'] as String?,
        unknown: json['unknown'] as bool? ?? false,
      );
}

/// Existencia y cantidad de testigos.
class WitnessInfo {
  final ConfirmationState existence;
  final String? count;
  final bool willIdentify;

  const WitnessInfo({
    this.existence = ConfirmationState.pending,
    this.count,
    this.willIdentify = false,
  });

  WitnessInfo copyWith({
    ConfirmationState? existence,
    String? count,
    bool? willIdentify,
  }) =>
      WitnessInfo(
        existence: existence ?? this.existence,
        count: count ?? this.count,
        willIdentify: willIdentify ?? this.willIdentify,
      );

  Map<String, dynamic> toJson() => {
        'existence': existence.name,
        if (count != null) 'count': count,
        'willIdentify': willIdentify,
      };

  factory WitnessInfo.fromJson(Map<String, dynamic> json) => WitnessInfo(
        existence: ConfirmationState.values.firstWhere(
          (e) => e.name == json['existence'],
          orElse: () => ConfirmationState.pending,
        ),
        count: json['count'] as String?,
        willIdentify: json['willIdentify'] as bool? ?? false,
      );
}

/// Un elemento de prueba disponible (foto, video, factura, certificado...).
class EvidenceItem {
  final String id;
  final String concept;
  final ConfirmationState availability;
  final bool offeredToShow;

  const EvidenceItem({
    required this.id,
    required this.concept,
    this.availability = ConfirmationState.pending,
    this.offeredToShow = false,
  });

  EvidenceItem copyWith({
    String? concept,
    ConfirmationState? availability,
    bool? offeredToShow,
  }) =>
      EvidenceItem(
        id: id,
        concept: concept ?? this.concept,
        availability: availability ?? this.availability,
        offeredToShow: offeredToShow ?? this.offeredToShow,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'concept': concept,
        'availability': availability.name,
        'offeredToShow': offeredToShow,
      };

  factory EvidenceItem.fromJson(Map<String, dynamic> json) => EvidenceItem(
        id: json['id'] as String? ?? 'e_${DateTime.now().millisecondsSinceEpoch}',
        concept: json['concept'] as String? ?? '',
        availability: ConfirmationState.values.firstWhere(
          (e) => e.name == json['availability'],
          orElse: () => ConfirmationState.pending,
        ),
        offeredToShow: json['offeredToShow'] as bool? ?? false,
      );
}

/// Papel de quien protagoniza un hecho.
///
/// Conjunto cerrado: era texto libre y nada impedía escribir un valor que
/// ningún lado supiera leer, así que la frase perdía a quién atribuía la
/// acción sin que nada lo avisara.
enum ActorRole {
  suspect,
  victim,
  thirdParty,
  unknown;

  static ActorRole parse(String? raw) {
    if (raw == null) return ActorRole.unknown;
    final clave = raw.trim().toLowerCase().replaceAll(' ', '_');
    return switch (clave) {
      'suspect' || 'sospechoso' || 'agresor' || 'ladron' => ActorRole.suspect,
      'victim' || 'victima' || 'yo' || 'declarante' => ActorRole.victim,
      'thirdparty' || 'third_party' || 'tercero' ||
      'otra_persona' => ActorRole.thirdParty,
      _ => ActorRole.unknown,
    };
  }
}

/// Cuánto respalda la persona lo que acaba de declarar.
///
/// No saber no es negar, y negar no es callar. Aplanar los tres estados en un
/// booleano convertía «no me acuerdo» en «no».
enum Certainty {
  confirmed,
  uncertain,
  unknown;

  static Certainty parse(String? raw) => switch (raw?.trim().toLowerCase()) {
        'uncertain' || 'incierto' => Certainty.uncertain,
        'unknown' || 'desconocido' => Certainty.unknown,
        _ => Certainty.confirmed,
      };
}

/// Un hecho del relato, con su propio protagonista.
///
/// Antes el relato tenía un único `FactInfo.action`, así que elegir ROBAR y
/// después ESCAPAR perdía el primero: la segunda selección lo sobrescribía.
/// Peor aún, la huida viajaba como propiedad del robo (`escapar_actor`), de
/// modo que no se podía distinguir «me robaron y yo escapé» de «me robaron y
/// el ladrón escapó». Cada hecho lleva ahora su protagonista.
class Fact {
  /// Estable dentro del borrador, para poder editar o quitar uno solo.
  final String id;

  /// ROBAR, PERDER, ESCAPAR, DAÑAR, ENGAÑAR, AGREDIR, AMENAZAR…
  final String action;

  final ActorRole actorRole;
  final String? actorDetail;

  /// Objetos de este hecho concreto, por id de entidad del borrador.
  final List<String> objectEntityIds;

  final bool negated;
  final Certainty certainty;

  /// 'theft' | 'loss' | 'unknown'. Solo tiene sentido en hechos de sustracción.
  final String? lossType;

  const Fact({
    required this.id,
    required this.action,
    this.actorRole = ActorRole.unknown,
    this.actorDetail,
    this.objectEntityIds = const [],
    this.negated = false,
    this.certainty = Certainty.confirmed,
    this.lossType,
  });

  Fact copyWith({
    String? action,
    ActorRole? actorRole,
    String? actorDetail,
    List<String>? objectEntityIds,
    bool? negated,
    Certainty? certainty,
    String? lossType,
  }) =>
      Fact(
        id: id,
        action: action ?? this.action,
        actorRole: actorRole ?? this.actorRole,
        actorDetail: actorDetail ?? this.actorDetail,
        objectEntityIds: objectEntityIds ?? this.objectEntityIds,
        negated: negated ?? this.negated,
        certainty: certainty ?? this.certainty,
        lossType: lossType ?? this.lossType,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'actorRole': actorRole.name,
        if (actorDetail != null) 'actorDetail': actorDetail,
        if (objectEntityIds.isNotEmpty) 'objectEntityIds': objectEntityIds,
        'negated': negated,
        'certainty': certainty.name,
        if (lossType != null) 'lossType': lossType,
      };

  factory Fact.fromJson(Map<String, dynamic> json) => Fact(
        id: (json['id'] ?? 'f1').toString(),
        action: (json['action'] ?? '').toString(),
        actorRole: ActorRole.parse(json['actorRole'] as String?),
        actorDetail: json['actorDetail'] as String?,
        objectEntityIds: [
          for (final o in (json['objectEntityIds'] as List? ?? const []))
            o.toString(),
        ],
        negated: json['negated'] as bool? ?? false,
        certainty: Certainty.parse(json['certainty'] as String?),
        lossType: json['lossType'] as String?,
      );

  /// Lee el objeto `fact` del contrato anterior, donde la huida viajaba como
  /// propiedad del hecho principal. Devuelve la lista que ese objeto
  /// significaba de verdad: uno o dos hechos.
  static List<Fact> fromLegacyJson(Map<String, dynamic> json) {
    final action = json['action'] as String?;
    if (action == null || action.isEmpty) return const [];

    final principal = Fact(
      id: 'f1',
      action: action,
      actorRole: ActorRole.parse(json['actorRole'] as String?),
      actorDetail: json['actorDetail'] as String?,
      lossType: json['lossType'] as String?,
    );

    final escapar = json['escapar_actor'] ?? json['escaparActor'];
    if (escapar == null || action.toUpperCase() == 'ESCAPAR') {
      return [principal];
    }
    return [
      principal,
      Fact(
        id: 'f1-escape',
        action: 'ESCAPAR',
        actorRole: ActorRole.parse(escapar.toString()),
      ),
    ];
  }
}

/// Detalles específicos para Denuncia de Violencia.
class ViolenceDetails {
  final String? aggressionType;
  final bool physicalInjury;
  final bool medicalCareRequested;
  final bool protectionRequested;

  const ViolenceDetails({
    this.aggressionType,
    this.physicalInjury = false,
    this.medicalCareRequested = false,
    this.protectionRequested = false,
  });

  Map<String, dynamic> toJson() => {
        if (aggressionType != null) 'aggressionType': aggressionType,
        'physicalInjury': physicalInjury,
        'medicalCareRequested': medicalCareRequested,
        'protectionRequested': protectionRequested,
      };

  factory ViolenceDetails.fromJson(Map<String, dynamic> json) => ViolenceDetails(
        aggressionType: json['aggressionType'] as String?,
        physicalInjury: json['physicalInjury'] as bool? ?? false,
        medicalCareRequested: json['medicalCareRequested'] as bool? ?? false,
        protectionRequested: json['protectionRequested'] as bool? ?? false,
      );
}

/// Detalles específicos para Engaño con Dinero / Estafas.
class FraudDetails {
  final String? amount;
  final String? currency; // 'bolivianos' | 'dolares'
  final String? deliveryMethod; // 'banco' | 'efectivo' | 'qr' | 'otro'
  final String? recipientName;
  final String? receiptDoc;

  const FraudDetails({
    this.amount,
    this.currency = 'bolivianos',
    this.deliveryMethod,
    this.recipientName,
    this.receiptDoc,
  });

  Map<String, dynamic> toJson() => {
        if (amount != null) 'amount': amount,
        if (currency != null) 'currency': currency,
        if (deliveryMethod != null) 'deliveryMethod': deliveryMethod,
        if (recipientName != null) 'recipientName': recipientName,
        if (receiptDoc != null) 'receiptDoc': receiptDoc,
      };

  factory FraudDetails.fromJson(Map<String, dynamic> json) => FraudDetails(
        amount: json['amount'] as String?,
        currency: json['currency'] as String? ?? 'bolivianos',
        deliveryMethod: json['deliveryMethod'] as String?,
        recipientName: json['recipientName'] as String?,
        receiptDoc: json['receiptDoc'] as String?,
      );
}

/// Detalles específicos para Amenazas Digitales.
class DigitalThreatDetails {
  final String? channel; // 'WhatsApp' | 'Facebook' | 'SMS' | 'Llamada'
  final String? messageType; // 'texto' | 'audio' | 'imagen'
  final bool hasSavedEvidence;

  const DigitalThreatDetails({
    this.channel,
    this.messageType,
    this.hasSavedEvidence = false,
  });

  Map<String, dynamic> toJson() => {
        if (channel != null) 'channel': channel,
        if (messageType != null) 'messageType': messageType,
        'hasSavedEvidence': hasSavedEvidence,
      };

  factory DigitalThreatDetails.fromJson(Map<String, dynamic> json) =>
      DigitalThreatDetails(
        channel: json['channel'] as String?,
        messageType: json['messageType'] as String?,
        hasSavedEvidence: json['hasSavedEvidence'] as bool? ?? false,
      );
}

/// Detalles específicos para Trámites e Identificación.
class ProcedureDetails {
  final String? docType; // 'Carnet de Identidad (C.I.)' | 'Licencia' | 'Pasaporte' | 'Certificado de Nacimiento'
  final String? procedureType; // 'renovacion' | 'duplicado' | 'consulta'
  final String? targetInstitution; // 'SEGIP' | 'SERECI' | 'FELCC' | 'FISCALIA'

  const ProcedureDetails({
    this.docType,
    this.procedureType,
    this.targetInstitution,
  });

  Map<String, dynamic> toJson() => {
        if (docType != null) 'docType': docType,
        if (procedureType != null) 'procedureType': procedureType,
        if (targetInstitution != null) 'targetInstitution': targetInstitution,
      };

  factory ProcedureDetails.fromJson(Map<String, dynamic> json) => ProcedureDetails(
        docType: json['docType'] as String?,
        procedureType: json['procedureType'] as String?,
        targetInstitution: json['targetInstitution'] as String?,
      );
}

/// Detalles específicos para Consultas y Testimonios.
class InquiryDetails {
  final bool isWitnessReport;
  final bool isProcessInquiry;
  final String? caseOrProcessReference;

  const InquiryDetails({
    this.isWitnessReport = false,
    this.isProcessInquiry = false,
    this.caseOrProcessReference,
  });

  Map<String, dynamic> toJson() => {
        'isWitnessReport': isWitnessReport,
        'isProcessInquiry': isProcessInquiry,
        if (caseOrProcessReference != null)
          'caseOrProcessReference': caseOrProcessReference,
      };

  factory InquiryDetails.fromJson(Map<String, dynamic> json) => InquiryDetails(
        isWitnessReport: json['isWitnessReport'] as bool? ?? false,
        isProcessInquiry: json['isProcessInquiry'] as bool? ?? false,
        caseOrProcessReference: json['caseOrProcessReference'] as String?,
      );
}

/// Borrador estructurado completo de una declaración para todos los 8 contextos.
class DeclarationDraft {
  final String contextId;
  final String speechAct; // 'statement' | 'question' | 'instruction' | 'reply'
  final String? replyToId;

  /// Los hechos del relato, hasta dos en «¿Qué ocurrió?».
  ///
  /// El orden es el de selección, **no** el temporal ni el causal: nada
  /// autoriza a redactar «primero X y luego Y» porque se tocaran en ese orden.
  final List<Fact> facts;
  final List<PersonEntity> persons;
  final List<ObjectInvolved> objects;
  final LocationInfo location;
  final TimeInfo time;
  final WitnessInfo witnesses;
  final List<EvidenceItem> evidence;

  final bool injured;
  final bool medicalHelpRequested;
  final ConfirmationState willFileComplaint;
  final bool needsLegalSupport;
  final String? receivingInstitution;

  // Extensiones transversales
  final ViolenceDetails? violence;
  final FraudDetails? fraud;
  final DigitalThreatDetails? digitalThreat;
  final ProcedureDetails? procedure;
  final InquiryDetails? inquiry;

  const DeclarationDraft({
    required this.contextId,
    this.speechAct = 'statement',
    this.replyToId,
    this.facts = const [],
    this.persons = const [],
    this.objects = const [],
    this.location = const LocationInfo(),
    this.time = const TimeInfo(),
    this.witnesses = const WitnessInfo(),
    this.evidence = const [],
    this.injured = false,
    this.medicalHelpRequested = false,
    this.willFileComplaint = ConfirmationState.pending,
    this.needsLegalSupport = false,
    this.receivingInstitution,
    this.violence,
    this.fraud,
    this.digitalThreat,
    this.procedure,
    this.inquiry,
  });

  /// El hecho que encabeza el relato, si hay alguno.
  ///
  /// Muchos sitios solo necesitan saber «qué ocurrió» en una palabra. Lo que
  /// ninguno puede hacer es escribir a través de esto: la lista es la dueña.
  Fact? get primaryFact => facts.isEmpty ? null : facts.first;

  /// Si el relato afirma alguna de [actions] sin negarla.
  bool hasAction(Set<String> actions) => facts.any(
      (f) => !f.negated && actions.contains(f.action.toUpperCase()));

  Fact? factWithAction(String action) {
    for (final f in facts) {
      if (f.action.toUpperCase() == action.toUpperCase()) return f;
    }
    return null;
  }

  DeclarationDraft copyWith({
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
        contextId: contextId ?? this.contextId,
        speechAct: speechAct ?? this.speechAct,
        replyToId: replyToId ?? this.replyToId,
        facts: facts ?? this.facts,
        persons: persons ?? this.persons,
        objects: objects ?? this.objects,
        location: location ?? this.location,
        time: time ?? this.time,
        witnesses: witnesses ?? this.witnesses,
        evidence: evidence ?? this.evidence,
        injured: injured ?? this.injured,
        medicalHelpRequested: medicalHelpRequested ?? this.medicalHelpRequested,
        willFileComplaint: willFileComplaint ?? this.willFileComplaint,
        needsLegalSupport: needsLegalSupport ?? this.needsLegalSupport,
        receivingInstitution: receivingInstitution ?? this.receivingInstitution,
        violence: violence ?? this.violence,
        fraud: fraud ?? this.fraud,
        digitalThreat: digitalThreat ?? this.digitalThreat,
        procedure: procedure ?? this.procedure,
        inquiry: inquiry ?? this.inquiry,
      );

  Map<String, dynamic> toJson() => {
        'contextId': contextId,
        'speechAct': speechAct,
        if (replyToId != null) 'replyToId': replyToId,
        'facts': [for (final f in facts) f.toJson()],
        'persons': [for (final p in persons) p.toJson()],
        'objects': [for (final o in objects) o.toJson()],
        'location': location.toJson(),
        'time': time.toJson(),
        'witnesses': witnesses.toJson(),
        'evidence': [for (final e in evidence) e.toJson()],
        'injured': injured,
        'medicalHelpRequested': medicalHelpRequested,
        'willFileComplaint': willFileComplaint.name,
        'needsLegalSupport': needsLegalSupport,
        if (receivingInstitution != null)
          'receivingInstitution': receivingInstitution,
        if (violence != null) 'violence': violence!.toJson(),
        if (fraud != null) 'fraud': fraud!.toJson(),
        if (digitalThreat != null) 'digitalThreat': digitalThreat!.toJson(),
        if (procedure != null) 'procedure': procedure!.toJson(),
        if (inquiry != null) 'inquiry': inquiry!.toJson(),
      };

  factory DeclarationDraft.fromJson(Map<String, dynamic> json) =>
      DeclarationDraft(
        contextId: json['contextId'] as String? ?? 'denuncia_robo',
        speechAct: json['speechAct'] as String? ?? 'statement',
        replyToId: json['replyToId'] as String?,
        // Compatibilidad: un borrador guardado con el contrato anterior trae
        // `fact` como objeto único, con la huida dentro. Se lee como la lista
        // que siempre significó.
        facts: json['facts'] is List
            ? [
                for (final f in (json['facts'] as List))
                  Fact.fromJson(Map<String, dynamic>.from(f as Map)),
              ]
            : (json['fact'] is Map
                ? Fact.fromLegacyJson(
                    Map<String, dynamic>.from(json['fact'] as Map))
                : const <Fact>[]),
        persons: (json['persons'] as List<dynamic>?)
                ?.map((p) => PersonEntity.fromJson(p as Map<String, dynamic>))
                .toList() ??
            const [],
        objects: (json['objects'] as List<dynamic>?)
                ?.map((o) => ObjectInvolved.fromJson(o as Map<String, dynamic>))
                .toList() ??
            const [],
        location: json['location'] != null
            ? LocationInfo.fromJson(json['location'] as Map<String, dynamic>)
            : const LocationInfo(),
        time: json['time'] != null
            ? TimeInfo.fromJson(json['time'] as Map<String, dynamic>)
            : const TimeInfo(),
        witnesses: json['witnesses'] != null
            ? WitnessInfo.fromJson(json['witnesses'] as Map<String, dynamic>)
            : const WitnessInfo(),
        evidence: (json['evidence'] as List<dynamic>?)
                ?.map((e) => EvidenceItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        injured: json['injured'] as bool? ?? false,
        medicalHelpRequested: json['medicalHelpRequested'] as bool? ?? false,
        willFileComplaint: ConfirmationState.values.firstWhere(
          (e) => e.name == json['willFileComplaint'],
          orElse: () => ConfirmationState.pending,
        ),
        needsLegalSupport: json['needsLegalSupport'] as bool? ?? false,
        receivingInstitution: json['receivingInstitution'] as String?,
        violence: json['violence'] != null
            ? ViolenceDetails.fromJson(json['violence'] as Map<String, dynamic>)
            : null,
        fraud: json['fraud'] != null
            ? FraudDetails.fromJson(json['fraud'] as Map<String, dynamic>)
            : null,
        digitalThreat: json['digitalThreat'] != null
            ? DigitalThreatDetails.fromJson(
                json['digitalThreat'] as Map<String, dynamic>)
            : null,
        procedure: json['procedure'] != null
            ? ProcedureDetails.fromJson(
                json['procedure'] as Map<String, dynamic>)
            : null,
        inquiry: json['inquiry'] != null
            ? InquiryDetails.fromJson(json['inquiry'] as Map<String, dynamic>)
            : null,
      );
}
