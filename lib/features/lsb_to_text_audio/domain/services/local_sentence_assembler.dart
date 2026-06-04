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

    switch (contextId) {
      case 'denuncia_robo':
      case 'violencia':
        return _composeIncident(contextId, roles, tokens);
      case 'accidente':
      case 'emergencia':
        return _composeEmergency(contextId, roles, tokens);
      case 'tramite_id':
        return _composeProcedure(roles, tokens);
      case 'orientacion':
        return _composeGuidance(roles, tokens);
      case 'perdida':
        return _composeLoss(roles, tokens);
      case 'otro':
      default:
        return _composeGeneric(contextId, roles, tokens);
    }
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

    final haystack = _stripDiacritics(trimmed.toLowerCase());
    var hits = 0;
    for (final g in glosses) {
      if (_glossCovered(g, haystack)) hits++;
    }
    final coverage = hits / glosses.length;
    return coverage < 0.5;
  }

  /// `true` si alguna raíz significativa de la glosa aparece en el texto.
  bool _glossCovered(String gloss, String haystackLower) {
    final parts = _stripDiacritics(gloss.toLowerCase())
        .split(RegExp(r'[ _/]+'))
        .where((p) => p.length >= 3); // ignora partículas cortas (de, la…)
    for (final p in parts) {
      final stem = p.length <= 4 ? p : p.substring(0, 4);
      if (haystackLower.contains(stem)) return true;
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
        case _Role.sujeto:        r.subject ??= e.es; break;
        case _Role.personaDesc:   r.perpetrator ??= e.es; break;
        case _Role.rasgo:         r.traits.add(e.es); break;
        case _Role.verboAgresion: r.aggression ??= e.es; break;
        case _Role.verboAccion:   r.action ??= e.es; break;
        case _Role.arma:          r.weapon ??= e.es; break;
        case _Role.objeto:        r.objects.add(e.es); break;
        case _Role.documento:     r.documents.add(e.es); break;
        case _Role.lugar:         r.place ??= e.es; break;
        case _Role.institucion:   r.institution ??= e.es; break;
        case _Role.servicio:      r.services.add(e.es); break;
        case _Role.emocion:       r.emotions.add(e.es); break;
        case _Role.urgencia:      r.urgencies.add(e.es); break;
        case _Role.tramite:       r.procedures.add(e.es); break;
        case _Role.tiempo:        r.time ??= e.es; break;
      }
    }
    return r;
  }

  // ───────────────────────── Compositores por contexto ────────────────────

  /// denuncia_robo / violencia → relato de incidente con agresor.
  String _composeIncident(String ctx, _Roles r, List<String> tokens) {
    final lead = ctx == 'violencia'
        ? 'Quiero reportar un caso de violencia.'
        : 'Quiero denunciar un robo.';

    final sentences = <String>[];

    // Cláusula del agresor + acción.
    final hasActor = r.perpetrator != null || r.traits.isNotEmpty;
    if (r.aggression != null || hasActor) {
      final subject = _subjectPhrase(r);
      final verb = r.aggression ?? (ctx == 'violencia' ? 'agredió' : 'asaltó');
      var clause = '$subject me $verb';
      final complement = _join([...r.objects, ...r.documents]);
      if (complement.isNotEmpty) clause += ' $complement';
      if (r.weapon != null) clause += ' ${r.weapon}';
      if (r.place != null) clause += ' ${r.place}';
      if (r.time != null) clause = '${_cap(r.time!)}, ${_decap(clause)}';
      sentences.add('${_cap(clause)}.');
    } else if (r.objects.isNotEmpty || r.documents.isNotEmpty) {
      final what = _join([...r.objects, ...r.documents]);
      var clause = 'Me quitaron $what';
      if (r.place != null) clause += ' ${r.place}';
      if (r.time != null) clause += ' ${r.time}';
      sentences.add('$clause.');
    }

    sentences.addAll(_stateSentences(r));
    if (r.unknown.isNotEmpty) {
      sentences.add('También menciono: ${_join(r.unknown)}.');
    }
    return _stitch(lead, sentences, tokens);
  }

  /// accidente / emergencia → estado personal + ayuda requerida.
  String _composeEmergency(String ctx, _Roles r, List<String> tokens) {
    final lead = ctx == 'accidente'
        ? 'Quiero reportar un accidente.'
        : 'Estoy en una emergencia y necesito ayuda.';

    final sentences = <String>[];

    final state = _join(r.emotions);
    if (state.isNotEmpty) {
      var clause = state;
      if (r.place != null) clause += ' ${r.place}';
      sentences.add('${_cap(clause)}.');
    }

    if (r.services.isNotEmpty) {
      sentences.add('Necesito ${_join(r.services)}.');
    }
    if (r.urgencies.isNotEmpty) {
      sentences.add('${_cap(_join(r.urgencies))}.');
    }
    if (r.perpetrator != null && state.isEmpty) {
      sentences.add('${_cap(_subjectPhrase(r))} necesita ayuda.');
    }
    if (r.unknown.isNotEmpty) {
      sentences.add('Detalles: ${_join(r.unknown)}.');
    }
    return _stitch(lead, sentences, tokens);
  }

  /// tramite_id → solicitud administrativa.
  String _composeProcedure(_Roles r, List<String> tokens) {
    const lead = 'Quiero realizar un trámite.';
    final sentences = <String>[];

    final verb = r.action ?? 'necesito tramitar';
    final what = _join([...r.documents, ...r.procedures]);
    var clause = verb;
    if (what.isNotEmpty) clause += ' $what';
    if (r.institution != null) clause += ' ${r.institution}';
    sentences.add('${_cap(clause)}.');

    if (r.subject != null && r.subject != 'yo') {
      sentences.add('El trámite es para ${r.subject}.');
    }
    if (r.unknown.isNotEmpty) {
      sentences.add('Detalles: ${_join(r.unknown)}.');
    }
    return _stitch(lead, sentences, tokens);
  }

  /// orientacion → consulta / pedido de orientación.
  String _composeGuidance(_Roles r, List<String> tokens) {
    const lead = 'Necesito orientación.';
    final sentences = <String>[];

    if (r.services.isNotEmpty) {
      var clause = 'Solicito ${_join(r.services)}';
      if (r.institution != null) clause += ' ${r.institution}';
      sentences.add('$clause.');
    } else if (r.action != null) {
      var clause = r.action!;
      if (r.procedures.isNotEmpty) clause += ' ${_join(r.procedures)}';
      if (r.institution != null) clause += ' ${r.institution}';
      sentences.add('${_cap(clause)}.');
    } else if (r.institution != null) {
      sentences.add('Necesito acudir ${r.institution}.');
    }
    if (r.unknown.isNotEmpty) {
      sentences.add('Consulto sobre: ${_join(r.unknown)}.');
    }
    return _stitch(lead, sentences, tokens);
  }

  /// perdida → reporte de extravío.
  String _composeLoss(_Roles r, List<String> tokens) {
    const lead = 'Quiero reportar la pérdida de un objeto.';
    final sentences = <String>[];

    final what = _join([...r.objects, ...r.documents]);
    if (what.isNotEmpty) {
      var clause = 'Perdí $what';
      if (r.place != null) clause += ' ${r.place}';
      if (r.time != null) clause += ' ${r.time}';
      sentences.add('$clause.');
    }
    if (r.services.isNotEmpty) {
      sentences.add('Necesito ${_join(r.services)}.');
    }
    if (r.unknown.isNotEmpty) {
      sentences.add('Detalles: ${_join(r.unknown)}.');
    }
    return _stitch(lead, sentences, tokens);
  }

  /// otro / fallback → ensamblaje genérico fiel a los roles detectados.
  String _composeGeneric(String ctx, _Roles r, List<String> tokens) {
    const lead = 'Quiero comunicar lo siguiente.';
    final sentences = <String>[];

    final verb = r.action;
    final what = _join([...r.documents, ...r.procedures, ...r.objects]);
    if (verb != null) {
      var clause = verb;
      if (what.isNotEmpty) clause += ' $what';
      if (r.institution != null) clause += ' ${r.institution}';
      sentences.add('${_cap(clause)}.');
    } else if (what.isNotEmpty) {
      sentences.add('${_cap(what)}.');
    }
    sentences.addAll(_stateSentences(r));
    if (r.services.isNotEmpty) {
      sentences.add('Necesito ${_join(r.services)}.');
    }
    if (r.unknown.isNotEmpty) {
      sentences.add('${_cap(_join(r.unknown))}.');
    }
    return _stitch(lead, sentences, tokens);
  }

  // ───────────────────────── Utilidades de composición ────────────────────

  /// Frase del sujeto agresor con sus rasgos ("un hombre alto, con barba").
  String _subjectPhrase(_Roles r) {
    final base = r.perpetrator ?? 'una persona';
    if (r.traits.isEmpty) return base;
    return '$base ${_join(r.traits)}';
  }

  /// Oraciones de estado emocional y urgencia, reutilizadas por varios
  /// contextos.
  List<String> _stateSentences(_Roles r) {
    final out = <String>[];
    if (r.emotions.isNotEmpty) out.add('${_cap(_join(r.emotions))}.');
    if (r.urgencies.isNotEmpty) out.add('${_cap(_join(r.urgencies))}.');
    if (r.services.isNotEmpty) out.add('Necesito ${_join(r.services)}.');
    return out;
  }

  /// Une el lead de contexto con las oraciones del cuerpo. Si el cuerpo
  /// quedó vacío (todas las glosas desconocidas y sin rol), cae a un
  /// ensamblaje mínimo para no perder la declaración del usuario.
  String _stitch(String lead, List<String> sentences, List<String> tokens) {
    final body = sentences.where((s) => s.trim().isNotEmpty).toList();
    if (body.isEmpty) {
      final raw = tokens.map((t) => t.toLowerCase().replaceAll('_', ' ')).toList();
      return '$lead ${_cap(_join(raw))}.';
    }
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
    'GRUPO': _Lex(_Role.personaDesc, 'un grupo de personas'),
    'ADULTO': _Lex(_Role.personaDesc, 'un adulto'),
    'ANCIANO': _Lex(_Role.personaDesc, 'un anciano'),
    'SOLO': _Lex(_Role.personaDesc, 'una persona'),
    'DOS': _Lex(_Role.personaDesc, 'dos personas'),
    'TRES_MAS': _Lex(_Role.personaDesc, 'tres o más personas'),
    'CONOCIDO': _Lex(_Role.personaDesc, 'un conocido'),

    // Rasgos físicos / vestimenta / color.
    'ALTO': _Lex(_Role.rasgo, 'alto'),
    'BAJO': _Lex(_Role.rasgo, 'bajo'),
    'DELGADO': _Lex(_Role.rasgo, 'delgado'),
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
    'CAMISETA': _Lex(_Role.rasgo, 'con camiseta'),
    'PANTALON': _Lex(_Role.rasgo, 'con pantalón'),
    'ZAPATILLAS': _Lex(_Role.rasgo, 'con zapatillas'),
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
    'GOLPEAR': _Lex(_Role.verboAgresion, 'golpeó'),
    'AMENAZAR': _Lex(_Role.verboAgresion, 'amenazó'),
    'EMPUJAR': _Lex(_Role.verboAgresion, 'empujó'),
    'GRITAR': _Lex(_Role.verboAgresion, 'gritó'),
    'QUITAR': _Lex(_Role.verboAgresion, 'quitó'),
    'PERSEGUIR': _Lex(_Role.verboAgresion, 'persiguió'),

    // Verbos de acción / trámite (1ª persona).
    'TRAMITAR': _Lex(_Role.verboAccion, 'quiero tramitar'),
    'SOLICITAR': _Lex(_Role.verboAccion, 'quiero solicitar'),
    'CONSULTAR': _Lex(_Role.verboAccion, 'quiero consultar'),
    'NECESITAR': _Lex(_Role.verboAccion, 'necesito'),
    'PAGAR': _Lex(_Role.verboAccion, 'quiero pagar'),
    'RENOVAR': _Lex(_Role.verboAccion, 'quiero renovar'),
    'RECOGER': _Lex(_Role.verboAccion, 'quiero recoger'),
    'ENTREGAR': _Lex(_Role.verboAccion, 'quiero entregar'),
    'PERDER': _Lex(_Role.verboAccion, 'perdí'),

    // Armas.
    'CUCHILLO': _Lex(_Role.arma, 'con un cuchillo'),

    // Objetos.
    'CELULAR': _Lex(_Role.objeto, 'mi celular'),
    'DINERO': _Lex(_Role.objeto, 'mi dinero'),
    'MOCHILA': _Lex(_Role.objeto, 'mi mochila'),
    'BOLSA': _Lex(_Role.objeto, 'mi bolsa'),
    'LLAVE': _Lex(_Role.objeto, 'mis llaves'),
    'AUTO': _Lex(_Role.objeto, 'mi auto'),
    'MOTO': _Lex(_Role.objeto, 'mi moto'),
    'BILLETERA': _Lex(_Role.objeto, 'mi billetera'),
    'TARJETA': _Lex(_Role.objeto, 'mi tarjeta bancaria'),
    'RELOJ': _Lex(_Role.objeto, 'mi reloj'),
    'CADENA': _Lex(_Role.objeto, 'mi cadena'),
    'ANILLO': _Lex(_Role.objeto, 'mi anillo'),
    'COLLAR': _Lex(_Role.objeto, 'mi collar'),
    'ARETES': _Lex(_Role.objeto, 'mis aretes'),
    'LAPTOP': _Lex(_Role.objeto, 'mi laptop'),
    'AUDIFONOS': _Lex(_Role.objeto, 'mis audífonos'),
    'LENTES_SOL': _Lex(_Role.objeto, 'mis lentes de sol'),
    'BICICLETA': _Lex(_Role.objeto, 'mi bicicleta'),

    // Documentos.
    'CARNET': _Lex(_Role.documento, 'mi carnet de identidad'),
    'DOCUMENTO': _Lex(_Role.documento, 'mi documento'),
    'CERTIFICADO': _Lex(_Role.documento, 'un certificado'),
    'PARTIDA_NACIMIENTO': _Lex(_Role.documento, 'mi partida de nacimiento'),
    'LICENCIA': _Lex(_Role.documento, 'mi licencia de conducir'),
    'FACTURA': _Lex(_Role.documento, 'una factura'),

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
    'ENFERMO': _Lex(_Role.emocion, 'estoy enfermo'),
    'DOLOR': _Lex(_Role.emocion, 'siento dolor'),
    'CONFUNDIDO': _Lex(_Role.emocion, 'estoy confundido'),

    // Urgencia.
    'URGENTE': _Lex(_Role.urgencia, 'es urgente'),
    'EMERGENCIA': _Lex(_Role.urgencia, 'es una emergencia'),
    'AYUDA': _Lex(_Role.urgencia, 'necesito ayuda'),

    // Trámites / consultas.
    'DENUNCIA': _Lex(_Role.tramite, 'una denuncia'),
    'CONSULTA': _Lex(_Role.tramite, 'una consulta'),
    'RECLAMO': _Lex(_Role.tramite, 'un reclamo'),
    'RENOVACION': _Lex(_Role.tramite, 'una renovación'),
    'PAGO': _Lex(_Role.tramite, 'un pago'),

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
  String? perpetrator;
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
  final List<String> unknown = [];
}
