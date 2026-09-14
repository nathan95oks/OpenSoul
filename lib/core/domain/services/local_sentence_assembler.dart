import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';

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
      // ANOS_EDAD es la misma pregunta que EDAD ("¿qué edad tiene?" / "¿cuántos
      // años tiene?"): cuando ya se afirmó la edad, la glosa sobrante no debe
      // volver a aparecer, ni siquiera en la red de seguridad "(...)".
      if (roles.markers.any((m) => m.startsWith('tengo ') && m.endsWith(' años')))
        ...const {'EDAD', 'ANOS_EDAD'},
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
        : '${roles.markers.map(_asSentence).join(' ')} $conTestigos'.trim();

    return _ensureCoverage(conMarcadores, limpios, skip: consumidas);
  }

  // ---------------------------------------------------------------------
  // Generación a partir del modelo estructurado (auditoría 2026-09).
  //
  // A diferencia de `assemble`, que clasifica una lista plana de glosas por
  // rol y adivina relaciones, este camino recibe relaciones ya explícitas
  // (qué prenda es de qué persona, qué lugar es referencia de qué, qué
  // objeto tiene qué papel) y solo tiene que redactarlas. No completa
  // acciones por contexto ni atribuye un hecho que el borrador no declaró.
  // ---------------------------------------------------------------------

  static const _neutralClothing = {
    'POLERA': 'una polera',
    'PANTALÓN': 'un pantalón',
    'PANTALON': 'un pantalón',
    'GORRA': 'una gorra',
    'CHAMARRA': 'una chamarra',
    'LENTES': 'lentes',
    'MOCHILA': 'una mochila',
    'BOLSA': 'una bolsa',
    'CAJA': 'una caja',
  };

  static const _feminineClothing = {
    'POLERA',
    'GORRA',
    'CHAMARRA',
    'BOLSA',
    'MOCHILA',
    'CAJA',
  };
  static const _pluralClothing = {'LENTES'};

  String _colorAdjFor(String concept, String colorGloss) {
    final plural = _pluralClothing.contains(concept.toUpperCase());
    final fem = _feminineClothing.contains(concept.toUpperCase());
    switch (colorGloss.toUpperCase()) {
      case 'ROJO':
        return plural ? 'rojos' : (fem ? 'roja' : 'rojo');
      case 'NEGRO':
        return plural ? 'negros' : (fem ? 'negra' : 'negro');
      case 'AZUL':
        return plural ? 'azules' : 'azul';
      case 'BLANCO':
        return plural ? 'blancos' : (fem ? 'blanca' : 'blanco');
      case 'VERDE':
        return plural ? 'verdes' : 'verde';
      case 'CAFE':
      case 'CAFÉ':
        return plural ? 'cafés' : 'café';
      case 'GRIS':
        return plural ? 'grises' : 'gris';
      case 'PLOMO':
        return plural ? 'plomos' : (fem ? 'ploma' : 'plomo');
      case 'AMARILLO':
        return plural ? 'amarillos' : (fem ? 'amarilla' : 'amarillo');
      case 'MORADO':
        return plural ? 'morados' : (fem ? 'morada' : 'morado');
      case 'NARANJA':
        return plural ? 'naranjas' : 'naranja';
      default:
        return colorGloss.toLowerCase().replaceAll('_', ' ');
    }
  }

  String _relationWord(String relation) => switch (relation.toUpperCase()) {
        'CERCA' => 'cerca',
        'LEJOS' => 'lejos',
        'DENTRO' => 'dentro',
        'FUERA' => 'fuera',
        'AL_LADO' => 'al lado',
        _ => relation.toLowerCase(),
      };

  String _personPhraseStructured(PersonEntity p) {
    final generoLex = p.gender == null ? null : _lexicon[_normalize(p.gender!)];
    final fem = generoLex?.es == 'una mujer';
    String concordar(String base) =>
        fem && base.endsWith('o') ? '${base.substring(0, base.length - 1)}a' : base;

    final traits = <String>[];
    if (p.ageApprox != null) {
      final lex = _lexicon[_normalize(p.ageApprox!)];
      if (lex != null) traits.add(concordar(lex.es));
    }
    if (p.build != null) {
      final lex = _lexicon[_normalize(p.build!)];
      if (lex != null) traits.add(lex.es);
    }
    if (p.height != null) {
      final lex = _lexicon[_normalize(p.height!)];
      if (lex != null) traits.add(concordar(lex.es));
    }

    var base = generoLex?.es ?? 'una persona';
    if (traits.isNotEmpty) base = '$base ${_join(traits)}';

    if (p.clothing.isNotEmpty) {
      final prendas = p.clothing.map((c) {
        final nombre = _neutralClothing[c.concept.toUpperCase()] ??
            c.concept.toLowerCase().replaceAll('_', ' ');
        if (c.color != null && c.colorState == ConfirmationState.confirmed) {
          return '$nombre ${_colorAdjFor(c.concept.toUpperCase(), c.color!)}';
        }
        return nombre;
      }).toList();
      base = '$base que llevaba ${_join(prendas)}';
    }
    return base;
  }

  String _objectSelfPhrase(ObjectInvolved o) {
    if (o.docType != null && o.docType!.trim().isNotEmpty) {
      final doc = o.docType!.trim();
      return doc.startsWith('Carnet') ||
              doc.startsWith('Licencia') ||
              doc.startsWith('Pasaporte') ||
              doc.startsWith('Cédula') ||
              doc.startsWith('Cedula')
          ? 'mi $doc'
          : 'un $doc';
    }
    if ((o.concept.toUpperCase() == 'BILLETES' || o.concept.toUpperCase() == 'DINERO') &&
        o.quantity != null &&
        o.quantity!.trim().isNotEmpty) {
      final unidad = (o.unit == null || o.unit!.trim().isEmpty) ? 'bolivianos' : o.unit!;
      return '${o.quantity} $unidad en billetes';
    }
    if (o.contents != null && o.contents!.trim().isNotEmpty) {
      final lex = _lexicon[_normalize(o.concept)];
      final nombre = lex?.es ?? o.concept.toLowerCase().replaceAll('_', ' ');
      return '$nombre que contenía ${o.contents!.trim()}';
    }
    final lex = _lexicon[_normalize(o.concept)];
    var base = lex?.es ?? o.concept.toLowerCase().replaceAll('_', ' ');
    if (o.detail != null && o.detail!.trim().isNotEmpty) {
      base = '$base (${o.detail!.trim()})';
    }
    return base;
  }

  String _objectNeutralPhrase(ObjectInvolved o) {
    final neutral = _neutralClothing[o.concept.toUpperCase()];
    if (neutral != null) return neutral;
    final lex = _lexicon[_normalize(o.concept)];
    var base = lex?.es ?? o.concept.toLowerCase().replaceAll('_', ' ');
    base = base.replaceFirst(RegExp(r'^(mi|mis|la|el)\s+'), '');
    return base.startsWith('un') || base.startsWith('el') || base.startsWith('la')
        ? base
        : 'un $base';
  }

  String? _locationClause(LocationInfo loc) {
    final partes = <String>[];
    if (loc.mainPlaceConcept != null) {
      final lex = _lexicon[_normalize(loc.mainPlaceConcept!)];
      var frase = lex?.es ?? loc.mainPlaceConcept!.toLowerCase();
      if (loc.isVehicleTransport && !frase.startsWith('en ')) {
        frase = frase.startsWith('un ') ? 'en el ${frase.substring(3)}' : 'en $frase';
      }
      if (loc.mainPlaceDetail != null && loc.mainPlaceDetail!.trim().isNotEmpty) {
        frase = '$frase ${loc.mainPlaceDetail!.trim()}';
      }
      partes.add(frase);
    }
    if (loc.relation != null && !loc.pending) {
      final rel = _relationWord(loc.relation!);
      String? referencia;
      if (loc.referenceType == 'home') {
        referencia = 'mi casa';
      } else if (loc.referenceLiteralText != null &&
          loc.referenceLiteralText!.trim().isNotEmpty) {
        referencia = loc.referenceLiteralText!.trim();
      } else if (loc.referenceConceptGloss != null) {
        final lex = _lexicon[_normalize(loc.referenceConceptGloss!)];
        referencia = lex?.es ?? loc.referenceConceptGloss!.toLowerCase();
      }
      if (referencia != null) partes.add('$rel de $referencia');
    }
    if (partes.isEmpty) return null;
    return ' ${_join(partes)}';
  }

  String? _timeClause(TimeInfo t) {
    if (t.unknown) return null;
    if (t.elapsedUnit != null) {
      final r = _Roles()
        ..timeUnit = _normalize(t.elapsedUnit!)
        ..timeCount = t.elapsedCount;
      _resolveTime(r, 'denuncia_robo', const []);
      if (r.time != null) return r.time;
    }
    if (t.dateOrMoment != null) {
      final lex = _lexicon[_normalize(t.dateOrMoment!)];
      if (lex != null) return lex.es;
    }
    return null;
  }

  /// Genera la declaración a partir del [DeclarationDraft] estructurado
  /// para todos los 8 contextos con gramática formal boliviana.
  String assembleStructured(DeclarationDraft d) {
    final sentences = <String>[];
    final locClause = _locationClause(d.location) ?? '';
    final timeClauseText = _timeClause(d.time);
    final timePrefix = timeClauseText == null ? '' : '${_cap(timeClauseText)}, ';

    final stolen = d.objects.where((o) => o.role == 'stolen').toList();
    final lost = d.objects.where((o) => o.role == 'lost').toList();
    final carried = d.objects.where((o) => o.role == 'carriedByOtherPerson').toList();

    final suspects = d.persons.where((p) => p.role == 'suspect').toList();
    final subjectPhrase = suspects.isEmpty
        ? 'Una persona'
        : _cap(_join(suspects.map(_personPhraseStructured).toList()));

    // Despacho por contexto y hecho
    switch (d.contextId) {
      case 'violencia':
        final agg = d.violence?.aggressionType ?? d.fact.action ?? 'agresión física';
        final aggText = agg.toLowerCase().replaceAll('_', ' ');
        sentences.add('${_cap(timePrefix)}El declarante denuncia haber sufrido $aggText$locClause.'.trim());
        break;

      case 'amenaza_digital':
        final chan = d.digitalThreat?.channel ?? 'medios digitales';
        sentences.add('${_cap(timePrefix)}El declarante refiere haber recibido amenazas a través de $chan$locClause.'.trim());
        break;

      case 'engano_dinero':
        final monto = d.fraud?.amount != null ? ' por el monto de ${d.fraud!.amount} ${d.fraud!.currency ?? "bolivianos"}' : '';
        final medio = d.fraud?.deliveryMethod != null ? ' mediante ${d.fraud!.deliveryMethod}' : '';
        sentences.add('${_cap(timePrefix)}El declarante denuncia haber sido víctima de engaño económico$monto$medio$locClause.'.trim());
        break;

      case 'seguimiento':
        sentences.add('${_cap(timePrefix)}El ciudadano consulta el estado de su trámite o investigación$locClause.'.trim());
        break;

      case 'identificacion':
        final docs = d.objects.where((o) => o.docType != null).map((o) => o.docType!).toList();
        if (docs.isNotEmpty) {
          sentences.add('El declarante presenta su ${_join(docs)}$locClause.'.trim());
        } else {
          sentences.add('El declarante se identifica ante la autoridad competente$locClause.'.trim());
        }
        break;

      case 'preguntas':
        sentences.add('¿Dónde debo realizar esta consulta o presentar el trámite?');
        break;

      case 'otro':
        if (d.inquiry?.isWitnessReport ?? true) {
          sentences.add('${_cap(timePrefix)}El declarante se presenta en calidad de testigo presencial de los hechos$locClause.'.trim());
        } else {
          sentences.add('${_cap(timePrefix)}El declarante realiza una manifestación voluntaria$locClause.'.trim());
        }
        break;

      default: // denuncia_robo
        switch (d.fact.action?.toUpperCase()) {
          case 'ROBAR':
            if (stolen.isNotEmpty) {
              final what = _join(stolen.map(_objectSelfPhrase).toList());
              sentences.add(
                '$timePrefix${_decap(subjectPhrase)} me robó $what$locClause.'
                    .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase()),
              );
            } else {
              sentences.add(
                '$timePrefix${_decap(subjectPhrase)} me robó$locClause.'
                    .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase()),
              );
            }
            break;
          case 'PERDER':
            final objetosPerdidos = lost.isNotEmpty ? lost : stolen;
            if (objetosPerdidos.isNotEmpty) {
              final what = _join(objetosPerdidos.map(_objectSelfPhrase).toList());
              sentences.add('${_cap(timePrefix)}Perdí $what$locClause.'.trim());
            } else {
              sentences.add(
                  '${_cap(timePrefix)}No sé con certeza qué ocurrió; puede que haya perdido algo$locClause.'
                      .trim());
            }
            break;
          case 'ENGAÑAR':
            sentences.add('${_cap(timePrefix)}Me engañaron$locClause.'.trim());
            break;
          case 'DAÑAR':
            final what = stolen.isNotEmpty
                ? ' ${_join(stolen.map(_objectSelfPhrase).toList())}'
                : '';
            sentences.add(
                '${_cap(timePrefix)}${_decap(subjectPhrase)} dañó$what$locClause.'
                    .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase()));
            break;
          case 'ESCAPAR':
            if (d.fact.actorRole == 'victim') {
              sentences.add(
                  '${_cap(timePrefix)}El declarante logró escapar$locClause.'.trim());
            } else if (d.fact.actorRole == 'thirdParty') {
              sentences.add(
                  '${_cap(timePrefix)}Una tercera persona escapó del lugar$locClause.'.trim());
            } else if (d.fact.actorDetail != null && d.fact.actorDetail!.isNotEmpty) {
              sentences.add(
                  '${_cap(timePrefix)}${d.fact.actorDetail} escapó$locClause.'.trim());
            } else {
              sentences.add(
                  '${_cap(timePrefix)}${_decap(subjectPhrase)} escapó$locClause.'
                      .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase()));
            }
            break;
          default:
            if (locClause.isNotEmpty || timeClauseText != null) {
              sentences.add('${_cap(timePrefix)}Ocurrió algo que quiero relatar$locClause.'.trim());
            }
        }
    }

    if (carried.isNotEmpty) {
      final what = _join(carried.map(_objectNeutralPhrase).toList());
      final quien = suspects.isEmpty ? 'La persona' : _cap(_personPhraseStructured(suspects.first));
      sentences.add('$quien llevaba $what.');
    }

    if (d.witnesses.existence == ConfirmationState.confirmed) {
      final count = d.witnesses.count;
      sentences.add(count == null || count.trim().isEmpty
          ? 'Hay testigos.'
          : 'Hay $count testigos.');
    } else if (d.witnesses.existence == ConfirmationState.negated) {
      sentences.add('No hay testigos.');
    } else if (d.witnesses.existence == ConfirmationState.uncertain) {
      sentences.add('No sé si hay testigos.');
    }

    if (d.evidence.isNotEmpty) {
      final items = d.evidence
          .where((e) => e.availability != ConfirmationState.negated)
          .map((e) => _lexicon[_normalize(e.concept)]?.es ??
              e.concept.toLowerCase().replaceAll('_', ' '))
          .toList();
      if (items.isNotEmpty) {
        sentences.add('Cuento con ${_join(items)} como prueba.');
      }
    }

    if (d.injured) {
      sentences.add(d.medicalHelpRequested
          ? 'Estoy herido y necesito atención médica.'
          : 'Estoy herido.');
    } else if (d.medicalHelpRequested) {
      sentences.add('Necesito atención médica.');
    }

    switch (d.willFileComplaint) {
      case ConfirmationState.confirmed:
        sentences.add('Quiero presentar una denuncia formal.');
        break;
      case ConfirmationState.negated:
        sentences.add('Por ahora no quiero presentar una denuncia formal.');
        break;
      default:
        break;
    }

    if (d.needsLegalSupport) {
      sentences.add('Necesito apoyo legal.');
    }

    if (d.receivingInstitution != null) {
      final lex = _lexicon[_normalize(d.receivingInstitution!)];
      final destino = lex?.es ?? d.receivingInstitution!.toLowerCase();
      sentences.add('Deseo presentar esto ante ${destino.replaceFirst('en ', '')}.');
    }

    final texto = sentences.where((s) => s.trim().isNotEmpty).join(' ');
    return texto.isEmpty
        ? 'Quiero comunicar lo siguiente, aunque todavía no completé los detalles.'
        : texto;
  }

  /// Frases directas del Corpus Maestro Unificado LSB v4 (Sección 7 y 8)
  String? _matchDirectIdioms(List<String> tokens) {
    final s = tokens.join(' ');

    if (s == 'SI CONOCER') return 'Sí conozco a esa persona.';
    if (s == 'NO CONOCER' || s == 'DESCONOCER' || s == 'EL CONOCER NO' || s == 'ELLA CONOCER NO') {
      return 'No conozco a esa persona.';
    }
    if (s == 'SI DENUNCIAR') return 'Sí quiero presentar una denuncia.';
    if (s == 'NO DENUNCIAR') return 'No quiero presentar una denuncia.';
    if (s == 'NO TESTIGO') return 'No hay testigos.';
    if (s == 'SI TESTIGO') return 'Sí, hay un testigo.';
    if (s == 'ABOGADO') return 'Necesito un abogado.';
    if (s == 'INTERPRETE') return 'Necesito un intérprete de LSB.';
    if (s == 'DONDE DENUNCIAR') return '¿Dónde puedo presentar una denuncia?';
    if (s == 'QUE FORMULARIO') return '¿Qué documentos necesito?';
    if (s == 'CUANDO VOLVER' || s == 'YO CUANDO VOLVER') return '¿Cuándo debo volver?';
    if (s == 'COMO AVANCE') return '¿Cómo puedo saber el avance de la investigación?';
    if (s == 'COMO CASO') return '¿Cómo puedo saber el estado de mi caso?';
    if (s == 'DONDE FISCALIA' || s == 'FISCALIA DONDE' || s == 'DONDE FISCAL') return '¿Dónde está la Fiscalía?';
    if (s == 'DONDE FELCC') return '¿Dónde está la FELCC?';
    if (s == 'DONDE FELCV') return '¿Dónde está la FELCV?';
    if (s == 'DONDE JUEZ') return '¿Dónde está el juzgado?';
    if (s == 'QUIEN FISCAL') return '¿Quién es el fiscal?';
    if (s == 'QUIEN POLICIA') return '¿Quién es el policía?';
    if (s == 'QUE REQUISITO') return '¿Qué trámite necesito?';
    if (s == 'QUE SOPORTE') return '¿Qué soporte necesito?';

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
    if (s == 'CALLE HOMBRE YO SEGUIR') {
      return 'Un hombre me siguió por la calle.';
    }
    if (s == 'PERSONA TIENDA ENFRENTE ESPERAR MIRAR') {
      return 'Una persona se quedó esperando frente a la tienda y me miraba.';
    }
    if (s == 'YO CASA IR ASUSTADO') {
      return 'Me fui a mi casa muy asustado.';
    }
    if (s == 'QUIERO DENUNCIAR') {
      return 'Quiero sentar una denuncia.';
    }
    if (s == 'DENUNCIA ESTADO SABER QUERER' || s == 'DENUNCIA INVESTIGACION SABER QUERER') {
      return 'Deseo saber el estado de mi denuncia.';
    }
    if (s == 'POLICIA INVESTIGACION PREGUNTAR') {
      return 'Quiero consultar con el policía a cargo de la investigación.';
    }
    if (s == 'FISCAL HABLAR QUERER') {
      return 'Quiero hablar con el fiscal.';
    }
    if (s == 'RESOLUCION FOTOCOPIA PEDIR') {
      return 'Solicito una fotocopia de la resolución.';
    }
    if (s == 'SEPDAVI ASISTENCIA PEDIR') {
      return 'Solicito asistencia y patrocinio legal a SEPDAVI.';
    }
    if (s == 'SEPDEP ABOGADO PEDIR') {
      return 'Solicito un defensor público de SEPDEP.';
    }
    if (s == 'ORGANO_JUDICIAL CITACION RECIBIR' || s == 'ÓRGANO_JUDICIAL CITACION RECIBIR') {
      return 'Recibí una citación del Órgano Judicial.';
    }
    if (s == 'JUEZ PRESENTAR NECESITAR') {
      return 'Tengo que presentarme ante un juez.';
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

  // Unidad sin cantidad ("SEMANA" sola, sin dígito detrás): la cadena queda
  // abierta y el lexema base ("semana") sale sin artículo ni deixis ("Semana,
  // una persona me robó."). Se resuelve con la forma deíctica de esa unidad,
  // que sigue siendo fiel a lo que la persona señaló sin inventar una fecha.
  static const _deicticTimeForm = {
    'MINUTO': 'este minuto', 'HORA': 'esta hora', 'DIA': 'hoy',
    'SEMANA': 'esta semana', 'MES': 'este mes', 'ANO': 'este año',
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
      'institucion' => '$lexema $propio',
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
      r.time ??= _deicticTimeForm[unit] ?? _lexicon[unit]!.es;
      return {unit};
    }

    // _cardinales solo deletrea 1-9 ("un", "dos"...): un modal de cantidad
    // ahora admite cualquier cifra (auditoría 2026-09, "hace 15 días"), y
    // 10 en adelante se escribe en dígitos, que es como se dice de todos
    // modos en español — el `!` aquí reventaba con cualquier número de dos
    // cifras.
    final cardinal = count == '1'
        ? (spec.femenino ? 'una' : 'un')
        : (_cardinales[count] ?? count);
    final medida = count == '1' ? spec.singular : spec.plural;
    final esPasado = _mirarAtras(r, contextId, tokens);
    r.timeIsFuture = !esPasado;
    r.time = '${esPasado ? 'hace' : 'dentro de'} $cardinal $medida';
    return {unit, count};
  }

  static const _admiteDetalle = {
    'PLAZA': 'plaza', 'CALLE': 'calle', 'AVENIDA': 'avenida',
    'MERCADO': 'mercado', 'BARRIO': 'barrio', 'TIENDA': 'tienda', 'BANCO': 'banco',
    'AUTO': 'placa', 'MOTOCICLETA': 'placa', 'MICRO': 'placa',
    'TAXI': 'placa', 'TRUFI': 'placa', 'BICICLETA': 'placa',
    'EDAD': 'edad', 'ANOS_EDAD': 'edad', 'NOMBRE': 'nombre', 'APELLIDO': 'apellido',
    'IDENTIDAD': 'carnet', 'CARNET': 'carnet', 'PAPEL': 'documento', 'CELULAR': 'numero',
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

  static const _flightVerbs = {'ESCAPAR', 'CORRER'};

  static const _inherentEvidence = {
    'FOTOS', 'VIDEO', 'CERTIFICADO', 'FACTURA', 'FOTOCOPIA',
    // Alias de FOTOS usado en el corpus (auditoría 2026-09): una fotografía
    // se aporta como prueba, nunca como botín.
    'FOTOGRAFIA',
    // MENSAJE/COMPROBANTE/RESPALDO/VIDEOLLAMADA ya estaban en el conjunto
    // equivalente del backend (`_INHERENT_EVIDENCE` en aws/lambda_function.py)
    // pero nunca se agregaron al lexicón de ninguno de los dos lados: sin
    // entrada, la glosa no tenía frase y en el servidor el `continue` de la
    // rama de evidencia la descartaba en silencio (auditoría 2026-09,
    // hallazgo CP-007/CP-016: "como prueba tengo un mensaje" desaparecía).
    'MENSAJE', 'COMPROBANTE', 'RESPALDO', 'VIDEOLLAMADA',
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
    final anadido = _join(missing);
    // Si falta algún token no capturado, se integra elegantemente sin coletillas artificiales
    if (text.isEmpty) return '${_cap(anadido)}.';
    return '$text ($anadido).'.trim();
  }

  bool _isRepresented(String gloss, String hayLower) {
    if (gloss == 'ROBAR' && (hayLower.contains('robo') || hayLower.contains('robaron') || hayLower.contains('sustrajeron') || hayLower.contains('asaltaron'))) {
      return true;
    }
    if (gloss == 'LADRON' && (hayLower.contains('ladron') || hayLower.contains('sospechoso') || hayLower.contains('autor') || hayLower.contains('persona') || hayLower.contains('hombre') || hayLower.contains('mujer'))) {
      return true;
    }
    if ((gloss == 'CELULAR' || gloss == 'TELEFONO') && (hayLower.contains('celular') || hayLower.contains('telefono'))) {
      return true;
    }
    if (gloss == 'IDENTIDAD' && (hayLower.contains('identidad') || hayLower.contains('carnet') || hayLower.contains('cedula') || hayLower.contains('documento'))) {
      return true;
    }
    if (gloss == 'DINERO' || gloss == 'BILLETES') {
      if (hayLower.contains('dinero') || hayLower.contains('billetes') || hayLower.contains('monto')) return true;
    }
    if (gloss == 'CONOCER' && (hayLower.contains('conozco') || hayLower.contains('conoce') || hayLower.contains('persona'))) return true;
    if (gloss == 'DENUNCIAR' && (hayLower.contains('denuncia') || hayLower.contains('denunciar'))) return true;
    if (gloss == 'ABOGADO' && hayLower.contains('abogado')) return true;
    if (gloss == 'INTERPRETE' && hayLower.contains('interprete')) return true;
    if (gloss == 'SEPDAVI' && hayLower.contains('sepdavi')) return true;
    if (gloss == 'SEPDEP' && (hayLower.contains('sepdep') || hayLower.contains('defensa publica'))) return true;
    if (gloss == 'FISCALIA' && (hayLower.contains('fiscalia') || hayLower.contains('fiscal'))) return true;
    if (gloss == 'FISCAL' && (hayLower.contains('fiscal') || hayLower.contains('fiscalia'))) return true;
    if (gloss == 'JUZGADO' && (hayLower.contains('juzgado') || hayLower.contains('juez'))) return true;
    if (gloss == 'JUEZ' && (hayLower.contains('juez') || hayLower.contains('juzgado'))) return true;
    if (gloss == 'POLICIA' && hayLower.contains('policia')) return true;
    if (gloss == 'TESTIGO' && (hayLower.contains('testigo') || hayLower.contains('testigos') || hayLower.contains('presencie'))) return true;
    if (gloss == 'TOTAL' && (hayLower.contains('todo') || hayLower.contains('totalidad'))) return true;
    if (gloss == 'AMENAZAR' && (hayLower.contains('amenaza') || hayLower.contains('amenazo'))) return true;
    if (gloss == 'PEGAR' && (hayLower.contains('pego') || hayLower.contains('golpeo') || hayLower.contains('agredio'))) return true;
    if (gloss == 'MALTRATAR' && hayLower.contains('maltrato')) return true;
    if (gloss == 'HERIDA' && (hayLower.contains('herida') || hayLower.contains('lesion') || hayLower.contains('lesiones'))) return true;
    if (gloss == 'COMPRENDER' && (hayLower.contains('entiendo') || hayLower.contains('comprendo') || hayLower.contains('entender'))) return true;
    if (gloss == 'EXPLICAR' && (hayLower.contains('explicar') || hayLower.contains('explique') || hayLower.contains('relatar'))) return true;
    if (gloss == 'SI' && (hayLower.contains('si') || hayLower.contains('afirmativo') || hayLower.contains('quiero') || hayLower.contains('hay'))) return true;
    if (gloss == 'NO' && (hayLower.contains('no') || hayLower.contains('ninguno'))) return true;
    if (gloss == 'PASAPORTE' && (hayLower.contains('pasaporte') || hayLower.contains('documento'))) return true;
    if (gloss == 'FORMULARIO' && (hayLower.contains('documento') || hayLower.contains('formulario') || hayLower.contains('papel'))) return true;
    if (gloss == 'REQUISITO' && (hayLower.contains('tramite') || hayLower.contains('requisito') || hayLower.contains('documento'))) return true;
    if (gloss == 'AVANCE' && (hayLower.contains('avance') || hayLower.contains('investigacion') || hayLower.contains('caso'))) return true;
    if (gloss == 'CASO' && (hayLower.contains('caso') || hayLower.contains('estado') || hayLower.contains('investigacion'))) return true;
    if (gloss == 'VOLVER' && (hayLower.contains('volver') || hayLower.contains('regresar'))) return true;
    if (gloss == 'FLACO' && (hayLower.contains('delgado') || hayLower.contains('delgada') || hayLower.contains('flaco') || hayLower.contains('flaca'))) return true;
    if (gloss == 'GORDO' && (hayLower.contains('grueso') || hayLower.contains('gruesa') || hayLower.contains('gordo') || hayLower.contains('gorda'))) return true;
    if (gloss == 'ALTO' && (hayLower.contains('alto') || hayLower.contains('alta'))) return true;
    if (gloss == 'BAJO' && (hayLower.contains('bajo') || hayLower.contains('baja'))) return true;
    if (gloss == 'JOVEN' && hayLower.contains('joven')) return true;
    if (gloss == 'ADULTO' && (hayLower.contains('adulto') || hayLower.contains('adulta'))) return true;

    final lex = _lexicon[gloss];
    if (lex == null) return false;
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
        case _Role.lugar:
          final lugarTxt = _conDetalle(t, e.es, r);
          // Dos glosas de lugar en la misma respuesta describen el mismo
          // sitio desde dos ángulos ("en mi casa" + "un lugar seguro"), no
          // dos lugares distintos: se concatenan en vez de que la segunda
          // se pierda por el `??=` (auditoría 2026-09, hallazgo SEGURO).
          r.place = r.place == null ? lugarTxt : '${r.place}, $lugarTxt';
          break;
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
      return '¿Para qué se necesita?';
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
          ? '¿Qué documento de respaldo necesitas?'
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
    const supportMarkers = ['papel', 'carpeta', 'hoja', 'documento'];
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
    final items = [...r.documents, ...r.objects];
    r.documents.clear();
    r.objects.clear();
    for (final d in items) {
      sentences.add('${_cap(d)}.');
    }
    return sentences.join(' ');
  }

  String _composeIncident(String ctx, _Roles r, List<String> tokens) {
    // Elegir el menú "Denunciar robo"/"Denunciar violencia" no prueba que
    // haya ocurrido un robo o una agresión: si no hay agresor ni verbo de
    // agresión (p. ej. la persona solo respondió PERDER, o solo contestó
    // sobre testigos), el encabezado no debe afirmarlo (auditoría 2026-09,
    // hallazgos PERDER y NO+TESTIGO).
    final hayAgresion = r.aggression != null || _hasAggressor(r);
    final lead = !hayAgresion
        ? 'Quiero comunicar lo siguiente.'
        : switch (ctx) {
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
      var clause = 'Hago referencia a $what';
      if (r.institution != null) {
        clause += ' ${_join(r.institutions)}';
        r.institution = null;
      }
      if (r.place != null) {
        clause += ' ${r.place}';
        r.place = null;
      }
      if (r.time != null) {
        clause = '${_cap(r.time!)}, ${_decap(clause)}';
        r.time = null;
      }
      sentences.add('$clause.');
      r.documents.clear();
      r.procedures.clear();
      r.objects.clear();
    }

    _supplements(r, sentences);
    return _stitch(lead, sentences, tokens);
  }

  void _supplements(_Roles r, List<String> sentences) {
    if (r.frequency != null) {
      sentences.add('${_cap(r.frequency!)}.');
      r.frequency = null;
    }
    if (r.emotions.isNotEmpty) {
      sentences.add('${_cap(_join(r.emotions))}.');
      r.emotions.clear();
    }
    if (r.urgencies.isNotEmpty) {
      sentences.add('${_cap(_join(r.urgencies))}.');
      r.urgencies.clear();
    }
    if (r.evidence.isNotEmpty) {
      sentences.add('Cuento con ${_join(r.evidence)} como prueba.');
      r.evidence.clear();
    }
    if (r.vehicles.isNotEmpty) {
      sentences.add('Hago referencia al vehículo ${_join(r.vehicles)}.');
      r.vehicles.clear();
    }
    if (r.services.isNotEmpty) {
      sentences.add('Solicito ${_join(r.services)}.');
      r.services.clear();
    }
    if (r.institutions.isNotEmpty) {
      sentences.add('Realizaré esta gestión ${_join(r.institutions)}.');
      r.institutions.clear();
    }
    final acciones = [if (r.action != null) r.action!, ...r.extraActions];
    for (final act in acciones) {
      if (act == 'no conozco') {
        sentences.add('No conozco a esa persona.');
      } else if (act == 'sí conozco') {
        sentences.add('Sí conozco a esa persona.');
      } else {
        sentences.add('${_cap(act)}.');
      }
    }
    r.action = null;
    r.extraActions.clear();
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
            ? 'una persona ${traits.first}'
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
      buffer.write(' ${_join(adjForm)}');
    }
    if (withs.isNotEmpty) {
      final items = withs.map((p) {
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
    '0': _Lex(_Role.verboAccion, '0'),
    '1': _Lex(_Role.verboAccion, '1'),
    '2': _Lex(_Role.verboAccion, '2'),
    '3': _Lex(_Role.verboAccion, '3'),
    '4': _Lex(_Role.verboAccion, '4'),
    '5': _Lex(_Role.verboAccion, '5'),
    '6': _Lex(_Role.verboAccion, '6'),
    '7': _Lex(_Role.verboAccion, '7'),
    '8': _Lex(_Role.verboAccion, '8'),
    '9': _Lex(_Role.verboAccion, '9'),
    'A': _Lex(_Role.verboAccion, 'a'),
    'ABOGADO': _Lex(_Role.servicio, 'un abogado'),
    'ABRIR': _Lex(_Role.verboAccion, 'abrí'),
    'ABUSAR': _Lex(_Role.verboAgresion, 'cometió abusos'),
    'ACEPTAR': _Lex(_Role.verboAccion, 'acepto'),
    'ACOMPAÑAR': _Lex(_Role.verboAccion, 'acompañar'),
    'ADULTO': _Lex(_Role.personaDesc, 'adulto'),
    'AHORA': _Lex(_Role.tiempo, 'ahora mismo'),
    'ALCALDIA': _Lex(_Role.institucion, 'en la alcaldía'),
    'ALLA': _Lex(_Role.lugar, 'allá'),
    'ALLI': _Lex(_Role.lugar, 'allí'),
    'ALTO': _Lex(_Role.rasgo, 'alto'),
    'AL_LADO': _Lex(_Role.lugar, 'al lado'),
    'AMBOS': _Lex(_Role.sujeto, 'ambos'),
    'AMENAZAR': _Lex(_Role.verboAgresion, 'amenazó'),
    'AMIGO': _Lex(_Role.personaDesc, 'un amigo'),
    'ANDAR': _Lex(_Role.verboAccion, 'caminaba'),
    'ANTEAYER': _Lex(_Role.tiempo, 'anteayer'),
    'AQUI': _Lex(_Role.lugar, 'aquí'),
    'ARREGLAR': _Lex(_Role.verboAccion, 'quiero corregir'),
    'ARRESTAR': _Lex(_Role.verboAccion, 'arrestaron'),
    'ASISTENCIA': _Lex(_Role.documento, 'asistencia'),
    'ASISTENTE': _Lex(_Role.servicio, 'un asistente'),
    'ASOCIACION_SORDOS': _Lex(_Role.personaDesc, 'la asociación de sordos'),
    'ATENDER': _Lex(_Role.verboAccion, 'atender'),
    'ATRAS': _Lex(_Role.lugar, 'atrás'),
    'AUMENTAR': _Lex(_Role.verboAccion, 'quiero agregar información'),
    'AUTORIDAD': _Lex(_Role.institucion, 'la autoridad'),
    'AUXILIO': _Lex(_Role.urgencia, 'auxilio urgente'),
    'AVENIDA': _Lex(_Role.lugar, 'en la avenida'),
    'AVISAR': _Lex(_Role.verboAccion, 'avisar'),
    'AYER': _Lex(_Role.tiempo, 'ayer'),
    'AYUDAR': _Lex(_Role.verboAccion, 'necesito ayuda'),
    'AZUL': _Lex(_Role.descriptor, 'de color azul'),
    'AÑO': _Lex(_Role.tiempo, 'año'),
    'AÑO_PASADO': _Lex(_Role.tiempo, 'el año pasado'),
    'AUN': _Lex(_Role.tiempo, 'aún'),
    'B': _Lex(_Role.verboAccion, 'b'),
    'BAJO': _Lex(_Role.rasgo, 'bajo'),
    'BANCO': _Lex(_Role.lugar, 'en el banco'),
    'BARRIO': _Lex(_Role.lugar, 'en el barrio'),
    'BILLETES': _Lex(_Role.objeto, 'billetes y dinero'),
    'BOCA': _Lex(_Role.objeto, 'la boca'),
    'BOLSA': _Lex(_Role.objeto, 'mi bolsa'),
    'BRAZO': _Lex(_Role.objeto, 'el brazo'),
    'BUENO': _Lex(_Role.descriptor, 'bueno'),
    'BUENOS_DIAS': _Lex(_Role.marcador, 'buenos días'),
    'BURLAR': _Lex(_Role.verboAccion, 'se burlaron'),
    'BUSCAR': _Lex(_Role.verboAccion, 'quiero buscar'),
    'C': _Lex(_Role.verboAccion, 'c'),
    'CABELLO': _Lex(_Role.objeto, 'el cabello'),
    'CADA_DIA': _Lex(_Role.tiempo, 'cada día'),
    'CAJA': _Lex(_Role.objeto, 'la caja'),
    'CALLE': _Lex(_Role.lugar, 'en la calle'),
    'CAMBIAR': _Lex(_Role.verboAccion, 'cambié'),
    'CARO': _Lex(_Role.descriptor, 'costoso'),
    'CARPETA': _Lex(_Role.documento, 'la carpeta de documentos'),
    'CASA': _Lex(_Role.lugar, 'en mi casa'),
    'CELULAR': _Lex(_Role.objeto, 'mi celular'),
    // Sin "del lugar": esa relación necesita su referencia real (auditoría
    // 2026-09); un valor fijo fabricaba una referencia vaga cuando no se
    // preguntó cerca de qué.
    'CERCA': _Lex(_Role.lugar, 'cerca'),
    'CERTIFICADO': _Lex(_Role.documento, 'un certificado'),
    'CHAMARRA': _Lex(_Role.objeto, 'mi chamarra'),
    'COCHABAMBA': _Lex(_Role.lugar, 'en Cochabamba'),
    'COMPAÑERO': _Lex(_Role.personaDesc, 'un compañero'),
    'COMPRAR': _Lex(_Role.verboAccion, 'compré'),
    'COMPRENDER': _Lex(_Role.marcador, 'comprender'),
    'COMPUTADORA': _Lex(_Role.objeto, 'una computadora'),
    'COMUNIDAD_SORDA': _Lex(_Role.personaDesc, 'la comunidad sorda'),
    'CONFIANZA': _Lex(_Role.emocion, 'tengo confianza'),
    // "Conozco" solo no dice a quién: el corpus penal judicial §4 pregunta
    // "¿conoce a la persona?" y la respuesta debe nombrar el complemento,
    // sí o no ("Sí/No conozco a esa persona"), no quedar en un verbo suelto.
    'CONOCER': _Lex(_Role.verboAccion, 'conozco a esa persona'),
    'CONTESTAR_DOS_VECES': _Lex(_Role.verboAccion, 'contesté dos veces'),
    'CONTINUAR': _Lex(_Role.verboAccion, 'continúa'),
    'CONVOCAR': _Lex(_Role.tramite, 'una citación'),
    'CORTO': _Lex(_Role.descriptor, 'corto'),
    'CREER': _Lex(_Role.verboAccion, 'creo'),
    'CURAR': _Lex(_Role.verboAccion, 'curar'),
    'CUAL': _Lex(_Role.interrogativa, 'cuál'),
    'CUANDO': _Lex(_Role.interrogativa, 'cuándo'),
    'CUANTOS': _Lex(_Role.interrogativa, 'cuántos'),
    'CAMARA_FOTOGRAFICA': _Lex(_Role.objeto, 'una cámara fotográfica'),
    'COMO': _Lex(_Role.interrogativa, 'cómo'),
    'D': _Lex(_Role.verboAccion, 'd'),
    'DAR': _Lex(_Role.verboAccion, 'entregué'),
    'DAÑAR': _Lex(_Role.verboAgresion, 'dañó'),
    'DECIDIR': _Lex(_Role.verboAccion, 'decidí'),
    'DEJAR': _Lex(_Role.verboAccion, 'dejé'),
    'DELGADO': _Lex(_Role.rasgo, 'delgado'),
    'DENTRO': _Lex(_Role.lugar, 'dentro'),
    'DESCANSO': _Lex(_Role.tiempo, 'en horario de descanso'),
    'DESPUES': _Lex(_Role.tiempo, 'después'),
    'DEVOLVER': _Lex(_Role.verboAccion, 'quiero que devuelvan'),
    'DE_NADA': _Lex(_Role.marcador, 'de nada'),
    'DIBUJAR': _Lex(_Role.verboAccion, 'dibujé'),
    'DIFERENTE': _Lex(_Role.descriptor, 'diferente'),
    'DIFICIL': _Lex(_Role.descriptor, 'difícil'),
    'DINERO': _Lex(_Role.objeto, 'mi dinero'),
    'DIRECCION': _Lex(_Role.lugar, 'en mi dirección'),
    'DISCRIMINACION': _Lex(_Role.documento, 'discriminación'),
    'DOCTOR': _Lex(_Role.servicio, 'un doctor'),
    'DOLOR': _Lex(_Role.urgencia, 'dolor físico'),
    'DORMIR': _Lex(_Role.verboAccion, 'dormía'),
    'DURANTE': _Lex(_Role.tiempo, 'durante ese tiempo'),
    'DIA': _Lex(_Role.tiempo, 'día'),
    'DONDE': _Lex(_Role.interrogativa, 'dónde'),
    'E': _Lex(_Role.verboAccion, 'e'),
    'EDAD': _Lex(_Role.marcador, 'tengo esa edad'),
    'ELLA': _Lex(_Role.sujeto, 'ella'),
    'ELLOS': _Lex(_Role.sujeto, 'ellos'),
    'EMPEZAR': _Lex(_Role.verboAccion, 'empezó'),
    'ENCONTRARSE': _Lex(_Role.verboAccion, 'me encontré'),
    'ENFRENTE': _Lex(_Role.lugar, 'enfrente'),
    'ENGAÑAR': _Lex(_Role.verboAgresion, 'engañó y estafó'),
    'ENVIAR': _Lex(_Role.verboAccion, 'envié'),
    'ESCAPAR': _Lex(_Role.verboAgresion, 'escapó'),
    'ESCONDER': _Lex(_Role.verboAccion, 'escondió'),
    'ESCRIBIR': _Lex(_Role.verboAccion, 'quiero escribir'),
    'ESCUELA': _Lex(_Role.lugar, 'en la escuela'),
    'ESCUELA_NOCTURNA': _Lex(_Role.lugar, 'en la escuela nocturna'),
    'ESPERAR': _Lex(_Role.verboAccion, 'esperar'),
    'ESPOSA': _Lex(_Role.personaDesc, 'mi esposa'),
    'ESTAR_DE_ACUERDO': _Lex(_Role.marcador, 'estoy de acuerdo'),
    'EVALUAR': _Lex(_Role.verboAccion, 'evaluar'),
    'EXPLICAR': _Lex(_Role.verboAccion, 'quiero explicar'),
    'F': _Lex(_Role.verboAccion, 'f'),
    'FACTURA': _Lex(_Role.documento, 'la factura'),
    // verboAccion, no verboAgresion: perder algo no es una agresión de un
    // tercero. Con verboAgresion, "FALTA CELULAR" se redactaba "una persona
    // me perdí mi celular" (auditoría 2026-09, hallazgo PERDER).
    'FALTA': _Lex(_Role.verboAccion, 'perdí'),
    'FECHA': _Lex(_Role.tiempo, 'en la fecha indicada'),
    'FELCC': _Lex(_Role.institucion, 'en la FELCC'),
    'FELCV': _Lex(_Role.institucion, 'en la FELCV'),
    'FILMAR': _Lex(_Role.verboAccion, 'filmé'),
    'FISCALIA': _Lex(_Role.institucion, 'en la Fiscalía'),
    'FLACO': _Lex(_Role.rasgo, 'delgado'),
    'FOTOCOPIA': _Lex(_Role.documento, 'una fotocopia'),
    'FOTOS': _Lex(_Role.objeto, 'fotografías'),
    'FRACTURA': _Lex(_Role.urgencia, 'una fractura'),
    'FUERA': _Lex(_Role.lugar, 'fuera'),
    'FUNCIONAR': _Lex(_Role.verboAccion, 'funciona'),
    'FUTURO': _Lex(_Role.tiempo, 'en el futuro'),
    'G': _Lex(_Role.verboAccion, 'g'),
    'GANAR_DINERO': _Lex(_Role.verboAccion, 'gané dinero'),
    'GESTIONAR': _Lex(_Role.verboAccion, 'quiero gestionar'),
    'GOBIERNO': _Lex(_Role.institucion, 'el gobierno'),
    'GORDO': _Lex(_Role.rasgo, 'de contextura gruesa'),
    'GORRA': _Lex(_Role.objeto, 'mi gorra'),
    'GRACIAS': _Lex(_Role.marcador, 'muchas gracias'),
    'GRATIS': _Lex(_Role.descriptor, 'gratuito'),
    'GRITAR': _Lex(_Role.verboAccion, 'gritó'),
    'GRUESO': _Lex(_Role.rasgo, 'grueso'),
    'GUARDAR': _Lex(_Role.verboAccion, 'guardé'),
    'H': _Lex(_Role.verboAccion, 'h'),
    'HABLAR': _Lex(_Role.verboAccion, 'quiero hablar'),
    'HACER': _Lex(_Role.verboAccion, 'hice'),
    'HASTA_LUEGO': _Lex(_Role.marcador, 'hasta luego'),
    'HASTA_MAÑANA': _Lex(_Role.marcador, 'hasta mañana'),
    'HERIDA': _Lex(_Role.urgencia, 'una herida'),
    'HERMANA': _Lex(_Role.personaDesc, 'mi hermana'),
    'HERMANO': _Lex(_Role.personaDesc, 'mi hermano'),
    'HIJA': _Lex(_Role.personaDesc, 'mi hija'),
    'HIJO': _Lex(_Role.personaDesc, 'mi hijo'),
    'HOLA': _Lex(_Role.marcador, 'hola'),
    'HOMBRE': _Lex(_Role.personaDesc, 'un hombre'),
    'HORA': _Lex(_Role.tiempo, 'hora'),
    'HOSPITAL': _Lex(_Role.institucion, 'en el hospital'),
    'HOY': _Lex(_Role.tiempo, 'hoy'),
    'HUESOS': _Lex(_Role.urgencia, 'los huesos'),
    'I': _Lex(_Role.verboAccion, 'i'),
    'IDENTIDAD': _Lex(_Role.marcador, 'mi carnet de identidad'),
    'IDENTIFICAR': _Lex(_Role.verboAccion, 'puedo identificar'),
    'IGNORAR': _Lex(_Role.verboAccion, 'me ignoraron'),
    'INSTITUCION': _Lex(_Role.institucion, 'en la institución'),
    'INTERNET': _Lex(_Role.objeto, 'por internet'),
    'INTERPRETE': _Lex(_Role.servicio, 'un intérprete de LSB'),
    'INVESTIGACION': _Lex(_Role.tramite, 'la investigación de mi caso'),
    'IR': _Lex(_Role.verboAccion, 'fui'),
    'J': _Lex(_Role.verboAccion, 'j'),
    'JAMAS': _Lex(_Role.tiempo, 'jamás'),
    'JEFE': _Lex(_Role.personaDesc, 'mi jefe'),
    'JOVEN': _Lex(_Role.personaDesc, 'joven'),
    'JUEVES': _Lex(_Role.tiempo, 'el jueves'),
    'JUEZ': _Lex(_Role.institucion, 'el juez'),
    'JULIO': _Lex(_Role.tiempo, 'en julio'),
    'JUSTICIA': _Lex(_Role.documento, 'la justicia'),
    'JUZGADO': _Lex(_Role.institucion, 'en el juzgado'),
    'K': _Lex(_Role.verboAccion, 'k'),
    'L': _Lex(_Role.verboAccion, 'l'),
    'LADRON': _Lex(_Role.personaDesc, 'un ladrón'),
    'LEER': _Lex(_Role.verboAccion, 'quiero leer'),
    'LEJOS': _Lex(_Role.lugar, 'lejos'),
    'LENTES': _Lex(_Role.objeto, 'mis lentes'),
    'LENTO': _Lex(_Role.descriptor, 'despacio'),
    'LEY': _Lex(_Role.documento, 'la ley'),
    'LIBRE': _Lex(_Role.tiempo, 'libre'),
    'LISTA': _Lex(_Role.documento, 'la lista'),
    'LLAMAR': _Lex(_Role.verboAccion, 'llamé'),
    'LLEGAR': _Lex(_Role.verboAccion, 'llegué'),
    'LLEVAR': _Lex(_Role.verboAccion, 'llevaba'),
    'LO_SIENTO': _Lex(_Role.marcador, 'lo siento'),
    'LUEGO': _Lex(_Role.tiempo, 'luego'),
    'LUNES': _Lex(_Role.tiempo, 'el lunes'),
    'M': _Lex(_Role.verboAccion, 'm'),
    'MAL': _Lex(_Role.descriptor, 'mal'),
    'MALTRATAR': _Lex(_Role.verboAgresion, 'maltrató'),
    'MAMA': _Lex(_Role.personaDesc, 'mi mamá'),
    'MARTES': _Lex(_Role.tiempo, 'el martes'),
    'MARZO': _Lex(_Role.tiempo, 'en marzo'),
    'MAÑANA': _Lex(_Role.tiempo, 'mañana'),
    'MEDICINA': _Lex(_Role.objeto, 'medicinas'),
    'MEJOR': _Lex(_Role.descriptor, 'mejor'),
    'MENTIRA': _Lex(_Role.marcador, 'es mentira'),
    'MERCADO': _Lex(_Role.lugar, 'en el mercado'),
    'MES': _Lex(_Role.tiempo, 'mes'),
    'MICRO': _Lex(_Role.objeto, 'un micro'),
    'MIEDO': _Lex(_Role.emocion, 'tengo miedo'),
    'MILITAR': _Lex(_Role.personaDesc, 'un militar'),
    'MINUTO': _Lex(_Role.tiempo, 'minuto'),
    'MIRAR': _Lex(_Role.verboAccion, 'vi'),
    'MOCHILA': _Lex(_Role.objeto, 'mi mochila'),
    'MOMENTO': _Lex(_Role.tiempo, 'en ese momento'),
    'MOSTRAR': _Lex(_Role.verboAccion, 'puedo mostrar'),
    'MUCHO': _Lex(_Role.descriptor, 'mucho'),
    'MUJER': _Lex(_Role.personaDesc, 'una mujer'),
    'MAS_O_MENOS': _Lex(_Role.marcador, 'más o menos'),
    'MIO': _Lex(_Role.sujeto, 'mi'),
    'N': _Lex(_Role.verboAccion, 'n'),
    'NARRAR': _Lex(_Role.verboAccion, 'quiero relatar'),
    'NECESITAR': _Lex(_Role.verboAccion, 'necesitar'),
    'NEGRO': _Lex(_Role.descriptor, 'de color negro'),
    'NO': _Lex(_Role.marcador, 'no'),
    'NOMBRE': _Lex(_Role.marcador, 'mi nombre es'),
    'NOSOTROS': _Lex(_Role.sujeto, 'nosotros'),
    'NO_ESTAR_DE_ACUERDO': _Lex(_Role.marcador, 'no estoy de acuerdo'),
    'NO_PUEDO': _Lex(_Role.marcador, 'no puedo'),
    'NO_SABER': _Lex(_Role.marcador, 'no sé'),
    'NUEVO': _Lex(_Role.descriptor, 'nuevo'),
    'O': _Lex(_Role.verboAccion, 'o'),
    'OBSERVAR': _Lex(_Role.verboAccion, 'observé'),
    'OCUPADO': _Lex(_Role.tiempo, 'ocupado'),
    'OFICIAL': _Lex(_Role.servicio, 'un oficial'),
    'OFICINA': _Lex(_Role.lugar, 'en la oficina'),
    'ORGANIZAR': _Lex(_Role.verboAccion, 'organicé'),
    'OSCURO': _Lex(_Role.descriptor, 'oscuro'),
    'OYENTE': _Lex(_Role.personaDesc, 'oyente'),
    'OIR': _Lex(_Role.verboAccion, 'escuché'),
    'P': _Lex(_Role.verboAccion, 'p'),
    'PALABRA': _Lex(_Role.verboAccion, 'palabra'),
    'PANTALON': _Lex(_Role.objeto, 'mi pantalón'),
    'PAPEL': _Lex(_Role.documento, 'el documento'),
    'PAREJA': _Lex(_Role.personaDesc, 'mi pareja'),
    'PARIENTE': _Lex(_Role.personaDesc, 'un pariente'),
    'PASADO': _Lex(_Role.tiempo, 'en el pasado'),
    'PASADO_MAÑANA': _Lex(_Role.tiempo, 'pasado mañana'),
    'PASAPORTE': _Lex(_Role.documento, 'mi pasaporte'),
    'PEDIR': _Lex(_Role.verboAccion, 'solicito'),
    'PEGAR': _Lex(_Role.verboAgresion, 'golpeó y pegó'),
    'PELEAR': _Lex(_Role.verboAgresion, 'inició una pelea'),
    // verboAccion, no verboAgresion (auditoría 2026-09, hallazgo PERDER): ver
    // la nota en 'FALTA', misma causa.
    'PERDER': _Lex(_Role.verboAccion, 'perdí'),
    'PERMISO': _Lex(_Role.marcador, 'con permiso'),
    'PLAZA': _Lex(_Role.lugar, 'en la plaza'),
    'PLAZO': _Lex(_Role.tramite, 'el plazo'),
    'POCO': _Lex(_Role.descriptor, 'poco'),
    'POLERA': _Lex(_Role.objeto, 'mi polera'),
    'POLICIA': _Lex(_Role.institucion, 'en la policía'),
    'POR_FAVOR': _Lex(_Role.marcador, 'por favor'),
    'POSTERGAR': _Lex(_Role.tiempo, 'postergar'),
    'PREOCUPAR': _Lex(_Role.emocion, 'estoy preocupado'),
    'PRESENTAR': _Lex(_Role.verboAccion, 'quiero presentar'),
    'PRIMERA_VEZ': _Lex(_Role.tiempo, 'la primera vez'),
    'PROHIBIDO': _Lex(_Role.documento, 'prohibido'),
    'PROTEGER': _Lex(_Role.verboAccion, 'necesito protección'),
    'PROVINCIA': _Lex(_Role.lugar, 'en la provincia'),
    'PROXIMO': _Lex(_Role.tiempo, 'el próximo'),
    'PUEDO': _Lex(_Role.marcador, 'puedo'),
    'PUERTA': _Lex(_Role.objeto, 'la puerta'),
    'PAGINA': _Lex(_Role.documento, 'la página'),
    'Q': _Lex(_Role.verboAccion, 'q'),
    'QUEJAR': _Lex(_Role.verboAccion, 'quejar'),
    'QUERER': _Lex(_Role.verboAccion, 'querer'),
    'QUIEN': _Lex(_Role.interrogativa, 'quién'),
    'QUE': _Lex(_Role.interrogativa, 'qué'),
    'R': _Lex(_Role.verboAccion, 'r'),
    'RAYOS_X': _Lex(_Role.objeto, 'placas de rayos X'),
    'RECHAZAR': _Lex(_Role.verboAccion, 'rechazo'),
    'RECIBIR': _Lex(_Role.verboAccion, 'recibí'),
    'RECORDAR': _Lex(_Role.verboAccion, 'recuerdo'),
    'RESOLUCION': _Lex(_Role.documento, 'una resolución'),
    'RESULTADO': _Lex(_Role.documento, 'el resultado'),
    'REUNION': _Lex(_Role.verboAccion, 'reunión'),
    'ROBAR': _Lex(_Role.verboAgresion, 'robó'),
    'ROJO': _Lex(_Role.descriptor, 'de color rojo'),
    'S': _Lex(_Role.verboAccion, 's'),
    'SABER': _Lex(_Role.marcador, 'sé'),
    'SEGUNDO': _Lex(_Role.tiempo, 'segundo'),
    'SELLO': _Lex(_Role.documento, 'un sello oficial'),
    'SEMANA': _Lex(_Role.tiempo, 'semana'),
    'SEPARADOS': _Lex(_Role.personaDesc, 'separados'),
    'SEPDAVI': _Lex(_Role.institucion, 'en el SEPDAVI'),
    'SEPDEP': _Lex(_Role.institucion, 'en el SEPDEP'),
    'SEÑOR': _Lex(_Role.personaDesc, 'el señor'),
    'SIEMPRE': _Lex(_Role.tiempo, 'siempre'),
    'SOLUCIONAR': _Lex(_Role.verboAccion, 'quiero solucionar'),
    'SOPORTE': _Lex(_Role.documento, 'soporte'),
    'SORDO': _Lex(_Role.personaDesc, 'una persona sorda'),
    'SUYO': _Lex(_Role.sujeto, 'suyo'),
    'SABADO': _Lex(_Role.tiempo, 'el sábado'),
    'SI': _Lex(_Role.marcador, 'sí'),
    'T': _Lex(_Role.verboAccion, 't'),
    'TAL_VEZ': _Lex(_Role.marcador, 'tal vez'),
    'TARDE': _Lex(_Role.tiempo, 'por la tarde'),
    'TELEFONO': _Lex(_Role.objeto, 'mi teléfono'),
    'TEMOR': _Lex(_Role.emocion, 'tengo temor'),
    'TEMPRANO': _Lex(_Role.tiempo, 'temprano'),
    'TENER': _Lex(_Role.verboAccion, 'tener'),
    'TERMINAR': _Lex(_Role.verboAccion, 'terminó'),
    'TESTIGO': _Lex(_Role.testigo, 'un testigo'),
    'TESTIMONIO': _Lex(_Role.documento, 'mi testimonio'),
    'TIENDA': _Lex(_Role.lugar, 'en la tienda'),
    'TODOS_LOS_DIAS': _Lex(_Role.tiempo, 'todos los días'),
    'TOTAL': _Lex(_Role.verboAccion, 'total'),
    'TRABAJADOR': _Lex(_Role.personaDesc, 'un trabajador'),
    'TRAER': _Lex(_Role.verboAccion, 'puedo traer'),
    'TRISTE': _Lex(_Role.emocion, 'estoy triste'),
    'TRUFI': _Lex(_Role.objeto, 'un trufi'),
    'TRAMITE': _Lex(_Role.tramite, 'un trámite'),
    'TUYO': _Lex(_Role.sujeto, 'su'),
    'TU': _Lex(_Role.sujeto, 'tú'),
    'U': _Lex(_Role.verboAccion, 'u'),
    'URGENTE': _Lex(_Role.urgencia, 'de manera urgente'),
    'V': _Lex(_Role.verboAccion, 'v'),
    'VARIOS': _Lex(_Role.sujeto, 'varios'),
    'VECINO': _Lex(_Role.personaDesc, 'un vecino'),
    'VENDER': _Lex(_Role.verboAccion, 'vendí'),
    'VENIR': _Lex(_Role.verboAccion, 'vine'),
    'VER': _Lex(_Role.verboAccion, 'vi'),
    'VERDAD': _Lex(_Role.marcador, 'es verdad'),
    'VIDEO': _Lex(_Role.objeto, 'un video'),
    'VIERNES': _Lex(_Role.tiempo, 'el viernes'),
    'VIOLENCIA': _Lex(_Role.urgencia, 'un hecho de violencia'),
    'VIVIR': _Lex(_Role.verboAccion, 'vivo'),
    'VOLVER': _Lex(_Role.verboAccion, 'debo volver'),
    'W': _Lex(_Role.verboAccion, 'w'),
    'X': _Lex(_Role.verboAccion, 'x'),
    'Y': _Lex(_Role.verboAccion, 'y'),
    'YO': _Lex(_Role.sujeto, 'yo'),
    'Z': _Lex(_Role.verboAccion, 'z'),
    'EL': _Lex(_Role.sujeto, 'él'),
    'Ñ': _Lex(_Role.verboAccion, 'ñ'),
    'ORGANO_JUDICIAL': _Lex(_Role.institucion, 'en el Órgano Judicial'),
    'ULTIMO': _Lex(_Role.tiempo, 'el último'),

    // Vocabulario del corpus ausente del lexicón (auditoría 2026-09): estas
    // glosas se usan en aws/tests/casos_corpus.json pero nunca se agregaron
    // aquí, así que caían en la red de seguridad genérica en vez de
    // redactarse con su propio sentido. Se agregan en paridad con
    // GLOSS_LEXICON en aws/lambda_function.py.
    'AUDIENCIA': _Lex(_Role.tramite, 'una audiencia'),
    'CENTRO_DE_SALUD': _Lex(_Role.lugar, 'en el centro de salud'),
    'CONSTANCIA': _Lex(_Role.documento, 'una constancia'),
    'COPIAR': _Lex(_Role.verboAccion, 'copié'),
    'DEFENSA_PUBLICA': _Lex(_Role.institucion, 'en la Defensa Pública'),
    'ESTADO': _Lex(_Role.tramite, 'el estado'),
    'EXPAREJA': _Lex(_Role.personaDesc, 'mi expareja'),
    'EXPEDIENTE': _Lex(_Role.documento, 'el expediente'),
    'FORMULARIO': _Lex(_Role.documento, 'un formulario'),
    'FOTOGRAFIA': _Lex(_Role.objeto, 'una fotografía'),
    'MEMORIAL': _Lex(_Role.documento, 'un memorial'),
    'NOTIFICACION': _Lex(_Role.documento, 'la notificación'),
    'NO_ENTIENDO': _Lex(_Role.marcador, 'no entiendo'),
    'NO_RECUERDO': _Lex(_Role.marcador, 'no recuerdo'),
    'NUREJ': _Lex(_Role.documento, 'el NUREJ'),
    'OBSERVACION': _Lex(_Role.documento, 'una observación'),
    // "Un lugar seguro" no es dónde ocurrió el hecho: es la seguridad ACTUAL
    // de quien declara. Como _Role.lugar se fundía con el lugar del hecho
    // ("en mi casa y un lugar seguro"); como estado emocional se une a MIEDO
    // en su propia cláusula ("Tengo miedo y me encuentro en un lugar
    // seguro"), igual que el resto de _Role.emocion (auditoría 2026-09,
    // hallazgo CP-004).
    'SEGURO': _Lex(_Role.emocion, 'me encuentro en un lugar seguro'),
    // Sus hermanas de estado emocional (CONFIANZA, MIEDO, TEMOR...) son
    // _Role.emocion con una cláusula completa en primera persona; SOSPECHA
    // había quedado como _Role.motivo con una locución suelta ("por
    // sospecha"), que en denuncia_robo/violencia ningún compositor consume
    // y termina cayendo a la red de seguridad como "(por sospecha)" en vez
    // de una oración propia (auditoría 2026-09, hallazgo CP-010).
    'SOSPECHA': _Lex(_Role.emocion, 'tengo una sospecha'),
    'VENTANILLA': _Lex(_Role.lugar, 'en la ventanilla'),
    // Ya trae la preposición: `_joinConCanales` la reconoce como canal (por
    // WhatsApp), igual que ENGANAR+WHATSAPP.
    'WHATSAPP': _Lex(_Role.objeto, 'por WhatsApp'),

    // Narrativa de estafa sin verbo de agresión ("pagué y no me entregaron
    // el producto"): PAGAR/ENTREGAR/PRODUCTO faltaban por completo, así que
    // caían en la red de seguridad genérica ("Me sustrajeron...") y
    // calificaban el hecho como robo aunque la persona nunca lo dijo
    // (auditoría 2026-09, hallazgo "lagunas cerradas"). ENTREGAR se redacta
    // en la voz que recibe ("me entregaron") porque así compone con NO
    // ("no me entregaron") sin hornear la negación en el lexema.
    'PAGAR': _Lex(_Role.verboAccion, 'pagué'),
    'ENTREGAR': _Lex(_Role.verboAccion, 'me entregaron'),
    'PRODUCTO': _Lex(_Role.objeto, 'el producto'),

    // CORRER faltaba del lexicón: al no reconocerse, `_extractDetails` la
    // confundía con un nombre propio deletreado y la fundía en el lugar
    // ("en el mercado correr") en vez de cerrar el relato como huida
    // (auditoría 2026-09, hallazgo CP-002). Se trata igual que ESCAPAR.
    'CORRER': _Lex(_Role.verboAgresion, 'salió corriendo'),
    'BILLETERA': _Lex(_Role.objeto, 'mi billetera'),
    'PARADA': _Lex(_Role.lugar, 'en la parada'),

    // AUTO/MOTOCICLETA/TAXI/BICICLETA estaban en `_admiteDetalle` (admiten
    // placa) pero nunca se agregaron al lexicón: sin entrada, `_classify`
    // las trataba como token desconocido, y como su placa ya había quedado
    // registrada en `detalles` (por `_extractDetails`), `_ensureCoverage`
    // las daba por "consumidas" y ni siquiera aparecían en la red de
    // seguridad "(...)" — el vehículo y su placa desaparecían del todo de
    // la declaración (auditoría 2026-09, hallazgo "placa alfanumérica").
    // AUTO/MOTOCICLETA/BICICLETA son vehículos propios (blanco de ROBAR o
    // DAÑAR, como CELULAR o MOCHILA), así que llevan posesivo igual que el
    // resto de bienes personales; TAXI/MICRO/TRUFI en cambio son transporte
    // público, no del declarante, y mantienen el artículo indefinido.
    'AUTO': _Lex(_Role.objeto, 'mi auto'),
    'MOTOCICLETA': _Lex(_Role.objeto, 'mi motocicleta'),
    'TAXI': _Lex(_Role.objeto, 'un taxi'),
    'BICICLETA': _Lex(_Role.objeto, 'mi bicicleta'),
    'MENSAJE': _Lex(_Role.objeto, 'un mensaje'),
    'COMPROBANTE': _Lex(_Role.objeto, 'un comprobante'),
    'RESPALDO': _Lex(_Role.objeto, 'un respaldo'),
    'VIDEOLLAMADA': _Lex(_Role.objeto, 'una videollamada'),

    // DESCONOCER es una seña propia para "no conocer" (no NO + CONOCER): su
    // lexema ya trae la negación horneada porque no hay una glosa NO previa
    // de la que derivarla. DENUNCIAR faltaba del todo — "¿desea denunciar?"
    // del corpus penal judicial §4 se perdía entera (corpus §4, auditoría
    // 2026-09).
    'DESCONOCER': _Lex(_Role.verboAccion, 'no conozco a esa persona'),
    'DENUNCIAR': _Lex(_Role.verboAccion, 'quiero presentar una denuncia'),

    // APELLIDO/CARNET/ANOS_EDAD estaban en `_admiteDetalle` (admiten
    // deletreo/dígitos) pero no en el lexicón: sin entrada, `_extractDetails`
    // no las distinguía de una racha de letras y las fundía en el detalle de
    // la glosa anterior ("Mi nombre es Juanapellidoperez.", Fase 1 de
    // identificación, auditoría 2026-09).
    'APELLIDO': _Lex(_Role.marcador, 'mi apellido es'),
    'CARNET': _Lex(_Role.marcador, 'mi carnet de identidad'),
    'ANOS_EDAD': _Lex(_Role.marcador, 'tengo esa edad'),
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
