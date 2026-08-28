const String kVictimMarker = 'VICTIMA';

const String kEvidenceMarker = 'PRUEBA_MARCADOR';

const String kVehicleMarker = 'VEHICULO_MARCADOR';

class LocalSentenceAssembler {
  const LocalSentenceAssembler();

  String assemble({
    required String contextId,
    required List<String> glosses,
  }) {
    final tokens = glosses
        .map(_normalize)
        .where((g) => g.isNotEmpty)
        .toList(growable: false);

    if (tokens.isEmpty) return '';

    final unidos = _joinSpelled(tokens);

    final detalles = <String, String>{};
    final limpios = _extractDetails(unidos, detalles);

    final roles = _classify(limpios, detalles);

    roles.narrativeIsPast = _pastContexts.contains(contextId);
    final consumidas = <String>{
      ...detalles.keys,
      if (roles.markers.any((m) => m.startsWith('tengo ') && m.endsWith(' años')))
        ...const {'EDAD', 'ANOS_EDAD'},
      ..._resolveGender(roles),
      ..._resolveTime(roles, contextId, unidos),
    };

    final composed = roles.question != null
        ? _composeQuestion(roles)
        : switch (contextId) {
      'denuncia_robo' || 'violencia' => _composeIncident(contextId, roles, unidos),
      'accidente' || 'emergencia' => _composeEmergency(contextId, roles, unidos),
      'tramite_id' => _composeProcedure(roles, unidos),
      'orientacion' => _composeGuidance(roles, unidos),
      'perdida' => _composeLoss(roles, unidos),
      'preguntas' => _composeQuestion(roles),
      'identificacion' => _composeIdentification(roles),
      'otro' => _composeWitness(roles, unidos),
      _ => _composeGeneric(contextId, roles, unidos),
    };

    final conTestigos = _withWitnesses(composed, roles);

    final conMarcadores = roles.markers.isEmpty
        ? conTestigos
        : '${roles.markers.map(_asSentence).join(' ')} $conTestigos'.trim();

    return _ensureCoverage(conMarcadores, limpios, skip: consumidas);
  }

  static const Map<String, ({bool femenino, String singular, String plural})>
      _timeUnits = {
    'MINUTO': (femenino: false, singular: 'minuto', plural: 'minutos'),
    'HORA':   (femenino: true,  singular: 'hora',   plural: 'horas'),
    'DIA':    (femenino: false, singular: 'día',    plural: 'días'),
    'SEMANA': (femenino: true,  singular: 'semana', plural: 'semanas'),
    'MES':    (femenino: false, singular: 'mes',    plural: 'meses'),
    'ANO':    (femenino: false, singular: 'año',    plural: 'años'),
  };

  static const _frequencyGlosses = {
    'PRIMERA_VEZ': 'Es la primera vez que ocurre',
    'VARIAS_VECES': 'Ha ocurrido varias veces',
    'ANTERIORMENTE': 'Ya había ocurrido anteriormente',
  };

  static const _cardinales = {
    '1': 'un', '2': 'dos', '3': 'tres', '4': 'cuatro', '5': 'cinco',
    '6': 'seis', '7': 'siete', '8': 'ocho', '9': 'nueve',
  };

  static const _pastContexts = {
    'denuncia_robo', 'violencia', 'accidente', 'emergencia', 'otro', 'perdida',
  };

  static const _pastVerbs = {
    'SEGUIMIENTO', 'COMPRENDER', 'ACLARAR', 'CONOCER', 'RECORDAR',
    'OBSERVAR', 'RECONOCER', 'PERDER', 'PAGAR', 'ENTREGAR', 'NARRAR',
    'CONFESAR', 'IDENTIFICAR',
  };

  static const _futureVerbs = {
    'PRESENTAR', 'CORREGIR', 'PEDIR', 'GESTIONAR', 'RECOGER', 'COPIAR',
    'IMPRIMIR', 'COORDINAR', 'SOLUCIONAR', 'TRATAR', 'EXIGIR',
  };

  List<String> _extractDetails(List<String> tokens, Map<String, String> destino) {
    final salida = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      final anterior = salida.isEmpty ? null : salida.last;
      final esRacha = t.length > 1 && _lexicon[t] == null && !_esDigito(t) &&
          RegExp(r'^[A-ZÑ0-9]+$').hasMatch(t);
      if (anterior != null &&
          _admiteDetalle.containsKey(anterior) &&
          !destino.containsKey(anterior) &&
          esRacha) {
        final buffer = StringBuffer(t);
        while (i + 1 < tokens.length) {
          final siguiente = tokens[i + 1];
          final continua = siguiente.length > 1 &&
              _lexicon[siguiente] == null &&
              RegExp(r'^[A-ZÑ0-9]+$').hasMatch(siguiente);
          if (!continua) break;
          buffer.write(siguiente);
          i++;
        }
        destino[anterior] = buffer.toString();
        continue;
      }
      salida.add(t);
    }
    return salida;
  }

  String _conDetalle(String gloss, String lexema, _Roles r) {
    final detalle = r.details.remove(gloss);
    if (detalle == null) return lexema;
    final etiqueta = _admiteDetalle[gloss];
    final propio = _capitalizarPropio(detalle);
    return switch (etiqueta) {
      'placa' => '$lexema con placa $detalle',
      'numero' => '$lexema número $detalle',
      'edad' => 'tengo $detalle años',
      'nombre' => 'mi nombre es $propio',
      'apellido' => 'mi apellido es $propio',
      'carnet' => '$lexema número $detalle',
      _ => '$lexema $propio',
    };
  }

  String _capitalizarPropio(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Set<String> _resolveGender(_Roles r) {
    final consumidas = <String>{};

    void concordar(List<String> personas) {
      if (personas.length < 2) return;
      final femenino = personas.contains('una mujer');
      final masculino = personas.contains('un hombre');
      if (!femenino && !masculino) return;

      final llevaGenero = personas.any(
          (p) => p != 'una mujer' && p != 'un hombre' && _feminino.containsKey(p));
      if (!llevaGenero) return;

      if (femenino) {
        for (var i = 0; i < personas.length; i++) {
          personas[i] = _feminino[personas[i]] ?? personas[i];
        }
        personas.remove('una mujer');
        consumidas.add('MUJER');
      } else {
        personas.remove('un hombre');
        consumidas.add('HOMBRE');
      }
    }

    concordar(r.perpetrators);
    concordar(r.victims);
    return consumidas;
  }

  bool _mirarAtras(_Roles r, String contextId, List<String> tokens) {
    for (final t in tokens) {
      if (_pastVerbs.contains(t)) return true;
      if (_futureVerbs.contains(t)) return false;
    }
    return _pastContexts.contains(contextId);
  }

  Set<String> _resolveTime(_Roles r, String contextId, List<String> tokens) {
    final unit = r.timeUnit;
    if (unit == null) return const {};
    final spec = _timeUnits[unit]!;
    final count = r.timeCount;

    if (count == null) {
      r.time ??= _lexicon[unit]!.es;
      return {unit};
    }

    final cardinal = count == '1'
        ? (spec.femenino ? 'una' : 'un')
        : _cardinales[count]!;
    final medida = count == '1' ? spec.singular : spec.plural;
    final esPasado = _mirarAtras(r, contextId, tokens);
    r.timeIsFuture = !esPasado;
    r.time = '${esPasado ? 'hace' : 'dentro de'} $cardinal $medida';
    return {unit, count};
  }

  static const _admiteDetalle = {
    'PLAZA': 'plaza', 'CALLE': 'calle', 'AVENIDA': 'avenida',
    'MERCADO': 'mercado', 'PARADA': 'parada',
    'AUTO': 'placa', 'MOTOCICLETA': 'placa', 'MICRO': 'placa',
    'TAXI': 'placa', 'TRUFI': 'placa', 'BICICLETA': 'placa',
    'CASO': 'numero', 'CODIGO': 'numero', 'NUREJ': 'numero',
    'WEBID': 'numero', 'EXPEDIENTE': 'numero',
    'EDAD': 'edad', 'ANOS_EDAD': 'edad',
    'NOMBRE': 'nombre', 'APELLIDO': 'apellido',
    'CARNET': 'carnet',
  };

  static String? etiquetaDeDetalle(String gloss) =>
      _admiteDetalle[gloss.trim().toUpperCase()];

  static const _feminino = {
    'un vecino': 'una vecina',
    'un militar': 'una militar',
    'un soldado': 'una soldado',
    'un testigo': 'una testigo',
    'un ladrón': 'una ladrona',
    'un doctor': 'una doctora',
    'un abogado': 'una abogada',
  };

  static const _flightVerbs = {'CORRER'};

  static const _inherentEvidence = {
    'FOTOGRAFIA', 'MENSAJE', 'COMPROBANTE', 'CERTIFICADO', 'RESPALDO',
    'VIDEOLLAMADA',
  };

  static const _inherentImplicit = {'YO'};

  String _ensureCoverage(String text, List<String> tokens,
      {Set<String> skip = const {}}) {
    final hay = _stripDiacritics(text.toLowerCase());
    final missing = <String>[];
    for (final t in tokens) {
      if (t == kVictimMarker || t == kEvidenceMarker || t == kVehicleMarker) {
        continue;
      }
      if (_inherentImplicit.contains(t)) continue;
      if (_esDigito(t)) continue;
      if (skip.contains(t)) continue;
      if (_isRepresented(t, hay)) continue;
      final lex = _lexicon[t];
      final frag = lex != null ? lex.es : t.toLowerCase().replaceAll('_', ' ');
      if (!missing.contains(frag)) missing.add(frag);
    }
    if (missing.isEmpty) return text;
    if (text.trim().endsWith('?')) return text;
    return '$text Para completar mi declaración, hago constar ${_join(missing)}.';
  }

  bool _isRepresented(String token, String hayLower) {
    final lex = _lexicon[token];
    if (lex == null) return _glossCovered(token, hayLower);
    switch (token) {
      case 'FISCAL':
        if (hayLower.contains('fiscal') || hayLower.contains('fiscalia')) {
          return true;
        }
        break;
      case 'JUEZ':
        if (hayLower.contains('juez') || hayLower.contains('juzgado')) {
          return true;
        }
        break;
      case 'OFICIAL':
        if (hayLower.contains('oficial')) return true;
        break;
      case 'AUTORIDAD':
        if (hayLower.contains('autoridad')) return true;
        break;
      case 'POLICIA':
        if (hayLower.contains('policia')) return true;
        break;
      case 'PAPEL':
        if (hayLower.contains('papel') ||
            hayLower.contains('documento') ||
            hayLower.contains('soporte')) {
          return true;
        }
        break;
      case 'ARCHIVADOR':
        if (hayLower.contains('archivador') ||
            hayLower.contains('documento') ||
            hayLower.contains('soporte')) {
          return true;
        }
        break;
      case 'CARPETA':
        if (hayLower.contains('carpeta') ||
            hayLower.contains('documento') ||
            hayLower.contains('soporte')) {
          return true;
        }
        break;
      case 'HOJA':
        if (hayLower.contains('hoja') ||
            hayLower.contains('documento') ||
            hayLower.contains('soporte')) {
          return true;
        }
        break;
    }
    final variants = <String>{lex.es, _verbPlural(lex.es), _femAdj(lex.es)};
    for (final variant in variants) {
      final words = _stripDiacritics(variant.toLowerCase())
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3)
          .toList();
      if (words.isEmpty) return true;
      if (words.every(hayLower.contains)) return true;
    }
    return false;
  }

  bool isBackendDegenerate({
    required String backendText,
    required List<String> glosses,
  }) {
    const marcadores = {kVictimMarker, kEvidenceMarker, kVehicleMarker};
    glosses = glosses
        .where((g) => !marcadores.contains(g.trim().toUpperCase()))
        .toList();
    final normalizadas = _joinSpelled(glosses.map(_normalize).toList());
    final utiles = <String>[];
    for (var i = 0; i < normalizadas.length; i++) {
      final g = normalizadas[i];
      if (_esDigito(g)) {
        final previa = i > 0 ? normalizadas[i - 1] : null;
        if (previa == null || !_timeUnits.containsKey(previa)) continue;
      }
      utiles.add(g);
    }
    glosses = utiles;
    final trimmed = backendText.trim();
    if (trimmed.isEmpty) return true;
    if (glosses.isEmpty) return false;

    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length < glosses.length) return true;

    const kLinking = {
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
    final hasLinking = textWords.any(kLinking.contains);
    if (!hasLinking && glosses.length > 1) return true;

    final haystack = _stripDiacritics(trimmed.toLowerCase());
    var hits = 0;
    for (final g in glosses) {
      if (_isRepresented(g, haystack) || _glossCovered(g, haystack)) hits++;
    }
    return hits < glosses.length;
  }

  bool _glossCovered(String gloss, String haystackLower) {
    final normalizada = _stripDiacritics(gloss.toLowerCase());

    final cardinal = _cardinales[gloss];
    if (cardinal != null) {
      if (RegExp('\\b$cardinal\\b').hasMatch(haystackLower)) return true;
      if (gloss == '1' && RegExp(r'\buna?\b').hasMatch(haystackLower)) {
        return true;
      }
    }
    final parts = normalizada
        .split(RegExp(r'[ _/]+'))
        .where((p) => p.length >= 3);
    if (parts.isEmpty) return haystackLower.contains(normalizada);
    for (final p in parts) {
      final stem = p.length <= 3 ? p : p.substring(0, 3);
      if (haystackLower.contains(stem)) return true;
    }
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

  _Roles _classify(List<String> tokens, [Map<String, String> detalles = const {}]) {
    final r = _Roles()..details.addAll(detalles);
    var victimMode = false;
    var afirmarSiguienteVerbo = false;
    final hayInterrogativa =
        tokens.any((t) => _lexicon[t]?.role == _Role.interrogativa);
    var negarSiguienteVerbo = false;
    var evidenceMode = false;
    var vehicleMode = false;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t == kVictimMarker) {
        victimMode = true;
        continue;
      }
      if (t == kEvidenceMarker) {
        evidenceMode = true;
        continue;
      }
      if (t == kVehicleMarker) {
        vehicleMode = true;
        continue;
      }

      final frecuencia = _frequencyGlosses[t];
      if (frecuencia != null) {
        r.frequency ??= frecuencia;
        continue;
      }

      if (_inherentEvidence.contains(t) && !hayInterrogativa) {
        final lex = _lexicon[t];
        if (lex != null && !r.evidence.contains(lex.es)) r.evidence.add(lex.es);
        continue;
      }

      if (evidenceMode || vehicleMode) {
        final lex = _lexicon[t];
        final admite = lex != null &&
            (lex.role == _Role.objeto ||
                (evidenceMode && lex.role == _Role.documento));
        if (admite) {
          final destino = evidenceMode ? r.evidence : r.vehicles;
          if (!destino.contains(lex.es)) destino.add(lex.es);
          continue;
        }
      }

      if (_cardinales.containsKey(t) &&
          r.timeUnit != null &&
          r.timeCount == null) {
        r.timeCount = t;
        continue;
      }

      if (_timeUnits.containsKey(t)) {
        r.timeUnit ??= t;
        continue;
      }

      if ((t == 'NO' || t == 'SI') && i + 1 < tokens.length) {
        final siguiente = _lexicon[tokens[i + 1]]?.role;
        if (siguiente == _Role.verboAccion || siguiente == _Role.testigo) {
          if (t == 'NO') {
            negarSiguienteVerbo = true;
          } else {
            afirmarSiguienteVerbo = true;
          }
          continue;
        }
      }

      if (_esDigito(t)) continue;

      final e = _lexicon[t];
      if (e == null) {
        r.unknown.add(t.toLowerCase().replaceAll('_', ' '));
        continue;
      }
      switch (e.role) {
        case _Role.sujeto:             r.subject ??= e.es; break;
        case _Role.personaDesc:
          if (victimMode) {
            if (!r.victims.contains(e.es)) r.victims.add(e.es);
          } else if (!r.perpetrators.contains(e.es)) {
            r.perpetrators.add(e.es);
          }
          break;
        case _Role.rasgo:
          (victimMode ? r.victimTraits : r.traits).add(e.es);
          break;
        case _Role.verboAgresion:
          if (_flightVerbs.contains(t)) {
            r.flight ??= e.es;
            break;
          }
          if (r.aggression == null) {
            r.aggression = e.es;
          } else if (!r.extraAggressions.contains(e.es)) {
            r.extraAggressions.add(e.es);
          }
          break;
        case _Role.verboAccion:
          final forma = negarSiguienteVerbo
              ? 'no ${e.es}'
              : afirmarSiguienteVerbo
                  ? 'sí ${e.es}'
                  : e.es;
          negarSiguienteVerbo = false;
          afirmarSiguienteVerbo = false;
          if (r.action == null) {
            r.action = forma;
          } else if (!r.extraActions.contains(forma)) {
            r.extraActions.add(forma);
          }
          break;
        case _Role.testigo:
          r.witnessesNegated = r.witnessesNegated || negarSiguienteVerbo;
          r.witnessesAffirmed = r.witnessesAffirmed || afirmarSiguienteVerbo;
          negarSiguienteVerbo = false;
          afirmarSiguienteVerbo = false;
          if (!r.witnesses.contains(e.es)) r.witnesses.add(e.es);
          break;
        case _Role.objeto:             r.objects.add(_conDetalle(t, e.es, r)); break;
        case _Role.documento:          r.documents.add(_conDetalle(t, e.es, r)); break;
        case _Role.lugar:              r.place ??= _conDetalle(t, e.es, r); break;
        case _Role.institucion:
          if (!r.institutions.contains(e.es)) r.institutions.add(e.es);
          break;
        case _Role.servicio:           r.services.add(e.es); break;
        case _Role.emocion:            r.emotions.add(e.es); break;
        case _Role.urgencia:           r.urgencies.add(e.es); break;
        case _Role.tramite:            r.procedures.add(_conDetalle(t, e.es, r)); break;
        case _Role.motivo:             r.purposes.add(e.es); break;
        case _Role.tiempo:             r.time ??= e.es; break;
        case _Role.marcador:
          final conDetalle = _conDetalle(t, e.es, r);
          if (!r.markers.contains(conDetalle) &&
              !(conDetalle == 'tengo esa edad' &&
                  r.markers.any((m) => m.startsWith('tengo ') &&
                      m.endsWith(' años')))) {
            r.markers.add(conDetalle);
          }
          break;
        case _Role.interrogativa:      r.question ??= e.es; break;
      }
    }
    return r;
  }

  bool _hasAggressor(_Roles r) =>
      r.perpetrators.isNotEmpty || r.traits.isNotEmpty;

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

  List<String> _joinSpelled(List<String> tokens) {
    final salida = <String>[];
    var i = 0;
    while (i < tokens.length) {
      if (_esLetra(tokens[i])) {
        var j = i;
        while (j < tokens.length && _esLetra(tokens[j])) {
          j++;
        }
        if (j - i >= 2) {
          salida.add(tokens.sublist(i, j).join());
          i = j;
          continue;
        }
      }
      if (_esDigito(tokens[i])) {
        var j = i;
        while (j < tokens.length && _esDigito(tokens[j])) {
          j++;
        }
        if (j - i >= 2) {
          salida.add(tokens.sublist(i, j).join());
          i = j;
          continue;
        }
      }
      salida.add(tokens[i]);
      i++;
    }
    return salida;
  }

  static const _digitos = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  };

  static bool _esDigito(String g) => _digitos.contains(g);

  static bool _esLetra(String g) =>
      g.length == 1 && RegExp(r'^[A-ZÑ]$').hasMatch(g);

  String _asSentence(String texto) {
    if (texto.isEmpty) return texto;
    final i = texto.indexOf(RegExp(r'[a-zA-ZÀ-ÿ]'));
    final t = i < 0
        ? texto
        : texto.substring(0, i) +
            texto[i].toUpperCase() +
            texto.substring(i + 1);
    return t.endsWith('.') || t.endsWith('?') || t.endsWith('!') ? t : '$t.';
  }

  String _withWitnesses(String texto, _Roles r) {
    if (r.witnesses.isEmpty) return texto;
    final afirmacion = r.witnessesAffirmed ? 'Sí, hay' : 'Hay';
    final clausula = r.witnessesNegated
        ? 'No hay testigos'
        : r.witnesses.length == 1
            ? '$afirmacion ${r.witnesses.first}'
            : '$afirmacion testigos';
    if (r.question != null) return texto;
    final base = texto.trim();
    if (base.isEmpty) return '$clausula.';
    final sinPunto = base.endsWith('.') ? base.substring(0, base.length - 1) : base;
    return '$sinPunto. $clausula.';
  }

  String _composeQuestion(_Roles r) {
    if (r.question == null) {
      return _composeInquiry(r);
    }

    final interrogativa = r.question!;

    final personas = [
      ...r.perpetrators,
      ...r.services,
      if (r.institution != null) r.institution!,
    ];
    if (interrogativa == 'qué' || interrogativa == 'cuál') {
      if (r.procedures.isNotEmpty) return '¿Qué trámite necesito?';
      if (r.documents.isNotEmpty) {
        return _looksLikeSupportDocument(r.documents)
            ? '¿Qué soporte necesito?'
            : '¿Qué documentos necesito?';
      }
      if (r.objects.isNotEmpty) return '¿Qué necesito?';
      if (r.services.isNotEmpty) return '¿Qué apoyo necesito?';
      if (r.institution != null) return '¿Qué institución?';
      return '¿Qué necesito?';
    }

    if (interrogativa == 'dónde') {
      if (r.institution != null) {
        final complemento = r.institution!.startsWith('en ')
            ? r.institution!.substring(3)
            : r.institution!;
        return '¿Dónde está $complemento?';
      }
      if (r.place != null) {
        final complemento = r.place!.startsWith('en ')
            ? r.place!.substring(3)
            : r.place!;
        return '¿Dónde está $complemento?';
      }
      final accion = _accionDePregunta(r);
      if (accion != null) return '¿Dónde puedo $accion?';
      return '¿Dónde ocurrió?';
    }

    if (interrogativa == 'cuándo') {
      final accion = _accionDePregunta(r);
      if (accion != null) return '¿Cuándo debo $accion?';
      final citado = [...r.procedures, ...r.documents];
      if (citado.isNotEmpty) return '¿Cuándo es ${_conArticuloDefinido(citado.first)}?';
      return '¿Cuándo ocurrió?';
    }

    if (interrogativa == 'quién' || interrogativa == 'cuántos') {
      if (personas.isEmpty) {
        return '¿${_capitalizar(interrogativa)}?';
      }
      if (r.institution != null) {
        return '¿${_capitalizar(interrogativa)} es ${_whoLabelForInstitution(r.institution!)}?';
      }
      final complemento = personas.first.startsWith('en ')
          ? personas.first.substring(3)
          : personas.first;
      return '¿${_capitalizar(interrogativa)} es $complemento?';
    }

    if (interrogativa == 'para qué') {
      return '¿Para qué lo necesitas?';
    }

    if (interrogativa == 'cómo') {
      final accion = _accionDePregunta(r);
      if (accion != null) return '¿Cómo puedo $accion?';
      final tema = [...r.procedures, ...r.documents];
      if (tema.isNotEmpty) {
        final x = tema.first;
        final yaEsEstado = x.contains('avance') || x.contains('estado');
        return '¿Cómo puedo saber ${yaEsEstado ? x : 'el estado de $x'}?';
      }
      return '¿Cómo es?';
    }

    if (interrogativa == 'por qué') {
      return '¿Por qué?';
    }

    final admitidos = [...r.procedures];
    if (admitidos.isEmpty) {
      return '¿${_capitalizar(interrogativa)}?';
    }
    return '¿${_capitalizar(interrogativa)} ${admitidos.first}?';
  }

  static const _modalesDeclarativos = [
    'quiero ', 'necesito ', 'debo ', 'puedo ', 'sí quiero ', 'no quiero ',
  ];

  String? _accionDePregunta(_Roles r) {
    final verbo = r.action ?? (r.extraActions.isEmpty ? null : r.extraActions.first);
    if (verbo == null) return null;
    for (final modal in _modalesDeclarativos) {
      if (verbo.startsWith(modal)) return verbo.substring(modal.length);
    }
    return verbo;
  }

  String _conArticuloDefinido(String lexema) {
    if (lexema.startsWith('una ')) return 'la ${lexema.substring(4)}';
    if (lexema.startsWith('un ')) return 'el ${lexema.substring(3)}';
    return lexema;
  }

  String _composeInquiry(_Roles r) {
    final institution = r.institution?.replaceFirst(RegExp(r'^en\s+'), '');
    final place = r.place?.replaceFirst(RegExp(r'^en\s+'), '');
    final documents = r.documents.isNotEmpty ? _join(r.documents) : '';
    final objects = r.objects.isNotEmpty ? _join(r.objects) : '';
    final procedures = r.procedures.isNotEmpty ? _join(r.procedures) : '';
    final services = r.services.isNotEmpty ? _join(r.services) : '';
    final person = _personPhrase(r.perpetrators, r.traits);
    final victim = _hasVictim(r)
        ? _personPhrase(r.victims, r.victimTraits)
        : '';

    if (institution != null) return '¿Ante qué institución?';
    if (place != null) return '¿Dónde ocurrió?';
    if (documents.isNotEmpty) {
      return _looksLikeSupportDocument(r.documents)
          ? '¿Qué soporte necesitas?'
          : '¿Qué necesitas?';
    }
    if (objects.isNotEmpty) return '¿Qué necesitas?';
    if (procedures.isNotEmpty) return '¿Qué trámite necesitas?';
    if (services.isNotEmpty) return '¿Qué apoyo necesitas?';
    if (victim.isNotEmpty) return '¿Quién es $victim?';
    if (person != 'una persona') return '¿Quién es $person?';
    return '¿Qué quieres preguntar?';
  }

  String _whoLabelForInstitution(String institution) {
    final normalized = institution.replaceAll('en ', '').trim();
    if (normalized.contains('fiscalía')) return 'el fiscal';
    if (normalized.contains('juzgado')) return 'el juez';
    if (normalized.contains('oficial')) return 'el oficial';
    if (normalized.contains('policía')) return 'el policía';
    if (normalized.contains('autoridad')) return 'la autoridad';
    return normalized;
  }

  bool _looksLikeSupportDocument(List<String> documents) {
    const supportMarkers = ['papel', 'carpeta', 'archivador', 'hoja'];
    return documents.any((doc) {
      final normalized = _stripDiacritics(doc.toLowerCase());
      return supportMarkers.any(normalized.contains);
    });
  }

  String _capitalizar(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  String _toDestino(String institucion) {
    if (institucion.startsWith('en el ')) return 'al ${institucion.substring(6)}';
    if (institucion.startsWith('en la ')) return 'a la ${institucion.substring(6)}';
    if (institucion.startsWith('en ')) return 'a ${institucion.substring(3)}';
    return institucion;
  }

  String _composeIdentification(_Roles r) {
    final sentences = <String>[];
    final documentos = [...r.documents];
    r.documents.clear();
    for (final d in documentos) {
      sentences.add('${_cap(d)}.');
    }
    return sentences.join(' ');
  }

  String _composeIncident(String ctx, _Roles r, List<String> tokens) {
    final lead = ctx == 'violencia'
        ? 'Quiero reportar un caso de violencia.'
        : 'Quiero denunciar un robo.';

    final sentences = <String>[];

    if (r.aggression != null || _hasAggressor(r)) {
      final subject = _subjectPhrase(r);
      final defaultVerb = ctx == 'violencia' ? 'agredió' : 'asaltó';
      final verb = r.aggression ?? defaultVerb;
      var clause = '${subject.contains(',') ? '$subject,' : subject} me $verb';
      final complement = _joinConCanales([...r.objects, ...r.documents]);
      if (complement.isNotEmpty) {
        clause += ' $complement';
        r.objects.clear();
        r.documents.clear();
      }
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      final flight = r.flight;
      if (flight != null) {
        clause += ' y $flight';
        r.flight = null;
      }
      if (r.time != null) {
        clause = '${_cap(r.time!)}, ${_decap(clause)}';
        r.time = null;
      }
      sentences.add('${_cap(clause)}.');
      r.aggression = null;
      r.perpetrators.clear();
      r.traits.clear();
    } else if (r.action != null &&
        (r.objects.isNotEmpty || r.documents.isNotEmpty)) {
      const preposiciones = {'por', 'en', 'con', 'a', 'de'};
      final todos = [...r.objects, ...r.documents];
      final canales =
          todos.where((o) => preposiciones.contains(o.split(' ').first)).toList();
      final nominales = todos.where((o) => !canales.contains(o)).toList();
      r.objects.clear();
      r.documents.clear();

      final acciones = [r.action!, ...r.extraActions];
      r.action = null;
      r.extraActions.clear();
      if (canales.isNotEmpty) {
        acciones[0] = '${acciones[0]} ${_join(canales)}';
      }
      if (nominales.isNotEmpty) {
        acciones[acciones.length - 1] =
            '${acciones.last} ${_join(nominales)}';
      }
      var clause = _join(acciones);
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '${_cap(r.time!)}, ${_decap(clause)}';
        r.time = null;
      }
      sentences.add('${_cap(clause)}.');
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

  String _composeEmergency(String ctx, _Roles r, List<String> tokens) {
    final lead = ctx == 'accidente'
        ? 'Quiero reportar un accidente.'
        : 'Estoy en una emergencia y necesito ayuda.';

    final sentences = <String>[];

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

  String _composeProcedure(_Roles r, List<String> tokens) {
    const lead = 'Quiero realizar un trámite.';
    final sentences = <String>[];
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

    if (r.purposes.isNotEmpty) {
      sentences.add('Lo necesito para presentar ${_join(r.purposes)}.');
      r.purposes.clear();
    }
    if (r.subject != null && r.subject != 'yo') {
      sentences.add('El trámite es para ${r.subject}.');
      r.subject = null;
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  String _composeGuidance(_Roles r, List<String> tokens) {
    const lead = 'Necesito orientación.';
    final sentences = <String>[];

    final verboPideServicio = r.action == null ||
        const {'quiero solicitar', 'necesito ayuda'}.contains(r.action);
    if (r.services.isNotEmpty && verboPideServicio) {
      final verb = r.action != null ? _cap(r.action!) : 'Solicito';
      var clause = '$verb ${_join(r.services)}';
      if (r.institution != null) {
        clause += ' ${_join(r.institutions)}';
        r.institution = null;
      }
      sentences.add('$clause.');
      r.services.clear();
      r.action = null;
    } else if (r.action != null) {
      var clause = r.action!;
      final what = _join([...r.documents, ...r.procedures]);
      if (what.isNotEmpty) {
        clause += ' $what';
        r.documents.clear();
        r.procedures.clear();
      }
      if (r.institution != null) {
        clause += ' ${_join(r.institutions)}';
        r.institution = null;
      }
      sentences.add('${_cap(clause)}.');
      r.action = null;
    } else if (r.institution != null) {
      sentences.add('Necesito acudir ${_toDestino(r.institution!)}.');
      r.institution = null;
    }
    if (r.purposes.isNotEmpty) {
      sentences.add('Deseo presentar ${_join(r.purposes)}.');
      r.purposes.clear();
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  String _composeLoss(_Roles r, List<String> tokens) {
    const lead = 'Quiero reportar la pérdida de un objeto.';
    final sentences = <String>[];

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

  String _composeWitness(_Roles r, List<String> tokens) {
    const lead = 'Quiero declarar como testigo lo que presencié.';
    final sentences = <String>[];

    final hasActor = _hasAggressor(r);
    final subject = hasActor ? _subjectPhrase(r) : 'una persona';
    final victim = _hasVictim(r)
        ? _personPhrase(r.victims, r.victimTraits)
        : null;

    if (r.aggression != null) {
      final verb = r.aggression!;
      var clause = 'presencié cómo $subject $verb';
      final complement = _joinConCanales([...r.objects, ...r.documents]);
      if (complement.isNotEmpty) {
        clause += ' $complement';
        r.objects.clear();
        r.documents.clear();
      }
      if (victim != null) {
        clause += ' a $victim';
      } else if (complement.isEmpty) {
        clause += ' a otra persona';
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
      r.traits.clear();
      _clearVictim(r);
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
    } else if (hasActor || victim != null) {
      var clause = hasActor ? 'observé a $subject' : 'observé a $victim';
      if (hasActor && victim != null) clause += ' y a $victim';
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
      r.traits.clear();
      _clearVictim(r);
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  bool _hasVictim(_Roles r) =>
      r.victims.isNotEmpty || r.victimTraits.isNotEmpty;

  void _clearVictim(_Roles r) {
    r.victims.clear();
    r.victimTraits.clear();
  }

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
        clause += ' ${_join(r.institutions)}';
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
        clause += ' ${_join(r.institutions)}';
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

  void _supplements(_Roles r, List<String> sentences) {
    if (r.aggression != null || _hasAggressor(r)) {
      final hasActor = _hasAggressor(r);
      final subject = hasActor ? _subjectPhrase(r) : 'una persona';
      if (r.aggression != null) {
            final verb = r.aggression!;
        var clause = '${subject.contains(',') ? '$subject,' : subject} me $verb';
        final comp = _join([...r.objects, ...r.documents]);
        if (comp.isNotEmpty) {
          clause += ' $comp';
          r.objects.clear();
          r.documents.clear();
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
        sentences.add('La persona involucrada era ${_decap(subject)}.');
      }
      r.aggression = null;
      r.perpetrators.clear();
      r.traits.clear();
    }

    final things = _join([...r.objects, ...r.documents]);
    if (things.isNotEmpty) {
      sentences.add('Necesito $things.');
      r.objects.clear();
      r.documents.clear();
    }

    if (r.action != null) {
      var clause = r.action!;
      if (r.procedures.isNotEmpty) {
        clause += ' ${_join(r.procedures)}';
        r.procedures.clear();
      }
      sentences.add('${_cap(clause)}.');
      r.action = null;
    }

    if (r.purposes.isNotEmpty) {
      sentences.add('Lo requiero para presentar ${_join(r.purposes)}.');
      r.purposes.clear();
    }
    if (r.procedures.isNotEmpty) {
      sentences.add('Solicito ${_join(r.procedures)}.');
      r.procedures.clear();
    }

    if (r.extraAggressions.isNotEmpty) {
      sentences.add('Además me ${_join(r.extraAggressions)}.');
      r.extraAggressions.clear();
    }
    if (r.extraActions.isNotEmpty) {
      sentences.add('${_cap(_join(r.extraActions))}.');
      r.extraActions.clear();
    }
    if (r.frequency != null) {
      sentences.add('${r.frequency}.');
      r.frequency = null;
    }
    if (r.vehicles.isNotEmpty) {
      sentences.add(r.vehicles.length == 1
          ? 'El vehículo involucrado fue ${r.vehicles.single}.'
          : 'Los vehículos involucrados fueron ${_join(r.vehicles)}.');
      r.vehicles.clear();
    }
    if (r.evidence.isNotEmpty) {
      sentences.add('Como prueba tengo ${_join(r.evidence)}.');
      r.evidence.clear();
    }
    final flight = r.flight;
    if (flight != null) {
      sentences.add('${_cap(flight)}.');
      r.flight = null;
    }

    if (r.time != null && r.timeIsFuture) {
      sentences.add('Lo necesito ${r.time}.');
      r.time = null;
    }
    if (r.time != null && !r.timeIsFuture && r.place == null) {
      sentences.add('Fue ${r.time}.');
      r.time = null;
    }
    if (r.place != null || r.time != null) {
      final narra = r.narrativeIsPast;
      var clause = narra ? 'Ocurrió' : 'Debo acudir';
      if (r.place != null) {
        clause += ' ${narra ? r.place : _toDestino(r.place!)}';
        r.place = null;
      }
      if (r.time != null) {
        clause += ' ${r.time}';
        r.time = null;
      }
      sentences.add('$clause.');
    }

    final affected = _affectedSubjectLine(r);
    if (affected != null) {
      sentences.add(affected);
      r.subject = null;
    }

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

    if (r.institution != null) {
      sentences.add('Realizaré esta gestión ${r.institution}.');
      r.institution = null;
    }

    if (r.unknown.isNotEmpty) {
      sentences.add('Adicionalmente, hago referencia a ${_join(r.unknown)}.');
      r.unknown.clear();
    }
  }

  String _subjectPhrase(_Roles r) =>
      _personPhrase(r.perpetrators, r.traits);

  String _personPhrase(List<String> persons, List<String> traits) {
    String base;
    {
      if (persons.isNotEmpty) {
        final relacionales = persons.where((p) => p.startsWith('mi ')).toList();
        if (relacionales.isNotEmpty) {
          final otros = persons.where((p) => !p.startsWith('mi ')).toList();
          base = otros.isEmpty
              ? _join(relacionales)
              : '${_join(relacionales)}, ${otros.join(', ')}';
        } else {
          final parts = <String>[];
          for (var i = 0; i < persons.length; i++) {
            var p = persons[i];
            if (i > 0) {
              p = p.replaceFirst(RegExp(r'^un\s+'), '').replaceFirst(RegExp(r'^una\s+'), '');
            }
            parts.add(p);
          }
          base = parts.join(' ');
        }
      } else {
        base = 'una persona';
      }
    }

    final isFeminine = base.startsWith('una ');
    if (traits.isEmpty) return base;

    var adjectives = traits
        .where((t) => !t.startsWith('con ') && !t.startsWith('de '))
        .toList();
    final phrases = traits
        .where((t) => t.startsWith('con ') || t.startsWith('de '))
        .toList();

    if (isFeminine) {
      adjectives = adjectives.map(_femAdj).toList();
    }

    final buffer = StringBuffer(base);
    if (adjectives.isNotEmpty) buffer.write(' ${_join(adjectives)}');
    if (phrases.isNotEmpty) {
      final items = phrases.map((p) {
        if (p.startsWith('con ')) return p.substring(4);
        if (p.startsWith('de ')) return p.substring(3);
        return p;
      }).toList();
      buffer.write(', con ${_join(items)}');
    }
    return buffer.toString();
  }

  static String _femAdj(String adj) {
    if (adj.startsWith('de piel') || adj.startsWith('de cabello')) return adj;
    if (adj.endsWith('o')) return '${adj.substring(0, adj.length - 1)}a';
    return adj;
  }

  String? _affectedSubjectLine(_Roles r) =>
      (r.subject == null || r.subject == 'yo')
          ? null
          : 'El hecho también afectó a ${r.subject}.';

  String _stitch(String lead, List<String> sentences, List<String> tokens) {
    final body = sentences.where((s) => s.trim().isNotEmpty).toList();
    if (body.isEmpty) return lead;
    return '$lead ${body.join(' ')}';
  }

  String _joinConCanales(List<String> items) {
    const preposiciones = {'por', 'en', 'con', 'a', 'de'};
    bool esCanal(String s) => preposiciones.contains(s.split(' ').first);
    final nominales = items.where((s) => !esCanal(s)).toList();
    final canales = items.where(esCanal).toList();
    final texto = _join(nominales);
    if (canales.isEmpty) return texto;
    return texto.isEmpty ? _join(canales) : '$texto ${_join(canales)}';
  }

  String _join(List<String> items) {
    final clean = items.where((s) => s.trim().isNotEmpty).toList();
    if (clean.isEmpty) return '';
    if (clean.length == 1) return clean.first;
    if (clean.length == 2) return '${clean[0]} y ${clean[1]}';
    return '${clean.sublist(0, clean.length - 1).join(', ')} y ${clean.last}';
  }

  /// Forma canonica de una glosa para buscarla en [_lexicon].
  ///
  /// Se quitan las tildes pero se conserva la N con virgulilla: las claves del
  /// lexico van sin acentuar, asi que una glosa acentuada llegada del
  /// diccionario remoto no encontraba su entrada y caia al placeholder, pero
  /// la N con virgulilla es una letra del alfabeto dactilologico y colapsarla
  /// en N confundiria dos senas distintas.
  String _normalize(String g) => _stripGlossAccents(g.trim().toUpperCase());

  static String _stripGlossAccents(String input) {
    const from = 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛ';
    const to = 'AAAAEEEEIIIIOOOOUUUU';
    var out = input;
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

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

  static const Map<String, _Lex> _lexicon = {
    'GRACIAS': _Lex(_Role.marcador, 'gracias'),
    'HOLA': _Lex(_Role.marcador, 'hola'),
    'PERMISO': _Lex(_Role.marcador, 'con permiso'),
    'POR_FAVOR': _Lex(_Role.marcador, 'por favor'),
    'LO_SIENTO': _Lex(_Role.marcador, 'lo siento'),

    'ESTOY_BIEN': _Lex(_Role.marcador, 'estoy bien'),
    'NO': _Lex(_Role.marcador, 'no'),
    'NO_PUEDO': _Lex(_Role.marcador, 'no puedo'),
    'NO_SABER': _Lex(_Role.marcador, 'no sé'),
    'PUEDO': _Lex(_Role.marcador, 'sí puedo'),
    'SABER': _Lex(_Role.marcador, 'sí sé'),
    'SI': _Lex(_Role.marcador, 'sí'),
    'MAS_O_MENOS': _Lex(_Role.marcador, 'más o menos'),
    'NO_RECUERDO': _Lex(_Role.marcador, 'no recuerdo'),
    'NO_ENTIENDO': _Lex(_Role.marcador, 'no entiendo'),
    'PUEDE_REPETIR': _Lex(_Role.marcador, '¿puede repetir?'),

    'COMO': _Lex(_Role.interrogativa, 'cómo'),
    'CUAL': _Lex(_Role.interrogativa, 'cuál'),
    'CUANDO': _Lex(_Role.interrogativa, 'cuándo'),
    'DONDE': _Lex(_Role.interrogativa, 'dónde'),
    'EL': _Lex(_Role.sujeto, 'él'),
    'ELLA': _Lex(_Role.sujeto, 'ella'),
    'POR_QUE': _Lex(_Role.interrogativa, 'por qué'),
    'QUE': _Lex(_Role.interrogativa, 'qué'),
    'QUIEN': _Lex(_Role.interrogativa, 'quién'),
    'TU': _Lex(_Role.sujeto, 'tú'),
    'YO': _Lex(_Role.sujeto, 'yo'),
    'CUANTOS': _Lex(_Role.interrogativa, 'cuántos'),
    'ELLOS': _Lex(_Role.sujeto, 'ellos'),
    'NOSOTROS': _Lex(_Role.sujeto, 'nosotros'),
    'PARA_QUE': _Lex(_Role.interrogativa, 'para qué'),
    'USTEDES': _Lex(_Role.sujeto, 'ustedes'),

    'NOMBRE': _Lex(_Role.marcador, 'mi nombre es'),
    'APELLIDO': _Lex(_Role.marcador, 'mi apellido es'),
    'IDENTIDAD': _Lex(_Role.marcador, 'quiero identificarme'),
    'EDAD': _Lex(_Role.marcador, 'tengo esa edad'),
    'ANOS_EDAD': _Lex(_Role.marcador, 'tengo esa edad'),
    'HOMBRE': _Lex(_Role.personaDesc, 'un hombre'),
    'LADRON': _Lex(_Role.personaDesc, 'un ladrón'),
    'MUJER': _Lex(_Role.personaDesc, 'una mujer'),
    'TESTIGO': _Lex(_Role.testigo, 'un testigo'),
    'VECINO': _Lex(_Role.personaDesc, 'un vecino'),
    'MILITAR': _Lex(_Role.personaDesc, 'un militar'),
    'SOLDADO': _Lex(_Role.personaDesc, 'un soldado'),
    'FAMILIAR': _Lex(_Role.personaDesc, 'un familiar'),
    'PAREJA': _Lex(_Role.personaDesc, 'mi pareja'),
    'EXPAREJA': _Lex(_Role.personaDesc, 'mi expareja'),

    'ABOGADO': _Lex(_Role.servicio, 'un abogado'),
    'AUTORIDAD': _Lex(_Role.institucion, 'en la autoridad'),
    'FISCAL': _Lex(_Role.institucion, 'en la fiscalía'),
    'FISCALIA': _Lex(_Role.institucion, 'en la Fiscalía'),
    'FELCC': _Lex(_Role.institucion, 'en la FELCC'),
    'FELCV': _Lex(_Role.institucion, 'en la FELCV'),
    'TRIBUNAL': _Lex(_Role.institucion, 'en el tribunal'),
    'JUZGADO': _Lex(_Role.institucion, 'en el juzgado de instrucción penal'),
    'SEPAV': _Lex(_Role.institucion, 'en el SEPAV'),
    'DEFENSA_PUBLICA': _Lex(_Role.institucion, 'en la Defensa Pública'),
    'INSTITUCION': _Lex(_Role.institucion, 'en la institución'),
    'INTERPRETE': _Lex(_Role.servicio, 'un intérprete de señas'),
    'JUEZ': _Lex(_Role.institucion, 'en el juzgado'),
    'OFICIAL': _Lex(_Role.institucion, 'en el oficial'),
    'ORGANO_JUDICIAL': _Lex(_Role.institucion, 'en el órgano judicial'),
    'POLICIA': _Lex(_Role.institucion, 'en la policía'),
    'ASISTENTE': _Lex(_Role.servicio, 'un asistente'),
    'COORDINADOR': _Lex(_Role.servicio, 'un coordinador'),
    'DOCTOR': _Lex(_Role.servicio, 'un doctor'),
    'ENFERMERA': _Lex(_Role.servicio, 'una enfermera'),
    'MINISTERIO': _Lex(_Role.institucion, 'en el ministerio'),
    'ALCALDIA': _Lex(_Role.institucion, 'en la alcaldía'),
    'DESPACHO': _Lex(_Role.institucion, 'en el despacho'),
    'OFICINA': _Lex(_Role.institucion, 'en la oficina'),
    'VENTANILLA': _Lex(_Role.institucion, 'en la ventanilla'),

    'INVESTIGACION': _Lex(_Role.tramite, 'una investigación'),
    'JUICIO': _Lex(_Role.tramite, 'un juicio'),
    'JUSTICIA': _Lex(_Role.documento, 'la justicia'),
    'LEY': _Lex(_Role.documento, 'la ley'),
    'RESOLUCION': _Lex(_Role.documento, 'la resolución'),
    'TESTIMONIO': _Lex(_Role.documento, 'mi testimonio'),
    'TRAMITE': _Lex(_Role.tramite, 'un trámite'),
    'ACUERDO_SOCIAL': _Lex(_Role.documento, 'un acuerdo'),
    'ARTICULO': _Lex(_Role.documento, 'el artículo'),
    'CONFIRMACION': _Lex(_Role.documento, 'la confirmación'),
    'CONTEXTO': _Lex(_Role.documento, 'el contexto'),
    'ESTADO': _Lex(_Role.documento, 'el estado del trámite'),
    'NORMA': _Lex(_Role.documento, 'la norma'),
    'PODER': _Lex(_Role.documento, 'un poder notarial'),
    'REGLAMENTO': _Lex(_Role.documento, 'el reglamento'),
    'EXPEDIENTE': _Lex(_Role.tramite, 'mi expediente'),
    'NOTIFICACION': _Lex(_Role.tramite, 'una notificación'),
    'CITACION': _Lex(_Role.tramite, 'una citación'),
    'AUDIENCIA': _Lex(_Role.tramite, 'una audiencia'),
    'AVANCE': _Lex(_Role.tramite, 'el avance de la investigación'),
    'SUBSANACION': _Lex(_Role.tramite, 'una subsanación'),
    'REQUISITO': _Lex(_Role.tramite, 'un requisito'),
    'CODIGO': _Lex(_Role.tramite, 'el código'),
    'CASO': _Lex(_Role.tramite, 'mi caso'),
    'NUREJ': _Lex(_Role.tramite, 'mi NUREJ'),
    'WEBID': _Lex(_Role.tramite, 'mi WebID'),

    'ANOTAR': _Lex(_Role.verboAccion, 'quiero anotar'),
    'AVISAR': _Lex(_Role.verboAccion, 'quiero avisar'),
    'ESCRIBIR': _Lex(_Role.verboAccion, 'quiero escribir'),
    'IDENTIFICAR': _Lex(_Role.verboAccion, 'quiero identificar'),
    'MOSTRAR': _Lex(_Role.verboAccion, 'quiero mostrar'),
    'NARRAR': _Lex(_Role.verboAccion, 'quiero narrar'),
    'OBSERVAR': _Lex(_Role.verboAccion, 'quiero observar'),
    'PEDIR': _Lex(_Role.verboAccion, 'quiero solicitar'),
    'PAGAR': _Lex(_Role.verboAccion, 'pagué'),
    'ENTREGAR': _Lex(_Role.verboAccion, 'me entregaron'),
    'PERDER': _Lex(_Role.verboAccion, 'perdí'),
    'PRESENTAR': _Lex(_Role.verboAccion, 'quiero presentar'),
    'PROTEGER': _Lex(_Role.verboAccion, 'necesito protección'),
    'QUEJAR': _Lex(_Role.verboAccion, 'quiero presentar una queja'),
    'RECONOCER': _Lex(_Role.verboAccion, 'quiero reconocer'),
    'ACOMPANAR': _Lex(_Role.verboAccion, 'necesito que me acompañen'),
    'CONFESAR': _Lex(_Role.verboAccion, 'quiero confesar'),
    'COORDINAR': _Lex(_Role.verboAccion, 'quiero coordinar'),
    'COPIAR': _Lex(_Role.verboAccion, 'quiero copiar'),
    'CUMPLIR': _Lex(_Role.verboAccion, 'quiero cumplir'),
    'DECIDIR': _Lex(_Role.verboAccion, 'quiero decidir'),
    'EXIGIR': _Lex(_Role.verboAccion, 'quiero exigir'),
    'GESTIONAR': _Lex(_Role.verboAccion, 'quiero gestionar'),
    'JURAR': _Lex(_Role.verboAccion, 'quiero jurar'),
    'RECOGER': _Lex(_Role.verboAccion, 'quiero recoger'),
    'SOLUCIONAR': _Lex(_Role.verboAccion, 'quiero solucionar'),
    'TRATAR': _Lex(_Role.verboAccion, 'quiero tratar'),
    'SEGUIMIENTO': _Lex(_Role.verboAccion, 'quiero seguir'),
    'CORREGIR': _Lex(_Role.verboAccion, 'quiero corregir'),
    'ACLARAR': _Lex(_Role.verboAccion, 'quiero aclarar'),
    'RECORDAR': _Lex(_Role.verboAccion, 'recuerdo'),
    'IMPRIMIR': _Lex(_Role.verboAccion, 'quiero imprimir'),
    'CONOCER': _Lex(_Role.verboAccion, 'conozco a esa persona'),
    'DESCONOCER': _Lex(_Role.verboAccion, 'no conozco a esa persona'),
    'DENUNCIAR': _Lex(_Role.verboAccion, 'quiero presentar una denuncia'),
    'VOLVER': _Lex(_Role.verboAccion, 'debo volver'),

    'ABUSAR': _Lex(_Role.verboAgresion, 'abusó sexualmente'),
    'ACCIDENTE': _Lex(_Role.urgencia, 'hubo un accidente'),
    'AMENAZAR': _Lex(_Role.verboAgresion, 'amenazó'),
    'ARRESTAR': _Lex(_Role.verboAgresion, 'arrestó'),
    'ASISTENCIA': _Lex(_Role.urgencia, 'necesito asistencia'),
    'AUXILIO': _Lex(_Role.urgencia, 'necesito auxilio'),
    'DANAR': _Lex(_Role.verboAgresion, 'dañó'),
    'DISCRIMINACION': _Lex(_Role.verboAgresion, 'discriminó'),
    'MALTRATAR': _Lex(_Role.verboAgresion, 'maltrató'),
    'PARAR': _Lex(_Role.verboAgresion, 'se detuvo'),
    'ROBAR': _Lex(_Role.verboAgresion, 'robó'),
    'SALVAR': _Lex(_Role.verboAgresion, 'me salvó'),
    'VIOLENCIA': _Lex(_Role.verboAgresion, 'ejerció violencia'),
    'CORRER': _Lex(_Role.verboAgresion, 'salió corriendo'),
    'CRISIS': _Lex(_Role.urgencia, 'es una crisis'),
    'HERIDA': _Lex(_Role.urgencia, 'tengo una herida'),
    'SOBORNO': _Lex(_Role.verboAgresion, 'ofreció un soborno'),
    'VIOLACION': _Lex(_Role.verboAgresion, 'violó'),

    'CORRECTO': _Lex(_Role.rasgo, 'correcto'),
    'PELIGROSO': _Lex(_Role.rasgo, 'peligroso'),
    'SEGURO': _Lex(_Role.emocion, 'me encuentro en un lugar seguro'),
    'AMARILLO': _Lex(_Role.rasgo, 'de color amarillo'),
    'AZUL': _Lex(_Role.rasgo, 'de color azul'),
    'BLANCO': _Lex(_Role.rasgo, 'de color blanco'),
    'CAFE': _Lex(_Role.rasgo, 'de color café'),
    'DELGADO': _Lex(_Role.rasgo, 'delgado'),
    'INOCENTE': _Lex(_Role.rasgo, 'inocente'),
    'NEGRO': _Lex(_Role.rasgo, 'de color negro'),
    'PRESO': _Lex(_Role.rasgo, 'detenido'),
    'ROJO': _Lex(_Role.rasgo, 'de color rojo'),
    'VERDE': _Lex(_Role.rasgo, 'de color verde'),
    'CELESTE': _Lex(_Role.rasgo, 'de color celeste'),
    'GRUESO': _Lex(_Role.rasgo, 'grueso'),
    'LILA': _Lex(_Role.rasgo, 'de color lila'),
    'NARANJA': _Lex(_Role.rasgo, 'de color naranja'),
    'ROSADO': _Lex(_Role.rasgo, 'de color rosado'),

    'CONFUSION': _Lex(_Role.emocion, 'estoy confundido'),
    'MAL': _Lex(_Role.emocion, 'me siento mal'),
    'PROBLEMA': _Lex(_Role.motivo, 'por un problema'),
    'SITUACION': _Lex(_Role.motivo, 'por esta situación'),
    'TEMOR': _Lex(_Role.emocion, 'siento temor'),
    'CONFIANZA': _Lex(_Role.emocion, 'tengo confianza'),
    'FALTA': _Lex(_Role.motivo, 'por una falta'),
    'RAZON': _Lex(_Role.motivo, 'por esa razón'),
    'VERGUENZA': _Lex(_Role.emocion, 'siento vergüenza'),
    'MIEDO': _Lex(_Role.emocion, 'tengo miedo'),
    'SOSPECHA': _Lex(_Role.emocion, 'tengo una sospecha'),

    'AHORA': _Lex(_Role.tiempo, 'ahora mismo'),
    'AYER': _Lex(_Role.tiempo, 'ayer'),
    'DIA': _Lex(_Role.tiempo, 'ese día'),
    'FECHA': _Lex(_Role.tiempo, 'en esa fecha'),
    'HORA': _Lex(_Role.tiempo, 'hace una hora'),
    'HOY': _Lex(_Role.tiempo, 'hoy'),
    'MANANA': _Lex(_Role.tiempo, 'mañana'),
    'MINUTO': _Lex(_Role.tiempo, 'hace unos minutos'),
    'ANO': _Lex(_Role.tiempo, 'este año'),
    'ANTEAYER': _Lex(_Role.tiempo, 'anteayer'),
    'MES': _Lex(_Role.tiempo, 'este mes'),
    'SEGUNDO': _Lex(_Role.tiempo, 'hace un segundo'),
    'SEMANA': _Lex(_Role.tiempo, 'esta semana'),
    'PASADO_MANANA': _Lex(_Role.tiempo, 'pasado mañana'),
    'VARIAS_VECES': _Lex(_Role.tiempo, 'varias veces'),
    'ANTERIORMENTE': _Lex(_Role.tiempo, 'anteriormente'),
    'PRIMERA_VEZ': _Lex(_Role.tiempo, 'es la primera vez'),

    'CALLE': _Lex(_Role.lugar, 'en la calle'),
    'CASA': _Lex(_Role.lugar, 'en mi casa'),
    'DIRECCION': _Lex(_Role.lugar, 'en esa dirección'),
    'HOSPITAL': _Lex(_Role.lugar, 'en el hospital'),
    'AVENIDA': _Lex(_Role.lugar, 'en la avenida'),
    'CARCEL': _Lex(_Role.lugar, 'en la cárcel'),
    'COCHABAMBA': _Lex(_Role.lugar, 'en Cochabamba'),
    'FARMACIA': _Lex(_Role.lugar, 'en la farmacia'),
    'MERCADO': _Lex(_Role.lugar, 'en el mercado'),
    'PLAZA': _Lex(_Role.lugar, 'en la plaza'),
    'UBICACION_GPS': _Lex(_Role.lugar, 'en esta ubicación'),
    'AEROPUERTO': _Lex(_Role.lugar, 'en el aeropuerto'),
    'CENTRO_DE_SALUD': _Lex(_Role.lugar, 'en el centro de salud'),
    'PARADA': _Lex(_Role.lugar, 'en la parada'),
    'PISO': _Lex(_Role.lugar, 'en el piso'),
    'DEPARTAMENTO': _Lex(_Role.lugar, 'en el departamento'),

    'DINERO': _Lex(_Role.objeto, 'mi dinero'),
    'FORMULARIO': _Lex(_Role.documento, 'el formulario'),
    'LICENCIA_DECONDUCIR': _Lex(_Role.documento, 'mi licencia de conducir'),
    'MOCHILA': _Lex(_Role.objeto, 'mi mochila'),
    'PAPEL': _Lex(_Role.documento, 'el papel'),
    'TELEFONO': _Lex(_Role.objeto, 'mi teléfono'),
    'TEXTO': _Lex(_Role.documento, 'el texto'),
    'CARNET': _Lex(_Role.documento, 'mi carnet de identidad'),
    'CARTA': _Lex(_Role.documento, 'la carta'),
    'FOTOCOPIA': _Lex(_Role.documento, 'una fotocopia'),
    'LICENCIA': _Lex(_Role.documento, 'mi licencia'),
    'PASAPORTE': _Lex(_Role.documento, 'mi pasaporte'),
    'SELLO': _Lex(_Role.documento, 'el sello'),
    'TITULO': _Lex(_Role.documento, 'mi título'),
    'CONSTANCIA': _Lex(_Role.documento, 'una constancia'),
    'MEMORIAL': _Lex(_Role.documento, 'un memorial'),
    'COMPROBANTE': _Lex(_Role.documento, 'un comprobante'),
    'CERTIFICADO': _Lex(_Role.documento, 'un certificado'),
    'OBSERVACION': _Lex(_Role.documento, 'una observación'),
    'ANEXO': _Lex(_Role.documento, 'un anexo'),
    'HOJA': _Lex(_Role.documento, 'una hoja'),
    'FORMATO': _Lex(_Role.documento, 'el formato'),
    'RESPALDO': _Lex(_Role.documento, 'un respaldo'),

    'AUTO': _Lex(_Role.objeto, 'mi auto'),
    'MICRO': _Lex(_Role.objeto, 'el micro'),
    'MOTOCICLETA': _Lex(_Role.objeto, 'mi motocicleta'),
    'TAXI': _Lex(_Role.objeto, 'el taxi'),
    'TRUFI': _Lex(_Role.objeto, 'el trufi'),
    'BICICLETA': _Lex(_Role.objeto, 'mi bicicleta'),
    'TREN': _Lex(_Role.objeto, 'el tren'),

    'BILLETERA': _Lex(_Role.objeto, 'mi billetera'),
    'MENSAJE': _Lex(_Role.objeto, 'un mensaje'),
    'FOTOGRAFIA': _Lex(_Role.objeto, 'una fotografía'),
    'CAMARA': _Lex(_Role.objeto, 'una cámara'),
    'CUENTA': _Lex(_Role.objeto, 'mi cuenta'),
    'PRODUCTO': _Lex(_Role.objeto, 'el producto'),

    'ACEPTAR': _Lex(_Role.verboAccion, 'acepto'),
    'ATENDER': _Lex(_Role.verboAccion, 'necesito que me atiendan'),
    'AYUDAR': _Lex(_Role.verboAccion, 'necesito ayuda'),
    'COMPRENDER': _Lex(_Role.verboAccion, 'quiero comprender'),
    'HABLAR': _Lex(_Role.verboAccion, 'quiero hablar'),
    'RECHAZAR': _Lex(_Role.verboAccion, 'rechazo'),
    'RESPONDER': _Lex(_Role.verboAccion, 'quiero responder'),

    'VIDEOLLAMADA': _Lex(_Role.objeto, 'por videollamada'),
    'WHATSAPP': _Lex(_Role.objeto, 'por WhatsApp'),

    'CORRUPTO': _Lex(_Role.rasgo, 'corrupto'),
  };
}

enum _Role {
  sujeto,
  personaDesc,

  testigo,

  rasgo,
  verboAgresion,
  verboAccion,
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
  marcador,

  interrogativa,
}

class _Lex {
  final _Role role;
  final String es;
  const _Lex(this.role, this.es);
}

class _Roles {
  String? subject;
  final List<String> perpetrators = [];
  final List<String> victims = [];
  final List<String> victimTraits = [];
  final List<String> institutions = [];

  String? get institution => institutions.isEmpty ? null : institutions.first;

  set institution(String? v) {
    institutions.clear();
    if (v != null) institutions.add(v);
  }

  String? aggression;

  String? flight;

  final Map<String, String> details = {};

  final List<String> extraActions = [];
  String? action;
  String? place;
  String? time;

  String? timeUnit;
  String? timeCount;

  bool timeIsFuture = false;

  bool narrativeIsPast = true;

  String? frequency;

  final List<String> evidence = [];
  final List<String> vehicles = [];
  final List<String> extraAggressions = [];
  final List<String> traits = [];
  final List<String> objects = [];
  final List<String> documents = [];
  final List<String> services = [];
  final List<String> emotions = [];
  final List<String> urgencies = [];
  final List<String> procedures = [];
  final List<String> purposes = [];
  final List<String> unknown = [];
  final List<String> witnesses = [];
  bool witnessesNegated = false;
  bool witnessesAffirmed = false;

  final List<String> markers = [];

  String? question;
}
