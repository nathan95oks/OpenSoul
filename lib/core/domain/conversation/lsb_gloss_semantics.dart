/// Qué dato pide una glosa canónica, para leer preguntas en LSB.
///
/// Es la misma tabla que usa Audio/Texto→LSB (`aws/lambda_text_to_lsb.py`,
/// `build_semantic_turn`) para su lectura semántica. Aquí sirve para leer las
/// formulaciones LSB del banco con el mismo criterio, y como respaldo cuando
/// un backend antiguo no envía la lectura.
///
/// Solo contiene clases cerradas: interrogativos, núcleos de tiempo y lugar y
/// glosas de función. Nada de frases del español.
class LsbGlossSemantics {
  const LsbGlossSemantics._();

  /// Ranuras del grafo de diálogo: el vocabulario común de lo que se pide.
  static const Set<String> slotVocabulary = {
    'time',
    'place',
    'person',
    'object',
    'amount',
    'evidence',
    'polarity',
    'free_text',
  };

  static const Map<String, String> interrogativeSlots = {
    'DONDE': 'place',
    'CUANDO': 'time',
    'QUIEN': 'person',
    'CUANTOS': 'amount',
  };

  static const Set<String> openInterrogatives = {
    'QUE',
    'CUAL',
    'COMO',
    'POR_QUE',
    'PARA_QUE',
  };

  /// «¿A qué hora?», «¿qué día?»: el núcleo dice el dato.
  static const Map<String, String> headSlots = {
    'HORA': 'time',
    'FECHA': 'time',
    'DIA': 'time',
    'MOMENTO': 'time',
    'DIRECCION': 'place',
  };

  /// Pronombres y atenuadores: no dicen de qué trata la pregunta.
  static const Set<String> functionGlosses = {
    'TU',
    'YO',
    'EL',
    'ELLA',
    'ELLOS',
    'NOSOTROS',
    'USTED',
    'USTEDES',
    'TUYO',
    'SUYO',
    'MIO',
    'MAS_O_MENOS',
  };

  static const Set<String> negators = {
    'NO',
    'JAMAS',
    'NUNCA',
    'NADA',
    'NADIE',
    'NINGUNO',
  };

  /// Forma comparable: mayúsculas, sin tildes (conserva la Ñ), sin signos
  /// de interrogación. `null` para lo que no es una glosa (dactilología
  /// `d(…)`, número `NÚM(…)` o una letra suelta).
  static String? normalize(String raw) {
    const from = 'ÁÉÍÓÚÜ';
    const to = 'AEIOUU';
    var out = raw.toUpperCase().trim();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    out = out.replaceAll(RegExp(r'[¿?¡!]'), '').trim();
    if (out.isEmpty || out.contains('(') || out.length == 1) return null;
    return out;
  }

  static List<String> normalizeAll(Iterable<String> glosses) => [
    for (final g in glosses) ?normalize(g),
  ];

  /// Ranuras que pide una secuencia de glosas.
  static Set<String> slotsOf(Iterable<String> normalized) => {
    for (final g in normalized) ?interrogativeSlots[g] ?? headSlots[g],
  };

  /// Ranuras de UNA pregunta: si trae un núcleo, manda el núcleo
  /// («HORA CUÁNTOS» pide la hora, no una cantidad).
  static Set<String> questionSlotsOf(Iterable<String> normalized) {
    final heads = {for (final g in normalized) ?headSlots[g]};
    if (heads.isNotEmpty) return heads;
    return {for (final g in normalized) ?interrogativeSlots[g]};
  }

  static Set<String> headsOf(Iterable<String> normalized) => {
    for (final g in normalized)
      if (headSlots.containsKey(g)) g,
  };

  /// Glosas de contenido: lo que queda al quitar interrogativos, núcleos de
  /// ranura y glosas de función.
  static Set<String> contentOf(Iterable<String> normalized) => {
    for (final g in normalized)
      if (!interrogativeSlots.containsKey(g) &&
          !openInterrogatives.contains(g) &&
          !headSlots.containsKey(g) &&
          !functionGlosses.contains(g))
        g,
  };

  static bool hasInterrogative(Iterable<String> normalized) => normalized.any(
    (g) => interrogativeSlots.containsKey(g) || openInterrogatives.contains(g),
  );
}
