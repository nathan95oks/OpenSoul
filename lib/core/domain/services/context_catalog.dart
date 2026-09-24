import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart'
    show DeclarationDraftLimits;
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_zone.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart'
    show kEvidenceMarker;

/// Quita duplicados exactos conservando el primer orden de aparición.
///
/// Varias zonas del catálogo traían la misma glosa repetida dos veces
/// (BILLETES, MICRO, PAREJA, AMIGO, NOMBRE, FISCALIA, PRESENTAR...), lo que
/// hacía aparecer la misma tarjeta dos veces en la misma pregunta.
List<String> _dedupe(List<String> glosses) => glosses.toSet().toList();

/// Contexto para preguntas directas del ciudadano sordo (Sección 7 del Corpus Maestro).
final preguntasContext = SemanticContext(
  id: 'preguntas',
  name: 'Preguntas',
  icon: 'question_answer',
  emoji: '❓',
  description: 'Preguntas y consultas del ciudadano sordo',
  entryZoneId: 'interrogativa',
  zones: const [
    SemanticZone(
      id: 'interrogativa',
      label: 'Pregunta',
      hint: 'Qué quiero preguntar',
      question: '¿Qué quieres preguntar?',
      emoji: '❓',
      semanticWeight: 0.95,
      glossAllowlist: [
        'DÓNDE', 'QUIÉN', 'QUÉ', 'CUÁNDO', 'CUÁL',
        'CÓMO', 'CUÁNTOS',
      ],
      relatedZones: ['lugar_pregunta', 'persona_pregunta', 'tema_pregunta'],
    ),
    SemanticZone(
      id: 'lugar_pregunta',
      label: 'Lugar o institución',
      hint: 'De qué lugar o institución pregunto',
      question: '¿Dónde queda…?',
      emoji: '📍',
      semanticWeight: 0.8,
      optional: true,
      glossAllowlist: [
        'FISCALIA', 'FELCC', 'FELCV', 'JUZGADO', 'ÓRGANO_JUDICIAL',
        'SEPDAVI', 'SEPDEP', 'POLICÍA', 'OFICINA', 'HOSPITAL', 'AQUÍ',
      ],
    ),
    SemanticZone(
      id: 'persona_pregunta',
      label: 'Persona',
      hint: 'Por quién pregunto',
      question: '¿Con quién deseo hablar?',
      emoji: '👤',
      semanticWeight: 0.8,
      optional: true,
      glossAllowlist: [
        'JUEZ', 'ABOGADO', 'INTÉRPRETE', 'POLICÍA', 'OFICIAL',
        'DOCTOR', 'TESTIGO', 'AUTORIDAD', 'ASISTENTE',
      ],
    ),
    SemanticZone(
      id: 'tema_pregunta',
      label: 'Tema o trámite',
      hint: 'Sobre qué trámite o evidencia consulto',
      question: '¿Sobre qué tema es la pregunta?',
      emoji: '📋',
      semanticWeight: 0.8,
      optional: true,
      glossAllowlist: [
        'INVESTIGACIÓN', 'TRÁMITE', 'RESOLUCIÓN', 'CONVOCAR',
        'RESULTADO', 'PLAZO', 'CERTIFICADO', 'CARPETA',
        'PAPEL', 'FOTOCOPIA', 'FACTURA', 'CELULAR',
        'FOTOS', 'VIDEO', 'SELLO', 'ASISTENCIA', 'JUSTICIA', 'LEY',
      ],
    ),
    SemanticZone(
      id: 'tiempo_pregunta',
      label: 'Tiempo y retorno',
      hint: 'Cuándo o cuánto tiempo',
      question: '¿Cuándo debo volver o cuánto esperar?',
      emoji: '🕐',
      semanticWeight: 0.7,
      optional: true,
      glossAllowlist: [
        'VOLVER', 'ESPERAR', 'AVISAR', 'HOY', 'MAÑANA',
        'PRÓXIMO', 'DÍA', 'SEMANA', 'MES', 'HORA', 'FECHA',
      ],
      chainTriggers: ['DÍA', 'SEMANA', 'MES', 'HORA'],
      chainZoneId: 'cantidad_pregunta',
    ),
    SemanticZone(
      id: 'cantidad_pregunta',
      label: 'Cantidad',
      hint: 'Cantidad de días, horas o personas',
      question: '¿Cuántos?',
      emoji: '🔢',
      semanticWeight: 0.3,
      optional: true,
      glossAllowlist: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
    ),
  ],
);

/// Contexto para identificación del ciudadano sordo y canal de comunicación.
final identificacionContext = SemanticContext(
  id: 'identificacion',
  name: 'Mis datos',
  icon: 'badge',
  emoji: '🪪',
  description: 'Identificación, lengua y datos de contacto',
  entryZoneId: 'identidad',
  zones: [
    SemanticZone(
      id: 'identidad',
      label: 'Identidad',
      hint: 'Nombre, apellido y documento de identidad',
      question: '¿Cuál es su nombre e identidad?',
      emoji: '🪪',
      semanticWeight: 0.95,
      maxPicks: 3,
      // APELLIDO y CARNET no son tarjetas reales del catálogo oficial (solo
      // NOMBRE/PAPEL/IDENTIDAD lo son): el compositor ya las reconoce por
      // reconocimiento de seña (ver local_sentence_assembler.dart), pero
      // ofrecerlas aquí como tarjeta táctil inventaría una entrada de
      // catálogo con procedencia que no existe.
      glossAllowlist: _dedupe(['NOMBRE', 'PAPEL', 'IDENTIDAD', 'SORDO', 'LEER', 'POCO', 'INTÉRPRETE']),
      relatedZones: ['contacto', 'edad'],
    ),
    SemanticZone(
      id: 'contacto',
      label: 'Contacto',
      hint: 'Número de celular y avisos por mensaje',
      question: '¿Cómo prefiere que le contactemos?',
      emoji: '📱',
      semanticWeight: 0.85,
      optional: true,
      maxPicks: 2,
      glossAllowlist: ['CELULAR', 'ESCRIBIR', 'ENVIAR', 'AVISAR', 'MEJOR', 'DIRECCIÓN', 'CAMBIAR'],
      relatedZones: ['acompanante'],
    ),
    SemanticZone(
      id: 'acompanante',
      label: 'Acompañante',
      hint: 'Si vino solo o con alguien',
      question: '¿Vino solo o acompañado?',
      emoji: '👥',
      semanticWeight: 0.7,
      optional: true,
      glossAllowlist: ['ACOMPAÑAR', 'AMIGO', 'HERMANO', 'HERMANA', 'MAMÁ', 'HIJO', 'HIJA', 'INTÉRPRETE', '1'],
    ),
    SemanticZone(
      id: 'edad',
      label: 'Edad',
      hint: 'Qué edad tengo',
      question: '¿Qué edad tiene?',
      emoji: '🎂',
      semanticWeight: 0.6,
      optional: true,
      // ANOS_EDAD tampoco es una tarjeta real del catálogo; mismo criterio
      // que APELLIDO/CARNET arriba.
      glossAllowlist: ['EDAD', 'JOVEN', 'ADULTO'],
    ),
  ],
);

/// Contextos operativos principales para la etapa preliminar judicial penal.
final availableContexts = <SemanticContext>[
  // 1. Denuncia de Robo / Hurto (Delitos patrimoniales)
  SemanticContext(
    id: 'denuncia_robo',
    name: 'Denunciar robo',
    icon: 'warning_amber',
    emoji: '🚨',
    description: 'Robo, hurto o pérdida de celular, dinero, documentos o bienes',
    entryZoneId: 'hecho',
    baseUrgency: UrgencyLevel.medium,
    // Auditoría 2026-09 (sección 12.1 del prompt de auditoría): se separan
    // hecho, participantes y acciones posteriores; PERDER ya no puede
    // derivar en una afirmación de robo, y APARIENCIA se fusiona con
    // PERSONA (editar la misma entidad en vez de duplicar la descripción).
    // 'objetos', 'persona' y 'lugar' usan el editor de entidades
    // (denunciaRoboDraftProvider) en vez de una simple lista de glosas: cada
    // objeto conserva su papel, cada persona sus propias prendas y colores,
    // y el lugar conserva la relación espacial junto con su referencia.
    zones: [
      SemanticZone(
        id: 'hecho',
        label: 'Hecho',
        hint: 'Qué le ocurrió',
        question: '¿Qué le ocurrió?',
        emoji: '⚡',
        semanticWeight: 0.95,
        // NO_SABER no tiene sentido aquí: es la pregunta fundacional del
        // relato, y "no sé qué me pasó" no es una respuesta que la persona
        // venga a declarar — a diferencia de "¿conoce a la persona?" o
        // "¿cuándo ocurrió?", donde no saber sí es una respuesta real.
        glossAllowlist: _dedupe(['ROBAR', 'PERDER', 'ESCAPAR', 'DAÑAR', 'ENGAÑAR']),
        // Un relato puede llevar dos acciones: «me robaron y escapó». Subir
        // esto es condición necesaria, no suficiente: lo que de verdad lo
        // permite es que el borrador guarde una colección de hechos, cada uno
        // con su protagonista. Con `maxPicks` solo, se podían tocar dos
        // tarjetas y seguía guardándose una sola acción.
        maxPicks: DeclarationDraftLimits.maxFacts,
        contextTags: [EmotionalTag.amenaza],
        relatedZones: ['objetos', 'persona', 'lugar', 'tiempo'],
      ),
      SemanticZone(
        id: 'objetos',
        label: 'Objetos involucrados',
        hint: 'Qué objetos están involucrados y qué papel cumple cada uno',
        question: '¿Qué objetos están involucrados?',
        emoji: '📱',
        semanticWeight: 0.9,
        maxPicks: 8,
        glossAllowlist: _dedupe([
          'CELULAR', 'BILLETES', 'MOCHILA', 'BOLSA',
          'PAPEL', 'IDENTIDAD', 'FACTURA', 'CAJA',
          'CHAMARRA', 'GORRA', 'LENTES', 'MICRO', 'TRUFI',
        ]),
        relatedZones: ['persona', 'lugar'],
      ),
      SemanticZone(
        id: 'persona',
        label: 'Personas descritas',
        hint: 'Quién estuvo involucrado y cómo era, con su ropa y color',
        question: '¿Puede describir a la persona involucrada?',
        emoji: '👤',
        semanticWeight: 0.85,
        optional: true,
        maxPicks: 6,
        // Solo el género inicia la ficha: tocar HOMBRE/MUJER abre el
        // asistente secuencial (edad, complexión/estatura, vestimenta con
        // color), que ya pregunta el resto paso a paso. Repetir esas mismas
        // glosas como tarjetas sueltas aquí las mostraba todas de encuentro,
        // confuso, porque el asistente vuelve a pedirlas una por una.
        glossAllowlist: const ['HOMBRE', 'MUJER'],
        relatedZones: ['conocimiento', 'lugar', 'tiempo'],
      ),
      SemanticZone(
        id: 'conocimiento',
        label: 'Conocimiento de la persona',
        hint: 'Si conoce a la persona involucrada y qué vínculo tiene',
        question: '¿Conoce a esa persona?',
        emoji: '👥',
        semanticWeight: 0.8,
        optional: true,
        // VER ("ver") no es una respuesta a "¿conoce a esa persona?": ni es
        // sí/no ni nombra un vínculo, como sí lo hacen AMIGO/PAREJA/etc.
        glossAllowlist: _dedupe(['SÍ', 'NO', 'NO_SABER', 'AMIGO', 'PAREJA', 'PARIENTE', 'HERMANO']),
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde ocurrió, con la referencia si hace falta',
        question: '¿Dónde ocurrió?',
        emoji: '📍',
        semanticWeight: 0.75,
        glossAllowlist: [
          'CALLE', 'AVENIDA', 'PLAZA', 'MERCADO', 'BARRIO',
          'TIENDA', 'CASA', 'COCHABAMBA', 'DENTRO', 'FUERA',
          'CERCA', 'LEJOS', 'AL_LADO', 'MICRO', 'TRUFI',
        ],
        relatedZones: ['tiempo', 'evidencia'],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Momento',
        hint: 'Cuándo ocurrió el hecho',
        question: '¿Cuándo ocurrió el hecho?',
        emoji: '🕐',
        semanticWeight: 0.7,
        optional: true,
        glossAllowlist: [
          'AHORA', 'HOY', 'AYER', 'ANTEAYER', 'TARDE', 'TEMPRANO',
          'HORA', 'MINUTO', 'DÍA', 'SEMANA', 'MES', 'NO_SABER',
        ],
        chainTriggers: ['HORA', 'MINUTO', 'DÍA', 'SEMANA', 'MES'],
        chainZoneId: 'cantidad',
      ),
      SemanticZone(
        id: 'testigos',
        label: 'Testigos presenciales',
        hint: 'Si hay testigos y cuántos',
        question: '¿Hay testigos?',
        emoji: '👁️',
        semanticWeight: 0.7,
        optional: true,
        glossAllowlist: ['SÍ', 'NO', 'NO_SABER'],
        chainTriggers: ['SÍ'],
        chainZoneId: 'cantidad',
      ),
      SemanticZone(
        id: 'evidencia',
        label: 'Evidencia disponible',
        hint: 'Fotos, video u otro elemento de prueba',
        question: '¿Tiene fotos, video u otro elemento de prueba?',
        emoji: '📎',
        semanticWeight: 0.65,
        optional: true,
        maxPicks: 6,
        // FILMAR/CAJA/PAPEL/MOSTRAR/PUEDO no eran respuestas reales a "¿qué
        // prueba tiene?": CAJA/PAPEL son objetos de otras preguntas, y
        // FILMAR/MOSTRAR/PUEDO son verbos sueltos sin acción asociada aquí.
        // FACTURA se mantiene: es evidencia concreta real del corpus (ver
        // test/precision_ventanilla_test.dart). ESCRIBIR es el "otro": abre
        // un teclado libre (ver su despacho en qualifier_sheets.dart) para
        // nombrar cualquier prueba que no sea foto, video o factura.
        glossAllowlist: const ['FOTOS', 'VIDEO', 'FACTURA', 'ESCRIBIR'],
        leadGloss: kEvidenceMarker,
      ),
      SemanticZone(
        id: 'emergencia',
        label: 'Atención médica',
        hint: 'Si está herido o necesita atención médica',
        question: '¿Está herido o necesita atención médica?',
        emoji: '🏥',
        semanticWeight: 0.65,
        optional: true,
        maxPicks: 2,
        glossAllowlist: ['HERIDA', 'DOLOR', 'HOSPITAL', 'DOCTOR', 'CERTIFICADO', 'AUXILIO', 'SÍ', 'NO'],
      ),
      SemanticZone(
        id: 'denuncia',
        label: 'Formalizar denuncia',
        hint: 'Si desea presentar la denuncia formal',
        question: '¿Desea presentar una denuncia formal?',
        emoji: '⚖️',
        semanticWeight: 0.6,
        optional: true,
        glossAllowlist: ['SÍ', 'NO', 'NO_SABER', 'AHORA'],
      ),
      SemanticZone(
        id: 'apoyo_legal',
        label: 'Apoyo legal e intérprete',
        hint: 'Abogado o intérprete',
        question: '¿Necesita apoyo legal?',
        emoji: '🤝',
        semanticWeight: 0.6,
        optional: true,
        glossAllowlist: ['ABOGADO', 'INTÉRPRETE', 'SEPDAVI', 'SEPDEP', 'GRATIS', 'AYUDAR', 'SÍ', 'NO'],
      ),
      SemanticZone(
        id: 'institucion',
        label: 'Autoridad receptora',
        hint: 'Dónde presentar la denuncia',
        question: '¿Ante qué autoridad desea presentar la denuncia?',
        emoji: '🏛️',
        semanticWeight: 0.5,
        optional: true,
        glossAllowlist: [
          'POLICÍA', 'FELCC', 'FISCALIA', 'SEPDAVI', 'ABOGADO', 'INTÉRPRETE',
        ],
      ),
      SemanticZone(
        id: 'cantidad',
        label: 'Cantidad',
        hint: 'Cantidad',
        question: '¿Cuántos?',
        emoji: '🔢',
        semanticWeight: 0.25,
        optional: true,
        glossAllowlist: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
      ),
    ],
  ),

  // 2. Denuncia de Violencia / Agresión física y amenazas
  SemanticContext(
    id: 'violencia',
    name: 'Denunciar violencia',
    icon: 'shield',
    emoji: '🛡️',
    description: 'Agresión física, maltrato, violencia intrafamiliar o amenazas',
    entryZoneId: 'hecho',
    baseUrgency: UrgencyLevel.high,
    zones: [
      SemanticZone(
        id: 'hecho',
        label: 'Agresión o violencia',
        hint: 'Qué tipo de agresión ocurrió',
        question: '¿Qué agresión o maltrato sufrió?',
        emoji: '⚡',
        semanticWeight: 0.95,
        urgencyLevel: UrgencyLevel.high,
        glossAllowlist: [
          'PEGAR', 'MALTRATAR', 'VIOLENCIA', 'AMENAZAR', 'ABUSAR',
          'PELEAR', 'DAÑAR', 'GRITAR',
        ],
        contextTags: [EmotionalTag.amenaza, EmotionalTag.peligro],
        relatedZones: ['persona', 'salud_urgencia', 'emocion_riesgo'],
      ),
      SemanticZone(
        id: 'persona',
        label: 'Persona agresora',
        hint: 'Quién cometió la agresión o amenaza',
        question: '¿Quién es la persona agresora?',
        emoji: '👤',
        semanticWeight: 0.9,
        maxPicks: 2,
        glossAllowlist: _dedupe([
          'PAREJA', 'HOMBRE', 'MUJER', 'HERMANO',
          'HERMANA', 'ESPOSA', 'PARIENTE', 'JOVEN', 'ADULTO',
        ]),
        relatedZones: ['salud_urgencia', 'emocion_riesgo'],
      ),
      SemanticZone(
        id: 'salud_urgencia',
        label: 'Heridas y atención médica',
        hint: 'Lesiones físicas, hospital o certificado forense',
        question: '¿Está herido o fue al hospital?',
        emoji: '🏥',
        semanticWeight: 0.85,
        maxPicks: 3,
        glossAllowlist: [
          'HERIDA', 'BRAZO', 'DOLOR', 'FRACTURA', 'HUESOS',
          'HOSPITAL', 'DOCTOR', 'CERTIFICADO', 'CURAR', 'MEDICINA',
          'AUXILIO', 'URGENTE',
        ],
        contextTags: [EmotionalTag.urgente, EmotionalTag.dolor],
        relatedZones: ['emocion_riesgo', 'evidencia'],
      ),
      SemanticZone(
        id: 'emocion_riesgo',
        label: 'Riesgo y protección',
        hint: 'Temor, retorno a casa o protección a hijos',
        question: '¿Tiene miedo o requiere protección?',
        emoji: '💔',
        semanticWeight: 0.8,
        glossAllowlist: [
          'MIEDO', 'TRISTE', 'CASA', 'VOLVER', 'PROTEGER',
          'HIJO', 'HIJA', 'AUXILIO', 'AHORA', 'NECESITAR',
        ],
        contextTags: [EmotionalTag.miedo, EmotionalTag.urgente],
        relatedZones: ['institucion'],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Frecuencia y momento',
        hint: 'Cuándo o si es recurrente',
        question: '¿Cuándo pasó o con qué frecuencia?',
        emoji: '🕐',
        semanticWeight: 0.65,
        optional: true,
        glossAllowlist: [
          'AHORA', 'HOY', 'AYER', 'SIEMPRE', 'CADA_DÍA',
          'TODOS_LOS_DÍAS', 'PRIMERA_VEZ',
        ],
      ),
      SemanticZone(
        id: 'evidencia',
        label: 'Pruebas',
        hint: 'Certificado médico, mensajes o fotos',
        question: '¿Tiene certificado del doctor o mensajes guardados?',
        emoji: '📎',
        semanticWeight: 0.65,
        optional: true,
        maxPicks: 3,
        glossAllowlist: [
          'CERTIFICADO', 'DOCTOR', 'FOTOS', 'VIDEO', 'ESCRIBIR',
          'GUARDAR', 'TOTAL', 'TESTIGO',
        ],
        leadGloss: kEvidenceMarker,
      ),
      SemanticZone(
        id: 'institucion',
        label: 'Asistencia y denuncia',
        hint: 'Acudir a FELCV, SEPDAVI o pedir abogado',
        question: '¿Desea asistencia especializada?',
        emoji: '🏛️',
        semanticWeight: 0.6,
        glossAllowlist: [
          'POLICÍA', 'FELCV', 'SEPDAVI', 'SEPDEP', 'ABOGADO',
          'GRATIS', 'INTÉRPRETE', 'ASISTENCIA',
        ],
      ),
    ],
  ),

  // 3. Amenazas Digitales / Mensajes por celular o internet
  SemanticContext(
    id: 'amenaza_digital',
    name: 'Amenazas digitales',
    icon: 'chat',
    emoji: '💬',
    description: 'Amenazas por celular, mensajes de texto o internet',
    entryZoneId: 'hecho',
    baseUrgency: UrgencyLevel.medium,
    zones: [
      SemanticZone(
        id: 'hecho',
        label: 'Mensajes recibidos',
        hint: 'Recepción de amenazas y hostigamiento digital',
        question: '¿Qué tipo de mensajes recibió?',
        emoji: '📱',
        semanticWeight: 0.95,
        glossAllowlist: [
          'AMENAZAR', 'CELULAR', 'INTERNET', 'ESCRIBIR', 'ENVIAR',
          'RECIBIR', 'AÚN',
        ],
        contextTags: [EmotionalTag.amenaza],
        relatedZones: ['persona', 'evidencia'],
      ),
      SemanticZone(
        id: 'persona',
        label: 'Remitente',
        hint: 'Quién envía los mensajes o si conoce el número',
        question: '¿Quién le envía los mensajes?',
        emoji: '👤',
        semanticWeight: 0.85,
        glossAllowlist: _dedupe([
          'PAREJA', 'HOMBRE', 'MUJER', 'CONOCER',
          'CELULAR',
        ]),
        relatedZones: ['evidencia'],
      ),
      SemanticZone(
        id: 'evidencia',
        label: 'Capturas y mensajes guardados',
        hint: 'Fotos de pantalla y conservación de chat',
        question: '¿Guardó los mensajes o tiene fotos de pantalla?',
        emoji: '📎',
        semanticWeight: 0.9,
        maxPicks: 3,
        glossAllowlist: [
          'ESCRIBIR', 'TOTAL', 'GUARDAR', 'FOTOS', 'CELULAR',
          'VIDEO', 'MOSTRAR', 'PUEDO', 'AHORA',
        ],
        leadGloss: kEvidenceMarker,
      ),
      SemanticZone(
        id: 'institucion',
        label: 'Denuncia',
        hint: 'Presentar ante FELCC o Fiscalía',
        question: '¿Desea presentar los mensajes como prueba?',
        emoji: '🏛️',
        semanticWeight: 0.6,
        optional: true,
        glossAllowlist: [
          'POLICÍA', 'FELCC', 'FELCV', 'FISCALIA', 'SEPDAVI', 'ABOGADO',
        ],
      ),
    ],
  ),

  // 4. Engaño con dinero / Estafas y transacciones bancarias
  SemanticContext(
    id: 'engano_dinero',
    name: 'Engaño con dinero',
    icon: 'payments',
    emoji: '💵',
    description: 'Estafa, engaño económico o transferencias bancarias',
    entryZoneId: 'hecho',
    baseUrgency: UrgencyLevel.medium,
    zones: [
      SemanticZone(
        id: 'hecho',
        label: 'Engaño o estafa',
        hint: 'Qué ocurrió con el dinero',
        question: '¿Cómo ocurrió el engaño con el dinero?',
        emoji: '⚡',
        semanticWeight: 0.95,
        glossAllowlist: _dedupe([
          'ENGAÑAR', 'BILLETES', 'ENVIAR', 'DAR', 'PERDER',
        ]),
        relatedZones: ['medio_banco', 'persona', 'comprobante'],
      ),
      SemanticZone(
        id: 'medio_banco',
        label: 'Vía de pago o entrega',
        hint: 'Mediante banco, internet o entrega directa',
        question: '¿Cómo entregó o envió el dinero?',
        emoji: '🏦',
        semanticWeight: 0.85,
        glossAllowlist: [
          'BANCO', 'CELULAR', 'INTERNET', 'ESCRIBIR', 'BILLETES',
        ],
        relatedZones: ['comprobante'],
      ),
      SemanticZone(
        id: 'persona',
        label: 'Persona receptora',
        hint: 'Nombre o datos de quien recibió el dinero',
        question: '¿Conoce el nombre o número de la persona?',
        emoji: '👤',
        semanticWeight: 0.8,
        glossAllowlist: [
          'NOMBRE', 'CELULAR', 'HOMBRE', 'MUJER', 'CONOCER',
        ],
        relatedZones: ['comprobante'],
      ),
      SemanticZone(
        id: 'comprobante',
        label: 'Comprobante y documentos',
        hint: 'Papel del banco, factura o registro de mensajes',
        question: '¿Tiene el papel del banco o factura?',
        emoji: '📄',
        semanticWeight: 0.85,
        maxPicks: 3,
        glossAllowlist: [
          'PAPEL', 'BANCO', 'FACTURA', 'ESCRIBIR', 'TOTAL',
          'GUARDAR', 'MOSTRAR', 'PUEDO',
        ],
        leadGloss: kEvidenceMarker,
      ),
      SemanticZone(
        id: 'institucion',
        label: 'Denuncia',
        hint: 'FELCC o Fiscalía',
        question: '¿Desea presentar la denuncia formal?',
        emoji: '🏛️',
        semanticWeight: 0.5,
        optional: true,
        glossAllowlist: [
          'POLICÍA', 'FELCC', 'FISCALIA', 'SEPDAVI', 'ABOGADO',
        ],
      ),
    ],
  ),

  // 5. Seguimiento de investigación y trámites institucionales
  SemanticContext(
    id: 'seguimiento',
    name: 'Consultar trámite',
    icon: 'fact_check',
    emoji: '📂',
    description: 'Estado del caso, citaciones, resoluciones o citas judiciales',
    entryZoneId: 'tramite',
    zones: [
      SemanticZone(
        id: 'tramite',
        label: 'Gestión o documento',
        hint: 'Consultar avance, citaciones o resoluciones',
        question: '¿Qué gestión o trámite viene a consultar?',
        emoji: '📋',
        semanticWeight: 0.95,
        glossAllowlist: [
          'INVESTIGACIÓN', 'RESOLUCIÓN', 'TRÁMITE', 'CONVOCAR',
          'RESULTADO', 'PLAZO', 'ASISTENCIA', 'PAPEL', 'CERTIFICADO',
          'CARPETA', 'FOTOCOPIA', 'SELLO',
        ],
        relatedZones: ['accion', 'institucion_autoridad'],
      ),
      SemanticZone(
        id: 'accion',
        label: 'Acción en ventanilla',
        hint: 'Saber estado, presentar documentos, pedir copias o solicitar apoyo',
        question: '¿Qué acción necesita realizar?',
        emoji: '🗣️',
        semanticWeight: 0.85,
        glossAllowlist: [
          'SABER', 'PRESENTAR', 'PEDIR', 'RECIBIR', 'DAR',
          'BUSCAR', 'VER', 'AVISAR', 'ESPERAR', 'VOLVER',
          'ESCRIBIR', 'AYUDAR', 'EXPLICAR',
        ],
        relatedZones: ['institucion_autoridad'],
      ),
      SemanticZone(
        id: 'institucion_autoridad',
        label: 'Autoridad o institución',
        hint: 'Policía, Fiscal, Juez, SEPDAVI o SEPDEP',
        question: '¿Con qué autoridad o institución debe coordinar?',
        emoji: '🏛️',
        semanticWeight: 0.9,
        glossAllowlist: _dedupe([
          'FISCALIA', 'JUZGADO', 'ÓRGANO_JUDICIAL', 'POLICÍA',
          'FELCC', 'FELCV', 'SEPDAVI', 'SEPDEP', 'JUEZ',
          'ABOGADO', 'INTÉRPRETE', 'AUTORIDAD', 'OFICINA',
        ]),
        relatedZones: ['tiempo'],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Fecha y retorno',
        hint: 'Cuándo debe volver',
        question: '¿Para cuándo está programada la actuación?',
        emoji: '🕐',
        semanticWeight: 0.65,
        optional: true,
        glossAllowlist: [
          'HOY', 'MAÑANA', 'PRÓXIMO', 'DÍA', 'SEMANA', 'HORA', 'FECHA',
        ],
      ),
    ],
  ),

  // 6. Testigo / Declaración general
  SemanticContext(
    id: 'otro',
    name: 'Declaración y testimonio',
    icon: 'visibility',
    emoji: '👁️',
    description: 'Testimonio de testigo presencial o aclaraciones',
    entryZoneId: 'relato',
    zones: const [
      SemanticZone(
        id: 'relato',
        label: 'Testimonio',
        hint: 'Lo que observó y desea relatar',
        question: '¿Qué presenció o desea declarar?',
        emoji: '🗣️',
        semanticWeight: 0.95,
        glossAllowlist: [
          'OBSERVAR', 'TESTIGO', 'TESTIMONIO', 'VER', 'TOTAL',
          'NARRAR', 'EXPLICAR', 'EMPEZAR', 'AUMENTAR', 'ARREGLAR',
        ],
        relatedZones: ['acceso', 'persona'],
      ),
      SemanticZone(
        id: 'persona',
        label: 'Personas involucradas',
        hint: 'A quién observó',
        question: '¿A quién observó durante el hecho?',
        emoji: '👤',
        semanticWeight: 0.8,
        glossAllowlist: [
          'HOMBRE', 'MUJER', 'JOVEN', 'ADULTO', 'LADRÓN', 'CONOCER',
        ],
      ),
      SemanticZone(
        id: 'acceso',
        label: 'Acceso y comprensión',
        hint: 'Comprensión, intérprete y lectura',
        question: '¿Necesita aclaraciones o intérprete?',
        emoji: '🤝',
        semanticWeight: 0.75,
        glossAllowlist: [
          'SORDO', 'LEER', 'POCO', 'INTÉRPRETE', 'LENTO',
          'POR_FAVOR', 'COMPRENDER', 'GRACIAS', 'ESTAR_DE_ACUERDO',
        ],
      ),
    ],
  ),
];

/// Lista completa de contextos seleccionables por el usuario en la interfaz.
final allSelectableContexts = <SemanticContext>[
  ...availableContexts,
  identificacionContext,
  preguntasContext,
];

/// Lista por defecto para el catálogo
final defaultSemanticContexts = allSelectableContexts;

/// Busca un contexto por su ID
SemanticContext? contextById(String id) {
  for (final c in allSelectableContexts) {
    if (c.id == id) return c;
  }
  return null;
}

/// Cómo quedó el enrutamiento hacia un contexto del ensamblador.
enum RouteStatus {
  /// El contexto existe y el ensamblador sabe redactarlo.
  supported,

  /// Se entiende qué se quiere hacer, pero no hay recorrido ni vocabulario
  /// para sostenerlo. No es un error: es una función que todavía no está.
  unsupported,
}

/// El resultado de enrutar, con su motivo.
///
/// Devolver una simple cadena obligaba a inventar un destino para todo. El
/// enrutador anterior mandaba a `denuncia_robo` cualquier caso que no
/// reconociera —incluidos los trámites— y convertía en denuncia de robo algo
/// que nadie había declarado.
class AssemblerRoute {
  final String contextId;
  final RouteStatus status;
  final String reason;

  /// Conceptos que harían falta y el catálogo no tiene. Se declaran para
  /// poder decirlo en pantalla en vez de simular cobertura.
  final List<String> missingVocabulary;

  const AssemblerRoute({
    required this.contextId,
    this.status = RouteStatus.supported,
    this.reason = '',
    this.missingVocabulary = const [],
  });

  bool get isSupported => status == RouteStatus.supported;
}

/// Los contextos que el ensamblador sabe redactar. Enrutar fuera de esta
/// lista produce una frase genérica, no la del contexto que se pidió.
const Set<String> assemblerContexts = {
  // Los ocho seleccionables en la interfaz.
  'denuncia_robo',
  'violencia',
  'amenaza_digital',
  'engano_dinero',
  'seguimiento',
  'identificacion',
  'preguntas',
  'otro',
  // Compositores internos que no son contextos de interfaz. Existen y están
  // probados desde hace tiempo; lo que faltaba era una vía para alcanzarlos.
  'perdida',
  'tramite_id',
  'orientacion',
};

/// Necesidad de negocio → contexto del ensamblador que la sirve.
///
/// Sustituye a las ramas `tramite` y `consulta`, que comparaban contra
/// identificadores de contexto que el catálogo **nunca ha ofrecido**
/// (`allSelectableContexts` no tiene ninguno con esos ids), de modo que sus
/// compositores —`_composeLoss`, `_composeProcedure`, `_composeGuidance`—
/// eran inalcanzables desde la interfaz aunque estuvieran escritos y
/// probados. Ahora los alcanza la necesidad elegida, que sí existe.
const Map<String, String> contextForNeed = {
  'denuncias': 'denuncia_robo',
  'tramites': 'tramite_id',
  'consultas': 'orientacion',
};

/// Dentro de «trámites», qué compositor corresponde.
///
/// Tres cosas distintas que no se redactan igual: perder un documento relata
/// un extravío, gestionarlo relata una gestión, y pedir un intérprete o un
/// abogado es pedir orientación. El reparto es el que ya existía; lo que
/// cambia es que ahora cuelga de la necesidad y no de un contexto que el
/// catálogo nunca ha ofrecido.
String _procedureContextFor(Set<String> norm) {
  const perdida = {'FALTA', 'PERDER', 'TELEFONO', 'CARNET'};
  if (norm.any(perdida.contains)) return 'perdida';

  const gestion = {
    'PASAPORTE', 'INVESTIGACION', 'GESTIONAR', 'FOTOCOPIA',
    'LICENCIA_DECONDUCIR', 'PODER', 'TESTIMONIO',
  };
  if (norm.any(gestion.contains)) return 'tramite_id';

  const orientacion = {'INTERPRETE', 'HABLAR', 'ABOGADO', 'INSTITUCION'};
  if (norm.any(orientacion.contains)) return 'orientacion';

  return 'tramite_id';
}

/// Intenciones cuyo recorrido no existe todavía, con lo que les falta.
///
/// Salen de los perfiles declarados sin cobertura en
/// `docs/negocio/config/perfiles_institucionales.json`. Se listan aquí para
/// que el enrutador pueda decir «esto todavía no» en vez de aproximar.
const Map<String, List<String>> unsupportedIntents = {
  'DDRR_FOLIO_ACTUALIZADO': ['FOLIO', 'PROPIEDAD'],
  'DDRR_CERTIFICADO_PROPIEDAD': ['PROPIEDAD'],
  'DDRR_CERTIFICADO_NO_PROPIEDAD': ['PROPIEDAD'],
  'NOTARIA_GESTION_DOCUMENTAL': ['DOCUMENTO', 'ESCRITURA', 'REGISTRAR'],
  'GAMC_GESTION_MUNICIPAL': ['PAGAR', 'REGISTRAR', 'RENOVAR'],
};

/// Enruta hacia el contexto que el ensamblador sabe redactar.
///
/// Orden de decisión, de más explícito a menos:
///
///   1. una intención declarada sin cobertura corta aquí,
///   2. las glosas elegidas, que son lo que la persona dijo de verdad,
///   3. la necesidad elegida,
///   4. el contexto activo, si es uno de los soportados.
///
/// Si nada de eso resuelve, **no se inventa un destino**: se devuelve `otro`,
/// que es el contexto general, marcado como no soportado y con su motivo.
/// Mandar lo desconocido a denuncia de robo era poner una acusación en boca
/// de quien no la hizo.
AssemblerRoute routeToAssembler({
  String currentContextId = '',
  List<String> glosses = const [],
  String? needId,
  String? intentId,
}) {
  String unaccent(String s) => s
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U');

  final norm = glosses.map(unaccent).toSet();

  // 1. Intención sin cobertura: se dice, no se aproxima.
  final falta = intentId == null ? null : unsupportedIntents[intentId];
  if (falta != null) {
    return AssemblerRoute(
      contextId: 'otro',
      status: RouteStatus.unsupported,
      reason: 'La intención $intentId no tiene recorrido todavía.',
      missingVocabulary: falta,
    );
  }

  // 2. Lo que la persona eligió manda sobre lo que se supuso de ella.
  if (norm.contains('ROBAR') ||
      norm.contains('LADRON') ||
      norm.contains('QUITAR')) {
    return const AssemblerRoute(
        contextId: 'denuncia_robo', reason: 'acción de sustracción elegida');
  }
  if (norm.contains('GOLPEAR') ||
      norm.contains('INSULTAR') ||
      norm.contains('AMENAZAR') ||
      norm.contains('MIEDO')) {
    return const AssemblerRoute(
        contextId: 'violencia', reason: 'acción o estado de agresión');
  }
  if (norm.contains('INTERNET') ||
      norm.contains('MENTIRA') ||
      norm.contains('FOTO') ||
      norm.contains('NUMERO') ||
      norm.contains('AVISAR')) {
    if (norm.contains('BILLETES') ||
        norm.contains('BANCO') ||
        norm.contains('PAGAR')) {
      return const AssemblerRoute(
          contextId: 'engano_dinero', reason: 'medio digital y dinero');
    }
    return const AssemblerRoute(
        contextId: 'amenaza_digital', reason: 'medio digital');
  }
  if (norm.contains('SEGUIR') ||
      norm.contains('MIRAR') ||
      norm.contains('ESCONDER') ||
      norm.contains('ESPERAR')) {
    return const AssemblerRoute(
        contextId: 'seguimiento', reason: 'acción de seguimiento');
  }

  final esPregunta = norm.contains('DONDE') ||
      norm.contains('QUIEN') ||
      norm.contains('QUE') ||
      norm.contains('CUANDO') ||
      norm.contains('COMO') ||
      norm.contains('CUANTOS') ||
      norm.contains('POR_QUE') ||
      norm.contains('PARA_QUE');

  // "¿Qué es este papel?" es una pregunta sobre un documento, no el
  // formulario de datos de Fase 1: una interrogativa presente manda sobre
  // el atajo de identificación, igual que el resto de este enrutador ya deja
  // que la glosa más específica decida por encima del contexto de entrada.
  if (!esPregunta &&
      (norm.contains('NOMBRE') ||
          norm.contains('IDENTIDAD') ||
          norm.contains('PAPEL'))) {
    if (!norm.contains('ROBAR') && !norm.contains('GOLPEAR')) {
      return const AssemblerRoute(
          contextId: 'identificacion', reason: 'datos de identificación');
    }
  }
  if (esPregunta) {
    return const AssemblerRoute(
        contextId: 'preguntas', reason: 'interrogativa explícita');
  }

  // 3. La necesidad elegida, cuando las glosas no bastan.
  if (needId == 'tramites') {
    return AssemblerRoute(
      contextId: _procedureContextFor(norm),
      reason: 'necesidad elegida: tramites',
    );
  }
  final porNecesidad = needId == null ? null : contextForNeed[needId];
  if (porNecesidad != null) {
    return AssemblerRoute(
      contextId: porNecesidad,
      reason: 'necesidad elegida: $needId',
    );
  }

  // 4. El contexto activo, si el ensamblador lo conoce.
  if (assemblerContexts.contains(currentContextId)) {
    return AssemblerRoute(
        contextId: currentContextId, reason: 'contexto activo');
  }

  // Nada resolvió. No se aproxima a una denuncia.
  return AssemblerRoute(
    contextId: 'otro',
    status: RouteStatus.unsupported,
    reason: currentContextId.isEmpty
        ? 'no hay contexto ni glosas que permitan decidir'
        : 'el contexto $currentContextId no lo redacta el ensamblador',
  );
}

/// Contexto del ensamblador, en la forma de cadena que espera el generador.
///
/// Conserva la firma anterior para quien solo necesita el destino. Quien deba
/// distinguir «no soportado» tiene que usar [routeToAssembler] y mirar el
/// estado.
String resolveAssemblerContext(
  String currentContextId,
  List<String> glosses, [
  dynamic Function(String)? getCategory,
  String? needId,
  String? intentId,
]) =>
    routeToAssembler(
      currentContextId: currentContextId,
      glosses: glosses,
      needId: needId,
      intentId: intentId,
    ).contextId;

/// Mapeo de identificadores de contexto para la UI y el motor de selección.
Set<String> cardSourceContexts(String uiContextId) {
  return switch (uiContextId) {
    'denuncia_robo' => {'denuncia_robo', 'otro'},
    'violencia' => {'violencia', 'otro'},
    'amenaza_digital' => {'amenaza_digital', 'otro'},
    'engano_dinero' => {'engano_dinero', 'otro'},
    'seguimiento' => {'seguimiento', 'otro'},
    'identificacion' => {'identificacion', 'otro'},
    'preguntas' => {'preguntas', 'otro'},
    _ => {uiContextId, 'otro'},
  };
}
