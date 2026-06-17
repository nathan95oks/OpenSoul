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
/// A diferencia de la versión inicial —que solo unía las glosas con comas
/// ("hombre, cuchillo, robar y celular")— este ensamblador clasifica cada
/// glosa por su **rol gramatical** (sujeto, verbo, objeto, lugar, tiempo,
/// rasgo, emoción, servicio, documento, institución) y compone una oración
/// con sintaxis española correcta, reflejando el dialecto LSB de Cochabamba
/// documentado en el perfil. Espeja —de forma compacta y offline— la lógica
/// del `GLOSS_LEXICON` del backend Lambda.
class LocalSentenceAssembler {
  const LocalSentenceAssembler();

  /// Construye la oración base. Nunca retorna cadena vacía si hay glosas.
  String assemble({
    required String contextId,
    required List<String> glosses,
  }) {
    final tokens = glosses
        .map(_normalize)
        .where((g) => g.isNotEmpty)
        .toList(growable: false);

    if (tokens.isEmpty) return '';

    final roles = _classify(tokens);

    final composed = switch (contextId) {
      'denuncia_robo' || 'violencia' => _composeIncident(contextId, roles, tokens),
      'accidente' || 'emergencia' => _composeEmergency(contextId, roles, tokens),
      'tramite_id' => _composeProcedure(roles, tokens),
      'orientacion' => _composeGuidance(roles, tokens),
      'perdida' => _composeLoss(roles, tokens),
      'otro' => _composeWitness(roles, tokens),
      _ => _composeGeneric(contextId, roles, tokens),
    };

    // Regla de cobertura semántica: ninguna glosa seleccionada puede perderse.
    return _ensureCoverage(composed, tokens);
  }

  /// Glosas inherentemente representadas por la 1ª persona ("me", "mi"…),
  /// que no exigen aparición literal en el texto.
  static const _inherentImplicit = {'YO'};

  /// Red de seguridad de la regla de cobertura: si tras componer alguna glosa
  /// no quedó representada (porque su rol no encajó en la plantilla del
  /// contexto), la añadimos explícitamente para no perder valor probatorio.
  ///
  /// La detección es precisa: como los compositores emiten el lexema `es`
  /// literal, una glosa está representada cuando todas las palabras
  /// significativas de su lexema aparecen en el texto.
  String _ensureCoverage(String text, List<String> tokens) {
    final hay = _stripDiacritics(text.toLowerCase());
    final missing = <String>[];
    for (final t in tokens) {
      if (_inherentImplicit.contains(t)) continue;
      if (_isRepresented(t, hay)) continue;
      final lex = _lexicon[t];
      final frag = lex != null ? lex.es : t.toLowerCase().replaceAll('_', ' ');
      if (!missing.contains(frag)) missing.add(frag);
    }
    if (missing.isEmpty) return text;
    // Red de seguridad de último recurso. Con los bloques semánticos
    // (`_supplements`) integrando todos los roles, esta rama prácticamente no
    // se ejecuta; si lo hiciera, usa un conector formal natural (nunca
    // "Asimismo, menciono").
    return '$text Para completar mi declaración, hago constar ${_join(missing)}.';
  }

  /// `true` si el lexema de la glosa ya está emitido (todas sus palabras
  /// significativas presentes). Para glosas desconocidas usa la raíz.
  bool _isRepresented(String token, String hayLower) {
    final lex = _lexicon[token];
    if (lex == null) return _glossCovered(token, hayLower);
    // Considera variantes morfológicas para no disparar la red de seguridad
    // por error cuando el compositor conjugó/concordó la palabra:
    //  - plural del verbo: "golpeó" → "golpearon" (agresor plural);
    //  - femenino del adjetivo: "alto" → "alta" (sujeto femenino).
    final variants = <String>{lex.es, _verbPlural(lex.es), _femAdj(lex.es)};
    for (final variant in variants) {
      final words = _stripDiacritics(variant.toLowerCase())
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3)
          .toList();
      if (words.isEmpty) return true; // lexema sin palabras significativas
      if (words.every(hayLower.contains)) return true;
    }
    return false;
  }

  // ───────────────────────── Detección de degeneración ─────────────────────

  /// Heurística de degeneración del resultado del backend.
  ///
  /// El backend se considera "degenerado" cuando:
  /// - su salida está vacía;
  /// - su salida tiene menos palabras que la cantidad de glosas
  ///   seleccionadas (perdió contenido);
  /// - cubre menos del 50% de las glosas (caso típico: el backend no
  ///   reconoció la mayoría de los términos y devolvió algo genérico).
  ///
  /// La cobertura se calcula con **coincidencia por raíz** y es tolerante a
  /// guiones bajos (PARTIDA_NACIMIENTO), acentos (NIÑO) y conjugación
  /// (PERDER → "perdí"). La versión anterior comparaba la glosa cruda como
  /// subcadena, por lo que toda glosa con guion bajo contaba siempre como
  /// "no cubierta" y descartaba refinamientos válidos (falso positivo).
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

    // Detecta si el backend simplemente devolvió las glosas como lista
    // de palabras sin estructura gramatical española (sin artículos,
    // preposiciones ni verbos conjugados). Una oración real contiene
    // al menos una palabra de enlace.
    const _kLinking = {
      'de', 'en', 'con', 'el', 'la', 'los', 'las', 'un', 'una', 'unos',
      'unas', 'me', 'te', 'se', 'le', 'mi', 'tu', 'su', 'que', 'y', 'a',
      'por', 'para', 'del', 'al', 'fue', 'era', 'es', 'son', 'quiero',
      'necesito', 'robó', 'golpeó', 'agredió', 'asaltó', 'amenazó',
    };
    final textWords = trimmed
        .toLowerCase()
        .split(RegExp(r'[\s.,;:!?]+'))
        .where((w) => w.isNotEmpty)
        .toSet();
    final hasLinking = textWords.any(_kLinking.contains);
    if (!hasLinking && glosses.length > 1) return true;

    final haystack = _stripDiacritics(trimmed.toLowerCase());
    var hits = 0;
    for (final g in glosses) {
      if (_glossCovered(g, haystack)) hits++;
    }
    // Regla estricta de cobertura: el backend solo se acepta si representa
    // TODAS las glosas seleccionadas. Si pierde aunque sea una, se considera
    // degenerado y se usa el motor local (que garantiza cobertura completa).
    // Esto evita además que el backend introduzca o sustituya información.
    return hits < glosses.length;
  }

  /// `true` si alguna raíz significativa de la glosa aparece en el texto.
  ///
  /// Considera dos vías: (1) la raíz de la propia glosa y (2) las palabras
  /// del lexema en español (para reconocer conjugaciones: ROBAR→"robó").
  bool _glossCovered(String gloss, String haystackLower) {
    final parts = _stripDiacritics(gloss.toLowerCase())
        .split(RegExp(r'[ _/]+'))
        .where((p) => p.length >= 3); // ignora partículas cortas (de, la…)
    for (final p in parts) {
      // Raíz de 3 letras: tolera conjugación (robar/robó comparten "rob").
      final stem = p.length <= 3 ? p : p.substring(0, 3);
      if (haystackLower.contains(stem)) return true;
    }
    // Vía lexema: alguna palabra significativa del equivalente en español.
    final lex = _lexicon[_normalize(gloss)];
    if (lex != null) {
      final words = _stripDiacritics(lex.es.toLowerCase())
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 4);
      for (final w in words) {
        if (haystackLower.contains(w)) return true;
      }
    }
    return false;
  }

  // ───────────────────────── Clasificación de roles ───────────────────────

  _Roles _classify(List<String> tokens) {
    final r = _Roles();
    for (final t in tokens) {
      final e = _lexicon[t];
      if (e == null) {
        // Glosa desconocida: la conservamos como objeto/detalle genérico
        // para no perder información del relato del usuario sordo.
        r.unknown.add(t.toLowerCase().replaceAll('_', ' '));
        continue;
      }
      switch (e.role) {
        case _Role.sujeto:             r.subject ??= e.es; break;
        case _Role.personaDesc:        if (!r.perpetrators.contains(e.es)) r.perpetrators.add(e.es); break;
        // Bug fix #2: personaDescPlural almacena el sujeto plural por separado
        // para que el compositor sepa usar verbo plural (agredieron).
        case _Role.personaDescPlural:  r.perpetratorPlural ??= e.es; break;
        case _Role.rasgo:              r.traits.add(e.es); break;
        case _Role.verboAgresion:      r.aggression ??= e.es; break;
        case _Role.verboAccion:        r.action ??= e.es; break;
        case _Role.arma:               r.weapon ??= e.es; break;
        case _Role.objeto:             r.objects.add(e.es); break;
        case _Role.documento:          r.documents.add(e.es); break;
        case _Role.lugar:              r.place ??= e.es; break;
        case _Role.institucion:        r.institution ??= e.es; break;
        case _Role.servicio:           r.services.add(e.es); break;
        case _Role.emocion:            r.emotions.add(e.es); break;
        case _Role.urgencia:           r.urgencies.add(e.es); break;
        case _Role.tramite:            r.procedures.add(e.es); break;
        case _Role.motivo:             r.purposes.add(e.es); break;
        case _Role.tiempo:             r.time ??= e.es; break;
      }
    }
    return r;
  }

  /// true si hay un agresor explícito (personaDesc o personaDescPlural o rasgos).
  bool _hasAggressor(_Roles r) =>
      r.perpetrators.isNotEmpty || r.perpetratorPlural != null || r.traits.isNotEmpty;

  /// Convierte un verbo conjugado en 3ª singular a 3ª plural.
  /// Solo mapea los verbos del lexicón — lista cerrada y segura.
  static String _verbPlural(String v) {
    const map = {
      'robó': 'robaron', 'golpeó': 'golpearon', 'amenazó': 'amenazaron',
      'empujó': 'empujaron', 'gritó': 'gritaron', 'quitó': 'quitaron',
      'persiguió': 'persiguieron', 'asaltó': 'asaltaron', 'acosó': 'acosaron',
      'agredió': 'agredieron', 'secuestró': 'secuestraron',
      'agredió sexualmente': 'agredieron sexualmente',
    };
    return map[v] ?? v;
  }

  // ───────────────────────── Compositores por contexto ────────────────────

  /// denuncia_robo / violencia → relato de incidente con agresor.
  String _composeIncident(String ctx, _Roles r, List<String> tokens) {
    final lead = ctx == 'violencia'
        ? 'Quiero reportar un caso de violencia.'
        : 'Quiero denunciar un robo.';

    final sentences = <String>[];

    // CUCHILLO sin verbo de agresión → amenaza implícita con arma.
    if (r.weapon != null && r.aggression == null && !_hasAggressor(r)) {
      var clause = 'Me amenazaron con un cuchillo';
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '${_cap(r.time!)}, ${_decap(clause)}';
        r.time = null;
      }
      sentences.add('$clause.');
      r.weapon = null;
    } else if (r.aggression != null || _hasAggressor(r)) {
      // Cláusula del agresor + acción.
      final subject = _subjectPhrase(r);
      final isPlural = r.perpetratorPlural != null || r.perpetrators.length > 1;
      final defaultVerb = ctx == 'violencia'
          ? (isPlural ? 'agredieron' : 'agredió')
          : (isPlural ? 'asaltaron' : 'asaltó');
      final aggression = r.aggression;
      final verb = aggression == null
          ? defaultVerb
          : (isPlural ? _verbPlural(aggression) : aggression);
      var clause = '$subject me $verb';
      final complement = _join([...r.objects, ...r.documents]);
      if (complement.isNotEmpty) {
        clause += ' $complement';
        r.objects.clear();
        r.documents.clear();
      }
      if (r.weapon != null) {
        clause += ' ${r.weapon}';
        r.weapon = null;
      }
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '${_cap(r.time!)}, ${_decap(clause)}';
        r.time = null;
      }
      sentences.add('${_cap(clause)}.');
      r.aggression = null;
      r.perpetrators.clear();
      r.perpetratorPlural = null;
      r.traits.clear();
    } else if (r.objects.isNotEmpty || r.documents.isNotEmpty) {
      final what = _join([...r.objects, ...r.documents]);
      var clause = 'Me sustrajeron $what';
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause += ' ${r.time}';
        r.time = null;
      }
      sentences.add('$clause.');
      r.objects.clear();
      r.documents.clear();
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  /// accidente / emergencia → estado personal + ayuda requerida.
  String _composeEmergency(String ctx, _Roles r, List<String> tokens) {
    final lead = ctx == 'accidente'
        ? 'Quiero reportar un accidente.'
        : 'Estoy en una emergencia y necesito ayuda.';

    final sentences = <String>[];

    // Bloque de estado físico/emocional integrando lugar y tiempo.
    if (r.emotions.isNotEmpty) {
      var clause = _join(r.emotions);
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '${_cap(r.time!)}, ${_decap(clause)}';
        r.time = null;
      }
      sentences.add('${_cap(clause)}.');
      r.emotions.clear();
    } else if (r.place != null || r.time != null) {
      var clause = 'Ocurrió';
      if (r.time != null) {
        clause += ' ${r.time}';
        r.time = null;
      }
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      sentences.add('$clause.');
    }

    // Ayuda requerida y urgencia, prioritarias en este contexto.
    if (r.services.isNotEmpty) {
      sentences.add('Necesito ${_join(r.services)}.');
      r.services.clear();
    }
    if (r.urgencies.isNotEmpty) {
      sentences.add('${_cap(_join(r.urgencies))}.');
      r.urgencies.clear();
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  /// tramite_id → solicitud administrativa / judicial.
  ///
  /// Cubre el flujo judicial amplio: acción, documento(s), motivo (para qué
  /// se necesita), institución, apoyo de accesibilidad (intérprete/abogado),
  /// para quién y plazo. Cada categoría ocupa su posición lógica.
  String _composeProcedure(_Roles r, List<String> tokens) {
    const lead = 'Quiero realizar un trámite.';
    final sentences = <String>[];

    // Acción + documento(s) + tipo de gestión + institución.
    final verb = r.action ?? 'necesito tramitar';
    final what = _join([...r.documents, ...r.procedures]);
    var clause = verb;
    if (what.isNotEmpty) clause += ' $what';
    if (r.institution != null) {
      clause += ' ${r.institution}';
      r.institution = null;
    }
    sentences.add('${_cap(clause)}.');
    r.action = null;
    r.documents.clear();
    r.procedures.clear();

    // Motivo / propósito judicial del documento.
    if (r.purposes.isNotEmpty) {
      sentences.add('Lo necesito para presentar ${_join(r.purposes)}.');
      r.purposes.clear();
    }
    // Para quién es el trámite.
    if (r.subject != null && r.subject != 'yo') {
      sentences.add('El trámite es para ${r.subject}.');
      r.subject = null;
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  /// orientacion → consulta / pedido de orientación.
  String _composeGuidance(_Roles r, List<String> tokens) {
    const lead = 'Necesito orientación.';
    final sentences = <String>[];

    if (r.services.isNotEmpty) {
      // Si el usuario eligió un verbo (necesito/quiero solicitar...), encabeza
      // la oración para no dejarlo suelto y mantener la fluidez.
      final verb = r.action != null ? _cap(r.action!) : 'Solicito';
      var clause = '$verb ${_join(r.services)}';
      if (r.institution != null) {
        clause += ' ${r.institution}';
        r.institution = null;
      }
      sentences.add('$clause.');
      r.services.clear();
      r.action = null;
    } else if (r.action != null) {
      var clause = r.action!;
      if (r.procedures.isNotEmpty) {
        clause += ' ${_join(r.procedures)}';
        r.procedures.clear();
      }
      if (r.institution != null) {
        clause += ' ${r.institution}';
        r.institution = null;
      }
      sentences.add('${_cap(clause)}.');
      r.action = null;
    } else if (r.institution != null) {
      sentences.add('Necesito acudir ${r.institution}.');
      r.institution = null;
    }
    if (r.purposes.isNotEmpty) {
      sentences.add('Deseo presentar ${_join(r.purposes)}.');
      r.purposes.clear();
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  /// perdida → reporte de extravío.
  String _composeLoss(_Roles r, List<String> tokens) {
    const lead = 'Quiero reportar la pérdida de un objeto.';
    final sentences = <String>[];

    // El verbo PERDER ('perdí') ya queda expresado por la cláusula "Perdí …";
    // lo consumimos para que `_supplements` no lo repita como "Perdí." suelto.
    if (r.action == 'perdí') r.action = null;

    final what = _join([...r.objects, ...r.documents]);
    if (what.isNotEmpty) {
      var clause = 'Perdí $what';
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause += ' ${r.time}';
        r.time = null;
      }
      sentences.add('$clause.');
      r.objects.clear();
      r.documents.clear();
    } else if (r.time != null || r.place != null) {
      var clause = 'Ocurrió';
      if (r.time != null) {
        clause += ' ${r.time}';
        r.time = null;
      }
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      sentences.add('$clause.');
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  /// otro → declaración de testigo (relato en tercera persona de lo que
  /// presenció). A diferencia de [_composeIncident], el hecho no le ocurrió
  /// al declarante: se narra como observado ("Presencié cómo …").
  String _composeWitness(_Roles r, List<String> tokens) {
    const lead = 'Quiero declarar como testigo lo que presencié.';
    final sentences = <String>[];

    final hasActor = _hasAggressor(r);
    final subject = hasActor ? _subjectPhrase(r) : 'una persona';
    final isPlural = r.perpetratorPlural != null || r.perpetrators.length > 1;

    if (r.aggression != null) {
      final verb = isPlural ? _verbPlural(r.aggression!) : r.aggression!;
      var clause = 'presencié cómo $subject $verb';
      final complement = _join([...r.objects, ...r.documents]);
      if (complement.isNotEmpty) {
        clause += ' $complement';
        r.objects.clear();
        r.documents.clear();
      } else {
        clause += ' a otra persona';
      }
      if (r.weapon != null) {
        clause += ' ${r.weapon}';
        r.weapon = null;
      }
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '${_cap(r.time!)}, $clause';
        r.time = null;
      }
      sentences.add('${_cap(clause)}.');
      r.aggression = null;
      r.perpetrators.clear();
      r.perpetratorPlural = null;
      r.traits.clear();
    } else if (r.objects.isNotEmpty || r.documents.isNotEmpty) {
      final what = _join([...r.objects, ...r.documents]);
      var clause = 'presencié un hecho relacionado con $what';
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '${_cap(r.time!)}, $clause';
        r.time = null;
      }
      sentences.add('${_cap(clause)}.');
      r.objects.clear();
      r.documents.clear();
    } else if (hasActor) {
      var clause = 'observé a $subject';
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '${_cap(r.time!)}, $clause';
        r.time = null;
      }
      sentences.add('${_cap(clause)}.');
      r.perpetrators.clear();
      r.perpetratorPlural = null;
      r.traits.clear();
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  /// fallback → ensamblaje genérico fiel a los roles detectados.
  String _composeGeneric(String ctx, _Roles r, List<String> tokens) {
    const lead = 'Quiero comunicar lo siguiente.';
    final sentences = <String>[];

    final verb = r.action;
    final what = _join([...r.documents, ...r.procedures, ...r.objects]);
    if (verb != null) {
      var clause = verb;
      if (what.isNotEmpty) {
        clause += ' $what';
        r.documents.clear();
        r.procedures.clear();
        r.objects.clear();
      }
      if (r.institution != null) {
        clause += ' ${r.institution}';
        r.institution = null;
      }
      if (r.time != null) {
        clause = '${_cap(r.time!)}, ${_decap(clause)}';
        r.time = null;
      }
      sentences.add('${_cap(clause)}.');
      r.action = null;
    } else if (what.isNotEmpty) {
      var clause = what;
      if (r.institution != null) {
        clause += ' ${r.institution}';
        r.institution = null;
      }
      sentences.add('${_cap(clause)}.');
      r.documents.clear();
      r.procedures.clear();
      r.objects.clear();
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  /// Bloques semánticos complementarios — integra de forma NATURAL todos los
  /// roles que el compositor principal no consumió, garantizando cobertura
  /// total SIN frases-cola ("Asimismo", "Detalles:", "Consulto sobre:",
  /// "También menciono:"). Cada bloque limpia los roles que emite para que no
  /// se repitan ni los recoja la red de seguridad [_ensureCoverage].
  void _supplements(_Roles r, List<String> sentences) {
    // 1. Evento residual: agresor y/o agresión no integrados por el contexto.
    if (r.aggression != null || _hasAggressor(r)) {
      final hasActor = _hasAggressor(r);
      final subject = hasActor ? _subjectPhrase(r) : 'una persona';
      if (r.aggression != null) {
        final isPlural =
            r.perpetratorPlural != null || r.perpetrators.length > 1;
        final verb = isPlural ? _verbPlural(r.aggression!) : r.aggression!;
        var clause = '$subject me $verb';
        final comp = _join([...r.objects, ...r.documents]);
        if (comp.isNotEmpty) {
          clause += ' $comp';
          r.objects.clear();
          r.documents.clear();
        }
        if (r.weapon != null) {
          clause += ' ${r.weapon}';
          r.weapon = null;
        }
        if (r.place != null) {
          clause += ' ${r.place}';
          r.place = null;
        }
        if (r.time != null) {
          clause = '${_cap(r.time!)}, ${_decap(clause)}';
          r.time = null;
        }
        sentences.add('${_cap(clause)}.');
      } else {
        // Solo se describió a una persona, sin acción.
        sentences.add('La persona involucrada era ${_decap(subject)}.');
      }
      r.aggression = null;
      r.perpetrators.clear();
      r.perpetratorPlural = null;
      r.traits.clear();
    }

    // 2. Objetos / documentos no usados → se dejan constar formalmente.
    final things = _join([...r.objects, ...r.documents]);
    if (things.isNotEmpty) {
      sentences.add('Quiero hacer constar $things.');
      r.objects.clear();
      r.documents.clear();
    }

    // 3. Arma residual.
    if (r.weapon != null) {
      final w = r.weapon!.replaceFirst(RegExp(r'^con '), '');
      sentences.add('Se utilizó $w.');
      r.weapon = null;
    }

    // 4. Acción de trámite residual (1ª persona).
    if (r.action != null) {
      var clause = r.action!;
      if (r.procedures.isNotEmpty) {
        clause += ' ${_join(r.procedures)}';
        r.procedures.clear();
      }
      sentences.add('${_cap(clause)}.');
      r.action = null;
    }

    // 5. Propósito y 6. procedimientos restantes.
    if (r.purposes.isNotEmpty) {
      sentences.add('Lo requiero para presentar ${_join(r.purposes)}.');
      r.purposes.clear();
    }
    if (r.procedures.isNotEmpty) {
      sentences.add('Solicito ${_join(r.procedures)}.');
      r.procedures.clear();
    }

    // 7. Lugar / tiempo residuales.
    if (r.place != null || r.time != null) {
      var clause = 'Ocurrió';
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause += ' ${r.time}';
        r.time = null;
      }
      sentences.add('$clause.');
    }

    // 8. Sujeto co-afectado (familia, hijo, esposo…).
    final affected = _affectedSubjectLine(r);
    if (affected != null) {
      sentences.add(affected);
      r.subject = null;
    }

    // 9. Estado: emociones, urgencias, servicios.
    if (r.emotions.isNotEmpty) {
      sentences.add('${_cap(_join(r.emotions))}.');
      r.emotions.clear();
    }
    if (r.urgencies.isNotEmpty) {
      sentences.add('${_cap(_join(r.urgencies))}.');
      r.urgencies.clear();
    }
    if (r.services.isNotEmpty) {
      sentences.add('Necesito ${_join(r.services)}.');
      r.services.clear();
    }

    // 10. Institución residual (lexema locativo: "en la policía").
    if (r.institution != null) {
      sentences.add('Realizaré esta gestión ${r.institution}.');
      r.institution = null;
    }

    // 11. Glosas sin rol (caso raro: el catálogo las tiene todas mapeadas).
    if (r.unknown.isNotEmpty) {
      sentences.add('Adicionalmente, hago referencia a ${_join(r.unknown)}.');
      r.unknown.clear();
    }
  }

  // ───────────────────────── Utilidades de composición ────────────────────

  /// Frase del sujeto agresor con sus rasgos físicos y accesorios.
  ///
  /// Separa rasgos adjetivales (alto, delgado, moreno) de complementos
  /// preposicionales (con barba, con lentes, con gorra) para producir
  /// español natural: "un hombre alto y moreno, con tatuaje y lentes"
  /// en vez de "un hombre alto y moreno y con tatuaje y con lentes".
  ///
  /// Cuando el sujeto es genérico ("una persona") los adjetivos simples
  /// se convierten a su forma femenina para mantener concordancia.
  String _subjectPhrase(_Roles r) {
    String base;
    if (r.perpetratorPlural != null) {
      base = r.perpetratorPlural!;
      if (r.perpetrators.isNotEmpty) {
        base += ' (${_join(r.perpetrators)})';
      }
    } else {
      if (r.perpetrators.isNotEmpty) {
        final parts = <String>[];
        for (var i = 0; i < r.perpetrators.length; i++) {
          var p = r.perpetrators[i];
          if (i > 0) {
            p = p.replaceFirst(RegExp(r'^un\s+'), '').replaceFirst(RegExp(r'^una\s+'), '');
          }
          parts.add(p);
        }
        base = _join(parts);
      } else {
        base = 'una persona';
      }
    }
    
    // Concordancia de género: cualquier sujeto femenino ("una persona", "una
    // mujer"…) feminiza sus adjetivos simples ("alto" → "alta"), no solo el
    // genérico. Los complementos preposicionales ("con gorra", "de color
    // negro") son invariables y se dejan tal cual.
    final isFeminine = base.startsWith('una ');
    if (r.traits.isEmpty) return base;

    // Separa adjetivos simples de frases con preposición (empieza con "con"/"de")
    var adjectives = r.traits
        .where((t) => !t.startsWith('con ') && !t.startsWith('de '))
        .toList();
    final phrases = r.traits
        .where((t) => t.startsWith('con ') || t.startsWith('de '))
        .toList();

    if (isFeminine) {
      adjectives = adjectives.map(_femAdj).toList();
    }

    final buffer = StringBuffer(base);
    if (adjectives.isNotEmpty) buffer.write(' ${_join(adjectives)}');
    if (phrases.isNotEmpty) {
      // Normaliza: quita el "con " de cada frase para re-unirlas
      final items = phrases.map((p) {
        if (p.startsWith('con ')) return p.substring(4);
        if (p.startsWith('de ')) return p.substring(3);
        return p;
      }).toList();
      buffer.write(', con ${_join(items)}');
    }
    return buffer.toString();
  }

  /// Convierte un adjetivo masculino terminado en -o a su forma femenina (-a),
  /// y adjetivos compuestos "de color [X]o" → "de color [X]a", etc.
  /// Solo actúa sobre palabras que terminan en -o (no toca invariables
  /// como "calvo" → "calva" o "moreno" → "morena").
  static String _femAdj(String adj) {
    // Frases tipo "de piel clara", "de cabello corto" — invariables o ya
    // concordadas con el sustantivo interno: las dejamos tal cual.
    if (adj.startsWith('de piel') || adj.startsWith('de cabello')) return adj;
    // Adjetivos simples terminados en -o masculino → -a femenino.
    if (adj.endsWith('o')) return '${adj.substring(0, adj.length - 1)}a';
    // Adjetivos terminados en -oso → -osa (robusto → robusta ya cubierto).
    return adj;
  }

  /// Oración para sujetos co-afectados distintos del declarante (familia,
  /// hijo, esposo…). "yo" es implícito en la 1ª persona.
  String? _affectedSubjectLine(_Roles r) =>
      (r.subject == null || r.subject == 'yo')
          ? null
          : 'El hecho también afectó a ${r.subject}.';

  /// Une el lead de contexto con las oraciones del cuerpo. Si el cuerpo
  /// quedó vacío (todas las glosas desconocidas y sin rol), cae a un
  /// ensamblaje mínimo para no perder la declaración del usuario.
  String _stitch(String lead, List<String> sentences, List<String> tokens) {
    final body = sentences.where((s) => s.trim().isNotEmpty).toList();
    // Si el cuerpo quedó vacío, el lead ya es una oración completa. No se
    // vuelcan glosas crudas: la red de seguridad `_ensureCoverage` integra de
    // forma natural cualquier glosa que el lead no exprese.
    if (body.isEmpty) return lead;
    return '$lead ${body.join(' ')}';
  }

  /// Une una lista con comas y "y" final ("a, b y c").
  String _join(List<String> items) {
    final clean = items.where((s) => s.trim().isNotEmpty).toList();
    if (clean.isEmpty) return '';
    if (clean.length == 1) return clean.first;
    if (clean.length == 2) return '${clean[0]} y ${clean[1]}';
    return '${clean.sublist(0, clean.length - 1).join(', ')} y ${clean.last}';
  }

  String _normalize(String g) => g.trim().toUpperCase();

  String _cap(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _decap(String s) {
    if (s.isEmpty) return s;
    return s[0].toLowerCase() + s.substring(1);
  }

  static String _stripDiacritics(String input) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    var out = input;
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  // ───────────────────────── Lexicón local compacto ───────────────────────
  // Espeja los roles del GLOSS_LEXICON del backend para garantizar fidelidad
  // offline. Las claves son las glosas del catálogo (LsbCard.gloss).
  static const Map<String, _Lex> _lexicon = {
    // Sujetos (1ª persona / familia).
    'YO': _Lex(_Role.sujeto, 'yo'),
    'FAMILIA': _Lex(_Role.sujeto, 'mi familia'),
    'HIJO': _Lex(_Role.sujeto, 'mi hijo'),
    'ESPOSO': _Lex(_Role.sujeto, 'mi esposo'),
    'MAMA': _Lex(_Role.sujeto, 'mi madre'),
    'PAPA': _Lex(_Role.sujeto, 'mi padre'),
    'HERMANO': _Lex(_Role.sujeto, 'mi hermano'),

    // Personas / agresor (3ª persona).
    'HOMBRE': _Lex(_Role.personaDesc, 'un hombre'),
    'MUJER': _Lex(_Role.personaDesc, 'una mujer'),
    'JOVEN': _Lex(_Role.personaDesc, 'un joven'),
    'NIÑO': _Lex(_Role.personaDesc, 'un niño'),
    'DESCONOCIDO': _Lex(_Role.personaDesc, 'un desconocido'),
    'VECINO': _Lex(_Role.personaDesc, 'un vecino'),
    // Bug fix #2: DOS/TRES usan role personaDescPlural para que el verbo
    // concuerde en plural ("me agredieron" no "me agredió").
    'GRUPO': _Lex(_Role.personaDesc, 'un grupo de personas'),
    'ADULTO': _Lex(_Role.personaDesc, 'un adulto'),
    'ABUELO': _Lex(_Role.personaDesc, 'un abuelo'),
    'SOLO': _Lex(_Role.personaDesc, 'una persona'),
    'DOS': _Lex(_Role.personaDescPlural, 'dos personas'),
    'TRES': _Lex(_Role.personaDescPlural, 'tres personas'),
    'CONOCIDO': _Lex(_Role.personaDesc, 'un conocido'),

    // Rasgos físicos / vestimenta / color.
    'ALTO': _Lex(_Role.rasgo, 'alto'),
    'BAJO': _Lex(_Role.rasgo, 'bajo'),
    'FLACO': _Lex(_Role.rasgo, 'flaco'),
    'GORDO': _Lex(_Role.rasgo, 'robusto'),
    'FUERTE': _Lex(_Role.rasgo, 'de contextura fuerte'),
    'MORENO': _Lex(_Role.rasgo, 'moreno'),
    'BLANCO_PIEL': _Lex(_Role.rasgo, 'de piel clara'),
    'PELO_CORTO': _Lex(_Role.rasgo, 'de cabello corto'),
    'PELO_LARGO': _Lex(_Role.rasgo, 'de cabello largo'),
    'CALVO': _Lex(_Role.rasgo, 'calvo'),
    'BARBA': _Lex(_Role.rasgo, 'con barba'),
    'BIGOTE': _Lex(_Role.rasgo, 'con bigote'),
    'TATUAJE': _Lex(_Role.rasgo, 'con un tatuaje'),
    'CICATRIZ': _Lex(_Role.rasgo, 'con una cicatriz'),
    'LENTES': _Lex(_Role.rasgo, 'con lentes'),
    'MASCARA': _Lex(_Role.rasgo, 'con el rostro cubierto'),
    'GORRA': _Lex(_Role.rasgo, 'con gorra'),
    'CAPUCHA': _Lex(_Role.rasgo, 'con capucha'),
    'CHOMPA': _Lex(_Role.rasgo, 'con chompa'),
    'CASCO': _Lex(_Role.rasgo, 'con casco'),
    'CAMISA': _Lex(_Role.rasgo, 'con camisa'),
    'PANTALON': _Lex(_Role.rasgo, 'con pantalón'),
    'ZAPATOS': _Lex(_Role.rasgo, 'con zapatos'),
    'MOCHILA_USADA': _Lex(_Role.rasgo, 'con una mochila'),
    'NEGRO': _Lex(_Role.rasgo, 'de color negro'),
    'BLANCO': _Lex(_Role.rasgo, 'de color blanco'),
    'AZUL': _Lex(_Role.rasgo, 'de color azul'),
    'ROJO': _Lex(_Role.rasgo, 'de color rojo'),
    'GRIS': _Lex(_Role.rasgo, 'de color gris'),
    'VERDE': _Lex(_Role.rasgo, 'de color verde'),
    'OSCURO': _Lex(_Role.rasgo, 'de color oscuro'),
    'CLARO': _Lex(_Role.rasgo, 'de color claro'),

    // Verbos de agresión (3ª persona, se antepone "me").
    'ROBAR': _Lex(_Role.verboAgresion, 'robó'),
    'PEGAR': _Lex(_Role.verboAgresion, 'golpeó'),
    'AMENAZAR': _Lex(_Role.verboAgresion, 'amenazó'),
    'EMPUJAR': _Lex(_Role.verboAgresion, 'empujó'),
    'GRITAR': _Lex(_Role.verboAgresion, 'gritó'),
    'QUITAR': _Lex(_Role.verboAgresion, 'quitó'),
    'PERSEGUIR': _Lex(_Role.verboAgresion, 'persiguió'),
    'ASALTAR': _Lex(_Role.verboAgresion, 'asaltó'),
    'ACOSAR': _Lex(_Role.verboAgresion, 'acosó'),
    'ABUSO': _Lex(_Role.verboAgresion, 'agredió sexualmente'),
    'SECUESTRAR': _Lex(_Role.verboAgresion, 'secuestró'),

    // Verbos de acción / trámite (1ª persona).
    'TRAMITAR': _Lex(_Role.verboAccion, 'quiero tramitar'),
    'PEDIR': _Lex(_Role.verboAccion, 'quiero solicitar'),
    'CONSULTAR': _Lex(_Role.verboAccion, 'quiero consultar'),
    'NECESITAR': _Lex(_Role.verboAccion, 'necesito'),
    'PAGAR': _Lex(_Role.verboAccion, 'quiero pagar'),
    'RENOVAR': _Lex(_Role.verboAccion, 'quiero renovar'),
    'RECOGER': _Lex(_Role.verboAccion, 'quiero recoger'),
    'DAR': _Lex(_Role.verboAccion, 'quiero entregar'),
    'PERDER': _Lex(_Role.verboAccion, 'perdí'),
    'CORREGIR': _Lex(_Role.verboAccion, 'quiero corregir'),

    // Armas.
    'CUCHILLO': _Lex(_Role.arma, 'con un cuchillo'),

    // Objetos.
    'CELULAR': _Lex(_Role.objeto, 'mi celular'),
    'DINERO': _Lex(_Role.objeto, 'mi dinero'),
    'MOCHILA': _Lex(_Role.objeto, 'mi mochila'),
    'BOLSA': _Lex(_Role.objeto, 'mi bolsa'),
    'LLAVE': _Lex(_Role.objeto, 'mis llaves'),
    'AUTO': _Lex(_Role.objeto, 'mi auto'),
    'MOTOCICLETA': _Lex(_Role.objeto, 'mi motocicleta'),
    'BILLETERA': _Lex(_Role.objeto, 'mi billetera'),
    'TARJETA': _Lex(_Role.objeto, 'mi tarjeta bancaria'),
    'RELOJ': _Lex(_Role.objeto, 'mi reloj'),
    'CADENA': _Lex(_Role.objeto, 'mi cadena'),
    'ANILLO': _Lex(_Role.objeto, 'mi anillo'),
    'COLLAR': _Lex(_Role.objeto, 'mi collar'),
    'ARETES': _Lex(_Role.objeto, 'mis aretes'),
    'COMPUTADORA': _Lex(_Role.objeto, 'mi computadora'),
    'AUDIFONOS': _Lex(_Role.objeto, 'mis audífonos'),
    'LENTES_SOL': _Lex(_Role.objeto, 'mis lentes de sol'),
    'BICICLETA': _Lex(_Role.objeto, 'mi bicicleta'),

    // Documentos.
    'CARNET': _Lex(_Role.documento, 'mi carnet de identidad'),
    'PAPEL': _Lex(_Role.documento, 'mi documento'),
    'CERTIFICADO': _Lex(_Role.documento, 'un certificado'),
    'PARTIDA_NACIMIENTO': _Lex(_Role.documento, 'mi partida de nacimiento'),
    'LICENCIA': _Lex(_Role.documento, 'mi licencia de conducir'),
    'FACTURA': _Lex(_Role.documento, 'una factura'),
    'ANTECEDENTES': _Lex(_Role.documento, 'mi certificado de antecedentes penales'),
    'COPIA_DENUNCIA': _Lex(_Role.documento, 'una copia de la denuncia'),
    'COPIA_SENTENCIA': _Lex(_Role.documento, 'una copia de la sentencia'),
    'PODER': _Lex(_Role.documento, 'un poder notarial'),
    'DECLARACION_JURADA': _Lex(_Role.documento, 'una declaración jurada'),

    // Lugares.
    'CALLE': _Lex(_Role.lugar, 'en la calle'),
    'CASA': _Lex(_Role.lugar, 'en mi casa'),
    'MERCADO': _Lex(_Role.lugar, 'en el mercado'),
    'PARADA': _Lex(_Role.lugar, 'en la parada'),
    'MICRO': _Lex(_Role.lugar, 'en el micro'),
    'PARQUE': _Lex(_Role.lugar, 'en el parque'),
    'TRABAJO': _Lex(_Role.lugar, 'en mi trabajo'),
    'CAJERO': _Lex(_Role.lugar, 'en el cajero automático'),
    'BANCO': _Lex(_Role.lugar, 'en el banco'),
    'TAXI': _Lex(_Role.lugar, 'en un taxi'),
    'PLAZA': _Lex(_Role.lugar, 'en la plaza'),
    'ESQUINA': _Lex(_Role.lugar, 'en la esquina'),
    'PUENTE': _Lex(_Role.lugar, 'en el puente'),

    // Instituciones.
    'POLICIA': _Lex(_Role.institucion, 'en la policía'),
    'DEFENSORIA': _Lex(_Role.institucion, 'en la defensoría'),
    'SEGIP': _Lex(_Role.institucion, 'en el SEGIP'),
    'HOSPITAL': _Lex(_Role.institucion, 'en el hospital'),
    'ALCALDIA': _Lex(_Role.institucion, 'en la alcaldía'),
    'REGISTRO_CIVIL': _Lex(_Role.institucion, 'en el registro civil'),
    'FISCAL': _Lex(_Role.institucion, 'en la fiscalía'),
    'JUZGADO': _Lex(_Role.institucion, 'en el juzgado'),
    'NOTARIA': _Lex(_Role.institucion, 'en la notaría'),

    // Servicios.
    'INTERPRETE': _Lex(_Role.servicio, 'un intérprete de señas'),
    'AMBULANCIA': _Lex(_Role.servicio, 'una ambulancia'),
    'DOCTOR': _Lex(_Role.servicio, 'un médico'),
    'ABOGADO': _Lex(_Role.servicio, 'un abogado'),
    'INFORMACION': _Lex(_Role.servicio, 'información'),
    'ORIENTACION': _Lex(_Role.servicio, 'orientación'),

    // Emociones / estado.
    'MIEDO': _Lex(_Role.emocion, 'tengo miedo'),
    'ENOJO': _Lex(_Role.emocion, 'estoy enojado'),
    'TRISTE': _Lex(_Role.emocion, 'estoy triste'),
    'ASUSTADO': _Lex(_Role.emocion, 'estoy asustado'),
    'NERVIOSO': _Lex(_Role.emocion, 'estoy nervioso'),
    'ENFERMEDAD': _Lex(_Role.emocion, 'estoy enfermo'),
    'DOLOR': _Lex(_Role.emocion, 'siento dolor'),
    'CONFUNDIDO': _Lex(_Role.emocion, 'estoy confundido'),

    // Urgencia.
    'URGENTE': _Lex(_Role.urgencia, 'es urgente'),
    'EMERGENCIA': _Lex(_Role.urgencia, 'es una emergencia'),
    'AYUDA': _Lex(_Role.urgencia, 'necesito ayuda'),

    // Motivo / propósito del trámite (a qué se destina el documento).
    'DENUNCIA': _Lex(_Role.motivo, 'una denuncia'),
    'CONSULTA': _Lex(_Role.motivo, 'una consulta'),
    'QUEJAR': _Lex(_Role.motivo, 'un reclamo'),
    // Trámites (tipo de gestión).
    'RENOVACION': _Lex(_Role.tramite, 'una renovación'),
    'PAGO': _Lex(_Role.tramite, 'un pago'),
    'DUPLICADO': _Lex(_Role.tramite, 'un duplicado'),

    // Tiempo.
    'HOY': _Lex(_Role.tiempo, 'hoy'),
    'AHORA': _Lex(_Role.tiempo, 'ahora mismo'),
    'AYER': _Lex(_Role.tiempo, 'ayer'),
    'MAÑANA': _Lex(_Role.tiempo, 'por la mañana'),
    'TARDE': _Lex(_Role.tiempo, 'por la tarde'),
    'NOCHE': _Lex(_Role.tiempo, 'por la noche'),
  };
}

enum _Role {
  sujeto,
  personaDesc,
  personaDescPlural, // Bug fix #2: DOS/TRES — verbo concuerda en plural
  rasgo,
  verboAgresion,
  verboAccion,
  arma,
  objeto,
  documento,
  lugar,
  institucion,
  servicio,
  emocion,
  urgencia,
  tramite,
  motivo,
  tiempo,
}

class _Lex {
  final _Role role;
  final String es;
  const _Lex(this.role, this.es);
}

/// Acumulador mutable de roles detectados en una secuencia de glosas.
class _Roles {
  String? subject;
  final List<String> perpetrators = [];
  String? perpetratorPlural; // Bug fix #2: sujeto plural (DOS/TRES)
  String? aggression;
  String? action;
  String? weapon;
  String? place;
  String? institution;
  String? time;
  final List<String> traits = [];
  final List<String> objects = [];
  final List<String> documents = [];
  final List<String> services = [];
  final List<String> emotions = [];
  final List<String> urgencies = [];
  final List<String> procedures = [];
  final List<String> purposes = [];
  final List<String> unknown = [];
}
