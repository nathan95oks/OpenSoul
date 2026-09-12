/// Modelo estructurado de hechos y entidades para una declaración.
///
/// Sustituye, para el contexto `denuncia_robo`, la dependencia de una bolsa
/// de palabras (una lista plana de glosas que el ensamblador debía adivinar
/// cómo relacionar) por relaciones explícitas: quién es cada persona, qué
/// prenda y color le pertenecen, qué objeto tiene qué papel, y qué lugar es
/// referencia de qué. Cada campo conserva su procedencia (tarjeta elegida,
/// texto literal escrito) y su estado de confirmación, sin equiparar la
/// ausencia de respuesta con una negación.
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

  /// 'suspect' (autor del hecho), 'witness' o 'other'. Describir a alguien
  /// no le atribuye por sí solo la autoría: eso requiere que el hecho lo
  /// señale explícitamente.
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
    String? gender,
    String? ageApprox,
    String? build,
    String? height,
    ConfirmationState? identityState,
    List<ClothingItem>? clothing,
  }) =>
      PersonEntity(
        id: id,
        role: role,
        gender: gender ?? this.gender,
        ageApprox: ageApprox ?? this.ageApprox,
        build: build ?? this.build,
        height: height ?? this.height,
        identityState: identityState ?? this.identityState,
        clothing: clothing ?? this.clothing,
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

  ClothingItem copyWith({String? color, ConfirmationState? colorState}) =>
      ClothingItem(
        id: id,
        personId: personId,
        concept: concept,
        color: color ?? this.color,
        colorState: colorState ?? this.colorState,
      );
}

/// Un objeto mencionado en el relato, con el papel que cumple.
///
/// El mismo concepto léxico (p. ej. MOCHILA) puede aparecer dos veces con
/// papeles o dueños distintos: eso son dos entidades, no una sola.
class ObjectInvolved {
  final String id;
  final String concept;

  /// 'stolen' | 'lost' | 'carriedByOtherPerson' | 'evidenceSupport'
  final String role;

  /// Si el objeto era de otra persona descrita (p. ej. la mochila que
  /// llevaba el hombre), su id aquí.
  final String? carriedByPersonId;
  final String? quantity;
  final String? unit;
  final String? detail;

  const ObjectInvolved({
    required this.id,
    required this.concept,
    required this.role,
    this.carriedByPersonId,
    this.quantity,
    this.unit,
    this.detail,
  });
}

/// Relación espacial de un hecho con un lugar de referencia.
///
/// CERCA/LEJOS/DENTRO/FUERA/AL_LADO no significan nada por sí solos: además
/// de la relación se necesita saber cerca/lejos/dentro/fuera/al lado de qué.
/// Si esa referencia falta, [pending] queda en true y el texto no debe
/// inventar un lugar vago.
class LocationInfo {
  final String? mainPlaceConcept; // CALLE, AVENIDA, PLAZA, MERCADO... (gloss)
  final String? mainPlaceDetail; // texto literal del lugar principal

  final String? relation; // CERCA, LEJOS, DENTRO, FUERA, AL_LADO (gloss)

  /// 'home' (mi casa) | 'knownPlace' (algo ya indicado antes) | 'other'
  /// (texto libre) | 'conceptCard' (una tarjeta como MICRO).
  final String? referenceType;
  final String? referenceLiteralText;
  final String? referenceConceptGloss;

  const LocationInfo({
    this.mainPlaceConcept,
    this.mainPlaceDetail,
    this.relation,
    this.referenceType,
    this.referenceLiteralText,
    this.referenceConceptGloss,
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
  }) =>
      LocationInfo(
        mainPlaceConcept: mainPlaceConcept ?? this.mainPlaceConcept,
        mainPlaceDetail: mainPlaceDetail ?? this.mainPlaceDetail,
        relation: relation ?? this.relation,
        referenceType: referenceType ?? this.referenceType,
        referenceLiteralText: referenceLiteralText ?? this.referenceLiteralText,
        referenceConceptGloss: referenceConceptGloss ?? this.referenceConceptGloss,
      );
}

/// Fecha, momento del día o tiempo transcurrido, capturados por separado.
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
}

/// Existencia y cantidad de testigos, con su propia polaridad. No saber si
/// hay testigos es distinto de saber que no los hay.
class WitnessInfo {
  final ConfirmationState existence;
  final String? count;
  final bool willIdentify;

  const WitnessInfo({
    this.existence = ConfirmationState.pending,
    this.count,
    this.willIdentify = false,
  });
}

/// Un elemento de prueba disponible (foto, video, factura, certificado...),
/// separado del testimonio de testigos.
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
}

/// El hecho principal que la persona quiere comunicar, separado de quién
/// interviene y de lo que le ocurrió a esa persona.
///
/// Elegir un menú (p. ej. "Denunciar robo") organiza la navegación; no prueba
/// por sí solo que haya ocurrido un robo. [action] puede ser null cuando la
/// persona aún no lo aclaró, o 'unknown' cuando indicó explícitamente que no
/// sabe qué ocurrió (p. ej. tras elegir PERDER).
class FactInfo {
  final String? action; // ROBAR, PERDER, ESCAPAR, DAÑAR, ENGAÑAR, null, 'unknown'
  final bool motiveConfirmed;

  const FactInfo({this.action, this.motiveConfirmed = true});
}

/// Borrador estructurado completo de una declaración.
///
/// Es lo que viaja al generador local y, versionado, al backend: conserva
/// las relaciones desde la selección hasta el texto final, en vez de una
/// lista plana de glosas sin relación entre sí.
class DeclarationDraft {
  final String contextId;
  final String speechAct; // 'statement' | 'question' | 'instruction'
  final String? replyToId;

  final FactInfo fact;
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

  const DeclarationDraft({
    required this.contextId,
    this.speechAct = 'statement',
    this.replyToId,
    this.fact = const FactInfo(),
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
  });

  Map<String, dynamic> toJson() => {
        'contextId': contextId,
        'speechAct': speechAct,
        if (replyToId != null) 'replyToId': replyToId,
        'fact': {
          if (fact.action != null) 'action': fact.action,
          'motiveConfirmed': fact.motiveConfirmed,
        },
        'persons': [
          for (final p in persons)
            {
              'id': p.id,
              'role': p.role,
              if (p.gender != null) 'gender': p.gender,
              if (p.ageApprox != null) 'ageApprox': p.ageApprox,
              if (p.build != null) 'build': p.build,
              if (p.height != null) 'height': p.height,
              'identityState': p.identityState.name,
              'clothing': [
                for (final c in p.clothing)
                  {
                    'id': c.id,
                    'concept': c.concept,
                    if (c.color != null) 'color': c.color,
                    'colorState': c.colorState.name,
                  },
              ],
            },
        ],
        'objects': [
          for (final o in objects)
            {
              'id': o.id,
              'concept': o.concept,
              'role': o.role,
              if (o.carriedByPersonId != null)
                'carriedByPersonId': o.carriedByPersonId,
              if (o.quantity != null) 'quantity': o.quantity,
              if (o.unit != null) 'unit': o.unit,
              if (o.detail != null) 'detail': o.detail,
            },
        ],
        'location': {
          if (location.mainPlaceConcept != null)
            'mainPlaceConcept': location.mainPlaceConcept,
          if (location.mainPlaceDetail != null)
            'mainPlaceDetail': location.mainPlaceDetail,
          if (location.relation != null) 'relation': location.relation,
          if (location.referenceType != null)
            'referenceType': location.referenceType,
          if (location.referenceLiteralText != null)
            'referenceLiteralText': location.referenceLiteralText,
          if (location.referenceConceptGloss != null)
            'referenceConceptGloss': location.referenceConceptGloss,
          'pending': location.pending,
        },
        'time': {
          if (time.dateOrMoment != null) 'dateOrMoment': time.dateOrMoment,
          if (time.elapsedUnit != null) 'elapsedUnit': time.elapsedUnit,
          if (time.elapsedCount != null) 'elapsedCount': time.elapsedCount,
          'unknown': time.unknown,
        },
        'witnesses': {
          'existence': witnesses.existence.name,
          if (witnesses.count != null) 'count': witnesses.count,
          'willIdentify': witnesses.willIdentify,
        },
        'evidence': [
          for (final e in evidence)
            {
              'id': e.id,
              'concept': e.concept,
              'availability': e.availability.name,
              'offeredToShow': e.offeredToShow,
            },
        ],
        'injured': injured,
        'medicalHelpRequested': medicalHelpRequested,
        'willFileComplaint': willFileComplaint.name,
        'needsLegalSupport': needsLegalSupport,
        if (receivingInstitution != null)
          'receivingInstitution': receivingInstitution,
      };
}
