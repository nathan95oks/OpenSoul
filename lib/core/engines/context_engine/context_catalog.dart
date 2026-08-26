import '../../domain/entities/semantic_context.dart';
import '../../domain/entities/semantic_zone.dart';
import '../semantic_engine/local_sentence_assembler.dart' show kVictimMarker, kEvidenceMarker, kVehicleMarker;

/// Catálogo de contextos situacionales — labels en primera persona,
/// IDs preservados porque el datasource de tarjetas los referencia.
///
/// Cada contexto declara zonas semánticas con peso base, urgencia
/// intrínseca y relaciones cruzadas. El [SemanticNavigationEngine]
/// usa esa información para ordenar y resaltar zonas en tiempo real.
///
/// Cada zona expone además una `question` — una pregunta guiada en
/// primera persona que se presenta al usuario sordo como prompt. Las
/// tarjetas (entrada visual-táctil definida en el perfil de proyecto)
/// son las que responden esa pregunta; el motor semántico encadena las
/// respuestas para construir el relato.
/// Contexto de preguntas: la persona sorda arma una pregunta en vez de narrar
/// un hecho. Es el único contexto cuya salida no es una declaración, así que
/// entra por la interrogativa —lo que la LSB coloca primero— y luego acota de
/// quién o de qué se pregunta.
final preguntasContext = SemanticContext(
  id: 'preguntas',
  name: 'Preguntas',
  icon: 'question_answer',
  emoji: '❓',
  description: 'Quiero preguntar algo',
  entryZoneId: 'interrogativa',
  zones: const [
    // La interrogativa manda: la LSB la coloca primero y en el motor decide
    // qué compositor se ejecuta. Solo interrogativas reales — los pronombres
    // (YO, TU, EL…) tienen subcategoría `sujeto` y al elegirlos `r.question`
    // queda en null, con lo que `_composeQuestion` cae a `_composeInquiry`:
    // la interfaz prometía una pregunta y devolvía una declaración.
    SemanticZone(
      id: 'interrogativa',
      label: 'Pregunta',
      hint: 'Qué quiero preguntar',
      question: '¿Qué quieres preguntar?',
      emoji: '❓',
      semanticWeight: 0.95,
      glossAllowlist: [
        'DONDE', 'QUIEN', 'QUE', 'CUANDO', 'CUAL',
        'COMO', 'CUANTOS', 'POR_QUE', 'PARA_QUE',
      ],
      relatedZones: ['lugar_pregunta', 'persona_pregunta', 'tema_pregunta'],
    ),
    // Las cuatro zonas siguientes sustituyen a la antigua "¿Sobre qué tema?",
    // que mostraba 74 tarjetas —lugares, objetos robables, documentos y
    // trámites juntos— fuera cual fuera la interrogativa elegida.
    SemanticZone(
      id: 'lugar_pregunta',
      label: 'Lugar',
      hint: 'De qué lugar pregunto',
      question: '¿Dónde está…?',
      emoji: '📍',
      semanticWeight: 0.8,
      optional: true,
      glossAllowlist: [
        'FISCALIA', 'FELCC', 'FELCV', 'JUZGADO',
        'DEFENSA_PUBLICA', 'SEPAV', 'TRIBUNAL',
        'OFICINA', 'VENTANILLA', 'DESPACHO', 'HOSPITAL',
      ],
    ),
    SemanticZone(
      id: 'persona_pregunta',
      label: 'Persona',
      hint: 'Por quién pregunto',
      question: '¿Quién es…?',
      emoji: '👤',
      semanticWeight: 0.8,
      optional: true,
      glossAllowlist: [
        'FISCAL', 'JUEZ', 'ABOGADO', 'INTERPRETE',
        'AUTORIDAD', 'DOCTOR', 'COORDINADOR',
      ],
    ),
    SemanticZone(
      id: 'tema_pregunta',
      label: 'Trámite o documento',
      hint: 'Por qué gestión pregunto',
      question: '¿Qué documento o trámite?',
      emoji: '📋',
      semanticWeight: 0.8,
      optional: true,
      glossAllowlist: [
        'TRAMITE', 'REQUISITO', 'CASO', 'EXPEDIENTE',
        'CARNET', 'PASAPORTE', 'CERTIFICADO', 'CONSTANCIA', 'FORMULARIO',
      ],
    ),
    // Composición temporal en dirección futuro: una pregunta por una fecha
    // mira siempre hacia adelante ("¿cuándo debo presentarme?").
    SemanticZone(
      id: 'tiempo_pregunta',
      label: 'Cuándo',
      hint: 'Por qué fecha pregunto',
      question: '¿Cuándo es…?',
      emoji: '🕐',
      semanticWeight: 0.7,
      optional: true,
      glossAllowlist: ['AUDIENCIA', 'CITACION', 'NOTIFICACION', 'DIA', 'SEMANA', 'MES'],
      chainTriggers: ['DIA', 'SEMANA', 'MES'],
      chainZoneId: 'cantidad_pregunta',
    ),
    SemanticZone(
      id: 'cantidad_pregunta',
      label: 'Cuántos',
      hint: 'Cantidad',
      question: '¿Cuántos?',
      emoji: '🔢',
      semanticWeight: 0.3,
      optional: true,
      glossAllowlist: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
    ),
  ],
);

/// Fase 1: identidad. Toda atención en ventanilla empieza por aquí —"¿cómo se
/// llama?", "¿qué edad tiene?"— y hasta ahora la persona sorda no tenía con
/// qué contestarlo, así que no se llegaba a la Fase 2, que es su relato.
///
/// Las respuestas son datos, no señas del corpus: el nombre se deletrea, la
/// edad y el carnet se teclean. Por eso las zonas son cortas y cada glosa
/// abre su propio teclado.
final identificacionContext = SemanticContext(
  id: 'identificacion',
  name: 'Mis datos',
  icon: 'badge',
  emoji: '🪪',
  description: 'Mi nombre, mi edad y mi documento',
  entryZoneId: 'identidad',
  zones: const [
    SemanticZone(
      id: 'identidad',
      label: 'Identidad',
      hint: 'Cómo me llamo',
      question: '¿Cuál es su nombre?',
      emoji: '🪪',
      semanticWeight: 0.95,
      maxPicks: 3,
      glossAllowlist: ['NOMBRE', 'APELLIDO', 'CARNET', 'IDENTIDAD'],
      relatedZones: ['edad'],
    ),
    SemanticZone(
      id: 'edad',
      label: 'Edad',
      hint: 'Qué edad tengo',
      question: '¿Qué edad tiene?',
      emoji: '🎂',
      semanticWeight: 0.9,
      glossAllowlist: ['EDAD', 'ANOS_EDAD'],
    ),
  ],
);

/// Contextos de **declaración**: los que narran un hecho.
///
/// El de preguntas queda fuera a propósito. Esta lista alimenta la inferencia
/// de contexto a partir de glosas, y una pregunta no es un relato: incluirlo
/// hacía que 'preguntas' compitiera por glosas como ROBAR y ganara por
/// solapamiento de categorías, desviando denuncias reales.
final availableContexts = <SemanticContext>[
  // ─── 1. ROBO ──────────────────────────────────────────
  SemanticContext(
    id: 'denuncia_robo',
    name: 'Denunciar robo',
    icon: 'warning_amber',
    emoji: '🚨',
    description: 'Me robaron / Hurto / Asalto',
    entryZoneId: 'situacion',
    baseUrgency: UrgencyLevel.medium,
    zones: const [
      SemanticZone(
        id: 'situacion',
        label: 'Situación',
        hint: 'Qué pasó',
        question: '¿Qué pasó?',
        emoji: '⚡',
        semanticWeight: 0.9,
        // Sin ABUSAR/VIOLACION/MALTRATAR: ofrecer verbos de violencia en un
        // flujo de robo invita a una calificación jurídica equivocada, que es
        // justo lo que el corpus §8 prohíbe que haga la aplicación.
        glossAllowlist: ['ROBAR', 'AMENAZAR', 'DANAR', 'CORRER', 'SOBORNO'],
        contextTags: [EmotionalTag.amenaza],
        relatedZones: ['agravante', 'personas', 'objetos', 'emergencia'],
      ),
      // Antes: "¿Usó algún arma?". El diccionario no tiene NI UNA glosa de
      // arma —no existe CUCHILLO, PISTOLA ni ARMA— y la zona ofrecía
      // ARRESTAR, ASISTENCIA y AUXILIO como respuesta. El arma concreta se
      // captura deletreando: `_joinSpelled` ya reconstruye C·U·C·H·I·L·L·O.
      SemanticZone(
        id: 'agravante',
        label: 'Agravante',
        hint: '¿Te amenazó o te hizo daño?',
        question: '¿Te amenazó o te hizo daño?',
        emoji: '⚠️',
        semanticWeight: 0.7,
        optional: true,
        glossAllowlist: ['AMENAZAR', 'DANAR', 'VIOLENCIA', 'HERIDA'],
        contextTags: [EmotionalTag.amenaza, EmotionalTag.peligro],
        relatedZones: ['personas', 'objetos'],
      ),
      SemanticZone(
        id: 'personas',
        label: 'Quién',
        hint: 'Tipo de persona',
        question: '¿Quién te robó?',
        emoji: '👤',
        semanticWeight: 0.85,
        maxPicks: 2,
        // IDENTIDAD y NOMBRE se refieren al declarante ("mi nombre"), no al
        // agresor: producían "mi nombre me robó".
        // Sin LADRON: en una denuncia de robo la glosa no aporta nada —el
        // verbo ya lo dice— y ocupa el sitio de un dato que sí distingue.
        // VECINO, MILITAR y SOLDADO concuerdan en género con HOMBRE o MUJER
        // si la persona elige ambos (ver _personPhrase).
        glossAllowlist: ['HOMBRE', 'MUJER', 'VECINO', 'MILITAR', 'SOLDADO'],
        relatedZones: ['apariencia', 'objetos'],
      ),
      // Fusiona las antiguas 'apariencia' y 'vestimenta'. La segunda se
      // elimina: el diccionario no tiene ninguna prenda (ni CHOMPA, ni GORRA,
      // ni PANTALON), así que "¿Qué ropa llevaba?" no tenía respuesta posible.
      // Los colores quedan fuera a propósito: su forma es "de color X" y
      // aplicada a una persona el motor componía "un hombre de color negro",
      // una descripción racial no solicitada. Los colores describen objetos.
      SemanticZone(
        id: 'apariencia',
        label: 'Apariencia',
        hint: 'Cómo era físicamente',
        question: '¿Cómo era la persona?',
        emoji: '🧍',
        semanticWeight: 0.6,
        optional: true,
        maxPicks: 2,
        glossAllowlist: ['DELGADO', 'GRUESO'],
        relatedZones: ['personas'],
      ),
      SemanticZone(
        id: 'objetos',
        label: 'Objetos',
        hint: 'Qué se llevaron',
        question: '¿Qué se llevaron?',
        emoji: '📱',
        semanticWeight: 0.8,
        maxPicks: 3,
        // Solo pertenencias sustraíbles. Fuera: los soportes (PAPEL, TEXTO),
        // la evidencia del caso (PRUEBA, FOTOGRAFIA, MENSAJE) y el transporte
        // público (MICRO, TAXI, TRUFI), que no es de nadie.
        //
        // AUTO y MOTOCICLETA quedan fuera por perfil de usuario: el declarante
        // no conduce, así que en 1ª persona no son suyos. Siguen disponibles
        // donde el vehículo es de un tercero — la zona 'vehiculo' de accidente
        // y el flujo de testigo—, que es donde el corpus los necesita.
        // BICICLETA se queda: sí es una pertenencia habitual.
        glossAllowlist: [
          'TELEFONO', 'MOCHILA', 'DINERO', 'BILLETERA', 'CARNET',
          'BICICLETA', 'CAMARA',
          'PASAPORTE', 'LICENCIA_DECONDUCIR',
        ],
        relatedZones: ['lugar'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde fue',
        question: '¿Dónde ocurrió?',
        emoji: '📍',
        semanticWeight: 0.6,
        // DIRECCION y UBICACION_GPS son deícticos sin antecedente: no nombran
        // un lugar, lo señalan ("me robaron en esa dirección", ¿cuál?).
        glossAllowlist: [
          'CALLE', 'AVENIDA', 'PLAZA', 'MERCADO',
          'PARADA', 'CASA', 'AEROPUERTO', 'COCHABAMBA',
        ],
        relatedZones: ['tiempo'],
      ),
      // Corpus §2.3 t.12: la evidencia es un turno propio en 6 de los 7
      // escenarios de denuncia, y no existía en ningún flujo.
      SemanticZone(
        id: 'pruebas',
        label: 'Pruebas',
        hint: 'Qué evidencia tengo',
        question: '¿Tienes pruebas?',
        emoji: '📎',
        semanticWeight: 0.55,
        optional: true,
        maxPicks: 3,
        glossAllowlist: [
          // Sin PRUEBA: en un juzgado nadie declara "tengo una prueba" sin
          // decir cuál. Solo evidencias concretas, que son las que un acta
          // puede consignar.
          'FOTOGRAFIA', 'MENSAJE', 'CERTIFICADO', 'COMPROBANTE',
          'VIDEOLLAMADA', 'CAMARA',
          'WHATSAPP', 'VIDEOLLAMADA', 'COMPROBANTE', 'CERTIFICADO',
        ],
        leadGloss: kEvidenceMarker,
      ),
      SemanticZone(
        id: 'emergencia',
        label: 'Emergencia',
        hint: 'Estoy en peligro',
        question: '¿Necesitas ayuda urgente?',
        emoji: '🆘',
        semanticWeight: 0.3,
        urgencyLevel: UrgencyLevel.high,
        // Antes mezclaba 15 instituciones con los verbos: "a quién acudir" no
        // responde "qué necesitas".
        glossAllowlist: ['AUXILIO', 'ASISTENCIA', 'CRISIS', 'HERIDA'],
        contextTags: [EmotionalTag.urgente, EmotionalTag.ayuda, EmotionalTag.peligro],
        relatedZones: ['situacion'],
      ),
      // Composición temporal en pasado: un hecho consumado. MANANA y
      // PASADO_MANANA quedan fuera — un robo no pudo pasar mañana.
      SemanticZone(
        id: 'tiempo',
        label: 'Tiempo',
        hint: 'Cuándo',
        question: '¿Cuándo pasó?',
        emoji: '🕐',
        semanticWeight: 0.4,
        optional: true,
        glossAllowlist: [
          'AHORA', 'HOY', 'AYER', 'ANTEAYER',
          'MINUTO', 'HORA', 'DIA', 'SEMANA', 'MES',
        ],
        chainTriggers: ['MINUTO', 'HORA', 'DIA', 'SEMANA', 'MES'],
        chainZoneId: 'cantidad',
      ),
      SemanticZone(
        id: 'cantidad',
        label: 'Cuántos',
        hint: 'Cantidad',
        question: '¿Cuántos?',
        emoji: '🔢',
        semanticWeight: 0.25,
        optional: true,
        glossAllowlist: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
      ),
    ],
  ),

  // ─── 2. VIOLENCIA ─────────────────────────────────────
  SemanticContext(
    id: 'violencia',
    name: 'Denunciar violencia',
    icon: 'shield',
    emoji: '🛡️',
    description: 'Me agredieron / Me amenazaron / Abuso',
    entryZoneId: 'situacion',
    baseUrgency: UrgencyLevel.high,
    zones: const [
      SemanticZone(
        id: 'situacion',
        label: 'Situación',
        hint: 'Qué pasó',
        question: '¿Qué te hicieron?',
        emoji: '⚡',
        semanticWeight: 0.95,
        urgencyLevel: UrgencyLevel.medium,
        glossAllowlist: [
          'MALTRATAR', 'AMENAZAR', 'ABUSAR', 'VIOLACION',
          'DISCRIMINACION', 'VIOLENCIA', 'DANAR',
        ],
        contextTags: [EmotionalTag.amenaza, EmotionalTag.peligro],
        relatedZones: ['personas', 'reincidencia', 'emocion', 'emergencia'],
      ),
      // Corpus §2.2 t.2 pregunta literalmente "¿es un familiar, pareja o
      // expareja?": el orden de la lista es esa pregunta.
      SemanticZone(
        id: 'personas',
        label: 'Quién',
        hint: 'Tipo de persona',
        question: '¿Quién te agredió?',
        emoji: '👤',
        semanticWeight: 0.85,
        maxPicks: 2,
        glossAllowlist: [
          'PAREJA', 'EXPAREJA', 'FAMILIAR', 'VECINO',
          'HOMBRE', 'MUJER', 'MILITAR', 'SOLDADO',
        ],
        relatedZones: ['apariencia', 'reincidencia'],
      ),
      SemanticZone(
        id: 'apariencia',
        label: 'Apariencia',
        hint: 'Cómo era físicamente',
        question: '¿Cómo era la persona?',
        emoji: '🧍',
        semanticWeight: 0.5,
        optional: true,
        maxPicks: 2,
        glossAllowlist: ['DELGADO', 'GRUESO'],
      ),
      // Corpus §2.2 t.6: "¿ocurrió una sola vez o ya ocurrió anteriormente?".
      // Dato central para medidas de protección. Las tres glosas existían
      // pero vivían en "¿Cuándo pasó?", donde no responden lo que se pregunta.
      SemanticZone(
        id: 'reincidencia',
        label: 'Reincidencia',
        hint: 'Si ya había pasado',
        question: '¿Es la primera vez o ya había pasado?',
        emoji: '🔁',
        semanticWeight: 0.75,
        glossAllowlist: ['PRIMERA_VEZ', 'VARIAS_VECES', 'ANTERIORMENTE'],
        relatedZones: ['emocion'],
      ),
      SemanticZone(
        id: 'emocion',
        label: 'Cómo me siento',
        hint: 'Estado emocional',
        question: '¿Cómo te sientes?',
        emoji: '💔',
        semanticWeight: 0.7,
        // PROBLEMA, SITUACION, FALTA y RAZON tienen rol `motivo`: el motor las
        // redacta como "por un problema". Son causas, no sentimientos.
        glossAllowlist: ['MIEDO', 'TEMOR', 'MAL', 'VERGUENZA', 'CONFUSION'],
        contextTags: [EmotionalTag.miedo, EmotionalTag.dolor],
        relatedZones: ['seguridad', 'emergencia'],
      ),
      // Corpus §2.2 t.12: "¿Actualmente se encuentra en un lugar seguro?"
      SemanticZone(
        id: 'seguridad',
        label: 'Seguridad',
        hint: 'Si estoy a salvo',
        question: '¿Estás en un lugar seguro?',
        emoji: '🏠',
        semanticWeight: 0.68,
        optional: true,
        glossAllowlist: ['SEGURO', 'CASA', 'FAMILIAR'],
      ),
      SemanticZone(
        id: 'pruebas',
        label: 'Pruebas',
        hint: 'Qué evidencia tengo',
        question: '¿Tienes pruebas?',
        emoji: '📎',
        semanticWeight: 0.6,
        optional: true,
        maxPicks: 3,
        glossAllowlist: [
          'MENSAJE', 'FOTOGRAFIA', 'CERTIFICADO', 'COMPROBANTE',
          'VIDEOLLAMADA', 'WHATSAPP',
          'VIDEOLLAMADA', 'CERTIFICADO', 'CAMARA',
        ],
        leadGloss: kEvidenceMarker,
      ),
      SemanticZone(
        id: 'emergencia',
        label: 'Necesito ayuda',
        hint: 'Estoy en peligro',
        question: '¿Necesitas ayuda urgente?',
        emoji: '🆘',
        semanticWeight: 0.5,
        urgencyLevel: UrgencyLevel.critical,
        glossAllowlist: ['AUXILIO', 'ASISTENCIA', 'CRISIS', 'HERIDA'],
        contextTags: [EmotionalTag.urgente, EmotionalTag.ayuda],
        relatedZones: ['salud'],
      ),
      SemanticZone(
        id: 'salud',
        label: 'Salud',
        hint: 'Atención médica',
        question: '¿Necesitas atención médica?',
        emoji: '🏥',
        semanticWeight: 0.58,
        optional: true,
        // Sin FARMACIA: no atiende lesiones ni emite el certificado médico
        // que el corpus §2.5 necesita para la denuncia.
        glossAllowlist: ['HOSPITAL', 'CENTRO_DE_SALUD', 'DOCTOR', 'ENFERMERA', 'HERIDA'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde fue',
        question: '¿Dónde ocurrió?',
        emoji: '📍',
        semanticWeight: 0.55,
        // CASA encabeza: la violencia intrafamiliar ocurre en el domicilio.
        glossAllowlist: [
          'CASA', 'CALLE', 'AVENIDA', 'PLAZA',
          'MERCADO', 'PARADA', 'COCHABAMBA',
        ],
      ),
      SemanticZone(
        id: 'institucion',
        label: 'Institución',
        hint: 'A dónde acudir',
        question: '¿A qué institución quieres acudir?',
        emoji: '🏛️',
        semanticWeight: 0.5,
        optional: true,
        glossAllowlist: [
          'POLICIA', 'FISCAL', 'ORGANO_JUDICIAL', 'ALCALDIA', 'MINISTERIO',
        ],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Tiempo',
        hint: 'Cuándo',
        question: '¿Cuándo pasó?',
        emoji: '🕐',
        semanticWeight: 0.35,
        optional: true,
        glossAllowlist: [
          'AHORA', 'HOY', 'AYER', 'ANTEAYER',
          'MINUTO', 'HORA', 'DIA', 'SEMANA', 'MES',
        ],
        chainTriggers: ['MINUTO', 'HORA', 'DIA', 'SEMANA', 'MES'],
        chainZoneId: 'cantidad',
      ),
      SemanticZone(
        id: 'cantidad',
        label: 'Cuántos',
        hint: 'Cantidad',
        question: '¿Cuántos?',
        emoji: '🔢',
        semanticWeight: 0.25,
        optional: true,
        glossAllowlist: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
      ),
    ],
  ),

  // ─── 3. ACCIDENTE ─────────────────────────────────────
  SemanticContext(
    id: 'accidente',
    name: 'Reportar accidente',
    icon: 'car_crash',
    emoji: '🚗',
    description: 'Tránsito / Caída / Lesión / Emergencia médica',
    entryZoneId: 'estado',
    baseUrgency: UrgencyLevel.high,
    zones: const [
      SemanticZone(
        id: 'estado',
        label: 'Cómo estoy',
        hint: 'Estado físico',
        question: '¿Cómo te encuentras?',
        emoji: '💔',
        semanticWeight: 0.85,
        urgencyLevel: UrgencyLevel.high,
        // Tras un siniestro el dato relevante es clínico, no emocional:
        // MIEDO y VERGUENZA son propios de un delito con agresor.
        glossAllowlist: ['MAL', 'HERIDA', 'CRISIS', 'CONFUSION'],
        contextTags: [EmotionalTag.dolor, EmotionalTag.urgente],
        relatedZones: ['ayuda', 'vehiculo'],
      ),
      // Aquí el transporte público SÍ es coherente, al revés que en robo:
      // la misma categoría "Objetos" no distingue una pertenencia de un micro.
      SemanticZone(
        id: 'vehiculo',
        label: 'Vehículo',
        hint: 'Qué vehículo',
        question: '¿Qué vehículo estuvo involucrado?',
        emoji: '🚗',
        semanticWeight: 0.75,
        maxPicks: 2,
        glossAllowlist: [
          'AUTO', 'MOTOCICLETA', 'BICICLETA', 'MICRO', 'TAXI', 'TRUFI', 'TREN',
        ],
        leadGloss: kVehicleMarker,
        relatedZones: ['lugar'],
      ),
      SemanticZone(
        id: 'ayuda',
        label: 'Ayuda',
        hint: 'Qué necesito',
        question: '¿Qué ayuda necesitas?',
        emoji: '🚑',
        semanticWeight: 0.7,
        urgencyLevel: UrgencyLevel.high,
        // Antes ofrecía las 15 instituciones sin filtrar, incluidas ABOGADO y
        // ORGANO_JUDICIAL: apoyo jurídico en el momento de un accidente.
        glossAllowlist: ['AUXILIO', 'ASISTENCIA', 'DOCTOR', 'ENFERMERA'],
        contextTags: [EmotionalTag.urgente, EmotionalTag.ayuda],
        relatedZones: ['salud'],
      ),
      SemanticZone(
        id: 'salud',
        label: 'Salud',
        hint: 'Hospital o centro de salud',
        question: '¿Necesitas atención médica?',
        emoji: '🏥',
        semanticWeight: 0.58,
        optional: true,
        glossAllowlist: ['HOSPITAL', 'CENTRO_DE_SALUD', 'FARMACIA'],
      ),
      SemanticZone(
        id: 'personas',
        label: 'Personas',
        hint: 'Quién estuvo',
        question: '¿A quién más le ocurrió?',
        emoji: '👤',
        semanticWeight: 0.5,
        maxPicks: 2,
        // Único flujo donde TESTIGO responde a "quién": no hay agresor, así
        // que el rol no se confunde con el autor de un delito.
        glossAllowlist: ['HOMBRE', 'MUJER', 'FAMILIAR', 'PAREJA', 'VECINO', 'TESTIGO'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde fue',
        question: '¿Dónde ocurrió?',
        emoji: '📍',
        semanticWeight: 0.5,
        glossAllowlist: ['CALLE', 'AVENIDA', 'PLAZA', 'MERCADO', 'PARADA', 'COCHABAMBA'],
      ),
      SemanticZone(
        id: 'institucion',
        label: 'Institución',
        hint: 'A dónde acudir',
        question: '¿A qué institución acudiste?',
        emoji: '🏛️',
        semanticWeight: 0.45,
        optional: true,
        glossAllowlist: ['POLICIA', 'HOSPITAL', 'ALCALDIA', 'FISCAL'],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Tiempo',
        hint: 'Cuándo',
        question: '¿Cuándo ocurrió?',
        emoji: '🕐',
        semanticWeight: 0.35,
        optional: true,
        glossAllowlist: [
          'AHORA', 'HOY', 'AYER', 'ANTEAYER',
          'MINUTO', 'HORA', 'DIA', 'SEMANA', 'MES',
        ],
        chainTriggers: ['MINUTO', 'HORA', 'DIA', 'SEMANA', 'MES'],
        chainZoneId: 'cantidad',
      ),
      SemanticZone(
        id: 'cantidad',
        label: 'Cuántos',
        hint: 'Cantidad',
        question: '¿Cuántos?',
        emoji: '🔢',
        semanticWeight: 0.25,
        optional: true,
        glossAllowlist: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
      ),
    ],
  ),

  // ─── 4. DECLARAR COMO TESTIGO ─────────────────────────
  // (id 'otro' conservado por compatibilidad con datasource/motor)
  SemanticContext(
    id: 'otro',
    name: 'Declarar como testigo',
    icon: 'visibility',
    emoji: '👁️',
    description: 'Presencié un robo, violencia o accidente',
    entryZoneId: 'que',
    baseUrgency: UrgencyLevel.medium,
    zones: const [
      SemanticZone(
        id: 'que',
        label: 'Hecho',
        hint: 'Qué presencié',
        question: '¿Qué hecho presenciaste?',
        emoji: '⚡',
        semanticWeight: 0.85,
        // Este flujo sí abarca todos los tipos: es su propósito. Fuera quedan
        // las urgencias propias (AUXILIO, HERIDA): un testigo narra lo que
        // vio, no lo que necesita.
        glossAllowlist: [
          'ROBAR', 'MALTRATAR', 'AMENAZAR', 'ABUSAR', 'VIOLACION',
          'DANAR', 'ACCIDENTE', 'DISCRIMINACION', 'VIOLENCIA',
        ],
        relatedZones: ['personas', 'victima', 'lugar'],
      ),
      SemanticZone(
        id: 'personas',
        label: 'Quién agredió',
        hint: 'Quién cometió el hecho',
        question: '¿Quién cometió el hecho?',
        emoji: '👤',
        semanticWeight: 0.7,
        maxPicks: 2,
        // Sin LADRON: en una denuncia de robo la glosa no aporta nada —el
        // verbo ya lo dice— y ocupa el sitio de un dato que sí distingue.
        // VECINO, MILITAR y SOLDADO concuerdan en género con HOMBRE o MUJER
        // si la persona elige ambos (ver _personPhrase).
        glossAllowlist: ['HOMBRE', 'MUJER', 'VECINO', 'MILITAR', 'SOLDADO'],
        relatedZones: ['victima', 'lugar'],
      ),
      // Sus descriptores se marcan con [kVictimMarker] para que el motor no
      // confunda a la víctima con el agresor. Sin esta zona poblada, el
      // compositor siempre redactaba el genérico "a otra persona".
      SemanticZone(
        id: 'victima',
        label: 'A quién agredió',
        hint: 'Quién fue agredido',
        question: '¿A quién se lo hizo?',
        emoji: '🧑‍🤝‍🧑',
        semanticWeight: 0.6,
        optional: true,
        maxPicks: 2,
        glossAllowlist: ['HOMBRE', 'MUJER', 'FAMILIAR', 'PAREJA', 'VECINO'],
        leadGloss: kVictimMarker,
        relatedZones: ['lugar'],
      ),
      // El testigo SÍ describe vehículos: no son suyos, son del hecho que
      // presenció. Es el flujo al que se retiran AUTO y MOTOCICLETA desde la
      // zona de pertenencias robadas.
      SemanticZone(
        id: 'vehiculo',
        label: 'Vehículo',
        hint: 'Qué vehículo vi',
        question: '¿Qué vehículo estuvo involucrado?',
        emoji: '🚗',
        semanticWeight: 0.55,
        optional: true,
        maxPicks: 2,
        glossAllowlist: [
          'AUTO', 'MOTOCICLETA', 'BICICLETA', 'MICRO', 'TAXI', 'TRUFI',
        ],
        leadGloss: kVehicleMarker,
        relatedZones: ['lugar'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde ocurrió',
        question: '¿Dónde ocurrió?',
        emoji: '📍',
        semanticWeight: 0.6,
        glossAllowlist: [
          'CALLE', 'AVENIDA', 'PLAZA', 'MERCADO',
          'PARADA', 'CASA', 'COCHABAMBA',
        ],
        relatedZones: ['tiempo'],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Tiempo',
        hint: 'Cuándo',
        question: '¿Cuándo ocurrió?',
        emoji: '🕐',
        semanticWeight: 0.45,
        optional: true,
        glossAllowlist: [
          'AHORA', 'HOY', 'AYER', 'ANTEAYER',
          'MINUTO', 'HORA', 'DIA', 'SEMANA', 'MES',
        ],
        chainTriggers: ['MINUTO', 'HORA', 'DIA', 'SEMANA', 'MES'],
        chainZoneId: 'cantidad',
      ),
      SemanticZone(
        id: 'cantidad',
        label: 'Cuántos',
        hint: 'Cantidad',
        question: '¿Cuántos?',
        emoji: '🔢',
        semanticWeight: 0.25,
        optional: true,
        glossAllowlist: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
      ),
    ],
  ),

  // ─── 5. TRÁMITES ──────────────────────────────────────
  // Corpus §4: presentar un memorial, adjuntar pruebas, pedir una constancia,
  // actualizar datos, recuperar NUREJ/WebID, subsanar, gestionar una citación.
  //
  // Antes Trámites y Consultas eran el MISMO contexto ('orientacion'): la
  // persona elegía entre dos tarjetas distintas en la primera pantalla y
  // recibía las nueve preguntas idénticas. El corpus las separa por objetivo
  // comunicativo y aquí se separan también.
  SemanticContext(
    id: 'tramite',
    name: 'Trámites',
    icon: 'app_registration',
    emoji: '📋',
    description: 'Presentar, pedir, corregir o recoger documentación',
    entryZoneId: 'accion',
    zones: const [
      SemanticZone(
        id: 'accion',
        label: 'Gestión',
        hint: 'Qué necesito hacer',
        question: '¿Qué necesitas hacer?',
        emoji: '📋',
        semanticWeight: 0.9,
        glossAllowlist: [
          'PRESENTAR', 'PEDIR', 'RECOGER', 'CORREGIR',
          'COPIAR', 'GESTIONAR', 'SEGUIMIENTO', 'MOSTRAR',
        ],
        relatedZones: ['documento', 'caso', 'donde'],
      ),
      SemanticZone(
        id: 'documento',
        label: 'Documento',
        hint: 'Qué documento oficial',
        question: '¿Qué documento?',
        emoji: '📄',
        semanticWeight: 0.85,
        maxPicks: 2,
        glossAllowlist: [
          'CARNET', 'PASAPORTE', 'LICENCIA_DECONDUCIR', 'CERTIFICADO',
          'CONSTANCIA', 'COMPROBANTE', 'FORMULARIO', 'MEMORIAL', 'TITULO',
        ],
        relatedZones: ['caso', 'donde'],
      ),
      SemanticZone(
        id: 'caso',
        label: 'Caso',
        hint: 'Número de caso o expediente al que corresponde',
        question: '¿Sobre qué caso?',
        emoji: '🧾',
        semanticWeight: 0.82,
        optional: true,
        glossAllowlist: [
          'CASO', 'EXPEDIENTE', 'CODIGO', 'NUREJ',
          'WEBID', 'JUICIO', 'AUDIENCIA', 'CITACION',
        ],
        relatedZones: ['donde'],
      ),
      SemanticZone(
        id: 'donde',
        label: 'Institución',
        hint: 'Ante qué institución',
        question: '¿Ante qué institución?',
        emoji: '🏛️',
        semanticWeight: 0.6,
        // POLICIA y FISCAL entran aquí pese a tener subcategoría `cargo`: sus
        // formas en español son institucionales ("en la policía", "en la
        // fiscalía"). Es el caso que demuestra por qué la lista blanca manda
        // sobre la taxonomía gramatical.
        glossAllowlist: [
          // Ámbito penal judicial boliviano: recepción e investigación
          // (Ministerio Público/Fiscalía), intervención policial especializada
          // (FELCC para delitos, FELCV para violencia), etapa preparatoria
          // (juzgado de instrucción penal, tribunal) y asistencia legal
          // (Defensa Pública, SEPAV). Las municipales y genéricas salen: no
          // reciben una denuncia penal y desviaban a quien las elegía.
          'FISCALIA', 'FELCC', 'FELCV', 'JUZGADO',
          'DEFENSA_PUBLICA', 'SEPAV', 'TRIBUNAL', 'ORGANO_JUDICIAL',
          'OFICINA', 'VENTANILLA', 'DESPACHO',
        ],
        relatedZones: ['apoyo'],
      ),
      // Corpus §4.6 "Subsanación o corrección de un documento".
      SemanticZone(
        id: 'observacion',
        label: 'Observación',
        hint: 'Qué me observaron',
        question: '¿Qué te observaron?',
        emoji: '⚠️',
        semanticWeight: 0.55,
        optional: true,
        glossAllowlist: ['OBSERVACION', 'REQUISITO', 'SUBSANACION', 'FORMATO', 'FALTA'],
      ),
      // Corpus §4.x: el plazo mira hacia adelante. Se descarta todo marcador
      // de pasado — un plazo no vence ayer.
      SemanticZone(
        id: 'plazo',
        label: 'Plazo',
        hint: 'Para cuándo lo necesito',
        question: '¿Para cuándo lo necesitas?',
        emoji: '🕐',
        semanticWeight: 0.4,
        optional: true,
        glossAllowlist: [
          'AHORA', 'HOY', 'MANANA', 'PASADO_MANANA', 'DIA', 'SEMANA', 'MES',
        ],
        chainTriggers: ['DIA', 'SEMANA', 'MES'],
        chainZoneId: 'cantidad',
      ),
      SemanticZone(
        id: 'cantidad',
        label: 'Cuántos',
        hint: 'Cantidad',
        question: '¿Cuántos?',
        emoji: '🔢',
        semanticWeight: 0.3,
        optional: true,
        glossAllowlist: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
      ),
      SemanticZone(
        id: 'apoyo',
        label: 'Apoyo',
        hint: 'Intérprete o abogado',
        question: '¿Necesitas apoyo?',
        emoji: '🤝',
        semanticWeight: 0.5,
        optional: true,
        glossAllowlist: ['INTERPRETE', 'ABOGADO', 'ACOMPANAR', 'ASISTENTE'],
      ),
      // Antes esta zona filtraba ['Identificación'] y devolvía UNA sola
      // tarjeta (FAMILIAR): YO, la respuesta más frecuente, pertenece a la
      // categoría Preguntas con subcategoría `sujeto` y quedaba excluida.
      SemanticZone(
        id: 'quien',
        label: 'Para quién',
        hint: 'De quién es el trámite',
        question: '¿Para quién es el trámite?',
        emoji: '👤',
        semanticWeight: 0.4,
        optional: true,
        glossAllowlist: ['YO', 'FAMILIAR', 'PAREJA', 'HOMBRE', 'MUJER'],
      ),
      // Reactiva `_composeLoss`, hoy inalcanzable: ninguna zona exponía
      // Objetos y la glosa PERDER no existía en el diccionario.
      SemanticZone(
        id: 'perdida',
        label: 'Pérdida',
        hint: 'Qué perdí',
        question: '¿Qué perdiste?',
        emoji: '🔍',
        semanticWeight: 0.45,
        optional: true,
        glossAllowlist: [
          'PERDER', 'CARNET', 'PASAPORTE', 'LICENCIA_DECONDUCIR', 'TITULO',
          'CERTIFICADO', 'CONSTANCIA', 'TELEFONO', 'MOCHILA',
        ],
      ),
    ],
  ),

  // ─── 6. CONSULTAS ─────────────────────────────────────
  // Corpus §3: ya existe una denuncia, causa o expediente y la persona
  // pregunta por su estado, quién lo lleva, una citación o dónde acudir.
  SemanticContext(
    id: 'consulta',
    name: 'Consultas',
    icon: 'balance',
    emoji: '💬',
    description: 'Estado de un caso, orientación y derechos',
    entryZoneId: 'necesidad',
    zones: const [
      SemanticZone(
        id: 'necesidad',
        label: 'Necesidad',
        hint: 'Qué necesito saber',
        question: '¿Qué necesitas hacer?',
        emoji: '💬',
        semanticWeight: 0.9,
        // Verbos de duda y necesidad. No existe EXPLICAR en el diccionario:
        // ACLARAR ("quiero aclarar") cubre ese valor en el corpus §3.3.
        // INTERPRETE y CASO entran aquí porque son las dos respuestas que el
        // corpus penal ve una y otra vez en ventanilla —"necesito un
        // intérprete", "quiero saber el avance de mi caso"— y estaban a dos
        // preguntas de distancia.
        glossAllowlist: [
          'SEGUIMIENTO', 'CASO', 'INTERPRETE', 'NO_SABER',
          'COMPRENDER', 'ACLARAR', 'AYUDAR', 'ATENDER',
        ],
        relatedZones: ['avance', 'materia', 'identificador', 'donde'],
      ),
      // Seguimiento de investigación. El corpus penal lo trata como un
      // escenario propio: el ciudadano no viene a denunciar ni a tramitar,
      // viene a preguntar en qué quedó lo suyo. Antes se resolvía con las
      // preguntas de consulta genérica, que no llegan a la etapa procesal ni
      // a si tiene defensa.
      SemanticZone(
        id: 'avance',
        label: 'Avance',
        hint: 'Qué quiero saber de la investigación',
        question: '¿Qué necesita saber?',
        emoji: '🔎',
        semanticWeight: 0.88,
        optional: true,
        glossAllowlist: ['AVANCE', 'CASO', 'ESTADO', 'INVESTIGACION', 'AUDIENCIA'],
        relatedZones: ['defensa', 'identificador'],
      ),
      SemanticZone(
        id: 'defensa',
        label: 'Defensa',
        hint: 'Si tengo abogado',
        question: '¿Tiene abogado?',
        emoji: '⚖️',
        semanticWeight: 0.75,
        optional: true,
        // SI y NO son respuestas cerradas legítimas aquí: la pregunta del
        // funcionario admite las dos y la Defensa Pública es la salida cuando
        // la respuesta es no.
        glossAllowlist: ['SI', 'NO', 'DEFENSA_PUBLICA', 'ABOGADO'],
        relatedZones: ['identificador'],
      ),
      SemanticZone(
        id: 'materia',
        label: 'Materia',
        hint: 'Sobre qué consulto',
        question: '¿Sobre qué quieres consultar?',
        emoji: '🧾',
        semanticWeight: 0.85,
        glossAllowlist: [
          'CASO', 'EXPEDIENTE', 'ESTADO', 'TRAMITE',
          'REQUISITO', 'NOTIFICACION', 'CITACION', 'AUDIENCIA',
        ],
        relatedZones: ['identificador', 'donde'],
      ),
      // Corpus §3.1/§3.2/§3.4/§3.5 abren con esta pregunta. Es la única zona
      // donde las respuestas negativas son parte del diseño y no de la capa
      // transversal: "No tengo el código conmigo" es un turno del corpus.
      SemanticZone(
        id: 'identificador',
        label: 'Número de caso',
        hint: 'NUREJ, WebID o código',
        question: '¿Tienes el número de tu caso?',
        emoji: '🔢',
        semanticWeight: 0.8,
        optional: true,
        glossAllowlist: [
          'CODIGO', 'NUREJ', 'WEBID', 'EXPEDIENTE', 'NO_SABER', 'NO_RECUERDO',
        ],
      ),
      // Corpus §3.2 "Consulta sobre fiscal o autoridad asignada": escenario
      // completo del corpus que ningún flujo servía.
      SemanticZone(
        id: 'responsable',
        label: 'Responsable',
        hint: 'Quién lleva mi caso',
        question: '¿Quién lleva tu caso?',
        emoji: '👤',
        semanticWeight: 0.7,
        optional: true,
        glossAllowlist: ['FISCAL', 'JUEZ', 'ABOGADO', 'AUTORIDAD', 'COORDINADOR'],
      ),
      SemanticZone(
        id: 'donde',
        label: 'Dónde ir',
        hint: 'A qué institución u oficina acudo',
        question: '¿Dónde debes ir?',
        emoji: '🏛️',
        semanticWeight: 0.65,
        // PISO es válido aquí y solo aquí: se descarta en denuncias por
        // ambiguo, pero el corpus §3.2 lo usa literal — "en qué piso u
        // oficina debo preguntar".
        glossAllowlist: [
          // Ámbito penal judicial boliviano: recepción e investigación
          // (Ministerio Público/Fiscalía), intervención policial especializada
          // (FELCC para delitos, FELCV para violencia), etapa preparatoria
          // (juzgado de instrucción penal, tribunal) y asistencia legal
          // (Defensa Pública, SEPAV). Las municipales y genéricas salen: no
          // reciben una denuncia penal y desviaban a quien las elegía.
          'FISCALIA', 'FELCC', 'FELCV', 'JUZGADO',
          'DEFENSA_PUBLICA', 'SEPAV', 'TRIBUNAL', 'ORGANO_JUDICIAL',
          'OFICINA', 'VENTANILLA', 'DESPACHO', 'PISO',
        ],
      ),
      // Corpus §3.3 t.11: "Debe llevar su identificación y los documentos que
      // específicamente se le hayan solicitado."
      SemanticZone(
        id: 'documento',
        label: 'Documento',
        hint: 'Qué debo llevar',
        question: '¿Qué documento debes llevar?',
        emoji: '📄',
        semanticWeight: 0.6,
        optional: true,
        glossAllowlist: [
          'CARNET', 'PASAPORTE', 'CERTIFICADO', 'CONSTANCIA',
          'COMPROBANTE', 'FOTOCOPIA', 'NOTIFICACION',
        ],
      ),
      SemanticZone(
        id: 'apoyo',
        label: 'Apoyo',
        hint: 'Intérprete o abogado',
        question: '¿Necesitas apoyo?',
        emoji: '🤝',
        semanticWeight: 0.5,
        optional: true,
        glossAllowlist: ['INTERPRETE', 'ABOGADO', 'ACOMPANAR', 'AYUDAR'],
      ),
      // Corpus §3.1 t.13: "¿Tengo que volver otro día…?" — futuro.
      SemanticZone(
        id: 'plazo',
        label: 'Cuándo volver',
        hint: 'Para cuándo',
        question: '¿Cuándo debes volver?',
        emoji: '🕐',
        semanticWeight: 0.4,
        optional: true,
        glossAllowlist: ['HOY', 'MANANA', 'PASADO_MANANA', 'DIA', 'SEMANA', 'MES'],
        chainTriggers: ['DIA', 'SEMANA', 'MES'],
        chainZoneId: 'cantidad',
      ),
      SemanticZone(
        id: 'cantidad',
        label: 'Cuántos',
        hint: 'Cantidad',
        question: '¿Cuántos?',
        emoji: '🔢',
        semanticWeight: 0.3,
        optional: true,
        glossAllowlist: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
      ),
    ],
  ),
];

/// Para contextos fusionados: ids de contexto de tarjeta que abarca cada
/// contexto de la UI. El contexto 'orientacion' reúne las tarjetas de los
/// antiguos 'orientacion', 'tramite_id' y 'perdida' sin tocar el datasource.
/// El resto de contextos usan su propio id.
const Map<String, List<String>> kContextCardSources = {
  // Trámites y Consultas nacen de la escisión de 'orientacion' y heredan sus
  // tarjetas, más las de los antiguos 'tramite_id' y 'perdida'. Con las zonas
  // ya gobernadas por `glossAllowlist` este mapa solo importa para las que
  // siguen filtrando por categoría.
  'tramite': ['orientacion', 'tramite_id', 'perdida'],
  'consulta': ['orientacion', 'tramite_id'],
  'preguntas': ['preguntas', 'orientacion', 'tramite_id'],
};

/// Familia de contextos: lo que la persona elige en la primera pantalla.
///
/// La selección se presenta por *qué gestión trae*, no por el subtipo del
/// hecho. Antes la primera pantalla mezclaba los dos niveles —"Denunciar
/// robo" junto a "Orientación y trámites"— y obligaba a decidir el detalle
/// del delito antes de haber dicho a qué se venía.
///
/// Los contextos de debajo no cambian: conservan sus zonas, sus preguntas y
/// su enrutado al motor. Esto es solo cómo se agrupan para elegirlos.
class ContextFamily {
  final String id;
  final String name;
  final String emoji;
  final String description;

  /// Contextos que agrupa. Con uno solo se entra directo; con varios, la
  /// pantalla pide primero de cuál se trata.
  final List<String> contextIds;

  const ContextFamily({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.contextIds,
  });
}

/// Las cuatro entradas de "Selecciona el contexto".
const List<ContextFamily> contextFamilies = [
  ContextFamily(
    id: 'identificacion',
    name: 'Mis datos',
    emoji: '🪪',
    description: 'Nombre, edad y documento',
    contextIds: ['identificacion'],
  ),
  ContextFamily(
    id: 'denuncias',
    name: 'Denuncias',
    emoji: '🚨',
    description: 'Robo, violencia, accidente o declarar como testigo',
    contextIds: ['denuncia_robo', 'violencia', 'accidente', 'otro'],
  ),
  ContextFamily(
    id: 'consultas',
    name: 'Consultas',
    emoji: '💬',
    description: 'Estado de un caso, orientación y derechos',
    contextIds: ['consulta'],
  ),
  ContextFamily(
    id: 'tramites',
    name: 'Trámites',
    emoji: '📋',
    description: 'Documentos, certificados, pérdidas y antecedentes',
    contextIds: ['tramite'],
  ),
  ContextFamily(
    id: 'preguntas',
    name: 'Preguntas',
    emoji: '❓',
    description: 'Quiero preguntar algo',
    contextIds: ['preguntas'],
  ),
];

/// Todos los contextos seleccionables, incluido el de preguntas.
///
/// [availableContexts] es el subconjunto que infiere y narra; esta lista es la
/// que la interfaz puede abrir.
List<SemanticContext> get allSelectableContexts =>
    [...availableContexts, preguntasContext, identificacionContext];

/// Contextos de una familia, en el orden del catálogo.
List<SemanticContext> contextsOfFamily(ContextFamily family) => [
      for (final id in family.contextIds)
        for (final ctx in allSelectableContexts)
          if (ctx.id == id) ctx,
    ];

/// Ids de contexto de tarjeta que cubre [contextId] (para el filtro de
/// tarjetas). Siempre incluye el propio id, además de los heredados.
///
/// Que el propio id esté en la lista es lo que permite etiquetar una glosa
/// directamente con 'tramite' o 'consulta' para que discrimine entre las dos:
/// las que siguen marcadas solo como 'orientacion' alimentan a ambas y, por
/// tanto, no deciden nada — que es exactamente lo que son, vocabulario común.
List<String> cardSourceContexts(String contextId) {
  final heredados = kContextCardSources[contextId];
  if (heredados == null) return [contextId];
  return [contextId, ...heredados];
}

/// Resuelve el `contextId` que se envía al ensamblador (motor de traducción
/// intacto) según las glosas seleccionadas. Solo el contexto fusionado
/// 'orientacion' se reenruta a su sub-dominio más fiel para preservar la
/// coherencia del compositor:
///   - objeto perdido / PERDER  → 'perdida'   (_composeLoss)
///   - documento / trámite      → 'tramite_id' (_composeProcedure)
///   - resto (consulta/derechos)→ 'orientacion' (_composeGuidance)
///
/// `cardCategoryOf` mapea una glosa a su categoría (vía catálogo) para no
/// duplicar conocimiento del léxico. Como el motor garantiza cobertura
/// (`_ensureCoverage`), un reenrutado imperfecto nunca pierde glosas.
String resolveAssemblerContext(
  String contextId,
  List<String> glosses,
  String? Function(String gloss) cardCategoryOf,
) {
  // El contexto de preguntas conserva su dominio: no debe colarse como
  // orientación porque la salida cambia de intención.
  if (contextId == 'preguntas') return 'preguntas';
  // Fase 1 no narra: sus glosas son marcadores que encabezan la
  // declaración, y el compositor genérico las emite tal cual.
  if (contextId == 'identificacion') return 'identificacion';

  // Consultas usa el compositor de orientación tal cual.
  if (contextId == 'consulta') return 'orientacion';

  // Trámites se reparte entre dos compositores según lo elegido. PERDER ya
  // existe como glosa, así que la pérdida deja de depender solo de que
  // aparezca un objeto: la persona puede decirlo con todas las letras.
  if (contextId != 'tramite') return contextId;
  var hasObject = false;
  var hasDocOrProcedure = false;
  for (final g in glosses) {
    if (g.toUpperCase() == 'PERDER') hasObject = true;
    final cat = cardCategoryOf(g);
    if (cat == 'Objetos') hasObject = true;
    if (cat == 'Documentos' || cat == 'Conceptos jurídicos') hasDocOrProcedure = true;
  }
  // Un objeto solo indica pérdida si no se nombra además un documento o un
  // trámite: "corregir mi carnet y mi teléfono" es una gestión, no un
  // extravío. Solo PERDER lo decide por sí mismo.
  final dijoPerder = glosses.any((g) => g.toUpperCase() == 'PERDER');
  if (dijoPerder || (hasObject && !hasDocOrProcedure)) return 'perdida';
  if (hasDocOrProcedure) return 'tramite_id';
  return 'orientacion';
}

/// Contexto del catálogo con ese id, o `null` si no existe.
///
/// Permite que la conversación resuelva un `contextId` inferido —que viaja
/// como texto en el mensaje semántico— al contexto real con el que abrir el
/// flujo guiado, sin que la capa de presentación reimplemente la búsqueda.
SemanticContext? contextById(String id) {
  for (final context in allSelectableContexts) {
    if (context.id == id) return context;
  }
  return null;
}
