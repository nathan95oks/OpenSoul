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
    'description',
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

  /// Raíces que piden describir a alguien en cualquier parte del turno, aun
  /// sin signos de pregunta («describa al agresor»). DESCRIBIR no tiene seña:
  /// la traducción lo deletrea y solo el texto conserva lo que se pide.
  static const Map<String, String> spokenStemSlots = {
    'DESCRIB': 'description',
    'DESCRIPCION': 'description',
    'CARACTERISTICA': 'description',
    'APARIENCIA': 'description',
    'RASGO': 'description',
    'FISICAMENTE': 'description',
  };

  /// «¿Cómo era?», «¿cómo lucían?»: CÓMO + ser/lucir en pasado.
  static const Map<String, String> spokenAfterHowSlots = {
    'ERA': 'description',
    'ERAN': 'description',
    'LUCIA': 'description',
    'LUCIAN': 'description',
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

  static List<String> _stemSlotsOf(String text) {
    final out = <String>[];
    for (final w in _words(text)) {
      final key = _plain(w);
      for (final e in spokenStemSlots.entries) {
        if (key.startsWith(e.key) && !out.contains(e.value)) out.add(e.value);
      }
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
    return out;
  }

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
