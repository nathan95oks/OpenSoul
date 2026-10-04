import 'dart:convert';

import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_zone.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/rag/tramites_data.g.dart';

/// Un trámite documentado de Cochabamba (SERECI, SEGIP, impuestos…).
class RagTramite {
  final String contextId;
  final String name;
  final String institution;
  final String area;
  final String emoji;
  final String scenarioId;

  const RagTramite({
    required this.contextId,
    required this.name,
    required this.institution,
    required this.area,
    required this.emoji,
    required this.scenarioId,
  });
}

/// Los trámites del corpus RAG dentro del módulo de tarjetas LSB.
///
/// Cada trámite es un contexto más de la familia «Trámites» y un recorrido
/// del banco de preguntas: la pregunta del funcionario con su formulación en
/// LSB y las respuestas documentadas de la persona sorda como opciones. Así
/// se muestran con los mismos componentes y el mismo flujo guiado que
/// Denuncias. Los datos los genera `tool/build_rag_corpus.py`.
abstract final class RagTramites {
  static final Map<String, dynamic> _data =
      jsonDecode(kRagTramitesJson) as Map<String, dynamic>;

  static final List<RagTramite> all = [
    for (final raw in _data['contextos'] as List<dynamic>)
      RagTramite(
        contextId: raw['id'] as String,
        name: raw['nombre'] as String,
        institution: raw['institucion'] as String,
        area: raw['area'] as String,
        emoji: raw['emoji'] as String,
        scenarioId: raw['escenario'] as String,
      ),
  ];

  static final List<String> contextIds = [for (final t in all) t.contextId];

  static final Map<String, RagTramite> _byScenario = {
    for (final t in all) t.scenarioId: t,
  };

  /// Los contextos que ve la persona sorda en «Trámites».
  static final List<SemanticContext> contexts = [
    for (final t in all)
      SemanticContext(
        id: t.contextId,
        name: t.name,
        icon: 'description',
        emoji: t.emoji,
        description: t.institution,
        entryZoneId: 'tramite',
        zones: [
          SemanticZone(
            id: 'tramite',
            label: t.name,
            hint: t.institution,
            emoji: t.emoji,
            // Las respuestas de un trámite vienen del banco (sus opciones);
            // la zona ofrece las de siempre para contestar.
            glossAllowlist: const ['SÍ', 'NO', 'NO_SABER'],
          ),
        ],
      ),
  ];

  /// Cómo se llama y qué abarca cada institución en la lista de «Trámites».
  static const Map<String, (String, String, String)> _sectionInfo = {
    'DDRR': (
      'Derechos Reales',
      '🏠',
      'Certificado de gravámenes e inscripción de inmuebles',
    ),
    'IMP': (
      'GAM Cochabamba',
      '💰',
      'Impuestos de motos, vehículos e inmuebles (RUAT)',
    ),
    'FIS': (
      'Ministerio Público – Fiscalía',
      '🔎',
      'Denuncias ante la Fiscalía y su seguimiento',
    ),
    'OJ': ('Órgano Judicial', '⚖️', 'Causas, juzgados y audiencias'),
    'SEPDEP': ('SEPDEP', '🧑‍⚖️', 'Defensa pública gratuita'),
    'SEPDAVI': ('SEPDAVI', '🤝', 'Patrocinio y apoyo a víctimas de delitos'),
    'FELCC': ('FELCC', '🚓', 'Denuncias de robos y estafas'),
    'FELCV': ('FELCV', '🛡️', 'Denuncias de violencia familiar'),
    'SLIM': (
      'SLIM – Gobierno Autónomo Municipal Cbba',
      '💜',
      'Apoyo a mujeres en situación de violencia',
    ),
    'DNA': (
      'DNA – Gobierno Autónomo Municipal Cbba',
      '🧒',
      'Defensa de niñas, niños y adolescentes',
    ),
    'NOT': (
      'Notarías de Fe Pública DIRNOPLU',
      '✍️',
      'Contratos de alquiler, anticrético y notarías',
    ),
    'SEGIP': ('SEGIP', '🪪', 'Cédula de identidad'),
    'SERECI': (
      'SERECI',
      '📜',
      'Certificados de nacimiento, matrimonio y defunción',
    ),
    'DISC': (
      'Registro y carnet de discapacidad',
      '♿',
      'Calificación y carnet de discapacidad',
    ),
    'LSB': (
      'Derechos lingüísticos LSB',
      '🤟',
      'Intérprete y accesibilidad en LSB',
    ),
  };

  static const sectionPrefix = 'tramites:';

  /// Los trámites agrupados por institución, en el orden del corpus.
  ///
  /// Solo ordenan la lista que ve la persona: los contextos, sus preguntas y
  /// el RAG no cambian, ni el grafo de conversación (que enruta por
  /// [ContextFamily.contextIds]).
  static final List<ContextFamily> sections = () {
    final porArea = <String, List<RagTramite>>{};
    for (final t in all) {
      porArea.putIfAbsent(t.area, () => []).add(t);
    }
    return [
      for (final MapEntry(key: area, value: tramites) in porArea.entries)
        ContextFamily(
          id: '$sectionPrefix$area',
          name: _sectionInfo[area]?.$1 ?? tramites.first.institution,
          emoji: _sectionInfo[area]?.$2 ?? tramites.first.emoji,
          description: _sectionInfo[area]?.$3 ?? tramites.first.institution,
          contextIds: [for (final t in tramites) t.contextId],
        ),
    ];
  }();

  /// La sección con id [id], o `null`.
  static ContextFamily? sectionById(String? id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Pregunta del banco del turno [turn] del funcionario en [scenarioId].
  static String questionId(String scenarioId, int turn) =>
      'R.$scenarioId.$turn';

  /// Las preguntas del banco del turno [turn]: la suya y, si el funcionario
  /// preguntó varias cosas a la vez («¿Cuándo y dónde ocurrió?»), una por
  /// cada una (`R.<escenario>.<turno>.donde`), en el orden de la frase.
  static List<String> questionIdsOfTurn(String scenarioId, int turn) {
    final base = questionId(scenarioId, turn);
    return [
      for (final raw in _data['preguntas'] as List<dynamic>)
        if (raw['id'] == base || (raw['id'] as String).startsWith('$base.'))
          raw['id'] as String,
    ];
  }

  /// El trámite de un escenario del corpus, o `null` si no tiene preguntas
  /// que se respondan con tarjetas.
  static RagTramite? ofScenario(String scenarioId) => _byScenario[scenarioId];

  static QuestionBank? _bank;

  /// El banco del módulo de tarjetas con los trámites incluidos.
  ///
  /// El banco generado no cambia (la Lambda carga el mismo): los trámites se
  /// suman a sus preguntas y recorridos. Una declaración de un trámite se
  /// redacta en el teléfono con la frase documentada; si el servidor no la
  /// certifica, gana esa redacción local, como con cualquier recorrido.
  static QuestionBank bankWithTramites() {
    final cached = _bank;
    if (cached != null) return cached;
    final base = QuestionBank.generated().data;
    return _bank = QuestionBank({
      ...base,
      'preguntas': [
        ...base['preguntas'] as List<dynamic>,
        ..._data['preguntas'] as List<dynamic>,
      ],
      'recorridos': {
        ...base['recorridos'] as Map<String, dynamic>,
        ..._data['recorridos'] as Map<String, dynamic>,
      },
    });
  }
}
