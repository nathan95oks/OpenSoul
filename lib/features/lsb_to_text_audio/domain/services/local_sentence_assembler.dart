/// Motor semántico propio — construye una oración base en español formal
/// a partir de una secuencia de glosas LSB y el contexto situacional.
///
/// Es la mitad "propia" de la **arquitectura híbrida** declarada en el
/// perfil de proyecto: *"motor semántico propio con lexicón LSB + un
/// modelo fundacional (Transformer vía API) para coherencia gramatical"*.
///
/// El backend AWS (Bedrock) refina la salida cuando está disponible. Si
/// el backend falla o devuelve un resultado degenerado (más corto que las
/// glosas, o que omite la mayoría), este motor garantiza que el usuario
/// sordo siempre obtenga una declaración fiel a lo que seleccionó.
///
/// La construcción usa plantillas por contexto judicial (denuncia,
/// violencia, accidente, emergencia, trámite, orientación, pérdida) que
/// reflejan el dialecto LSB de Cochabamba documentado en el perfil.
class LocalSentenceAssembler {
  const LocalSentenceAssembler();

  /// Construye la oración base. Nunca retorna cadena vacía si hay glosas.
  String assemble({
    required String contextId,
    required List<String> glosses,
  }) {
    if (glosses.isEmpty) return '';

    final cleaned = glosses
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList(growable: false);

    if (cleaned.isEmpty) return '';

    final intro = _contextLead(contextId);
    final body = _glossesToProse(cleaned);

    return '$intro $body.';
  }

  /// Heurística de degeneración del resultado del backend.
  ///
  /// El backend se considera "degenerado" cuando:
  /// - su salida está vacía;
  /// - su salida tiene menos palabras que la cantidad de glosas
  ///   seleccionadas (perdió contenido);
  /// - menos del 60% de las glosas aparecen como tokens (caso típico:
  ///   "necesito hoy" cuando el usuario seleccionó 5 glosas).
  ///
  /// Cuando el backend está degenerado, el motor local toma el relevo
  /// para garantizar que la declaración del usuario sordo no se pierda.
  bool isBackendDegenerate({
    required String backendText,
    required List<String> glosses,
  }) {
    final trimmed = backendText.trim();
    if (trimmed.isEmpty) return true;
    if (glosses.isEmpty) return false;

    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length < glosses.length) return true;

    final lowerBackend = trimmed.toLowerCase();
    final hits = glosses
        .map((g) => g.toLowerCase().trim())
        .where((g) => g.isNotEmpty && lowerBackend.contains(g))
        .length;
    final coverage = hits / glosses.length;
    return coverage < 0.6;
  }

  String _contextLead(String contextId) {
    switch (contextId) {
      case 'denuncia_robo':
        return 'Quiero denunciar un robo:';
      case 'violencia':
        return 'Quiero reportar un caso de violencia:';
      case 'accidente':
        return 'Quiero reportar un accidente:';
      case 'emergencia':
        return 'Estoy en una emergencia y necesito ayuda:';
      case 'tramite_id':
        return 'Quiero realizar un trámite:';
      case 'orientacion':
        return 'Necesito orientación:';
      case 'perdida':
        return 'Quiero reportar la pérdida de un objeto:';
      case 'otro':
      default:
        return 'Quiero comunicar lo siguiente:';
    }
  }

  /// Convierte la lista de glosas en una frase legible en minúsculas con
  /// separación natural por comas. Mantiene el orden de selección porque
  /// refleja la narrativa que construyó el usuario sordo.
  String _glossesToProse(List<String> glosses) {
    final lower = glosses.map((g) => g.toLowerCase()).toList(growable: false);
    if (lower.length == 1) return lower.first;
    if (lower.length == 2) return '${lower[0]} y ${lower[1]}';
    final allButLast = lower.sublist(0, lower.length - 1).join(', ');
    return '$allButLast y ${lower.last}';
  }
}
