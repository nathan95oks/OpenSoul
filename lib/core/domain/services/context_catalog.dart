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
        'POLICÍA', 'FISCALIA', 'JUEZ', 'ABOGADO', 'INTÉRPRETE',
        'DOCTOR', 'TESTIGO', 'AUTORIDAD',
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
        'INVESTIGACIÓN', 'TRÁMITE', 'TESTIMONIO', 'RESOLUCIÓN', 'CERTIFICADO',
        'FACTURA', 'PAPEL', 'FOTOCOPIA', 'CELULAR', 'FOTOS', 'VIDEO', 'SELLO',
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
        'VOLVER', 'ESPERAR', 'AVISAR', 'TERMINAR', 'CONTINUAR',
        'HOY', 'MAÑANA', 'DÍA', 'SEMANA', 'MES', 'HORA',
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
        glossAllowlist: _dedupe(['ROBAR', 'PERDER', 'ESCAPAR', 'DAÑAR', 'ENGAÑAR', 'NO_SABER']),
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
        glossAllowlist: _dedupe([
          'HOMBRE', 'MUJER', 'JOVEN', 'ADULTO', 'FLACO', 'GORDO',
          'ALTO', 'BAJO', 'MOCHILA', 'GORRA', 'POLERA', 'PANTALÓN',
          'CHAMARRA', 'LENTES', 'CABELLO', 'NEGRO', 'AZUL', 'ROJO',
        ]),
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
        glossAllowlist: _dedupe(['SÍ', 'NO', 'NO_SABER', 'AMIGO', 'PAREJA', 'PARIENTE', 'HERMANO', 'VER']),
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
        hint: 'Fotos, video, factura u otro elemento de prueba',
        question: '¿Tiene fotos, video u otro elemento de prueba?',
        emoji: '📎',
        semanticWeight: 0.65,
        optional: true,
        maxPicks: 6,
        glossAllowlist: _dedupe([
          'FOTOS', 'VIDEO', 'FILMAR', 'FACTURA', 'CAJA', 'PAPEL', 'MOSTRAR', 'PUEDO',
        ]),
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
        label: 'Estado y resoluciones',
        hint: 'Consultar avance, citaciones o resoluciones',
        question: '¿Qué gestión o trámite viene a consultar?',
        emoji: '📋',
        semanticWeight: 0.95,
        glossAllowlist: [
          'INVESTIGACIÓN', 'RESOLUCIÓN', 'PAPEL', 'CONVOCAR',
          'TESTIMONIO', 'SABER', 'CONTINUAR', 'TERMINAR',
        ],
        relatedZones: ['accion', 'institucion_autoridad'],
      ),
      SemanticZone(
        id: 'accion',
        label: 'Acción requerida',
        hint: 'Hablar con funcionario, presentarse o entregar documentos',
        question: '¿Qué acción necesita realizar?',
        emoji: '🗣️',
        semanticWeight: 0.85,
        glossAllowlist: [
          'HABLAR', 'PRESENTAR', 'VOLVER', 'ESPERAR', 'LEER',
          'NOMBRE', 'ESCRIBIR', 'AVISAR', 'COMPRENDER',
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
          'POLICÍA', 'FISCALIA', 'JUEZ', 'JUZGADO',
          'ÓRGANO_JUDICIAL', 'SEPDAVI', 'SEPDEP', 'ABOGADO',
          'GRATIS', 'INTÉRPRETE',
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

/// Resuelve el contexto final del ensamblador según el contexto actual y las glosas seleccionadas
String resolveAssemblerContext(
  String currentContextId,
  List<String> glosses, [
  dynamic Function(String)? getCategory,
]) {
  String unaccent(String s) => s
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U');

  final norm = glosses.map(unaccent).toSet();
  
  if (currentContextId == 'tramite') {
    if (norm.contains('FALTA') || norm.contains('PERDER') || norm.contains('TELEFONO') || norm.contains('CARNET')) {
      return 'perdida';
    }
    if (norm.contains('PASAPORTE') ||
        norm.contains('INVESTIGACION') ||
        norm.contains('GESTIONAR') ||
        norm.contains('FOTOCOPIA') ||
        norm.contains('LICENCIA_DECONDUCIR') ||
        norm.contains('PODER') ||
        norm.contains('TESTIMONIO')) {
      return 'tramite_id';
    }
    if (norm.contains('INTERPRETE') ||
        norm.contains('HABLAR') ||
        norm.contains('ABOGADO') ||
        norm.contains('INSTITUCION')) {
      return 'orientacion';
    }
    return 'tramite_id';
  }

  if (currentContextId == 'consulta') {
    return 'orientacion';
  }

  if (norm.contains('ROBAR') || norm.contains('LADRON') || norm.contains('QUITAR')) {
    return 'denuncia_robo';
  }
  if (norm.contains('GOLPEAR') || norm.contains('INSULTAR') || norm.contains('AMENAZAR') || norm.contains('MIEDO')) {
    return 'violencia';
  }
  if (norm.contains('INTERNET') || norm.contains('MENTIRA') || norm.contains('FOTO') || norm.contains('NUMERO') || norm.contains('AVISAR')) {
    if (norm.contains('BILLETES') || norm.contains('BANCO') || norm.contains('PAGAR')) {
      return 'engano_dinero';
    }
    return 'amenaza_digital';
  }
  if (norm.contains('SEGUIR') || norm.contains('MIRAR') || norm.contains('ESCONDER') || norm.contains('ESPERAR')) {
    return 'seguimiento';
  }
  if (norm.contains('NOMBRE') || norm.contains('IDENTIDAD') || norm.contains('PAPEL')) {
    if (!norm.contains('ROBAR') && !norm.contains('GOLPEAR')) {
      return 'identificacion';
    }
  }
  if (norm.contains('DONDE') || norm.contains('QUIEN') || norm.contains('QUE') || norm.contains('CUANDO') || norm.contains('COMO') || norm.contains('CUANTOS') || norm.contains('POR_QUE') || norm.contains('PARA_QUE')) {
    return 'preguntas';
  }
  return currentContextId.isEmpty ? 'denuncia_robo' : currentContextId;
}

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
