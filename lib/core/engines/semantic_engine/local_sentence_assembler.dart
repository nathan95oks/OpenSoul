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
/// Marcador sintético (no es una glosa del catálogo) que separa, en la
/// secuencia plana, a la persona AGRESORA de la persona AGREDIDA en el flujo
/// de testigo. La capa de presentación lo inyecta antes de las respuestas de
/// la zona "víctima" (ver `SemanticZone.leadGloss`); el ensamblador y el
/// backend lo usan para no fundir ambos descriptores en una sola persona.
const String kVictimMarker = 'VICTIMA';

/// Marcador de zona: lo que sigue es EVIDENCIA del caso, no lo sustraído.
///
/// Sin él, elegir "tengo mensajes" en la zona de pruebas se fundía con el
/// objeto directo del verbo y salía "me amenazó un mensaje y WhatsApp".
const String kEvidenceMarker = 'PRUEBA_MARCADOR';

/// Marcador de zona: lo que sigue es el VEHÍCULO involucrado en el siniestro.
/// Sin él, un auto o una moto se leían como un servicio solicitado
/// ("Necesito mi motocicleta").
const String kVehicleMarker = 'VEHICULO_MARCADOR';

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

    // Dactilología: una racha de letras sueltas es una palabra deletreada, no
    // ocho glosas. El corpus tiene 208 señas verificadas y no piensa crecer con
    // invenciones, así que lo que no está en él se representa como lo
    // representa la propia LSB —letra a letra—, y aquí se vuelve a juntar para
    // que la declaración diga "cuchillo" y no "C. U. C. H...".
    final unidos = _joinSpelled(tokens);

    // Detalle dactilológico: la racha que sigue a un lugar o a un vehículo es
    // su nombre propio o su matrícula. Se extrae ANTES de clasificar porque el
    // lexema se compone en el momento de leer la glosa: si el detalle llegara
    // después, el lugar ya estaría escrito sin él.
    final detalles = <String, String>{};
    final limpios = _extractDetails(unidos, detalles);

    final roles = _classify(limpios, detalles);

    // Composición de tiempo: una unidad suelta no responde "¿cuándo?", abre una
    // cadena. [SEMANA]+[2] no es "esta semana" más un dos huérfano: es "hace dos
    // semanas". La dirección —hace / dentro de— no la elige la persona porque no
    // hay glosa que la exprese (el diccionario no tiene PASADO ni FUTURO): la
    // aporta el flujo, que ya sabe si narra un hecho consumado o pide un plazo.
    roles.narrativeIsPast = _pastContexts.contains(contextId);
    final consumidas = <String>{
      // Una glosa con detalle ya se dijo, pero con otras palabras que su
      // lexema base: EDAD sale como "tengo 25 años", nunca como "tengo esa
      // edad". Sin esto la red de cobertura la reclamaba al final.
      ...detalles.keys,
      // Dicha la edad, EDAD y ANOS_EDAD están las dos representadas: son la
      // misma respuesta y repetirla sonaría a tartamudeo.
      if (roles.markers.any((m) => m.startsWith('tengo ') && m.endsWith(' años')))
        ...const {'EDAD', 'ANOS_EDAD'},
      ..._resolveGender(roles),
      ..._resolveTime(roles, contextId, unidos),
    };

    // Una interrogativa manda sobre el contexto: si se eligió ¿DÓNDE?, lo que
    // la persona construye es una pregunta, y ninguno de los composers de
    // declaración sabe redactarla.
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

    // Los testigos son su propia oración, después del relato: quién vio el
    // hecho no es parte de lo que ocurrió. Se añade aquí, y no en cada
    // composer, por el mismo motivo que los marcadores —son ocho composers y
    // la regla es una—.
    final conTestigos = _withWitnesses(composed, roles);

    // Las cortesías y respuestas encabezan, en su orden de selección: "Hola.
    // Sí. Quiero denunciar un robo." Un único punto de inserción para los
    // siete composers, en vez de repetir la regla en cada uno.
    final conMarcadores = roles.markers.isEmpty
        ? conTestigos
        : '${roles.markers.map(_asSentence).join(' ')} $conTestigos'.trim();

    // Regla de cobertura semántica: ninguna glosa seleccionada puede perderse.
    return _ensureCoverage(conMarcadores, limpios, skip: consumidas);
  }

  // ───────────────────────── Composición de tiempo ────────────────────────

  /// Unidades de tiempo componibles: género y formas para concordar.
  ///
  /// El género importa para la cantidad 1 — "hace **una** semana" pero
  /// "hace **un** día"—; el plural, para todo lo demás.
  static const Map<String, ({bool femenino, String singular, String plural})>
      _timeUnits = {
    'MINUTO': (femenino: false, singular: 'minuto', plural: 'minutos'),
    'HORA':   (femenino: true,  singular: 'hora',   plural: 'horas'),
    'DIA':    (femenino: false, singular: 'día',    plural: 'días'),
    'SEMANA': (femenino: true,  singular: 'semana', plural: 'semanas'),
    'MES':    (femenino: false, singular: 'mes',    plural: 'meses'),
    'ANO':    (femenino: false, singular: 'año',    plural: 'años'),
  };

  /// Marcadores de reincidencia. Su rol léxico es `tiempo`, pero no responden
  /// "¿cuándo?" sino "¿cuántas veces?": mezclarlos con la fecha dejaba uno de
  /// los dos huérfano y la red de cobertura lo soltaba al final de la
  /// declaración ("…hago constar varias veces").
  static const _frequencyGlosses = {
    'PRIMERA_VEZ': 'Es la primera vez que ocurre',
    'VARIAS_VECES': 'Ha ocurrido varias veces',
    'ANTERIORMENTE': 'Ya había ocurrido anteriormente',
  };

  static const _cardinales = {
    '1': 'un', '2': 'dos', '3': 'tres', '4': 'cuatro', '5': 'cinco',
    '6': 'seis', '7': 'siete', '8': 'ocho', '9': 'nueve',
  };

  /// Contextos que narran un hecho ya ocurrido. El resto pide un plazo.
  ///
  /// De aquí sale la dirección de la cadena temporal: una denuncia solo puede
  /// mirar atrás ("hace dos semanas") y un trámite solo adelante ("dentro de
  /// dos semanas"). Derivarla del flujo, en vez de pedir una tarjeta más, le
  /// ahorra un paso a la persona: en una denuncia no hay otra opción posible.
  static const _pastContexts = {
    'denuncia_robo', 'violencia', 'accidente', 'emergencia', 'otro', 'perdida',
  };

  /// Verbos que miran a lo ya ocurrido. Mandan sobre la dirección del
  /// contexto: consultar el estado de algo presentado "la semana pasada" es
  /// pasado aunque el flujo de consulta apunte, por defecto, a un plazo.
  static const _pastVerbs = {
    'SEGUIMIENTO', 'COMPRENDER', 'ACLARAR', 'CONOCER', 'RECORDAR',
    'OBSERVAR', 'RECONOCER', 'PERDER', 'PAGAR', 'ENTREGAR', 'NARRAR',
    'CONFESAR', 'IDENTIFICAR',
  };

  /// Verbos de gestión por venir. Mandan sobre un contexto de pasado cuando
  /// lo que se fija es un plazo y no una fecha del hecho.
  static const _futureVerbs = {
    'PRESENTAR', 'CORREGIR', 'PEDIR', 'GESTIONAR', 'RECOGER', 'COPIAR',
    'IMPRIMIR', 'COORDINAR', 'SOLUCIONAR', 'TRATAR', 'EXIGIR',
  };

  /// Hace concordar en género los oficios epicenos y absorbe la glosa de
  /// género que ya no aporta nada.
  ///
  /// En una denuncia el género no es estilo: identifica a quien se busca.
  /// VECINO + MUJER es "una vecina", no "un vecino una mujer"; y MILITAR +
  /// HOMBRE es "un militar", porque el masculino ya era la forma por defecto
  /// —"un militar hombre" no lo dice nadie—.
  ///
  /// Devuelve las glosas consumidas para que la red de cobertura no las
  /// reclame: "una vecina" ya representa a MUJER.
  /// Separa las rachas deletreadas que califican a la glosa anterior.
  ///
  /// Devuelve los tokens sin ellas y llena [destino] con glosa → detalle.
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
        // Una matrícula mezcla letras y dígitos ("234ABC") y `_joinSpelled`
        // junta cada tipo por separado: hay que reunir los tramos seguidos o
        // la placa se parte en dos y la mitad se pierde como ruido.
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

  /// Engancha el detalle deletreado al lexema: "en la plaza Murillo",
  /// "mi auto con placa 234ABC".
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

  /// Un nombre propio se escribe con inicial mayúscula; una matrícula, tal
  /// cual la deletreó la persona.
  String _capitalizarPropio(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Set<String> _resolveGender(_Roles r) {
    final consumidas = <String>{};

    void concordar(List<String> personas) {
      if (personas.length < 2) return;
      final femenino = personas.contains('una mujer');
      final masculino = personas.contains('un hombre');
      if (!femenino && !masculino) return;

      // ¿Hay algún oficio que pueda llevar el género?
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
        // El masculino ya es la forma del lexema: la glosa sobra.
        personas.remove('un hombre');
        consumidas.add('HOMBRE');
      }
    }

    concordar(r.perpetrators);
    concordar(r.victims);
    return consumidas;
  }

  /// Cierra la cadena temporal y deja [_Roles.time] listo para los composers.
  ///
  /// Devuelve las glosas que consumió, para que la red de cobertura no las
  /// reclame: "hace dos semanas" ya representa a SEMANA y a 2, pero ninguna
  /// aparece con su lexema literal.
  /// `true` si el complemento temporal mira atrás.
  ///
  /// El verbo manda sobre el contexto: el contexto dice de qué trata el flujo,
  /// pero el verbo dice hacia dónde mira ESTA frase. Sin él, "quiero seguir el
  /// estado, la semana pasada" salía como "dentro de una semana" solo porque
  /// el flujo de consulta apunta por defecto a un plazo.
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

    // Unidad sin cantidad: la cadena quedó abierta y se resuelve con la forma
    // deíctica propia del lexema ("esta semana"), que sigue siendo una
    // respuesta válida — no todo el mundo precisa el número.
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

  /// Glosas que admiten un nombre propio o una matrícula deletreada detrás.
  ///
  /// "Me robaron en la plaza" no sirve en una denuncia: el oficial necesita
  /// QUÉ plaza. La interfaz abre el teclado dactilológico al elegirlas y las
  /// letras llegan como una racha que `_joinSpelled` ya reconstruye; aquí solo
  /// hay que engancharlas al sitio correcto de la frase.
  static const _admiteDetalle = {
    'PLAZA': 'plaza', 'CALLE': 'calle', 'AVENIDA': 'avenida',
    'MERCADO': 'mercado', 'PARADA': 'parada',
    'AUTO': 'placa', 'MOTOCICLETA': 'placa', 'MICRO': 'placa',
    'TAXI': 'placa', 'TRUFI': 'placa', 'BICICLETA': 'placa',
    // Un expediente sin su número no identifica nada: quien consulta por "mi
    // caso" a secas obliga al funcionario a preguntarlo otra vez. El número
    // se deletrea, igual que una placa.
    'CASO': 'numero', 'CODIGO': 'numero', 'NUREJ': 'numero',
    'WEBID': 'numero', 'EXPEDIENTE': 'numero',
    // Fase 1. La edad se teclea entera —"25", no un dígito—, el nombre se
    // deletrea y el carnet mezcla letras y números.
    'EDAD': 'edad', 'ANOS_EDAD': 'edad',
    'NOMBRE': 'nombre', 'APELLIDO': 'apellido',
    'CARNET': 'carnet',
  };

  /// Etiqueta del detalle que admite [gloss], o `null` si no admite ninguno.
  ///
  /// La interfaz la consulta para decidir si abre el teclado dactilológico.
  /// Vive aquí, junto a la tabla, para que no haya dos listas que mantener.
  static String? etiquetaDeDetalle(String gloss) =>
      _admiteDetalle[gloss.trim().toUpperCase()];

  /// Oficios y relaciones cuyo lexema viene en masculino por defecto y que
  /// concuerdan si la persona además eligió MUJER.
  ///
  /// En una denuncia el género no es un detalle de estilo: identifica a quien
  /// se busca. "Un vecino" y "una vecina" no señalan a la misma persona.
  static const _feminino = {
    'un vecino': 'una vecina',
    'un militar': 'una militar',
    'un soldado': 'una soldado',
    'un testigo': 'una testigo',
    'un ladrón': 'una ladrona',
    'un doctor': 'una doctora',
    'un abogado': 'una abogada',
  };

  /// Glosas que son material probatorio en cualquier flujo.
  ///
  /// No dependen del marcador de zona porque su papel no depende de por dónde
  /// se eligieron: una fotografía o un comprobante se aportan para acreditar
  /// el hecho, nunca son lo sustraído ni lo dañado.
  /// Verbos de huida: describen la salida del agresor, no la agresión.
  static const _flightVerbs = {'CORRER'};

  static const _inherentEvidence = {
    'FOTOGRAFIA', 'MENSAJE', 'COMPROBANTE', 'CERTIFICADO', 'RESPALDO',
    'VIDEOLLAMADA',
  };

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
  String _ensureCoverage(String text, List<String> tokens,
      {Set<String> skip = const {}}) {
    final hay = _stripDiacritics(text.toLowerCase());
    final missing = <String>[];
    for (final t in tokens) {
      // Marcadores de control de zona: no son contenido declarable.
      if (t == kVictimMarker || t == kEvidenceMarker || t == kVehicleMarker) {
        continue;
      }
      if (_inherentImplicit.contains(t)) continue;
      // Un dígito huérfano se descartó a propósito en _classify; reclamarlo
      // aquí lo devolvería por la puerta de atrás.
      if (_esDigito(t)) continue;
      // Consumida por la cadena temporal: "hace dos semanas" representa a
      // SEMANA y a 2 sin que ninguno aparezca con su lexema literal.
      if (skip.contains(t)) continue;
      if (_isRepresented(t, hay)) continue;
      final lex = _lexicon[t];
      final frag = lex != null ? lex.es : t.toLowerCase().replaceAll('_', ' ');
      if (!missing.contains(frag)) missing.add(frag);
    }
    if (missing.isEmpty) return text;
    // Una pregunta no tiene "declaración que completar": pegarle este
    // relleno detrás produce un despropósito ("¿Qué trámite necesitas? Para
    // completar mi declaración, hago constar mi expediente."), la pregunta
    // se responde a sí misma en la misma frase. Mejor una pregunta genérica
    // pero coherente que forzar el dato dentro de un acto de habla que no
    // es el suyo.
    if (text.trim().endsWith('?')) return text;
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
    // Los marcadores de control (p. ej. VICTIMA) no son contenido: no cuentan
    // para el conteo de palabras ni para la cobertura.
    const marcadores = {kVictimMarker, kEvidenceMarker, kVehicleMarker};
    glosses = glosses
        .where((g) => !marcadores.contains(g.trim().toUpperCase()))
        .toList();
    // Las mismas reglas que aplica el ensamblador: una racha de dígitos es un
    // número deletreado, y un dígito huérfano —sin unidad de tiempo delante—
    // se descarta a propósito. Sin esto el detector exigía representar algo
    // que ambos motores tiran, y descartaba respuestas correctas.
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

    // Detecta si el backend simplemente devolvió las glosas como lista
    // de palabras sin estructura gramatical española (sin artículos,
    // preposiciones ni verbos conjugados). Una oración real contiene
    // al menos una palabra de enlace.
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
      // _isRepresented exige TODAS las palabras del lexema (correcto para
      // decidir si omitir el relleno de _composeGeneric), lo que es
      // demasiado estricto aquí: el backend puede parafrasear parte de una
      // frase de varias palabras ("deseo" en vez de "quiero solicitar") y
      // seguir representando la glosa. _glossCovered acepta que cualquier
      // palabra significativa coincida, así que basta con una de las dos.
      if (_isRepresented(g, haystack) || _glossCovered(g, haystack)) hits++;
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
    final normalizada = _stripDiacritics(gloss.toLowerCase());

    // Un dígito de una cadena temporal se redacta como palabra: el 2 de
    // [SEMANA]+[2] sale en el texto como "hace DOS semanas". Sin esto, el
    // detector de degeneración daba por perdida la cantidad y descartaba una
    // respuesta del backend que era correcta — el motor local acababa
    // rehaciendo trabajo ya bien hecho.
    final cardinal = _cardinales[gloss];
    if (cardinal != null) {
      if (RegExp('\\b$cardinal\\b').hasMatch(haystackLower)) return true;
      // El 1 concuerda en género con su unidad: "una hora", "un día".
      if (gloss == '1' && RegExp(r'\buna?\b').hasMatch(haystackLower)) {
        return true;
      }
    }
    final parts = normalizada
        .split(RegExp(r'[ _/]+'))
        .where((p) => p.length >= 3); // ignora partículas cortas (de, la…)
    // Glosa entera de una o dos letras —un dígito de dactilología, una letra
    // suelta—: ninguna parte supera el umbral de raíz, así que sin esta rama
    // se daba por no cubierta aunque estuviera literalmente en el texto, y la
    // red de seguridad la repetía al final.
    if (parts.isEmpty) return haystackLower.contains(normalizada);
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

  _Roles _classify(List<String> tokens, [Map<String, String> detalles = const {}]) {
    final r = _Roles()..details.addAll(detalles);
    // Tras el marcador [kVictimMarker], los descriptores de persona pasan a
    // describir a la persona AGREDIDA (no al agresor). Flujo de testigo.
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

      // Reincidencia antes que tiempo: "varias veces" no es una fecha.
      final frecuencia = _frequencyGlosses[t];
      if (frecuencia != null) {
        r.frequency ??= frecuencia;
        continue;
      }

      // Evidencia por naturaleza, haya o no marcador de zona. El marcador
      // solo llega si la persona pasó por la zona de pruebas; eligiendo la
      // misma tarjeta desde otra zona, una fotografía acababa como botín:
      // "me robó mi motocicleta y una fotografía". Nadie roba una fotografía
      // ni daña un certificado — se aportan para probar el hecho.
      // Salvo que se esté construyendo una PREGUNTA: quien pregunta "¿qué
      // documentos necesito?" no está aportando un certificado como prueba, y
      // clasificarlo como evidencia lo sacaba de `documents` y la pregunta
      // salía sin complemento ("¿Qué necesito?").
      if (_inherentEvidence.contains(t) && !hayInterrogativa) {
        final lex = _lexicon[t];
        if (lex != null && !r.evidence.contains(lex.es)) r.evidence.add(lex.es);
        continue;
      }

      // Tras el marcador de zona, objetos y documentos cambian de papel: son
      // la evidencia que se aporta o el vehículo del siniestro, no lo que se
      // llevaron ni un servicio que se pide.
      // Solo cambia el papel de lo que puede serlo: un vehículo es un objeto,
      // una prueba es un objeto o un documento. El resto —lugar, servicio,
      // tiempo— sigue su curso normal, porque el marcador no sabe dónde
      // termina la zona y si no se acotara se tragaría el resto del relato
      // ("Estuvo involucrado mi motocicleta, en la avenida y un doctor").
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

      // Cantidad de una cadena temporal. El rol es *posicional*, no léxico: un
      // dígito solo cuenta como cantidad si viene detrás de una unidad de
      // tiempo que aún no la tiene. Fuera de esa posición un dígito sigue
      // siendo dactilología —el número de un NUREJ, un teléfono— y cae por la
      // rama de desconocidos, que es donde debe estar.
      if (_cardinales.containsKey(t) &&
          r.timeUnit != null &&
          r.timeCount == null) {
        r.timeCount = t;
        continue;
      }

      // Unidad de tiempo: abre la cadena en vez de cerrar la respuesta.
      if (_timeUnits.containsKey(t)) {
        r.timeUnit ??= t;
        continue;
      }

      // Polaridad posicional. En LSB tanto la negación como la afirmación son
      // señas aparte, no prefijos del verbo: NO delante de un verbo lo niega
      // ("NO ENTREGAR" → "no me entregaron") y SÍ lo afirma. Sin esto, el NO o
      // el SÍ quedaban como cortesía suelta —"No."— y el verbo se afirmaba
      // solo, que en el primer caso es decir lo contrario.
      //
      // Alcanza también a TESTIGO porque "¿Hay testigos?" es una pregunta de
      // sí o no y su respuesta no es un verbo, sino la persona misma.
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

      // Dígito huérfano: llegó sin unidad de tiempo delante, así que no es
      // una cantidad, y no viene en racha, así que tampoco es un número
      // deletreado. Es una selección que no significa nada por sí sola y se
      // descarta: "Adicionalmente, hago referencia a 2" no dice nada y
      // ensucia una declaración que puede acabar en un expediente.
      if (_esDigito(t)) continue;

      final e = _lexicon[t];
      if (e == null) {
        // Glosa desconocida: la conservamos como objeto/detalle genérico
        // para no perder información del relato del usuario sordo.
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
          // Huida: es lo que hizo el agresor DESPUÉS, no lo que me hizo.
          // Como agresión producía "un hombre me salió corriendo", que además
          // de falso es agramatical —salir es intransitivo—. Se guarda para
          // cerrar el relato: "…y salió corriendo".
          if (_flightVerbs.contains(t)) {
            r.flight ??= e.es;
            break;
          }
          // Dos agresiones en un mismo relato son dos hechos, no uno: la
          // segunda se guarda aparte en vez de perderse.
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
          // Un segundo verbo de acción no se pierde: es otro hecho del
          // relato ("pagué" y además "no me entregaron").
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
          // Varias instituciones son varios destinos, no uno: con `??=` la
          // segunda se perdía y la red de cobertura la soltaba al final
          // ("…hago constar en el despacho").
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
          // EDAD y ANOS_EDAD son la misma respuesta: si ya se dijo la edad,
          // la segunda no añade nada y sonaría a tartamudeo.
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

  /// true si hay un agresor explícito (descriptor de persona o rasgos).
  bool _hasAggressor(_Roles r) =>
      r.perpetrators.isNotEmpty || r.traits.isNotEmpty;

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
  /// Une las rachas de letras sueltas en la palabra que deletrean.
  ///
  /// Solo actúa sobre secuencias de dos o más: una letra aislada es una
  /// inicial legítima y se respeta. Los dígitos no se tocan —"2" es una
  /// cantidad, no media palabra.
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
      // Misma lógica para los dígitos: una racha es UN número deletreado —el
      // NUREJ, un teléfono— y se junta ("1","2","3" → "123"). Un dígito
      // aislado no se toca aquí: si sigue a una unidad de tiempo lo recoge la
      // cadena temporal, y si no, es ruido que _classify descarta.
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

  /// Dígitos de dactilología. Incluye el 0, que [_cardinales] no lleva a
  /// propósito: sirve para deletrear un NUREJ pero jamás es una cantidad
  /// —"hace cero semanas" no significa nada—. Sin el 0 aquí, un número como
  /// "1 0 2 4" se partía en trozos y el primer dígito se perdía.
  static const _digitos = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  };

  static bool _esDigito(String g) => _digitos.contains(g);

  static bool _esLetra(String g) =>
      g.length == 1 && RegExp(r'^[A-ZÑ]$').hasMatch(g);

  /// Convierte una forma suelta en oración: mayúscula inicial y punto.
  ///
  /// Mayusculiza la primera LETRA, no el carácter 0: formas como
  /// "¿puede repetir?" empiezan con signo de apertura, y capitalizar el
  /// índice 0 no hace nada (deja "¿puede…" en vez de "¿Puede…").
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

  /// Redacta una pregunta a partir de la interrogativa y su complemento.
  ///
  /// La cópula la decide el complemento: un lugar o una institución *están*,
  /// lo demás *es*. Sin esa distinción salían preguntas como "¿Dónde es la
  /// fiscalía?", que es justo el error que delata a una máquina.
  ///
  /// Cuando no hay complemento, la interrogativa vale por sí sola: "¿Dónde?"
  /// es una pregunta legítima en un mostrador, y forzar un objeto inventado
  /// sería peor que devolverla tal cual.
  /// Cierra el relato con quién lo presenció.
  ///
  /// "¿Hay testigos?" se responde sí o no, así que la negativa tiene forma
  /// propia: la ausencia de testigos es un dato del acta, no un silencio.
  String _withWitnesses(String texto, _Roles r) {
    if (r.witnesses.isEmpty) return texto;
    final afirmacion = r.witnessesAffirmed ? 'Sí, hay' : 'Hay';
    final clausula = r.witnessesNegated
        ? 'No hay testigos'
        : r.witnesses.length == 1
            ? '$afirmacion ${r.witnesses.first}'
            : '$afirmacion testigos';
    // En una pregunta la cláusula no encaja: quien pregunta por un testigo no
    // está declarando que lo haya.
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

    // Cada interrogativa pregunta por una clase de cosa. Sin esta restricción
    // el composer emparejaba la primera glosa que encontrara y salían
    // preguntas como "¿Quién es mi motocicleta?": una persona no es un objeto,
    // y un lugar no responde a "cuándo".
    final personas = [
      ...r.perpetrators,
      ...r.services,
      if (r.institution != null) r.institution!,
    ];
    // La pregunta la formula la persona sorda y la escucha el funcionario:
    // va en PRIMERA persona. En segunda —"¿Qué documento necesitas?"— la
    // aplicación le preguntaba al funcionario por las necesidades DEL
    // FUNCIONARIO, que es lo contrario de lo que quiso decir quien la usó.
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
      // §6: "¿Dónde puedo presentar la denuncia?". Con un verbo elegido, la
      // pregunta es por dónde HACER algo, no por dónde ocurrió: devolver
      // "¿Dónde ocurrió?" perdía el verbo y cambiaba la pregunta entera.
      final accion = _accionDePregunta(r);
      if (accion != null) return '¿Dónde puedo $accion?';
      return '¿Dónde ocurrió?';
    }

    if (interrogativa == 'cuándo') {
      // §6: "¿Cuándo debo volver?" — la pregunta que cierra toda atención.
      final accion = _accionDePregunta(r);
      if (accion != null) return '¿Cuándo debo $accion?';
      // Una citación o una audiencia tienen fecha: se pregunta cuándo SON.
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
      // §6: "¿Cómo puedo saber el avance del caso?". Devolver "¿Cómo es?"
      // descartaba el complemento y dejaba una pregunta que no pregunta nada.
      final accion = _accionDePregunta(r);
      if (accion != null) return '¿Cómo puedo $accion?';
      // §6: "¿Cómo puedo saber el avance del caso?". Un expediente no se
      // "sabe": se sabe su estado. AVANCE y ESTADO ya lo nombran en su propio
      // lexema, así que anteponérselo daría "el estado de el avance de…".
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

  /// Modales con los que el lexicón redacta los verbos en una declaración.
  /// En una pregunta sobran: "¿Dónde puedo quiero presentar una denuncia?".
  static const _modalesDeclarativos = [
    'quiero ', 'necesito ', 'debo ', 'puedo ', 'sí quiero ', 'no quiero ',
  ];

  /// Verbo elegido, en la forma que admite un modal interrogativo delante.
  ///
  /// Devuelve `null` si no se eligió ninguno, que es cuando la interrogativa
  /// pregunta por una cosa y no por una acción.
  String? _accionDePregunta(_Roles r) {
    final verbo = r.action ?? (r.extraActions.isEmpty ? null : r.extraActions.first);
    if (verbo == null) return null;
    for (final modal in _modalesDeclarativos) {
      if (verbo.startsWith(modal)) return verbo.substring(modal.length);
    }
    return verbo;
  }

  /// "una audiencia" → "la audiencia". Se pregunta por LA citación concreta
  /// que le compete a quien pregunta, no por una cualquiera.
  String _conArticuloDefinido(String lexema) {
    if (lexema.startsWith('una ')) return 'la ${lexema.substring(4)}';
    if (lexema.startsWith('un ')) return 'el ${lexema.substring(3)}';
    return lexema;
  }

  /// Contexto de preguntas sin una interrogativa clara.
  ///
  /// Se usa como red de seguridad cuando el usuario entra a la zona de
  /// preguntas pero todavía no eligió la palabra interrogativa. En vez de
  /// caer en una frase burocrática, devuelve una pregunta corta y propia del
  /// corpus.
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

  /// Convierte una institución o cargo institucional en una etiqueta más
  /// natural para preguntas sobre personas.
  String _whoLabelForInstitution(String institution) {
    final normalized = institution.replaceAll('en ', '').trim();
    if (normalized.contains('fiscalía')) return 'el fiscal';
    if (normalized.contains('juzgado')) return 'el juez';
    if (normalized.contains('oficial')) return 'el oficial';
    if (normalized.contains('policía')) return 'el policía';
    if (normalized.contains('autoridad')) return 'la autoridad';
    return normalized;
  }

  /// Detecta si los documentos seleccionados son soporte físico más que
  /// documentos formales. Sirve para no preguntar "qué documento" cuando la
  /// selección real es "papel", "carpeta" u "hoja".
  bool _looksLikeSupportDocument(List<String> documents) {
    const supportMarkers = ['papel', 'carpeta', 'archivador', 'hoja'];
    return documents.any((doc) {
      final normalized = _stripDiacritics(doc.toLowerCase());
      return supportMarkers.any(normalized.contains);
    });
  }


  String _capitalizar(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  /// Las instituciones se redactan como complemento de "estar" ("en la
  /// fiscalía"), pero "acudir" rige "a", no "en" — "acudir en la fiscalía"
  /// no es español. Convierte el complemento locativo al destino ("a la
  /// fiscalía", "al ministerio") para los verbos de movimiento.
  String _toDestino(String institucion) {
    if (institucion.startsWith('en el ')) return 'al ${institucion.substring(6)}';
    if (institucion.startsWith('en la ')) return 'a la ${institucion.substring(6)}';
    if (institucion.startsWith('en ')) return 'a ${institucion.substring(3)}';
    return institucion;
  }

  /// Fase 1: los datos SON la declaración.
  ///
  /// Nombre, apellido y edad viajan como marcadores y encabezan solos, así
  /// que aquí solo queda el documento. No hay frase de encuadre a propósito:
  /// "quiero comunicar lo siguiente" antes de un nombre suena a formulario, y
  /// el funcionario está esperando un dato, no un preámbulo.
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
      // Cláusula del agresor + acción.
      final subject = _subjectPhrase(r);
      final defaultVerb = ctx == 'violencia' ? 'agredió' : 'asaltó';
      final verb = r.aggression ?? defaultVerb;
      // Un sujeto en aposición ("mi pareja, una mujer") necesita la coma de
      // cierre antes de seguir la cláusula, si no el "una mujer me agredió"
      // se lee pegado a la aposición como si fuera una sola frase corrida.
      var clause = '${subject.contains(',') ? '$subject,' : subject} me $verb';
      // Un canal ("por WhatsApp") ya trae su preposición: unirlo con "y" a
      // los objetos daba "me robó mi dinero, el producto y por WhatsApp".
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
      // La huida cierra el relato del hecho, encadenada al mismo sujeto:
      // "…me robó mi motocicleta en el mercado y salió corriendo".
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
      // Hay verbos de acción propios del relato (§2.4: "pagué", "no me
      // entregaron"): los complementos son suyos, no de un hurto implícito.
      // Sin esta rama salía "Me sustrajeron por WhatsApp y el producto",
      // que además de falso califica el hecho como robo — justo lo que el
      // corpus §8 prohíbe que haga la aplicación.
      const preposiciones = {'por', 'en', 'con', 'a', 'de'};
      final todos = [...r.objects, ...r.documents];
      final canales =
          todos.where((o) => preposiciones.contains(o.split(' ').first)).toList();
      final nominales = todos.where((o) => !canales.contains(o)).toList();
      r.objects.clear();
      r.documents.clear();

      // El canal acompaña a la primera acción ("pagué por WhatsApp"); lo
      // nominal, a la última ("no me entregaron el producto").
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

    // Un servicio solo es complemento del verbo cuando el verbo es de
    // solicitud. Con cualquier otro salía "Quiero corregir un intérprete de
    // señas": el apoyo de accesibilidad se tragaba el objeto real del trámite.
    // En ese caso el servicio va en su propia oración, al final.
    final verboPideServicio = r.action == null ||
        const {'quiero solicitar', 'necesito ayuda'}.contains(r.action);
    if (r.services.isNotEmpty && verboPideServicio) {
      // Si el usuario eligió un verbo (necesito/quiero solicitar...), encabeza
      // la oración para no dejarlo suelto y mantener la fluidez.
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
      // Un documento ("un comprobante") y un trámite ("una audiencia") son
      // ambos lo que se está pidiendo: sin sumar r.documents aquí, "Quiero
      // solicitar." salía suelto y el comprobante quedaba en una oración
      // aparte por la red de cobertura ("Necesito un comprobante."), como si
      // fueran dos peticiones distintas en vez de una sola.
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
    // Persona AGREDIDA (separada del agresor por [kVictimMarker]). Si no se
    // indicó, el complemento por defecto sigue siendo "otra persona".
    final victim = _hasVictim(r)
        ? _personPhrase(r.victims, r.victimTraits)
        : null;

    if (r.aggression != null) {
      final verb = r.aggression!;
      var clause = 'presencié cómo $subject $verb';
      // Un canal ("por WhatsApp") ya trae su preposición: unirlo con "y" a
      // los objetos daba "me robó mi dinero, el producto y por WhatsApp".
      final complement = _joinConCanales([...r.objects, ...r.documents]);
      if (complement.isNotEmpty) {
        clause += ' $complement';
        r.objects.clear();
        r.documents.clear();
      }
      // Objeto directo: la persona agredida ("a un hombre mayor"). Si hubo
      // objeto sustraído y víctima → "robó el celular a un hombre". Si no hay
      // ni objeto ni víctima, se mantiene el genérico "a otra persona".
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
      // Se describió a personas pero sin acción explícita.
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

  /// true si se describió a la persona agredida (flujo de testigo).
  bool _hasVictim(_Roles r) =>
      r.victims.isNotEmpty || r.victimTraits.isNotEmpty;

  void _clearVictim(_Roles r) {
    r.victims.clear();
    r.victimTraits.clear();
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
        // Solo se describió a una persona, sin acción.
        sentences.add('La persona involucrada era ${_decap(subject)}.');
      }
      r.aggression = null;
      r.perpetrators.clear();
      r.traits.clear();
    }

    // 2. Objetos / documentos no usados → se expresan como necesidad.
    final things = _join([...r.objects, ...r.documents]);
    if (things.isNotEmpty) {
      sentences.add('Necesito $things.');
      r.objects.clear();
      r.documents.clear();
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

    // 6-bis. Agresión secundaria, reincidencia, evidencia y vehículo.
    // Cada uno es una oración propia: fundirlos con el núcleo del relato
    // producía "me amenazó un mensaje y WhatsApp" o "Necesito mi motocicleta".
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
    // Red de seguridad: si ninguna cláusula de agresor la absorbió, la huida
    // sigue siendo parte del relato y no puede perderse.
    final flight = r.flight;
    if (flight != null) {
      sentences.add('${_cap(flight)}.');
      r.flight = null;
    }

    // 7. Lugar / tiempo residuales.
    // Un plazo futuro no "ocurrió": se necesita. Sin esta rama, pedir un
    // certificado para dentro de dos semanas salía como "Ocurrió dentro de dos
    // semanas", que mezcla un pasado narrativo con un complemento de futuro.
    if (r.time != null && r.timeIsFuture) {
      sentences.add('Lo necesito ${r.time}.');
      r.time = null;
    }
    // Un tiempo pasado sin lugar no es un destino: "Debo acudir hace una
    // semana" mezcla una gestión por venir con una fecha que ya pasó. En una
    // consulta de seguimiento la fecha sitúa lo consultado, y se dice así.
    if (r.time != null && !r.timeIsFuture && r.place == null) {
      sentences.add('Fue ${r.time}.');
      r.time = null;
    }
    if (r.place != null || r.time != null) {
      // En un trámite o una consulta el lugar residual es a dónde hay que ir,
      // no dónde pasó algo: "Ocurrió en el piso" no dice nada.
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
  String _subjectPhrase(_Roles r) =>
      _personPhrase(r.perpetrators, r.traits);

  /// Frase nominal de una persona a partir de sus descriptores, su forma
  /// plural explícita (DOS/TRES) y sus rasgos. Reutilizable para el agresor
  /// ([_subjectPhrase]) y para la persona agredida (flujo de testigo).
  String _personPhrase(List<String> persons, List<String> traits) {
    String base;
    {
      if (persons.isNotEmpty) {
        // Un descriptor "mi X" (PAREJA, EXPAREJA, FAMILIAR…) ya es una frase
        // nominal completa y específica, no un rasgo apilable como "un
        // joven". Pegarlo detrás de "una mujer" da "una mujer mi pareja"
        // (agramatical). Si hay alguno, va primero y el resto (género/edad)
        // se suma en aposición con comas: "mi pareja, una mujer" — así no se
        // pierde el dato de género y la red de cobertura sigue viendo la
        // glosa representada en el texto.
        final relacionales = persons.where((p) => p.startsWith('mi ')).toList();
        if (relacionales.isNotEmpty) {
          final otros = persons.where((p) => !p.startsWith('mi ')).toList();
          base = otros.isEmpty
              ? _join(relacionales)
              : '${_join(relacionales)}, ${otros.join(', ')}';
        } else {
          // Los descriptores describen a UNA persona (género + edad + relación),
          // no a varias: se concatenan como una sola frase nominal — el primero
          // conserva su artículo ("una mujer") y el resto se anexa como
          // modificador sin artículo ni "y" ("una mujer" + "un joven" →
          // "una mujer joven"). Unirlos con "y" sugeriría personas distintas.
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

    // Concordancia de género: cualquier sujeto femenino ("una persona", "una
    // mujer"…) feminiza sus adjetivos simples ("alto" → "alta"), no solo el
    // genérico. Los complementos preposicionales ("con gorra", "de color
    // negro") son invariables y se dejan tal cual.
    final isFeminine = base.startsWith('una ');
    if (traits.isEmpty) return base;

    // Separa adjetivos simples de frases con preposición (empieza con "con"/"de")
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
  /// Une objetos separando los que ya traen preposición, que se adjuntan
  /// detrás en vez de entrar en la enumeración.
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
    // ── Cortesía (5) ──
    'GRACIAS': _Lex(_Role.marcador, 'gracias'),
    'HOLA': _Lex(_Role.marcador, 'hola'),
    'PERMISO': _Lex(_Role.marcador, 'con permiso'),
    'POR_FAVOR': _Lex(_Role.marcador, 'por favor'),
    'LO_SIENTO': _Lex(_Role.marcador, 'lo siento'),

    // ── Respuesta (11) ──
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

    // ── Preguntas (16) ──
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

    // ── Identificación (12) ──
    // ── Fase 1: identidad. Son marcadores porque abren la declaración —uno
    // se identifica antes de contar nada— y porque como `personaDesc` se
    // confundían con el agresor: "mi nombre me robó".
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

    // ── Instituciones (19) ──
    'ABOGADO': _Lex(_Role.servicio, 'un abogado'),
    'AUTORIDAD': _Lex(_Role.institucion, 'en la autoridad'),
    // Ámbito penal boliviano. FISCAL se conserva para "¿quién lleva tu
    // caso?" —donde se pregunta por la persona— y FISCALIA nombra la
    // dependencia; las listas blancas nunca ofrecen las dos en la misma zona.
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

    // ── Conceptos jurídicos (28) ──
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

    // ── Acciones (31) ──
    'ANOTAR': _Lex(_Role.verboAccion, 'quiero anotar'),
    'AVISAR': _Lex(_Role.verboAccion, 'quiero avisar'),
    'ESCRIBIR': _Lex(_Role.verboAccion, 'quiero escribir'),
    'IDENTIFICAR': _Lex(_Role.verboAccion, 'quiero identificar'),
    'MOSTRAR': _Lex(_Role.verboAccion, 'quiero mostrar'),
    'NARRAR': _Lex(_Role.verboAccion, 'quiero narrar'),
    'OBSERVAR': _Lex(_Role.verboAccion, 'quiero observar'),
    'PEDIR': _Lex(_Role.verboAccion, 'quiero solicitar'),
    // §2.4: el corpus necesita relatar un pago incumplido sin nombrar el
    // delito —la app no califica jurídicamente (corpus §8)—. Los dos verbos
    // son neutros y en 3ª persona se niegan con la glosa NO, como en LSB.
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
    // Verbo, no sintagma: 'quiero una copia' seguido del documento daba
    // "quiero una copia una constancia", sin la preposición.
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
    // §4: "¿Conoce a la persona involucrada?". El complemento va en el
    // lexema porque la respuesta es a esa pregunta: "Conozco." a secas no
    // dice a quién, y en un acta la diferencia es el caso entero.
    'CONOCER': _Lex(_Role.verboAccion, 'conozco a esa persona'),
    // Seña propia para la negativa. La regla posicional NO+verbo ya produce
    // "no conozco a esa persona", pero el corpus recoge DESCONOCER como seña
    // independiente: las dos rutas llegan al mismo texto.
    'DESCONOCER': _Lex(_Role.verboAccion, 'no conozco a esa persona'),
    // §4: "¿Desea realizar una denuncia?". No es QUEJAR: una queja
    // administrativa y una denuncia penal abren expedientes distintos.
    'DENUNCIAR': _Lex(_Role.verboAccion, 'quiero presentar una denuncia'),
    // §6: "¿Cuándo debo volver?" — la última pregunta de toda atención.
    'VOLVER': _Lex(_Role.verboAccion, 'debo volver'),

    // ── Hechos y urgencia (18) ──
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

    // ── Descripción (18) ──
    'CORRECTO': _Lex(_Role.rasgo, 'correcto'),
    'PELIGROSO': _Lex(_Role.rasgo, 'peligroso'),
    // Responde "¿estás en un lugar seguro?" (corpus §2.2 t.12), no
    // describe a nadie. Como `rasgo` se pegaba al agresor: "un hombre
    // seguro y delgado". Es un estado del declarante.
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

    // ── Estado y emoción (11) ──
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

    // ── Tiempo (17) ──
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

    // ── Lugares (16) ──
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

    // ── Documentos (24) ──
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

    // ── Transporte (8) ──
    'AUTO': _Lex(_Role.objeto, 'mi auto'),
    'MICRO': _Lex(_Role.objeto, 'el micro'),
    'MOTOCICLETA': _Lex(_Role.objeto, 'mi motocicleta'),
    'TAXI': _Lex(_Role.objeto, 'el taxi'),
    'TRUFI': _Lex(_Role.objeto, 'el trufi'),
    'BICICLETA': _Lex(_Role.objeto, 'mi bicicleta'),
    'TREN': _Lex(_Role.objeto, 'el tren'),

    // ── Objetos (7) ──
    'BILLETERA': _Lex(_Role.objeto, 'mi billetera'),
    'MENSAJE': _Lex(_Role.objeto, 'un mensaje'),
    'FOTOGRAFIA': _Lex(_Role.objeto, 'una fotografía'),
    'CAMARA': _Lex(_Role.objeto, 'una cámara'),
    'CUENTA': _Lex(_Role.objeto, 'mi cuenta'),
    'PRODUCTO': _Lex(_Role.objeto, 'el producto'),

    // ── Comunicación (7) ──
    'ACEPTAR': _Lex(_Role.verboAccion, 'acepto'),
    'ATENDER': _Lex(_Role.verboAccion, 'necesito que me atiendan'),
    'AYUDAR': _Lex(_Role.verboAccion, 'necesito ayuda'),
    'COMPRENDER': _Lex(_Role.verboAccion, 'quiero comprender'),
    'HABLAR': _Lex(_Role.verboAccion, 'quiero hablar'),
    'RECHAZAR': _Lex(_Role.verboAccion, 'rechazo'),
    'RESPONDER': _Lex(_Role.verboAccion, 'quiero responder'),

    // ── Comunicación digital (4) ──
    'VIDEOLLAMADA': _Lex(_Role.objeto, 'por videollamada'),
    // Canales, no objetos: sin la preposición el compositor los tomaba
    // como complemento directo — "me amenazó WhatsApp".
    'WHATSAPP': _Lex(_Role.objeto, 'por WhatsApp'),

    // ── Integridad (8) ──
    'CORRUPTO': _Lex(_Role.rasgo, 'corrupto'),
  };
}

enum _Role {
  sujeto,
  personaDesc,

  /// Persona que PRESENCIÓ el hecho.
  ///
  /// Tiene rol propio y no `personaDesc` porque un testigo nunca es el autor
  /// del delito, y como descriptor de persona lo era: en una denuncia de robo
  /// [TESTIGO] caía en `perpetrators` y el compositor redactaba "Un testigo me
  /// asaltó", que acusa de un delito a quien solo lo vio. No hay flujo en el
  /// que un testigo deba ocupar el sitio del agresor, así que la separación es
  /// del léxico y no de la zona: ninguna pantalla puede volver a fundirlos.
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
  /// Fórmula de cortesía o respuesta suelta (HOLA, GRACIAS, SÍ, NO PUEDO).
  ///
  /// No ocupa lugar en la oración: no es sujeto, ni verbo, ni complemento.
  /// Se antepone como frase independiente, que es como funciona en el
  /// diálogo real —quien saluda no está narrando todavía.
  marcador,

  /// Palabra interrogativa (¿QUIÉN?, ¿DÓNDE?, ¿CUÁNDO?).
  ///
  /// Cambia la naturaleza de la salida: con una de estas, lo que se compone
  /// deja de ser una declaración y pasa a ser una pregunta.
  interrogativa,
}

class _Lex {
  final _Role role;
  final String es;
  const _Lex(this.role, this.es);
}

/// Acumulador mutable de roles detectados en una secuencia de glosas.
class _Roles {
  String? subject;
  final List<String> perpetrators = []; // Bug fix #2: sujeto plural (DOS/TRES)
  // Persona AGREDIDA (flujo de testigo): descriptores tras [kVictimMarker].
  final List<String> victims = [];
  final List<String> victimTraits = [];
  /// Instituciones nombradas, en orden de selección. [institution] devuelve
  /// la primera y [institutionText] todas enlazadas.
  final List<String> institutions = [];

  /// Compatibilidad con los composers: la primera institución, o `null`.
  String? get institution => institutions.isEmpty ? null : institutions.first;

  set institution(String? v) {
    institutions.clear();
    if (v != null) institutions.add(v);
  }

  String? aggression;

  /// Huida del agresor ("salió corriendo"). Cierra el relato, no lo abre.
  String? flight;

  /// Detalle deletreado por glosa: PLAZA → "MURILLO", AUTO → "234ABC".
  final Map<String, String> details = {};

  /// Verbos de acción adicionales. Con `??=` el segundo se perdía: "pagué" y
  /// "no me entregaron" son dos hechos del mismo relato, no uno.
  final List<String> extraActions = [];
  String? action;
  String? place;
  String? time;

  /// Unidad temporal pendiente de cantidad (SEMANA, DIA…) y su cantidad.
  /// [LocalSentenceAssembler._resolveTime] los funde en [time] con la
  /// dirección que dicta el contexto.
  String? timeUnit;
  String? timeCount;

  /// `true` si [time] expresa un plazo por venir ("dentro de dos semanas").
  /// Los composers lo consultan para no narrarlo en pasado.
  bool timeIsFuture = false;

  /// `true` si el contexto narra un hecho consumado. Una consulta o un
  /// trámite no "ocurren": se gestionan.
  bool narrativeIsPast = true;

  /// Reincidencia del hecho, ya redactada ("Ha ocurrido varias veces").
  String? frequency;

  /// Evidencia aportada y vehículo del siniestro. Se llenan solo detrás de
  /// [kEvidenceMarker] y [kVehicleMarker]: fuera de sus zonas, un mensaje o
  /// una moto siguen siendo un objeto cualquiera.
  final List<String> evidence = [];
  final List<String> vehicles = [];

  /// Agresiones adicionales a la principal.
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

  /// Personas que PRESENCIARON el hecho, y si la respuesta fue negativa.
  ///
  /// Responden "¿Hay testigos?", que es una pregunta de sí o no: por eso hace
  /// falta guardar la negación aparte. Sin ella, [NO]+[TESTIGO] hoistaba el NO
  /// como cortesía suelta y el acta recogía "No. Hay un testigo." — una
  /// contradicción dentro de la misma declaración.
  final List<String> witnesses = [];
  bool witnessesNegated = false;
  bool witnessesAffirmed = false;

  /// Cortesías y respuestas, en el orden en que se eligieron.
  final List<String> markers = [];

  /// Palabra interrogativa. Su presencia convierte la salida en pregunta.
  String? question;

}
