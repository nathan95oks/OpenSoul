import 'package:lsb_legal_app/core/domain/conversation/lsb_gloss_semantics_data.g.dart';
import 'package:lsb_legal_app/core/domain/services/dialogue_graph.dart';

/// Qué dato pide una glosa canónica, para leer preguntas en LSB.
///
/// Es la misma tabla que usa Audio/Texto→LSB (`aws/lambda_text_to_lsb.py`,
/// `build_semantic_turn`) para su lectura semántica. Aquí sirve para leer las
/// formulaciones LSB del banco con el mismo criterio, y como respaldo cuando
/// un backend antiguo no envía la lectura.
///
/// Solo contiene clases cerradas: interrogativos, núcleos de tiempo y lugar y
/// glosas de función. Nada de frases del español. Las tablas que comparte con
/// la Lambda salen de `docs/negocio/config/semantica_lsb.json`
/// (`tool/build_semantica_lsb.py`): una señal nueva se añade allí, no aquí.
class LsbGlossSemantics {
  const LsbGlossSemantics._();

  /// Ranuras del grafo de diálogo: el vocabulario común de lo que se pide.
  static final Set<String> slotVocabulary = kSlotVocabulary.toSet();

  static const Map<String, String> interrogativeSlots = kInterrogativeSlots;

  static const Set<String> openInterrogatives = kOpenInterrogatives;

  /// «¿A qué hora?», «¿qué día?»: el núcleo dice el dato.
  static const Map<String, String> headSlots = kHeadSlots;

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

  static const Set<String> negators = kNegators;

  // ---- El texto del oyente ---------------------------------------------------
  //
  // El interrogativo escrito dice qué dato se pide aunque la traducción no
  // conserve su glosa. Mismas clases cerradas que `build_semantic_turn`
  // (fuente única en `docs/negocio/config/semantica_lsb.json`).

  static const Map<String, String> spokenInterrogativeSlots =
      kSpokenInterrogativeSlots;

  static const Set<String> spokenOpenInterrogatives = kSpokenOpenInterrogatives;

  /// El núcleo tras un interrogativo abierto: «¿a qué hora?», «¿en qué
  /// lugar?».
  static const Map<String, String> spokenHeadSlots = kSpokenHeadSlots;

  /// Palabras que piden un lugar en cualquier parte de la pregunta.
  static const Map<String, String> spokenWordSlots = kSpokenWordSlots;

  /// Raíces que piden describir a alguien en cualquier parte del turno, aun
  /// sin signos de pregunta («describa al agresor»). DESCRIBIR no tiene seña:
  /// la traducción lo deletrea y solo el texto conserva lo que se pide.
  static const Map<String, String> spokenStemSlots = kSpokenStemSlots;

  /// «¿Qué ropa llevaba?», «¿qué llevaba puesto?»: un verbo de llevar puesto
  /// junto a la prenda (o «puesto») pide la ropa. Sin el verbo, «¿qué ropa le
  /// robaron?» pregunta por el objeto robado.
  static const Set<String> spokenWearVerbs = kSpokenWearVerbs;

  static const Set<String> spokenWearWords = kSpokenWearWords;

  /// «¿Cómo era?», «¿cómo lucían?»: CÓMO + ser/lucir en pasado.
  static const Map<String, String> spokenAfterHowSlots = kSpokenAfterHowSlots;

  static const Set<String> questionPrepositions = kQuestionPrepositions;

  /// Glosa interrogativa que preserva cada dato pedido en el texto.
  static const Map<String, String> questionGlossBySlot = {
    'place': 'DONDE',
    'time': 'CUANDO',
    'person': 'QUIEN',
    'amount': 'CUANTOS',
  };

  /// Respuestas concretas que un modelo no puede usar en lugar de la
  /// pregunta. Solo se sustituyen cuando no están respaldadas por una palabra
  /// del texto: «¿dónde está la plaza?» conserva PLAZA y añade DONDE, mientras
  /// que «dónde te robaron» nunca puede convertirse en PLAZA.
  static const Map<String, Set<String>> concreteAnswersBySlot = {
    'place': {
      'AVENIDA',
      'BANCO',
      'BARRIO',
      'CALLE',
      'CASA',
      'HOSPITAL',
      'MERCADO',
      'MICRO',
      'OFICINA',
      'PLAZA',
      'PROVINCIA',
      'TIENDA',
      'TRUFI',
    },
    'time': {'AHORA', 'AYER', 'HOY', 'MANANA', 'NOCHE', 'SEMANA', 'TARDE'},
    'person': {
      'ABOGADO',
      'HOMBRE',
      'JUEZ',
      'LADRON',
      'MUJER',
      'POLICIA',
      'TESTIGO',
    },
    'amount': {
      'CERO',
      'UNO',
      'DOS',
      'TRES',
      'CUATRO',
      'CINCO',
      'SEIS',
      'SIETE',
      'OCHO',
      'NUEVE',
      'DIEZ',
    },
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
    if (clauses.isEmpty) {
      _stemSlotsOf(text).forEach(add);
      return slots;
    }
    final readings = [for (final clause in clauses) _readClause(clause)];
    // «lugar» pide un lugar en una pregunta QU- («¿cuál fue el lugar?»); en
    // una de sí/no solo precisa otra cosa («¿hay video del lugar?»).
    if (readings.any((r) => r.$2)) {
      for (final w in _words(text)) {
        final slot = spokenWordSlots[_plain(w)];
        if (slot != null) add(slot);
      }
    }
    var polar = false;
    for (var i = 0; i < clauses.length; i++) {
      final (clauseSlots, interrogative) = readings[i];
      clauseSlots.forEach(add);
      if (!interrogative && DialogueGraph.tokensOf(clauses[i]).isNotEmpty) {
        polar = true;
      }
    }
    if (slots.isNotEmpty && polar) add('polarity');
    _stemSlotsOf(text).forEach(add);
    return slots;
  }

  /// El turno pide la ropa: un verbo de llevar puesto con la prenda, o
  /// «vestido», «vestía».
  static bool asksClothing(String text) {
    final keys = {for (final w in _words(text)) _plain(w)};
    return keys.any((k) => k.startsWith('VESTI')) ||
        (keys.any(spokenWearVerbs.contains) &&
            keys.any(spokenWearWords.contains));
  }

  /// La frase nombra la ropa («¿Qué ropa llevaba?»). El verbo solo no
  /// basta: «¿Qué edad aproximada tenía?» no habla de ropa.
  static bool speaksOfClothing(String phrase) {
    final keys = {for (final w in _words(phrase)) _plain(w)};
    return keys.any(
      (k) => spokenWearWords.contains(k) || k.startsWith('VESTI'),
    );
  }

  static List<String> _stemSlotsOf(String text) {
    final out = <String>[];
    final keys = {for (final w in _words(text)) _plain(w)};
    for (final key in keys) {
      for (final e in spokenStemSlots.entries) {
        if (key.startsWith(e.key) && !out.contains(e.value)) out.add(e.value);
      }
    }
    if (keys.any(spokenWearVerbs.contains) &&
        keys.any(spokenWearWords.contains) &&
        !out.contains(kSpokenWearSlot)) {
      out.add(kSpokenWearSlot);
    }
    return out;
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
    // Errores muy frecuentes de escritura móvil. Solo normalizamos
    // interrogativos inequívocos; no se corrigen palabras de contenido ni
    // se intenta adivinar una oración completa.
    return const {
          'DND': 'DONDE',
          'DNDE': 'DONDE',
          'DONDE': 'DONDE',
          'CNDO': 'CUANDO',
          'CUANDO': 'CUANDO',
          'Q': 'QUE',
          'K': 'QUE',
        }[out] ??
        out;
  }

  /// Una palabra del español como la leen las reglas: mayúsculas, sin
  /// tildes y con los interrogativos abreviados al escribir en el celular
  /// («dnde», «q») completos.
  static String spokenWord(String word) => _plain(word);

  static List<String> _questionClauses(String text) {
    var spans = text.contains('¿')
        ? [for (final m in RegExp(r'¿([^¿?]*)').allMatches(text)) m.group(1)!]
        : [
            for (final m in RegExp(r'([^.!?]*)\?').allMatches(text))
              m.group(1)!,
          ];
    // En voz y en escritura móvil los signos suelen omitirse. Solo se toma el
    // turno completo cuando realmente abre con un interrogativo (o lo lleva
    // acentuado); así «donde te robaron» es pregunta, pero «cuando llegué me
    // robaron» sigue siendo una afirmación temporal.
    if (spans.isEmpty && _startsImplicitQuestion(text)) {
      spans = [text];
    }
    return [
      for (final span in spans)
        for (final clause in span.split(
          RegExp(r'\s+(?:y|e|o|u)\s+', caseSensitive: false),
        ))
          if (clause.trim().isNotEmpty) clause.trim(),
    ];
  }

  static bool _startsImplicitQuestion(String text) {
    final words = _words(text);
    final keys = [for (final word in words) _plain(word)];
    var start = 0;
    while (start < keys.length && questionPrepositions.contains(keys[start])) {
      start++;
    }
    if (start >= keys.length) return false;
    final key = keys[start];
    final accented = words[start].toUpperCase() != key;
    if (key == 'CUANDO' && !accented) {
      // «cuando llegué…» es una subordinada; «cuando te robaron…» conserva
      // la forma inequívoca de una pregunta dictada sin signos.
      final next = start + 1 < keys.length ? keys[start + 1] : '';
      return const {
        'TE',
        'TU',
        'USTED',
        'USTEDES',
        'LE',
        'LES',
        'FUE',
        'OCURRIO',
        'PASO',
        'SUCEDIO',
      }.contains(next);
    }
    return spokenInterrogativeSlots.containsKey(key) ||
        spokenOpenInterrogatives.contains(key);
  }

  /// Corrige únicamente una contradicción demostrable entre el español y las
  /// glosas: el texto pide un dato, pero el modelo devolvió una respuesta
  /// concreta o perdió el interrogativo. No reordena ni reinterpreta el resto
  /// de la traducción.
  static List<String> reconcileQuestionGlosses(
    String text,
    Iterable<String> glosses,
  ) {
    final result = [for (final g in glosses) g.toUpperCase().trim()];
    final requested = spokenSlotsOf(text);
    if (requested.isEmpty) return result;

    final sourceWords = [for (final word in _words(text)) _plain(word)];
    bool grounded(String gloss) {
      final key = normalize(gloss);
      if (key == null) return false;
      for (final word in sourceWords) {
        if (key == word ||
            (word.length >= 4 && (key.contains(word) || word.contains(key)))) {
          return true;
        }
        var common = 0;
        for (var i = 0; i < key.length && i < word.length; i++) {
          if (key[i] != word[i]) break;
          common++;
        }
        if (common >= 4) return true;
      }
      return false;
    }

    var insertionIndex = 0;
    for (final slot in requested) {
      final questionGloss = questionGlossBySlot[slot];
      if (questionGloss == null) continue;
      final represented = slotsOf(normalizeAll(result)).contains(slot);
      if (represented) continue;

      final concrete = concreteAnswersBySlot[slot] ?? const <String>{};
      final replaceAt = result.indexWhere((g) {
        final key = normalize(g);
        return key != null && concrete.contains(key) && !grounded(g);
      });
      if (replaceAt >= 0) {
        result[replaceAt] = questionGloss;
      } else {
        result.insert(insertionIndex, questionGloss);
        insertionIndex++;
      }
    }
    return result;
  }

  /// Si todas las preguntas del texto son abiertas («¿Qué vio
  /// exactamente?»): no se contestan con sí o no. Con una de sí/no entre
  /// ellas («Hola, ¿cómo está? ¿Tiene testigos?») no lo es.
  static bool asksOpen(String text) {
    final clauses = _questionClauses(text);
    return clauses.isNotEmpty && clauses.every(_clauseAsksOpen);
  }

  /// «¿Tiene fotos o videos?»: una sola pregunta que ofrece alternativas.
  static bool isDisjunction(String text) =>
      RegExp(r'(^|[^\p{L}])[oOuU]($|[^\p{L}])', unicode: true).hasMatch(text);

  /// Si todas las preguntas del texto son de sí o no («¿Tiene la denuncia
  /// de pérdida?»): no piden elegir entre opciones abiertas. Una
  /// disyuntiva («¿Era un hombre o una mujer?») no lo es.
  static bool asksPolar(String text) {
    if (isDisjunction(text)) return false;
    final clauses = _questionClauses(text);
    return clauses.isNotEmpty && clauses.every((c) => !_clauseAsksOpen(c));
  }

  /// «¿Viene/Quiere a ver cómo va su caso?» pregunta primero si ese es el
  /// motivo de la visita; el «cómo» pertenece a una subordinada.
  static bool _clauseAsksOpen(String clause) {
    final words = _words(clause);
    final keys = [for (final word in words) _plain(word)];
    var start = 0;
    while (start < keys.length && questionPrepositions.contains(keys[start])) {
      start++;
    }
    if (start < keys.length &&
        (keys[start].startsWith('VEN') ||
            keys[start].startsWith('VIEN') ||
            keys[start].startsWith('QUIER'))) {
      for (var i = start + 1; i < words.length; i++) {
        if (spokenInterrogativeSlots.containsKey(keys[i]) ||
            spokenOpenInterrogatives.contains(keys[i])) {
          return false;
        }
      }
    }
    return _readClause(clause).$2;
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
        final next = i + 1 < keys.length ? keys[i + 1] : '';
        final head =
            spokenHeadSlots[next] ??
            (keys[i] == 'COMO' ? spokenAfterHowSlots[next] : null);
        if (head != null) slots.add(head);
      }
    }
    // «qué» es abierto y normalmente no identifica una ranura por sí solo.
    // En una pregunta de robo, sin embargo, el verbo la acota al objeto
    // sustraído («¿Qué te robaron/se llevaron?»).
    final asksStolenObject = [
      for (var i = 0; i < keys.length; i++)
        if (keys[i] == 'QUE' &&
            (i + 1 >= keys.length || !spokenHeadSlots.containsKey(keys[i + 1])))
          i,
    ].isNotEmpty;
    if (interrogative &&
        asksStolenObject &&
        keys.any(
          (key) =>
              key.startsWith('ROB') ||
              key.startsWith('QUIT') ||
              key.startsWith('LLEV'),
        )) {
      slots.add('object');
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
  /// «HORA CUÁNTOS» es cómo LSB pregunta la hora: CUÁNTOS tras un núcleo
  /// pertenece a él y no pide además una cantidad.
  static Set<String> slotsOf(Iterable<String> normalized) {
    final glosses = normalized.toList();
    return {
      for (var i = 0; i < glosses.length; i++)
        if (!(glosses[i] == 'CUANTOS' &&
            i > 0 &&
            headSlots.containsKey(glosses[i - 1])))
          ?interrogativeSlots[glosses[i]] ?? headSlots[glosses[i]],
    };
  }

  /// Ranuras de UNA pregunta: si trae un núcleo, manda el núcleo
  /// («HORA CUÁNTOS» pide la hora, no una cantidad).
  static Set<String> questionSlotsOf(Iterable<String> normalized) {
    final heads = {for (final g in normalized) ?headSlots[g]};
    if (heads.isNotEmpty) return heads;
    return {for (final g in normalized) ?interrogativeSlots[g]};
  }

  /// Las ranuras de [slots] que el español respalda.
  ///
  /// Persona, lugar, tiempo y cantidad salen de un interrogativo; si solo
  /// los dice una glosa de la traducción (QUIÉN por «¿Quiere…?», o por
  /// «¿Alguien vio…?»), el oyente no los pidió: «¿Tiene testigos?» es de sí o
  /// no, no pregunta quién. Se conservan si el texto los pregunta o si los
  /// respalda un núcleo («a qué HORA»). Sin texto, todas.
  static Set<String> groundSlots(
    Set<String> slots,
    Iterable<String> normalized,
    String text,
  ) {
    if (text.trim().isEmpty) return slots;
    // Lo que pregunta el español: sus interrogativos, aun sin signos de
    // pregunta («hola como estas quien te robo»), y sus núcleos («en qué
    // LUGAR», «a qué HORA»).
    final spoken = {
      ...spokenSlotsOf(text),
      for (final w in _words(text)) ?spokenInterrogativeSlots[_plain(w)],
      for (final w in _words(text)) ?spokenHeadSlots[_plain(w)],
    };
    final heads = {for (final g in normalized) ?headSlots[g]};
    final fromInterrogatives = interrogativeSlots.values.toSet();
    return {
      for (final s in slots)
        if (!fromInterrogatives.contains(s) ||
            spoken.contains(s) ||
            heads.contains(s))
          s,
    };
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
