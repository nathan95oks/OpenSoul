import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

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

  // ---- El texto del oyente ---------------------------------------------------
  //
  // El interrogativo escrito dice qué dato se pide aunque la traducción no
  // conserve su glosa. Mismas clases cerradas que `build_semantic_turn`
  // (contrato en `aws/tests/lsb_gloss_semantics.json`).

  static const Map<String, String> spokenInterrogativeSlots = {
    'CUANDO': 'time',
    'DONDE': 'place',
    'ADONDE': 'place',
    'QUIEN': 'person',
    'QUIENES': 'person',
    'CUANTO': 'amount',
    'CUANTA': 'amount',
    'CUANTOS': 'amount',
    'CUANTAS': 'amount',
  };

  static const Set<String> spokenOpenInterrogatives = {
    'QUE',
    'CUAL',
    'CUALES',
    'COMO',
  };

  /// El núcleo tras un interrogativo abierto: «¿a qué hora?», «¿en qué
  /// lugar?».
  static const Map<String, String> spokenHeadSlots = {
    'HORA': 'time',
    'DIA': 'time',
    'FECHA': 'time',
    'MOMENTO': 'time',
    'LUGAR': 'place',
    'SITIO': 'place',
    'DIRECCION': 'place',
  };

  /// Palabras que piden un lugar en cualquier parte de la pregunta.
  static const Map<String, String> spokenWordSlots = {
    'LUGAR': 'place',
    'SITIO': 'place',
  };

  static const Set<String> questionPrepositions = {
    'A',
    'EN',
    'DE',
    'DESDE',
    'HASTA',
    'CON',
    'POR',
    'PARA',
    'HACIA',
  };

  /// Ranuras que pide el texto de un turno, en orden.
  ///
  /// Con tilde, un interrogativo cuenta en cualquier parte de la pregunta;
  /// sin tilde también es conjunción («cuando llegué…») y solo cuenta al
  /// abrir la cláusula. Una cláusula de sí/no junto a otra que pide un dato
  /// («¿Te robaron el celular y cuándo fue?») añade `polarity`; en «¿Cuándo
  /// te robaron el celular?» el robo es lo que el oyente da por hecho.
  static List<String> spokenSlotsOf(String text) {
    final slots = <String>[];
    void add(String slot) {
      if (!slots.contains(slot)) slots.add(slot);
    }

    final clauses = _questionClauses(text);
    if (clauses.isEmpty) return slots;
    for (final w in _words(text)) {
      final slot = spokenWordSlots[_plain(w)];
      if (slot != null) add(slot);
    }
    var polar = false;
    for (final clause in clauses) {
      final (clauseSlots, interrogative) = _readClause(clause);
      clauseSlots.forEach(add);
      if (!interrogative && DialogueGraph.tokensOf(clause).isNotEmpty) {
        polar = true;
      }
    }
    if (slots.isNotEmpty && polar) add('polarity');
    return slots;
  }

  static final RegExp _word = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}');

  static List<String> _words(String text) => [
    for (final m in _word.allMatches(text)) m.group(0)!,
  ];

  static String _plain(String word) {
    const from = 'ÁÉÍÓÚÜ';
    const to = 'AEIOUU';
    var out = word.toUpperCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  static List<String> _questionClauses(String text) {
    final spans = text.contains('¿')
        ? [for (final m in RegExp(r'¿([^¿?]*)').allMatches(text)) m.group(1)!]
        : [
            for (final m in RegExp(r'([^.!?]*)\?').allMatches(text))
              m.group(1)!,
          ];
    return [
      for (final span in spans)
        for (final clause in span.split(
          RegExp(r'\s+(?:y|e|o|u)\s+', caseSensitive: false),
        ))
          if (clause.trim().isNotEmpty) clause.trim(),
    ];
  }

  static (List<String>, bool) _readClause(String clause) {
    final words = _words(clause);
    final keys = [for (final w in words) _plain(w)];
    var start = 0;
    while (start < keys.length && questionPrepositions.contains(keys[start])) {
      start++;
    }
    final slots = <String>[];
    var interrogative = false;
    for (var i = 0; i < words.length; i++) {
      final accented = words[i].toUpperCase() != keys[i];
      if (!accented && i != start) continue;
      final slot = spokenInterrogativeSlots[keys[i]];
      if (slot != null) {
        interrogative = true;
        slots.add(slot);
      } else if (spokenOpenInterrogatives.contains(keys[i])) {
        interrogative = true;
        final head = i + 1 < keys.length ? spokenHeadSlots[keys[i + 1]] : null;
        if (head != null) slots.add(head);
      }
    }
    return (slots, interrogative);
  }

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
