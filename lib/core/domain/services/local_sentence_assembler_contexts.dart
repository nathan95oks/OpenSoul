part of 'local_sentence_assembler.dart';

/// Redacción de una lista plana de glosas según el contexto de la
/// conversación: preguntas, consultas, identificación, incidentes,
/// emergencias, trámites, orientación, pérdidas y testimonios. Recibe los
/// roles ya clasificados ([_Roles]) por `assemble`.
extension _ContextComposition on LocalSentenceAssembler {
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
      final normalized = LocalSentenceAssembler._stripDiacritics(doc.toLowerCase());
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
}
