import 'dart:convert';

/// Qué quiere lograr la persona. Tres entradas, no tres grupos exclusivos de
/// instituciones: se puede consultar en Derechos Reales, preguntar por un
/// documento en la Policía o pedir orientación sobre una denuncia.
enum NeedId {
  complaints('denuncias'),
  procedures('tramites'),
  inquiries('consultas');

  final String id;

  const NeedId(this.id);

  static NeedId? byId(String? id) {
    if (id == null) return null;
    for (final n in NeedId.values) {
      if (n.id == id) return n;
    }
    return null;
  }
}

class NeedDefinition {
  final NeedId id;
  final String label;
  final String description;

  /// De dónde arranca el recorrido. Cambia el orden y los datos que se piden,
  /// no solo el título de la pantalla.
  final String startingPoint;

  const NeedDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.startingPoint,
  });

  static NeedDefinition? fromJson(Map<String, dynamic> json) {
    final id = NeedId.byId(json['id'] as String?);
    if (id == null) return null;
    return NeedDefinition(
      id: id,
      label: (json['etiqueta'] ?? '').toString(),
      description: (json['descripcion'] ?? '').toString(),
      startingPoint: (json['puntoDePartida'] ?? '').toString(),
    );
  }
}

/// Una intención que el perfil propone pero para la que **no hay
/// vocabulario**.
///
/// Viaja hasta la interfaz para poder decirlo, no para esconderlo: se ofrece
/// explicando qué parte puede comunicarse hoy y qué falta. Ocultarla haría
/// creer que el trámite no existe; presentarla sin aviso haría creer que está
/// cubierto.
class UncoveredIntent {
  final String id;
  final NeedId? need;
  final List<String> lexicalGap;

  const UncoveredIntent({
    required this.id,
    this.need,
    this.lexicalGap = const [],
  });

  factory UncoveredIntent.fromJson(Map<String, dynamic> json) =>
      UncoveredIntent(
        id: (json['id'] ?? '').toString(),
        need: NeedId.byId(json['necesidad'] as String?),
        lexicalGap: [
          for (final g in (json['brechaLexica'] as List? ?? const []))
            g.toString(),
        ],
      );
}

class ProfileIntent {
  final String id;
  final NeedId? need;

  const ProfileIntent({required this.id, this.need});

  factory ProfileIntent.fromJson(Map<String, dynamic> json) => ProfileIntent(
        id: (json['id'] ?? '').toString(),
        need: NeedId.byId(json['necesidad'] as String?),
      );
}

class InstitutionUnit {
  final String id;
  final String name;

  const InstitutionUnit({required this.id, required this.name});
}

/// El perfil de la institución que atiende.
///
/// Ordena las prioridades de una atención. **No es contenido**: nada de lo que
/// diga el perfil entra en la declaración de nadie, y sus prioridades no
/// prohíben expresar otra cosa. Si alguien llega a Derechos Reales a contar un
/// hecho sufrido fuera, tiene que poder hacerlo.
class InstitutionProfile {
  final String id;
  final String name;
  final String serviceType;
  final List<NeedId> priorityNeeds;
  final List<String> initialScopes;
  final List<ProfileIntent> intents;
  final List<UncoveredIntent> uncoveredIntents;
  final List<InstitutionUnit> units;

  const InstitutionProfile({
    required this.id,
    required this.name,
    required this.serviceType,
    this.priorityNeeds = const [],
    this.initialScopes = const [],
    this.intents = const [],
    this.uncoveredIntents = const [],
    this.units = const [],
  });

  /// Perfil vacío: atención general, sin institución elegida.
  ///
  /// No bloquea nada. La falta de institución nunca impide comunicarse.
  static const unknown = InstitutionProfile(
    id: 'sin_institucion',
    name: 'Sin institución',
    serviceType: 'general',
    priorityNeeds: NeedId.values,
  );

  bool prioritizes(String intentId) =>
      intents.any((i) => i.id == intentId);

  /// Si esta intención está propuesta pero sin vocabulario que la sostenga.
  UncoveredIntent? gapFor(String intentId) {
    for (final u in uncoveredIntents) {
      if (u.id == intentId) return u;
    }
    return null;
  }

  factory InstitutionProfile.fromJson(Map<String, dynamic> json) =>
      InstitutionProfile(
        id: (json['id'] ?? '').toString(),
        name: (json['nombre'] ?? '').toString(),
        serviceType: (json['tipoServicio'] ?? '').toString(),
        priorityNeeds: [
          for (final n in (json['necesidadesPrioritarias'] as List? ?? const []))
            if (NeedId.byId(n.toString()) != null) NeedId.byId(n.toString())!,
        ],
        initialScopes: [
          for (final s in (json['ambitosIniciales'] as List? ?? const []))
            s.toString(),
        ],
        intents: [
          for (final i in (json['intenciones'] as List? ?? const []))
            ProfileIntent.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
        uncoveredIntents: [
          for (final i in (json['intencionesSinCobertura'] as List? ?? const []))
            UncoveredIntent.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
        units: [
          for (final u in (json['unidades'] as List? ?? const []))
            InstitutionUnit(
              id: (u['id'] ?? '').toString(),
              name: (u['nombre'] ?? '').toString(),
            ),
        ],
      );
}

/// El catálogo de negocio empaquetado con la aplicación.
class BusinessCatalog {
  final int version;
  final List<NeedDefinition> needs;
  final List<InstitutionProfile> profiles;

  const BusinessCatalog({
    this.version = 0,
    this.needs = const [],
    this.profiles = const [],
  });

  static const empty = BusinessCatalog();

  bool get isEmpty => profiles.isEmpty;

  InstitutionProfile profileById(String? id) {
    if (id == null) return InstitutionProfile.unknown;
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return InstitutionProfile.unknown;
  }

  NeedDefinition? needById(NeedId id) {
    for (final n in needs) {
      if (n.id == id) return n;
    }
    return null;
  }

  factory BusinessCatalog.fromJsonString(String raw) =>
      BusinessCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  factory BusinessCatalog.fromJson(Map<String, dynamic> json) => BusinessCatalog(
        version: (json['version'] as num?)?.toInt() ?? 0,
        needs: [
          for (final n in (json['necesidades'] as List? ?? const []))
            if (NeedDefinition.fromJson(Map<String, dynamic>.from(n as Map)) !=
                null)
              NeedDefinition.fromJson(Map<String, dynamic>.from(n))!,
        ],
        profiles: [
          for (final p in (json['perfiles'] as List? ?? const []))
            InstitutionProfile.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
      );
}
