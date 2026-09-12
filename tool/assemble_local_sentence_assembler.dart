import 'dart:io';

void main() {
  final lexiconContent = File('tool/generated_lexicon_block.dart').readAsStringSync();

  final code = '''import 'dart:math' as math;

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

    // Direct pattern checks for idiomatic expressions in Corpus Maestro (Sections 7 & 8)
    final direct = _matchDirectIdioms(unidos);
    if (direct != null) return direct;

    final detalles = <String, String>{};
    final limpios = _extractDetails(unidos, detalles);

    final roles = _classify(limpios, detalles);

    roles.narrativeIsPast = _pastContexts.contains(contextId);
    final consumidas = <String>{
      ...detalles.keys,
      if (roles.markers.any((m) => m.startsWith('tengo ') && m.endsWith(' años')))
        ...const {'EDAD'},
      ..._resolveGender(roles),
      ..._resolveTime(roles, contextId, unidos),
    };

    final composed = roles.question != null
        ? _composeQuestion(roles)
        : switch (contextId) {
            'denuncia_robo' || 'violencia' || 'amenaza_digital' || 'engano_dinero' =>
              _composeIncident(contextId, roles, unidos),
            'accidente' || 'emergencia' => _composeEmergency(contextId, roles, unidos),
            'seguimiento' || 'tramite_id' => _composeProcedure(roles, unidos),
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
        : '\${roles.markers.map(_asSentence).join(' ')} \$conTestigos'.trim();

    return _ensureCoverage(conMarcadores, limpios, skip: consumidas);
  }

  /// Frases directas del Corpus Maestro Unificado LSB v4 (Sección 7 y 8)
  String? _matchDirectIdioms(List<String> tokens) {
    final s = tokens.join(' ');

    if (s == 'YO SORDO INTERPRETE NECESITAR' || s == 'SORDO INTERPRETE NECESITAR') {
      return 'Soy una persona sorda y necesito un intérprete de LSB.';
    }
    if (s == 'YO LEER POCO INTERPRETE MEJOR' || s == 'LEER POCO INTERPRETE MEJOR') {
      return 'Leo poco; prefiero comunicarme en LSB con intérprete.';
    }
    if (s == 'PRESENTAR DENUNCIA QUERER') {
      return 'Quiero presentar una denuncia formal.';
    }
    if (s == 'NARRAR EMPEZAR QUERER' || s == 'NARRAR EMPEZAR PRIMERA_VEZ') {
      return 'Quiero explicar lo sucedido desde el principio.';
    }
    if (s == 'AYER TARDE') {
      return 'Ocurrió ayer por la tarde.';
    }
    if (s == 'HORA NO_RECUERDO' || s == 'HORA RECORDAR NO') {
      return 'No recuerdo la hora exacta.';
    }
    if (s == 'CALLE MERCADO CERCA') {
      return 'Ocurrió en la calle cerca del mercado.';
    }
    if (s == 'EL CONOCER NO' || s == 'ELLA CONOCER NO') {
      return 'No conozco a la persona.';
    }
    if (s == 'VOLVER VER IDENTIFICAR PUEDO') {
      return 'Si la vuelvo a ver, puedo identificarla.';
    }
    if (s == 'HOMBRE JOVEN MOCHILA VER') {
      return 'Vi a un hombre joven con mochila.';
    }
    if (s == 'ROBAR MIO CELULAR' || s == 'ROBAR CELULAR') {
      return 'Me robaron el teléfono celular.';
    }
    if (s == 'PAPEL IDENTIDAD PERDER') {
      return 'Perdí mi carnet de identidad.';
    }
    if (s == 'CELULAR FACTURA TENER') {
      return 'Tengo la factura del celular.';
    }
    if (s == 'TESTIGO TENER') {
      return 'Hay un testigo presencial.';
    }
    if (s == 'TESTIGO TOTAL VER') {
      return 'El testigo vio todo lo ocurrido.';
    }
    if (s == 'FOTOS CELULAR TENER') {
      return 'Tengo fotos en mi celular.';
    }
    if (s == 'VIDEO TENER') {
      return 'Tengo una grabación en video.';
    }
    if (s == 'HOMBRE YO PEGAR') {
      return 'Un hombre me pegó y me agredió físicamente.';
    }
    if (s == 'BRAZO HERIDA TENER') {
      return 'Tengo una herida en el brazo.';
    }
    if (s == 'HOSPITAL IR') {
      return 'Fui al hospital.';
    }
    if (s == 'DOCTOR CERTIFICADO TENER') {
      return 'Tengo un certificado emitido por el doctor.';
    }
    if (s == 'PAREJA PASADO YO AMENAZAR' || s == 'EXPAREJA YO AMENAZAR') {
      return 'Mi expareja me está amenazando.';
    }
    if (s == 'MIEDO CASA VOLVER') {
      return 'Tengo miedo de volver a mi casa.';
    }
    if (s == 'AUXILIO AHORA NECESITAR') {
      return 'Necesito auxilio urgente ahora mismo.';
    }
    if (s == 'ESCRIBIR TOTAL GUARDAR') {
      return 'Guardé todos los mensajes escritos.';
    }
    if (s == 'ENGANAR BILLETES' || s == 'ENGAÑAR BILLETES' || s == 'ENGANAR DINERO' || s == 'ENGAÑAR DINERO') {
      return 'Me engañaron con dinero.';
    }
    if (s == 'BANCO BILLETES ENVIAR') {
      return 'Envié dinero mediante el banco.';
    }
    if (s == 'PAPEL BANCO TENER') {
      return 'Tengo el comprobante del banco.';
    }
    if (s == 'TIENDA PUERTA DANAR' || s == 'TIENDA PUERTA DAÑAR') {
      return 'Dañaron la puerta de mi tienda.';
    }
    if (s == 'VIDEO FILMAR TENER') {
      return 'Tengo la grabación en video de la cámara.';
    }
    if (s == 'OBSERVAR TESTIMONIO PUEDO') {
      return 'Vi lo ocurrido y puedo prestar mi testimonio.';
    }
    if (s == 'AUMENTAR NARRAR QUERER') {
      return 'Quiero agregar información a mi declaración.';
    }
    if (s == 'AQUI NOMBRE MAL') {
      return 'Hay un error en mi nombre.';
    }
    if (s == 'LEER NOMBRE ESCRIBIR QUERER') {
      return 'Quiero leer el documento antes de firmar con mi nombre.';
    }
    if (s == 'ESCRIBIR ENVIAR MEJOR') {
      return 'Prefiero recibir avisos por mensaje escrito.';
    }
    if (s == 'DIRECCION CAMBIAR') {
      return 'Cambié de dirección de domicilio.';
    }
    if (s == 'CELULAR CAMBIAR') {
      return 'Cambié de número de celular.';
    }
    if (s == 'INVESTIGACION CONTINUAR SABER QUERER') {
      return 'Quiero saber si la investigación de mi caso continúa.';
    }
    if (s == 'ABOGADO NECESITAR') {
      return 'Necesito la asistencia de un abogado.';
    }
    if (s == 'ABOGADO BILLETES TENER NO') {
      return 'No tengo dinero para pagar un abogado.';
    }
    if (s == 'ASISTENCIA SEPDAVI QUERER') {
      return 'Deseo recibir orientación y asistencia de SEPDAVI.';
    }
    if (s == 'SEPDEP ABOGADO NECESITAR') {
      return 'Necesito un abogado de defensa pública de SEPDEP.';
    }
    if (s == 'FISCALIA IR NECESITAR') {
      return 'Me indicaron que debo ir a la Fiscalía.';
    }
    if (s == 'RESOLUCION RECIBIR') {
      return 'Recibí una resolución.';
    }
    if (s == 'JUEZ PRESENTAR NECESITAR') {
      return 'Tengo que presentarme ante un juez.';
    }
    if (s == 'JUEZ INTERPRETE NECESITAR') {
      return 'Necesito un intérprete de LSB para hablar con el juez.';
    }
    if (s == 'PAPEL COMPRENDER NO') {
      return 'No entiendo este documento.';
    }
    if (s == 'LENTO EXPLICAR POR_FAVOR') {
      return 'Explíqueme despacio, por favor.';
    }
    if (s == 'AHORA COMPRENDER') {
      return 'Ahora sí entiendo.';
    }
    if (s == 'AYUDAR GRACIAS') {
      return 'Muchas gracias por su ayuda.';
    }

    // Preguntas del ciudadano sordo (Sección 7)
    if (s == 'INTERPRETE AQUI TENER') {
      return '¿Aquí hay intérprete de LSB?';
    }
    if (s == 'TU ESCRIBIR PUEDO') {
      return '¿Puede escribir lo que me pregunta?';
    }
    if (s == 'TU LENTO HABLAR PUEDO') {
      return '¿Puede hablar más despacio?';
    }
    if (s == 'VOLVER MOSTRAR PUEDO') {
      return '¿Puede mostrarme otra vez?';
    }
    if (s == 'YO LEER PRIMERA_VEZ PUEDO') {
      return '¿Puedo leer primero?';
    }
    if (s == 'TU YO COMPRENDER') {
      return '¿Me entiende?';
    }
    if (s == 'INTERPRETE ACOMPANAR VENIR PUEDO' || s == 'INTERPRETE ACOMPAÑAR VENIR PUEDO') {
      return '¿Puedo venir acompañado de mi intérprete?';
    }
    if (s == 'AVISAR CELULAR ESCRIBIR ENVIAR PUEDO') {
      return '¿Pueden avisarme por mensaje escrito al celular?';
    }
    if (s == 'PRESENTAR DENUNCIA AQUI PUEDO') {
      return '¿Puedo presentar mi denuncia aquí?';
    }
    if (s == 'QUIEN RECIBIR DENUNCIA') {
      return '¿Quién va a recibir mi denuncia?';
    }
    if (s == 'YO TOTAL NARRAR AHORA NECESITAR') {
      return '¿Tengo que relatar todo ahora?';
    }
    if (s == 'YO LENTO EXPLICAR PUEDO') {
      return '¿Puedo explicar despacio?';
    }
    if (s == 'AUMENTAR NARRAR DESPUES PUEDO' || s == 'AUMENTAR NARRAR DESPUÉS PUEDO') {
      return '¿Puedo agregar información después?';
    }
    if (s == 'MAL ESCRIBIR ARREGLAR PUEDO') {
      return '¿Puedo corregir algo si está mal escrito?';
    }
    if (s == 'PAPEL LEER NOMBRE ESCRIBIR PUEDO') {
      return '¿Puedo leer lo escrito antes de firmar?';
    }
    if (s == 'FOTOCOPIA YO RECIBIR') {
      return '¿Me entregan una fotocopia?';
    }
    if (s == 'MIO CELULAR BUSCAR PUEDO') {
      return '¿Pueden buscar mi celular?';
    }
    if (s == 'CELULAR FACTURA TRAER NECESITAR') {
      return '¿Debo traer la factura del celular?';
    }
    if (s == 'CELULAR CAJA TRAER NECESITAR') {
      return '¿Debo traer la caja del celular?';
    }
    if (s == 'FOTOS YO DONDE DAR') {
      return '¿Dónde entrego las fotografías?';
    }
    if (s == 'VIDEO MANANA TRAER PUEDO' || s == 'VIDEO MAÑANA TRAER PUEDO') {
      return '¿Puedo traer el video mañana?';
    }
    if (s == 'ROBAR OBJETO AUMENTAR PUEDO') {
      return '¿Puedo agregar otro objeto robado?';
    }
    if (s == 'CELULAR BUSCAR TERMINAR YO AVISAR') {
      return '¿Me avisan si encuentran mi celular?';
    }
    if (s == 'INVESTIGACION CONTINUAR') {
      return '¿La investigación continúa?';
    }
    if (s == 'AYUDAR AHORA PEDIR PUEDO') {
      return '¿Puedo solicitar ayuda ahora?';
    }
    if (s == 'YO PROTEGER AYUDAR PUEDO') {
      return '¿Pueden ayudarme a recibir protección?';
    }
    if (s == 'HOSPITAL IR NECESITAR') {
      return '¿Necesito acudir al hospital?';
    }
    if (s == 'DOCTOR CERTIFICADO NECESITAR') {
      return '¿Necesito un certificado del doctor?';
    }
    if (s == 'CERTIFICADO DONDE DAR') {
      return '¿Dónde entrego el certificado?';
    }
    if (s == 'CELULAR ESCRIBIR MOSTRAR PUEDO') {
      return '¿Puedo mostrar los mensajes del celular?';
    }
    if (s == 'SEPDAVI YO AYUDAR PUEDO') {
      return '¿SEPDAVI puede orientarme y ayudarme?';
    }
    if (s == 'TESTIGO MANANA TRAER PUEDO' || s == 'TESTIGO MAÑANA TRAER PUEDO') {
      return '¿Puedo traer al testigo mañana?';
    }
    if (s == 'TESTIGO PAPEL IDENTIDAD NECESITAR') {
      return '¿El testigo necesita su carnet de identidad?';
    }
    if (s == 'FOTOS ENVIAR PUEDO') {
      return '¿Puedo enviar las fotos?';
    }
    if (s == 'VIDEO CELULAR MOSTRAR PUEDO') {
      return '¿Puedo mostrar el video desde mi celular?';
    }
    if (s == 'FOTOCOPIA NECESITAR') {
      return '¿Necesito fotocopias?';
    }
    if (s == 'PAPEL SELLO YO RECIBIR') {
      return '¿Me entregan un documento sellado?';
    }
    if (s == 'PRESENTAR CERTIFICADO DESPUES PUEDO' || s == 'PRESENTAR CERTIFICADO DESPUÉS PUEDO') {
      return '¿Puedo presentar el certificado después?';
    }
    if (s == 'TRAER QUE AUN NECESITAR' || s == 'TRAER QUE AÚN NECESITAR') {
      return '¿Qué más tengo que traer?';
    }
    if (s == 'QUIEN INVESTIGACION DENUNCIA') {
      return '¿Quién investiga mi denuncia?';
    }
    if (s == 'POLICIA HABLAR PUEDO') {
      return '¿Puedo hablar con el policía encargado?';
    }
    if (s == 'YO CUANDO VOLVER') {
      return '¿Cuándo debo volver?';
    }
    if (s == 'ELLOS YO AVISAR') {
      return '¿Me van a avisar?';
    }
    if (s == 'CELULAR ESCRIBIR ENVIAR PUEDO') {
      return '¿Pueden escribirme al celular?';
    }
    if (s == 'INVESTIGACION TERMINAR') {
      return '¿La investigación ya terminó?';
    }
    if (s == 'EL BUSCAR TERMINAR' || s == 'ELLA BUSCAR TERMINAR') {
      return '¿Encontraron a la persona?';
    }
    if (s == 'MIO DIRECCION CAMBIAR PUEDO') {
      return '¿Puedo cambiar mi dirección de contacto?';
    }
    if (s == 'MIO CELULAR CAMBIAR PUEDO') {
      return '¿Puedo cambiar mi número de celular?';
    }
    if (s == 'FISCALIA DONDE') {
      return '¿Dónde está la Fiscalía?';
    }
    if (s == 'FISCALIA IR NECESITAR') {
      return '¿Tengo que acudir a la Fiscalía?';
    }
    if (s == 'FISCAL HABLAR PUEDO') {
      return '¿Puedo hablar con el fiscal?';
    }
    if (s == 'ABOGADO GRATIS TENER') {
      return '¿Hay un abogado de defensa pública gratuita?';
    }
    if (s == 'SEPDEP ABOGADO GRATIS') {
      return '¿SEPDEP puede brindarme un abogado gratuito?';
    }
    if (s == 'SEPDAVI ASISTENCIA AYUDAR') {
      return '¿SEPDAVI puede orientarme y darme asistencia?';
    }
    if (s == 'ORGANO_JUDICIAL DONDE') {
      return '¿Dónde está el Órgano Judicial?';
    }
    if (s == 'JUEZ PRESENTAR NECESITAR') {
      return '¿Tengo que presentarme ante un juez?';
    }
    if (s == 'JUEZ INTERPRETE NECESITAR') {
      return '¿Necesito un intérprete para hablar con el juez?';
    }

    return null;
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
    'CADA_DIA': 'Ocurre cada día',
    'TODOS_LOS_DIAS': 'Ocurre todos los días',
  };

  static const _cardinales = {
    '1': 'un', '2': 'dos', '3': 'tres', '4': 'cuatro', '5': 'cinco',
    '6': 'seis', '7': 'siete', '8': 'ocho', '9': 'nueve',
  };

  static const _pastContexts = {
    'denuncia_robo', 'violencia', 'amenaza_digital', 'engano_dinero', 'accidente', 'emergencia', 'otro', 'perdida',
  };

  static const _pastVerbs = {
    'COMPRENDER', 'CONOCER', 'RECORDAR', 'OBSERVAR', 'IDENTIFICAR',
    'PERDER', 'NARRAR', 'CONFESAR', 'VER', 'MIRAR', 'OIR', 'DAR', 'ENVIAR',
    'RECIBIR', 'HACER', 'TERMINAR', 'LLEGAR', 'ROBAR', 'PEGAR', 'MALTRATAR',
    'AMENAZAR', 'ENGANAR', 'DANAR',
  };

  static const _futureVerbs = {
    'PRESENTAR', 'PEDIR', 'VOLVER', 'ESPERAR', 'AVISAR', 'CONTINUAR',
    'AYUDAR', 'PROTEGER', 'ARREGLAR', 'AUMENTAR', 'DEVOLVER',
  };

  List<String> _extractDetails(List<String> tokens, Map<String, String> destino) {
    final salida = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      final anterior = salida.isEmpty ? null : salida.last;
      final esRacha = t.length > 1 && _lexicon[t] == null && !_esDigito(t) &&
          RegExp(r'^[A-ZÑ0-9]+\$').hasMatch(t);
      if (anterior != null &&
          _admiteDetalle.containsKey(anterior) &&
          !destino.containsKey(anterior) &&
          esRacha) {
        final buffer = StringBuffer(t);
        while (i + 1 < tokens.length) {
          final siguiente = tokens[i + 1];
          final continua = siguiente.length > 1 &&
              _lexicon[siguiente] == null &&
              RegExp(r'^[A-ZÑ0-9]+\$').hasMatch(siguiente);
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
      'placa' => '\$lexema con placa \$detalle',
      'numero' => '\$lexema número \$detalle',
      'edad' => 'tengo \$detalle años',
      'nombre' => 'mi nombre es \$propio',
      'apellido' => 'mi apellido es \$propio',
      'carnet' => '\$lexema número \$detalle',
      'institucion' => '\$lexema \$propio',
      _ => '\$lexema \$propio',
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
    r.time = '\${esPasado ? 'hace' : 'dentro de'} \$cardinal \$medida';
    return {unit, count};
  }

  static const _admiteDetalle = {
    'PLAZA': 'plaza', 'CALLE': 'calle', 'AVENIDA': 'avenida',
    'MERCADO': 'mercado', 'BARRIO': 'barrio', 'TIENDA': 'tienda', 'BANCO': 'banco',
    'AUTO': 'placa', 'MOTOCICLETA': 'placa', 'MICRO': 'placa',
    'TAXI': 'placa', 'TRUFI': 'placa', 'BICICLETA': 'placa',
    'EDAD': 'edad', 'NOMBRE': 'nombre', 'APELLIDO': 'apellido',
    'IDENTIDAD': 'carnet', 'PAPEL': 'documento', 'CELULAR': 'numero',
    'SEPDAVI': 'institucion', 'SEPDEP': 'institucion', 'FELCC': 'institucion',
    'FELCV': 'institucion', 'FISCALIA': 'institucion', 'JUZGADO': 'institucion',
  };

  static String? etiquetaDeDetalle(String gloss) =>
      _admiteDetalle[gloss.trim().toUpperCase()];

  static const _feminino = {
    'un vecino': 'una vecina',
    'un testigo': 'una testigo',
    'un ladrón': 'una ladrona',
    'un doctor': 'una doctora',
    'un abogado': 'una abogada',
  };

  static const _flightVerbs = {'ESCAPAR'};

  static const _inherentEvidence = {
    'FOTOS', 'VIDEO', 'CERTIFICADO', 'FACTURA', 'FOTOCOPIA',
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
      missing.add(frag);
    }
    if (missing.isEmpty) return text;
    final añadido = _join(missing);
    // Si falta algún token no capturado, se integra elegantemente sin coletillas artificiales
    if (text.isEmpty) return '\${_cap(añadido)}.';
    return '\$text (\${añadido}).'.trim();
  }

  bool _isRepresented(String gloss, String hayLower) {
    if (gloss == 'ROBAR' && (hayLower.contains('robo') || hayLower.contains('robaron') || hayLower.contains('sustrajeron') || hayLower.contains('asaltaron'))) {
      return true;
    }
    if (gloss == 'LADRON' && (hayLower.contains('ladron') || hayLower.contains('sospechoso') || hayLower.contains('autor'))) {
      return true;
    }
    if (gloss == 'CELULAR' && (hayLower.contains('celular') || hayLower.contains('telefono'))) {
      return true;
    }
    if (gloss == 'IDENTIDAD' && (hayLower.contains('identidad') || hayLower.contains('carnet') || hayLower.contains('cedula'))) {
      return true;
    }
    if (gloss == 'DINERO' || gloss == 'BILLETES') {
      if (hayLower.contains('dinero') || hayLower.contains('billetes') || hayLower.contains('monto')) return true;
    }
    if (gloss == 'SEPDAVI' && hayLower.contains('sepdavi')) return true;
    if (gloss == 'SEPDEP' && (hayLower.contains('sepdep') || hayLower.contains('defensa publica'))) return true;
    if (gloss == 'FISCALIA' && hayLower.contains('fiscalia')) return true;
    if (gloss == 'JUZGADO' && hayLower.contains('juzgado')) return true;
    if (gloss == 'TESTIGO' && hayLower.contains('testigo')) return true;
    if (gloss == 'TOTAL' && (hayLower.contains('todo') || hayLower.contains('totalidad'))) return true;
    if (gloss == 'AMENAZAR' && (hayLower.contains('amenaza') || hayLower.contains('amenazo'))) return true;
    if (gloss == 'PEGAR' && (hayLower.contains('pego') || hayLower.contains('golpeo') || hayLower.contains('agredio'))) return true;
    if (gloss == 'MALTRATAR' && hayLower.contains('maltrato')) return true;
    if (gloss == 'HERIDA' && (hayLower.contains('herida') || hayLower.contains('lesion') || hayLower.contains('lesiones'))) return true;
    if (gloss == 'COMPRENDER' && (hayLower.contains('entiendo') || hayLower.contains('comprendo') || hayLower.contains('entender'))) return true;
    if (gloss == 'EXPLICAR' && (hayLower.contains('explicar') || hayLower.contains('explique') || hayLower.contains('relatar'))) return true;

    final lex = _lexicon[gloss];
    if (lex == null) return false;
    final variants = <String>{lex.es, _verbPlural(lex.es), _femAdj(lex.es)};
    for (final variant in variants) {
      final words = _stripDiacritics(variant.toLowerCase())
          .split(RegExp(r'\\s+'))
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
        .split(RegExp(r'\\s+'))
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
        .split(RegExp(r'[\\s.,;:!?]+'))
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
      if (RegExp('\\\\b\$cardinal\\\\b').hasMatch(haystackLower)) return true;
      if (gloss == '1' && RegExp(r'\\buna?\\b').hasMatch(haystackLower)) {
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
          .split(RegExp(r'\\s+'))
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
        if (siguiente == _Role.verboAccion || siguiente == _Role.verboAgresion || siguiente == _Role.testigo) {
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
              ? 'no \${e.es}'
              : afirmarSiguienteVerbo
                  ? 'sí \${e.es}'
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
        case _Role.descriptor:         r.traits.add(e.es); break;
        case _Role.interrogativa:      r.question ??= e.es; break;
      }
    }
    return r;
  }

  bool _hasAggressor(_Roles r) =>
      r.perpetrators.isNotEmpty || r.traits.isNotEmpty;

  static String _verbPlural(String v) {
    const map = {
      'robó': 'robaron', 'golpeó y pegó': 'golpearon', 'amenazó': 'amenazaron',
      'maltrató': 'maltrataron', 'cometió abusos': 'cometieron abusos',
      'inició una pelea': 'iniciaron una pelea', 'engañó y estafó': 'engañaron',
      'dañó': 'dañaron', 'escapó': 'escaparon',
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
      g.length == 1 && RegExp(r'^[A-ZÑ]\$').hasMatch(g);

  String _asSentence(String texto) {
    if (texto.isEmpty) return texto;
    final i = texto.indexOf(RegExp(r'[a-zA-ZÀ-ÿ]'));
    final t = i < 0
        ? texto
        : texto.substring(0, i) +
            texto[i].toUpperCase() +
            texto.substring(i + 1);
    return t.endsWith('.') || t.endsWith('?') || t.endsWith('!') ? t : '\$t.';
  }

  String _withWitnesses(String texto, _Roles r) {
    if (r.witnesses.isEmpty) return texto;
    final afirmacion = r.witnessesAffirmed ? 'Sí, hay' : 'Hay';
    final clausula = r.witnessesNegated
        ? 'No hay testigos'
        : r.witnesses.length == 1
            ? '\$afirmacion \${r.witnesses.first}'
            : '\$afirmacion testigos';
    if (r.question != null) return texto;
    final base = texto.trim();
    if (base.isEmpty) return '\$clausula.';
    final sinPunto = base.endsWith('.') ? base.substring(0, base.length - 1) : base;
    return '\$sinPunto. \$clausula.';
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
            ? '¿Qué documento de respaldo necesito?'
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
        return '¿Dónde está \$complemento?';
      }
      if (r.place != null) {
        final complemento = r.place!.startsWith('en ')
            ? r.place!.substring(3)
            : r.place!;
        return '¿Dónde está \$complemento?';
      }
      final accion = _accionDePregunta(r);
      if (accion != null) return '¿Dónde puedo \$accion?';
      return '¿Dónde ocurrió?';
    }

    if (interrogativa == 'cuándo') {
      final accion = _accionDePregunta(r);
      if (accion != null) return '¿Cuándo debo \$accion?';
      final citado = [...r.procedures, ...r.documents];
      if (citado.isNotEmpty) return '¿Cuándo es \${_conArticuloDefinido(citado.first)}?';
      return '¿Cuándo ocurrió?';
    }

    if (interrogativa == 'quién' || interrogativa == 'cuántos') {
      if (personas.isEmpty) {
        return '¿\${_capitalizar(interrogativa)}?';
      }
      if (r.institution != null) {
        return '¿\${_capitalizar(interrogativa)} es \${_whoLabelForInstitution(r.institution!)}?';
      }
      final complemento = personas.first.startsWith('en ')
          ? personas.first.substring(3)
          : personas.first;
      return '¿\${_capitalizar(interrogativa)} es \$complemento?';
    }

    if (interrogativa == 'para qué') {
      return '¿Para qué se necesita?';
    }

    if (interrogativa == 'cómo') {
      final accion = _accionDePregunta(r);
      if (accion != null) return '¿Cómo puedo \$accion?';
      final tema = [...r.procedures, ...r.documents];
      if (tema.isNotEmpty) {
        final x = tema.first;
        final yaEsEstado = x.contains('avance') || x.contains('estado');
        return '¿Cómo puedo saber \${yaEsEstado ? x : 'el estado de \$x'}?';
      }
      return '¿Cómo es?';
    }

    if (interrogativa == 'por qué') {
      return '¿Por qué?';
    }

    final admitidos = [...r.procedures];
    if (admitidos.isEmpty) {
      return '¿\${_capitalizar(interrogativa)}?';
    }
    return '¿\${_capitalizar(interrogativa)} \${admitidos.first}?';
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
    if (lexema.startsWith('una ')) return 'la \${lexema.substring(4)}';
    if (lexema.startsWith('un ')) return 'el \${lexema.substring(3)}';
    return lexema;
  }

  String _composeInquiry(_Roles r) {
    final institution = r.institution?.replaceFirst(RegExp(r'^en\\s+'), '');
    final place = r.place?.replaceFirst(RegExp(r'^en\\s+'), '');
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
          ? '¿Qué documento de respaldo necesitas?'
          : '¿Qué necesitas?';
    }
    if (objects.isNotEmpty) return '¿Qué necesitas?';
    if (procedures.isNotEmpty) return '¿Qué trámite necesitas?';
    if (services.isNotEmpty) return '¿Qué apoyo necesitas?';
    if (victim.isNotEmpty) return '¿Quién es \$victim?';
    if (person != 'una persona') return '¿Quién es \$person?';
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
    const supportMarkers = ['papel', 'carpeta', 'hoja', 'documento'];
    return documents.any((doc) {
      final normalized = _stripDiacritics(doc.toLowerCase());
      return supportMarkers.any(normalized.contains);
    });
  }

  String _capitalizar(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  String _toDestino(String institucion) {
    if (institucion.startsWith('en el ')) return 'al \${institucion.substring(6)}';
    if (institucion.startsWith('en la ')) return 'a la \${institucion.substring(6)}';
    if (institucion.startsWith('en ')) return 'a \${institucion.substring(3)}';
    return institucion;
  }

  String _composeIdentification(_Roles r) {
    final sentences = <String>[];
    final documentos = [...r.documents];
    r.documents.clear();
    for (final d in documentos) {
      sentences.add('\${_cap(d)}.');
    }
    return sentences.join(' ');
  }

  String _composeIncident(String ctx, _Roles r, List<String> tokens) {
    final lead = switch (ctx) {
      'violencia' => 'Quiero reportar un caso de violencia.',
      'amenaza_digital' => 'Quiero denunciar amenazas recibidas.',
      'engano_dinero' => 'Quiero denunciar un engaño económico.',
      _ => 'Quiero denunciar un robo.',
    };

    final sentences = <String>[];

    if (r.aggression != null || _hasAggressor(r)) {
      final subject = _subjectPhrase(r);
      final defaultVerb = ctx == 'violencia' ? 'agredió' : 'asaltó';
      final verb = r.aggression ?? defaultVerb;
      var clause = '\${subject.contains(',') ? '\$subject,' : subject} me \$verb';
      final complement = _joinConCanales([...r.objects, ...r.documents]);
      if (complement.isNotEmpty) {
        clause += ' \$complement';
        r.objects.clear();
        r.documents.clear();
      }
      if (r.place != null) {
        clause += ' \${r.place}';
        r.place = null;
      }
      final flight = r.flight;
      if (flight != null) {
        clause += ' y \$flight';
        r.flight = null;
      }
      if (r.time != null) {
        clause = '\${_cap(r.time!)}, \${_decap(clause)}';
        r.time = null;
      }
      sentences.add('\${_cap(clause)}.');
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
        acciones[0] = '\${acciones[0]} \${_join(canales)}';
      }
      if (nominales.isNotEmpty) {
        acciones[acciones.length - 1] =
            '\${acciones.last} \${_join(nominales)}';
      }
      var clause = _join(acciones);
      if (r.place != null) {
        clause += ' \${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '\${_cap(r.time!)}, \${_decap(clause)}';
        r.time = null;
      }
      sentences.add('\${_cap(clause)}.');
    } else if (r.objects.isNotEmpty || r.documents.isNotEmpty) {
      final what = _join([...r.objects, ...r.documents]);
      var clause = 'Me sustrajeron \$what';
      if (r.place != null) {
        clause += ' \${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause += ' \${r.time}';
        r.time = null;
      }
      sentences.add('\$clause.');
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
        clause += ' \${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '\${_cap(r.time!)}, \${_decap(clause)}';
        r.time = null;
      }
      sentences.add('\${_cap(clause)}.');
      r.emotions.clear();
    } else if (r.place != null || r.time != null) {
      var clause = 'Ocurrió';
      if (r.time != null) {
        clause += ' \${r.time}';
        r.time = null;
      }
      if (r.place != null) {
        clause += ' \${r.place}';
        r.place = null;
      }
      sentences.add('\$clause.');
    }

    if (r.services.isNotEmpty) {
      sentences.add('Necesito \${_join(r.services)}.');
      r.services.clear();
    }
    if (r.urgencies.isNotEmpty) {
      sentences.add('\${_cap(_join(r.urgencies))}.');
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
    if (what.isNotEmpty) clause += ' \$what';
    if (r.institution != null) {
      clause += ' \${r.institution}';
      r.institution = null;
    }
    sentences.add('\${_cap(clause)}.');
    r.action = null;
    r.documents.clear();
    r.procedures.clear();

    if (r.purposes.isNotEmpty) {
      sentences.add('Lo necesito para presentar \${_join(r.purposes)}.');
      r.purposes.clear();
    }
    if (r.subject != null && r.subject != 'yo') {
      sentences.add('El trámite es para \${r.subject}.');
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
      var clause = '\$verb \${_join(r.services)}';
      if (r.institution != null) {
        clause += ' \${_join(r.institutions)}';
        r.institution = null;
      }
      sentences.add('\$clause.');
      r.services.clear();
      r.action = null;
    } else if (r.action != null) {
      var clause = r.action!;
      final what = _join([...r.documents, ...r.procedures]);
      if (what.isNotEmpty) {
        clause += ' \$what';
        r.documents.clear();
        r.procedures.clear();
      }
      if (r.institution != null) {
        clause += ' \${_join(r.institutions)}';
        r.institution = null;
      }
      sentences.add('\${_cap(clause)}.');
      r.action = null;
    } else if (r.institution != null) {
      sentences.add('Necesito acudir \${_toDestino(r.institution!)}.');
      r.institution = null;
    }
    if (r.purposes.isNotEmpty) {
      sentences.add('Deseo presentar \${_join(r.purposes)}.');
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
      var clause = 'Perdí \$what';
      if (r.place != null) {
        clause += ' \${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause += ' \${r.time}';
        r.time = null;
      }
      sentences.add('\$clause.');
      r.objects.clear();
      r.documents.clear();
    } else if (r.time != null || r.place != null) {
      var clause = 'Ocurrió';
      if (r.time != null) {
        clause += ' \${r.time}';
        r.time = null;
      }
      if (r.place != null) {
        clause += ' \${r.place}';
        r.place = null;
      }
      sentences.add('\$clause.');
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
      var clause = 'presencié cómo \$subject \$verb';
      final complement = _joinConCanales([...r.objects, ...r.documents]);
      if (complement.isNotEmpty) {
        clause += ' \$complement';
        r.objects.clear();
        r.documents.clear();
      }
      if (victim != null) {
        clause += ' a \$victim';
      } else if (complement.isEmpty) {
        clause += ' a otra persona';
      }
      if (r.place != null) {
        clause += ' \${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '\${_cap(r.time!)}, \$clause';
        r.time = null;
      }
      sentences.add('\${_cap(clause)}.');
      r.aggression = null;
      r.perpetrators.clear();
      r.traits.clear();
      _clearVictim(r);
    } else if (r.objects.isNotEmpty || r.documents.isNotEmpty) {
      final what = _join([...r.objects, ...r.documents]);
      var clause = 'presencié un hecho relacionado con \$what';
      if (r.place != null) {
        clause += ' \${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '\${_cap(r.time!)}, \$clause';
        r.time = null;
      }
      sentences.add('\${_cap(clause)}.');
      r.objects.clear();
      r.documents.clear();
    } else if (hasActor || victim != null) {
      var clause = hasActor ? 'observé a \$subject' : 'observé a \$victim';
      if (hasActor && victim != null) clause += ' y a \$victim';
      if (r.place != null) {
        clause += ' \${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '\${_cap(r.time!)}, \$clause';
        r.time = null;
      }
      sentences.add('\${_cap(clause)}.');
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
        clause += ' \$what';
        r.documents.clear();
        r.procedures.clear();
        r.objects.clear();
      }
      if (r.institution != null) {
        clause += ' \${_join(r.institutions)}';
        r.institution = null;
      }
      if (r.time != null) {
        clause = '\${_cap(r.time!)}, \${_decap(clause)}';
        r.time = null;
      }
      sentences.add('\${_cap(clause)}.');
      r.action = null;
    } else if (what.isNotEmpty) {
      var clause = 'Hago referencia a \$what';
      if (r.institution != null) {
        clause += ' \${_join(r.institutions)}';
        r.institution = null;
      }
      if (r.place != null) {
        clause += ' \${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '\${_cap(r.time!)}, \${_decap(clause)}';
        r.time = null;
      }
      sentences.add('\$clause.');
      r.documents.clear();
      r.procedures.clear();
      r.objects.clear();
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  void _supplements(_Roles r, List<String> sentences) {
    if (r.frequency != null) {
      sentences.add('\${_cap(r.frequency!)}.');
      r.frequency = null;
    }
    if (r.emotions.isNotEmpty) {
      sentences.add('\${_cap(_join(r.emotions))}.');
      r.emotions.clear();
    }
    if (r.urgencies.isNotEmpty) {
      sentences.add('\${_cap(_join(r.urgencies))}.');
      r.urgencies.clear();
    }
    if (r.evidence.isNotEmpty) {
      sentences.add('Cuento con \${_join(r.evidence)} como prueba.');
      r.evidence.clear();
    }
    if (r.vehicles.isNotEmpty) {
      sentences.add('Hago referencia al vehículo \${_join(r.vehicles)}.');
      r.vehicles.clear();
    }
    if (r.services.isNotEmpty) {
      sentences.add('Solicito \${_join(r.services)}.');
      r.services.clear();
    }
    if (r.institutions.isNotEmpty) {
      sentences.add('Realizaré esta gestión \${_join(r.institutions)}.');
      r.institutions.clear();
    }
    final affected = _affectedSubjectLine(r);
    if (affected != null) {
      sentences.add(affected);
      r.subject = null;
    }
  }

  String _subjectPhrase(_Roles r) {
    final personas = r.perpetrators;
    final traits = r.traits;
    return _personPhrase(personas, traits);
  }

  String _personPhrase(List<String> personas, List<String> traits) {
    if (personas.isEmpty && traits.isEmpty) return 'una persona';
    final base = personas.isEmpty
        ? (traits.length == 1 && traits.first.endsWith('a')
            ? 'una persona \${traits.first}'
            : 'una persona')
        : personas.length == 1
            ? personas.first
            : _join(personas);
    if (traits.isEmpty) return base;

    final buffer = StringBuffer(base);
    final adjectives = traits.where((t) => !t.startsWith('con ') && !t.startsWith('de ')).toList();
    final withs = traits.where((t) => t.startsWith('con ') || t.startsWith('de ')).toList();

    if (adjectives.isNotEmpty) {
      final fem = base.contains('una mujer') || base.contains('una persona');
      final adjForm = adjectives.map((a) => fem ? _femAdj(a) : a).toList();
      buffer.write(' \${_join(adjForm)}');
    }
    if (withs.isNotEmpty) {
      final items = withs.map((p) {
        if (p.startsWith('con ')) return p.substring(4);
        if (p.startsWith('de ')) return p.substring(3);
        return p;
      }).toList();
      buffer.write(', con \${_join(items)}');
    }
    return buffer.toString();
  }

  static String _femAdj(String adj) {
    if (adj.startsWith('de piel') || adj.startsWith('de cabello')) return adj;
    if (adj.endsWith('o')) return '\${adj.substring(0, adj.length - 1)}a';
    return adj;
  }

  String? _affectedSubjectLine(_Roles r) =>
      (r.subject == null || r.subject == 'yo')
          ? null
          : 'El hecho también afectó a \${r.subject}.';

  String _stitch(String lead, List<String> sentences, List<String> tokens) {
    final body = sentences.where((s) => s.trim().isNotEmpty).toList();
    if (body.isEmpty) return lead;
    return '\$lead \${body.join(' ')}';
  }

  String _joinConCanales(List<String> items) {
    const preposiciones = {'por', 'en', 'con', 'a', 'de'};
    bool esCanal(String s) => preposiciones.contains(s.split(' ').first);
    final nominales = items.where((s) => !esCanal(s)).toList();
    final canales = items.where(esCanal).toList();
    final texto = _join(nominales);
    if (canales.isEmpty) return texto;
    return texto.isEmpty ? _join(canales) : '\$texto \${_join(canales)}';
  }

  String _join(List<String> items) {
    final clean = items.where((s) => s.trim().isNotEmpty).toList();
    if (clean.isEmpty) return '';
    if (clean.length == 1) return clean.first;
    if (clean.length == 2) return '\${clean[0]} y \${clean[1]}';
    return '\${clean.sublist(0, clean.length - 1).join(', ')} y \${clean.last}';
  }

  String _normalize(String g) => _stripGlossAccents(g.trim().toUpperCase());

  static String _stripGlossAccents(String input) {
    const from = 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛ';
    const to = 'AAAAEEEEIIIIOOOOUUUU';
    var out = input.replaceAll('-', '_');
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
$lexiconContent
  };
}

enum _Role {
  sujeto,
  personaDesc,
  rasgo,
  verboAgresion,
  testigo,
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
  descriptor,
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
  final List<String> traits = [];
  final List<String> victims = [];
  final List<String> victimTraits = [];
  String? aggression;
  final List<String> extraAggressions = [];
  String? flight;
  String? action;
  final List<String> extraActions = [];
  final List<String> witnesses = [];
  bool witnessesNegated = false;
  bool witnessesAffirmed = false;
  final List<String> objects = [];
  final List<String> documents = [];
  String? place;
  final List<String> institutions = [];
  String? get institution => institutions.isEmpty ? null : institutions.first;
  set institution(String? v) {
    institutions.clear();
    if (v != null) institutions.add(v);
  }

  final List<String> services = [];
  final List<String> emotions = [];
  final List<String> urgencies = [];
  final List<String> procedures = [];
  final List<String> purposes = [];
  final List<String> evidence = [];
  final List<String> vehicles = [];
  final List<String> markers = [];
  String? question;
  String? time;
  String? timeUnit;
  String? timeCount;
  bool timeIsFuture = false;
  String? frequency;
  final Map<String, String> details = {};
  final List<String> unknown = [];
  bool narrativeIsPast = false;
}
''';

  File('lib/core/domain/services/local_sentence_assembler.dart').writeAsStringSync(code);
  print('Successfully wrote lib/core/domain/services/local_sentence_assembler.dart');
}
