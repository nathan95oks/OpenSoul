import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_zone.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart'
    show kVictimMarker, kEvidenceMarker, kVehicleMarker;

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
  zones: const [
    SemanticZone(
      id: 'identidad',
      label: 'Identidad',
      hint: 'Nombre, apellido y documento de identidad',
      question: '¿Cuál es su nombre e identidad?',
      emoji: '🪪',
      semanticWeight: 0.95,
      maxPicks: 3,
      glossAllowlist: ['NOMBRE', 'NOMBRE', 'PAPEL', 'IDENTIDAD', 'SORDO', 'LEER', 'POCO', 'INTÉRPRETE'],
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
    description: 'Robo de celular, dinero, documentos o bienes',
    entryZoneId: 'hecho',
    baseUrgency: UrgencyLevel.medium,
    zones: const [
      SemanticZone(
        id: 'hecho',
        label: 'Hecho',
        hint: 'Qué ocurrió',
        question: '¿Qué delito ocurrió?',
        emoji: '⚡',
        semanticWeight: 0.95,
        glossAllowlist: ['ROBAR', 'LADRÓN', 'PERDER', 'ESCAPAR', 'DAÑAR', 'ENGAÑAR'],
        contextTags: [EmotionalTag.amenaza],
        relatedZones: ['objetos', 'persona', 'lugar', 'tiempo'],
      ),
      SemanticZone(
        id: 'objetos',
        label: 'Objetos robados',
        hint: 'Qué objetos o documentos fueron sustraídos',
        question: '¿Qué se llevaron o qué le robaron?',
        emoji: '📱',
        semanticWeight: 0.9,
        maxPicks: 3,
        glossAllowlist: [
          'CELULAR', 'BILLETES', 'BILLETES', 'MOCHILA', 'BOLSA',
          'PAPEL', 'IDENTIDAD', 'FACTURA', 'CAJA', 'MICRO', 'MICRO', 'TRUFI',
          'CHAMARRA', 'GORRA', 'LENTES',
        ],
        relatedZones: ['persona', 'lugar'],
      ),
      SemanticZone(
        id: 'persona',
        label: 'Autor del hecho',
        hint: 'Descripción física y vestimenta del sospechoso',
        question: '¿Quién cometió el hecho o cómo era?',
        emoji: '👤',
        semanticWeight: 0.85,
        maxPicks: 3,
        glossAllowlist: [
          'HOMBRE', 'MUJER', 'JOVEN', 'ADULTO', 'FLACO', 'GORDO',
          'ALTO', 'BAJO', 'MOCHILA', 'GORRA', 'POLERA', 'PANTALÓN',
          'CHAMARRA', 'CABELLO', 'NEGRO', 'AZUL', 'ROJO',
        ],
        relatedZones: ['lugar', 'tiempo'],
      ),
      SemanticZone(
        id: 'conocimiento',
        label: 'Conocimiento del autor',
        hint: 'Si conoce a la persona involucrada',
        question: '¿Conoce a la persona involucrada?',
        emoji: '👥',
        semanticWeight: 0.85,
        optional: true,
        glossAllowlist: ['CONOCER', 'SÍ', 'NO', 'AMIGO', 'PAREJA', 'PAREJA', 'AMIGO', 'VER'],
      ),
      SemanticZone(
        id: 'apariencia',
        label: 'Apariencia del autor',
        hint: 'Rasgos físicos y vestimenta',
        question: '¿Puede describir a la persona?',
        emoji: '🔍',
        semanticWeight: 0.85,
        optional: true,
        glossAllowlist: [
          'HOMBRE', 'MUJER', 'JOVEN', 'ADULTO', 'FLACO', 'GORDO',
          'ALTO', 'BAJO', 'MOCHILA', 'GORRA', 'POLERA', 'PANTALÓN',
          'CHAMARRA', 'CABELLO', 'NEGRO', 'AZUL', 'ROJO',
        ],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde ocurrió el hecho',
        question: '¿Dónde ocurrió?',
        emoji: '📍',
        semanticWeight: 0.75,
        glossAllowlist: [
          'CALLE', 'AVENIDA', 'PLAZA', 'MERCADO', 'BARRIO',
          'TIENDA', 'CASA', 'COCHABAMBA', 'DENTRO', 'FUERA',
          'CERCA', 'LEJOS', 'AL_LADO',
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
          'HORA', 'MINUTO', 'DÍA', 'SEMANA', 'MES',
        ],
        chainTriggers: ['HORA', 'MINUTO', 'DÍA', 'SEMANA', 'MES'],
        chainZoneId: 'cantidad',
      ),
      SemanticZone(
        id: 'testigos',
        label: 'Testigos presenciales',
        hint: 'Personas que vieron lo sucedido',
        question: '¿Hay testigos?',
        emoji: '👁️',
        semanticWeight: 0.7,
        optional: true,
        glossAllowlist: ['SÍ', 'NO', 'TESTIGO', 'TOTAL', 'VER', '1', '2', '3'],
      ),
      SemanticZone(
        id: 'pruebas',
        label: 'Fotografías y pruebas',
        hint: 'Fotos, videos o facturas',
        question: '¿Tiene fotografías o documentos?',
        emoji: '📷',
        semanticWeight: 0.65,
        optional: true,
        glossAllowlist: [
          'FOTOS', 'VIDEO', 'FILMAR', 'FACTURA', 'CAJA', 'PAPEL', 'CELULAR', 'MOSTRAR', 'PUEDO',
        ],
      ),
      SemanticZone(
        id: 'evidencia',
        label: 'Testigos y pruebas',
        hint: 'Testigos, grabaciones, fotos o factura',
        question: '¿Tiene testigos o elementos de prueba?',
        emoji: '📎',
        semanticWeight: 0.65,
        optional: true,
        maxPicks: 3,
        glossAllowlist: [
          'TESTIGO', 'TOTAL', 'VER', 'FOTOS', 'VIDEO', 'FILMAR',
          'FACTURA', 'CAJA', 'PAPEL', 'MOSTRAR', 'PUEDO',
        ],
        leadGloss: kEvidenceMarker,
      ),
      SemanticZone(
        id: 'emergencia',
        label: 'Atención médica',
        hint: 'Si está herido o requiere médico',
        question: '¿Está herido? ¿Necesita atención médica?',
        emoji: '🏥',
        semanticWeight: 0.65,
        optional: true,
        glossAllowlist: ['HERIDA', 'DOLOR', 'HOSPITAL', 'DOCTOR', 'CERTIFICADO', 'AUXILIO', 'SÍ', 'NO'],
      ),
      SemanticZone(
        id: 'denuncia',
        label: 'Formalizar denuncia',
        hint: 'Desea realizar la denuncia formal',
        question: '¿Desea realizar una denuncia?',
        emoji: '⚖️',
        semanticWeight: 0.6,
        optional: true,
        glossAllowlist: ['SÍ', 'NO', 'PRESENTAR', 'PRESENTAR', 'QUERER', 'AHORA'],
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
    zones: const [
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
        glossAllowlist: [
          'PAREJA', 'PAREJA', 'HOMBRE', 'MUJER', 'HERMANO',
          'HERMANA', 'ESPOSA', 'PARIENTE', 'PARIENTE', 'JOVEN', 'ADULTO',
        ],
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
    zones: const [
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
        glossAllowlist: [
          'PAREJA', 'PAREJA', 'HOMBRE', 'MUJER', 'CONOCER',
          'CELULAR',
        ],
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
    zones: const [
      SemanticZone(
        id: 'hecho',
        label: 'Engaño o estafa',
        hint: 'Qué ocurrió con el dinero',
        question: '¿Cómo ocurrió el engaño con el dinero?',
        emoji: '⚡',
        semanticWeight: 0.95,
        glossAllowlist: [
          'ENGAÑAR', 'BILLETES', 'BILLETES', 'ENVIAR', 'DAR', 'PERDER',
        ],
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
    zones: const [
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
        glossAllowlist: [
          'POLICÍA', 'FISCALIA', 'FISCALIA', 'JUEZ', 'JUZGADO',
          'ÓRGANO_JUDICIAL', 'SEPDAVI', 'SEPDEP', 'ABOGADO',
          'GRATIS', 'INTÉRPRETE',
        ],
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
  final upper = glosses.map((g) => g.toUpperCase()).toSet();
  
  if (currentContextId == 'tramite') {
    if (upper.contains('FALTA') || upper.contains('PERDER') || upper.contains('TELEFONO') || upper.contains('CARNET')) {
      return 'perdida';
    }
    if (upper.contains('PASAPORTE') || upper.contains('INVESTIGACIÓN') || upper.contains('GESTIONAR') || upper.contains('FOTOCOPIA')) {
      return 'tramite_id';
    }
    if (upper.contains('INTÉRPRETE') || upper.contains('HABLAR') || upper.contains('ABOGADO') || upper.contains('INSTITUCIÓN')) {
      return 'orientacion';
    }
    return 'tramite';
  }

  if (currentContextId == 'consulta') {
    return 'orientacion';
  }

  if (upper.contains('ROBAR') || upper.contains('LADRÓN') || upper.contains('QUITAR')) {
    return 'denuncia_robo';
  }
  if (upper.contains('GOLPEAR') || upper.contains('INSULTAR') || upper.contains('AMENAZAR') || upper.contains('MIEDO')) {
    return 'violencia';
  }
  if (upper.contains('INTERNET') || upper.contains('MENTIRA') || upper.contains('FOTO') || upper.contains('NUMERO') || upper.contains('AVISAR')) {
    if (upper.contains('BILLETES') || upper.contains('BANCO') || upper.contains('PAGAR')) {
      return 'engano_dinero';
    }
    return 'amenaza_digital';
  }
  if (upper.contains('SEGUIR') || upper.contains('MIRAR') || upper.contains('ESCONDER') || upper.contains('ESPERAR')) {
    return 'seguimiento';
  }
  if (upper.contains('NOMBRE') || upper.contains('IDENTIDAD') || upper.contains('PAPEL') || upper.contains('NOMBRE')) {
    if (!upper.contains('ROBAR') && !upper.contains('GOLPEAR')) {
      return 'identificacion';
    }
  }
  if (upper.contains('DÓNDE') || upper.contains('QUIÉN') || upper.contains('QUÉ') || upper.contains('CUÁNDO') || upper.contains('CÓMO') || upper.contains('CUÁNTOS') || upper.contains('POR_QUÉ') || upper.contains('PARA_QUÉ')) {
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
