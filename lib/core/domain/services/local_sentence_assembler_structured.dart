part of 'local_sentence_assembler.dart';

/// Redacción a partir del modelo estructurado (auditoría 2026-09).
///
/// A diferencia de `assemble`, que clasifica una lista plana de glosas por
/// rol y adivina relaciones, este camino recibe relaciones ya explícitas
/// (qué prenda es de qué persona, qué lugar es referencia de qué, qué
/// objeto tiene qué papel) y solo tiene que redactarlas. No completa
/// acciones por contexto ni atribuye un hecho que el borrador no declaró.
extension _StructuredComposition on LocalSentenceAssembler {
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

  /// Redaccion de UN hecho, con su propio protagonista.
  ///
  /// Devuelve `null` cuando la accion no tiene redaccion conocida: callar es
  /// preferible a inventar de que se trataba.
  ///
  /// La negacion y la incertidumbre se conservan tal cual las marco la
  /// persona. "No me acuerdo" no es "no", y ninguno de los dos es un hecho
  /// afirmado.
  String? _factSentence(
    Fact f, {
    required List<ObjectInvolved> stolen,
    required List<ObjectInvolved> lost,
    required String subjectPhrase,
    required String timePrefix,
    required String locClause,
  }) {
    String cap(String t) => t.replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase());

    String? nucleo;
    switch (f.action.toUpperCase()) {
      case 'ROBAR':
        final what = stolen.isEmpty
            ? ''
            : ' ${_join(stolen.map(_objectSelfPhrase).toList())}';
        nucleo = '${_decap(subjectPhrase)} me robó$what';
        break;
      case 'PERDER':
        final objetos = lost.isNotEmpty ? lost : stolen;
        nucleo = objetos.isEmpty
            ? 'no sé con certeza qué ocurrió; puede que haya perdido algo'
            : 'perdí ${_join(objetos.map(_objectSelfPhrase).toList())}';
        break;
      case 'ENGAÑAR':
        nucleo = 'me engañaron';
        break;
      case 'DAÑAR':
        final what = stolen.isEmpty
            ? ''
            : ' ${_join(stolen.map(_objectSelfPhrase).toList())}';
        nucleo = '${_decap(subjectPhrase)} dañó$what';
        break;
      case 'ESCAPAR':
        nucleo = switch (f.actorRole) {
          ActorRole.victim => 'el declarante logró escapar',
          ActorRole.thirdParty => 'una tercera persona escapó del lugar',
          ActorRole.suspect => '${_decap(subjectPhrase)} escapó',
          ActorRole.unknown => (f.actorDetail != null && f.actorDetail!.isNotEmpty)
              ? '${f.actorDetail} escapó'
              : 'hubo una huida, sin precisar de quién',
        };
        break;
      default:
        return null;
    }

    if (f.negated) {
      nucleo = 'no es cierto que $nucleo';
    } else if (f.certainty == Certainty.uncertain) {
      nucleo = 'no estoy seguro, pero creo que $nucleo';
    } else if (f.certainty == Certainty.unknown) {
      nucleo = 'no sé si $nucleo';
    }

    return cap('$timePrefix$nucleo$locClause.'.trim());
  }

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
      // Sin moneda elegida no se escribe ninguna: sería un dato inventado.
      final unidad = (o.unit == null || o.unit!.trim().isEmpty) ? '' : ' ${o.unit!}';
      return '${o.quantity}$unidad en billetes';
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

  String _composeStructured(DeclarationDraft d) {
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
        final agg = d.violence?.aggressionType ??
            d.primaryFact?.action ??
            'agresión física';
        final aggText = agg.toLowerCase().replaceAll('_', ' ');
        sentences.add('${_cap(timePrefix)}El declarante denuncia haber sufrido $aggText$locClause.'.trim());
        break;

      case 'amenaza_digital':
        final chan = d.digitalThreat?.channel ?? 'medios digitales';
        sentences.add('${_cap(timePrefix)}El declarante refiere haber recibido amenazas a través de $chan$locClause.'.trim());
        break;

      case 'engano_dinero':
        final moneda = d.fraud?.currency == null ? '' : ' ${d.fraud!.currency}';
        final monto = d.fraud?.amount != null ? ' por el monto de ${d.fraud!.amount}$moneda' : '';
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
        // Un relato puede llevar dos hechos. Cada uno se redacta con SU
        // protagonista: antes se despachaba sobre una sola accion, asi que
        // elegir ROBAR y despues ESCAPAR perdia el robo, y la huida se
        // atribuia a quien dijera un campo suelto del relato.
        //
        // El orden es el de seleccion, no el temporal: no se encadenan con
        // "primero" ni "luego".
        if (d.facts.isEmpty) {
          if (locClause.isNotEmpty || timeClauseText != null) {
            sentences.add('${_cap(timePrefix)}Ocurrió algo que quiero relatar$locClause.'.trim());
          }
        } else {
          var primero = true;
          for (final f in d.facts) {
            // El complemento de lugar y tiempo encabeza el relato una sola
            // vez: repetirlo en cada hecho sugiere dos sucesos separados.
            final prefijo = primero ? timePrefix : '';
            final lugar = primero ? locClause : '';
            final frase = _factSentence(
              f,
              stolen: stolen,
              lost: lost,
              subjectPhrase: subjectPhrase,
              timePrefix: prefijo,
              locClause: lugar,
            );
            if (frase != null) {
              sentences.add(frase);
              primero = false;
            }
          }
          if (sentences.isEmpty &&
              (locClause.isNotEmpty || timeClauseText != null)) {
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
}
