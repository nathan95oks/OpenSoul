import 'dart:convert';
import 'dart:io';

void main() {
  final corpusFile = File('docs/Corpus_Maestro_Unificado_LSB_v4_Auditado.md');
  final lines = corpusFile.readAsLinesSync();

  final List<Map<String, dynamic>> rawEntries = [];
  bool inTable = false;

  for (final line in lines) {
    if (line.contains('# **12. Diccionario maestro:')) {
      inTable = true;
      continue;
    }
    if (inTable && line.startsWith('# **13.')) {
      break;
    }
    if (inTable && line.startsWith('|') && !line.contains('---') && !line.contains('**Glosa**')) {
      final parts = line.split('|').map((s) => s.trim()).toList();
      if (parts.length >= 8) {
        final gloss = parts[1];
        final spanish = parts[2];
        final id = parts[3];
        final reference = parts[4];
        final maxUses = int.tryParse(parts[5]) ?? 0;
        final priorityStr = parts[6];
        final audit = parts[7];

        if (gloss.isNotEmpty && gloss != ':-') {
          rawEntries.add({
            'gloss': gloss,
            'spanish': spanish,
            'id': id,
            'reference': reference,
            'maxUses': maxUses,
            'priority': priorityStr == 'P1' ? 1 : (priorityStr == 'P2' ? 2 : 3),
            'audit': audit,
          });
        }
      }
    }
  }

  print('Parsed ${rawEntries.length} entries from Section 12.');

  String assignCategory(String gloss, String reference) {
    final g = gloss.toUpperCase().replaceAll('-', '_');
    final ref = reference.toLowerCase();

    if (const {'GRACIAS', 'HOLA', 'PERMISO', 'POR_FAVOR', 'LO_SIENTO', 'BUENOS_DIAS', 'DE_NADA', 'HASTA_LUEGO', 'HASTA_MANANA'}.contains(g)) {
      return 'Cortesía';
    }
    if (const {'SI', 'NO', 'ESTOY_BIEN', 'MAS_O_MENOS', 'PUEDO', 'NO_PUEDO', 'SABER', 'NO_SABER', 'COMPRENDER', 'NO_ENTIENDO', 'NO_RECUERDO', 'PUEDE_REPETIR', 'ESTAR_DE_ACUERDO', 'NO_ESTAR_DE_ACUERDO', 'VERDAD', 'MENTIRA', 'TAL_VEZ'}.contains(g)) {
      return 'Respuesta';
    }
    if (const {'QUE', 'QUIEN', 'DONDE', 'CUANDO', 'CUAL', 'COMO', 'CUANTOS', 'POR_QUE', 'PARA_QUE', 'YO', 'TU', 'EL', 'ELLA', 'NOSOTROS', 'ELLOS', 'MIO', 'TUYO', 'SUYO', 'AMBOS', 'VARIOS'}.contains(g)) {
      return 'Preguntas';
    }
    if (const {'HOMBRE', 'MUJER', 'JOVEN', 'ADULTO', 'FLACO', 'GORDO', 'ALTO', 'BAJO', 'SORDO', 'OYENTE', 'AMIGO', 'COMPANERO', 'COMPAÑERO', 'JEFE', 'TRABAJADOR', 'SEÑOR', 'SENOR', 'HIJO', 'HIJA', 'MAMA', 'MAMÁ', 'ESPOSA', 'HERMANO', 'HERMANA', 'PAREJA', 'SEPARADOS', 'PARIENTE', 'IDENTIDAD', 'NOMBRE', 'EDAD', 'APELLIDO', 'EXPAREJA', 'FAMILIAR', 'VECINO', 'LADRON', 'LADRÓN', 'TESTIGO', 'COMUNIDAD_SORDA', 'ASOCIACION_SORDOS', 'ASOCIACIÓN_SORDOS'}.contains(g)) {
      return 'Identificación';
    }
    if (const {'POLICIA', 'POLICÍA', 'ABOGADO', 'JUEZ', 'FISCAL', 'DOCTOR', 'AUTORIDAD', 'INTERPRETE', 'INTÉRPRETE', 'ASISTENTE', 'OFICIAL', 'GOBIERNO', 'ALCALDIA', 'ALCALDÍA', 'INSTITUCION', 'INSTITUCIÓN', 'ORGANO_JUDICIAL', 'ÓRGANO_JUDICIAL', 'HOSPITAL', 'SEPDAVI', 'SEPDEP', 'FELCC', 'FELCV', 'FISCALIA', 'FISCALÍA', 'JUZGADO'}.contains(g)) {
      return 'Instituciones';
    }
    if (const {'LEY', 'JUSTICIA', 'INVESTIGACION', 'INVESTIGACIÓN', 'RESOLUCION', 'RESOLUCIÓN', 'TRAMITE', 'TRÁMITE', 'TESTIMONIO', 'DENUNCIA', 'ASISTENCIA', 'CONVOCAR', 'CITACION', 'DISCRIMINACION', 'DISCRIMINACIÓN', 'PROHIBIDO', 'RESULTADO', 'PLAZO', 'CONFESAR'}.contains(g)) {
      return 'Conceptos jurídicos';
    }
    if (const {'ROBAR', 'HERIDA', 'DOLOR', 'FRACTURA', 'HUESOS', 'PEGAR', 'MALTRATAR', 'AMENAZAR', 'AUXILIO', 'URGENTE', 'VIOLENCIA', 'ABUSAR', 'PELEAR', 'PERDER', 'ENGAÑAR', 'ENGANAR', 'DANAR', 'DAÑAR', 'ACCIDENTE', 'ESCAPAR'}.contains(g)) {
      return 'Hechos y urgencia';
    }
    if (const {'HOY', 'AYER', 'ANTEAYER', 'MANANA', 'MAÑANA', 'PASADO_MANANA', 'PASADO_MAÑANA', 'PASADO', 'FUTURO', 'AHORA', 'DESPUES', 'DESPUÉS', 'LUEGO', 'TEMPRANO', 'TARDE', 'SIEMPRE', 'JAMAS', 'JAMÁS', 'AUN', 'AÚN', 'MOMENTO', 'FECHA', 'DIA', 'DÍA', 'SEMANA', 'MES', 'ANO', 'AÑO', 'ANO_PASADO', 'AÑO_PASADO', 'CADA_DIA', 'CADA_DÍA', 'TODOS_LOS_DIAS', 'TODOS_LOS_DÍAS', 'PRIMERA_VEZ', 'HORA', 'MINUTO', 'SEGUNDO', 'DURANTE', 'PROXIMO', 'PRÓXIMO', 'ULTIMO', 'ÚLTIMO', 'LUNES', 'MARTES', 'JUEVES', 'VIERNES', 'SABADO', 'SÁBADO', 'JULIO', 'MARZO', 'DESCANSO', 'POSTERGAR', 'OCUPADO', 'LIBRE'}.contains(g)) {
      return 'Tiempo';
    }
    if (const {'CASA', 'CALLE', 'AVENIDA', 'PLAZA', 'MERCADO', 'BARRIO', 'TIENDA', 'BANCO', 'ESCUELA', 'ESCUELA_NOCTURNA', 'OFICINA', 'COCHABAMBA', 'PROVINCIA', 'AQUI', 'AQUÍ', 'ALLI', 'ALLÍ', 'ALLA', 'ALLÁ', 'DENTRO', 'FUERA', 'CERCA', 'LEJOS', 'AL_LADO', 'ENFRENTE', 'ATRAS', 'ATRÁS', 'DIRECCION', 'DIRECCIÓN'}.contains(g)) {
      return 'Lugares';
    }
    if (const {'PAPEL', 'CERTIFICADO', 'FACTURA', 'FOTOCOPIA', 'CARPETA', 'PAGINA', 'PÁGINA', 'SELLO', 'LISTA'}.contains(g)) {
      return 'Documentos';
    }
    if (const {'CELULAR', 'FOTOS', 'VIDEO', 'CAMARA_FOTOGRAFICA', 'CÁMARA_FOTOGRÁFICA', 'COMPUTADORA', 'INTERNET', 'DINERO', 'BILLETES', 'CAJA', 'BOLSA', 'MOCHILA', 'LENTES', 'POLERA', 'PANTALON', 'PANTALÓN', 'CHAMARRA', 'GORRA', 'PUERTA', 'AUTO', 'MICRO', 'TRUFI', 'MEDICINA', 'RAYOS_X'}.contains(g)) {
      return 'Objetos';
    }
    if (const {'ROJO', 'AZUL', 'NEGRO', 'BUENO', 'MAL', 'MEJOR', 'NUEVO', 'CARO', 'CORTO', 'DIFERENTE', 'DIFICIL', 'DIFÍCIL', 'OSCURO', 'MUCHO', 'POCO', 'LENTO'}.contains(g)) {
      return 'Descripción';
    }
    if (const {'MIEDO', 'TRISTE', 'CONFIANZA', 'PREOCUPAR', 'ESTAR_DE_ACUERDO', 'NO_ESTAR_DE_ACUERDO'}.contains(g)) {
      return 'Estado y emoción';
    }
    if (const {'ESCRIBIR', 'VER', 'MIRAR', 'OIR', 'OÍR', 'HABLAR', 'EXPLICAR', 'LEER', 'MOSTRAR', 'NARRAR', 'OBSERVAR', 'PRESENTAR', 'GUARDAR', 'BUSCAR', 'DAR', 'ENVIAR', 'RECIBIR', 'TRAER', 'LLEVAR', 'VENIR', 'IR', 'LLEGAR', 'VOLVER', 'DEVOLVER', 'PEDIR', 'AYUDAR', 'PROTEGER', 'HACER', 'TERMINAR', 'EMPEZAR', 'CONTINUAR', 'CAMBIAR', 'ARREGLAR', 'AUMENTAR', 'CONOCER', 'RECORDAR', 'IDENTIFICAR', 'DEJAR', 'ABRIR', 'COMPRAR', 'VENDER', 'GANAR_DINERO', 'VIVIR', 'DORMIR', 'ANDAR', 'LLAMAR', 'BURLAR', 'IGNORAR', 'CREER', 'DECIDIR', 'ORGANIZAR', 'EVALUAR', 'DIBUJAR', 'FILMAR', 'FUNCIONAR', 'ENCONTRARSE', 'ESCONDER', 'CURAR', 'GRITAR', 'ACEPTAR', 'RECHAZAR', 'CONTESTAR_DOS_VECES'}.contains(g)) {
      return 'Acciones';
    }

    if (ref.contains('lugar') || ref.contains('depto')) return 'Lugares';
    if (ref.contains('salud')) return 'Hechos y urgencia';
    if (ref.contains('tiempo') || ref.contains('calendario') || ref.contains('semana')) return 'Tiempo';
    if (ref.contains('verbo')) return 'Acciones';
    if (ref.contains('ropa') || ref.contains('prendas')) return 'Objetos';
    if (ref.contains('familia') || ref.contains('personas')) return 'Identificación';
    if (ref.contains('opuestos') || ref.contains('colores')) return 'Descripción';
    return 'Acciones';
  }

  List<String> assignContexts(String category, String gloss) {
    final g = gloss.toUpperCase().replaceAll('-', '_');
    final c = <String>{'otro'};

    if (category == 'Cortesía' || category == 'Respuesta') {
      return ['denuncia_robo', 'violencia', 'amenaza_digital', 'engano_dinero', 'seguimiento', 'identificacion', 'preguntas', 'otro'];
    }
    if (category == 'Preguntas') {
      return ['preguntas', 'seguimiento', 'denuncia_robo', 'violencia', 'amenaza_digital', 'engano_dinero', 'identificacion', 'otro'];
    }
    if (category == 'Identificación') {
      return ['identificacion', 'denuncia_robo', 'violencia', 'amenaza_digital', 'engano_dinero', 'seguimiento', 'otro'];
    }
    if (category == 'Instituciones') {
      return ['seguimiento', 'denuncia_robo', 'violencia', 'amenaza_digital', 'engano_dinero', 'preguntas', 'otro'];
    }
    if (category == 'Conceptos jurídicos') {
      return ['seguimiento', 'denuncia_robo', 'violencia', 'preguntas', 'otro'];
    }
    if (const {'ROBAR', 'LADRON', 'LADRÓN', 'CELULAR', 'FACTURA', 'CAJA', 'TIENDA', 'PERDER', 'DINERO', 'BILLETES', 'MOCHILA', 'BOLSA', 'AUTO', 'MICRO', 'TRUFI'}.contains(g)) {
      c.add('denuncia_robo');
    }
    if (const {'HERIDA', 'BRAZO', 'HOSPITAL', 'DOCTOR', 'CERTIFICADO', 'PEGAR', 'MALTRATAR', 'VIOLENCIA', 'AMENAZAR', 'PAREJA', 'MIEDO', 'AUXILIO', 'URGENTE', 'PROTEGER', 'HIJO', 'HIJA', 'FRACTURA', 'HUESOS', 'CURAR', 'MEDICINA', 'ABUSAR', 'PELEAR', 'DOLOR'}.contains(g)) {
      c.add('violencia');
    }
    if (const {'CELULAR', 'INTERNET', 'ESCRIBIR', 'MENSAJE', 'FOTOS', 'GUARDAR', 'AMENAZAR', 'AUN', 'AÚN', 'RECIBIR', 'ENVIAR', 'NUMERO', 'MOSTRAR', 'VIDEO'}.contains(g)) {
      c.add('amenaza_digital');
    }
    if (const {'ENGANAR', 'ENGAÑAR', 'DINERO', 'BILLETES', 'BANCO', 'FACTURA', 'PAPEL', 'CELULAR', 'INTERNET', 'ESCRIBIR', 'NOMBRE', 'ENVIAR', 'COMPROBANTE'}.contains(g)) {
      c.add('engano_dinero');
    }
    if (const {'INVESTIGACION', 'INVESTIGACIÓN', 'POLICIA', 'POLICÍA', 'ABOGADO', 'FISCAL', 'FISCALIA', 'JUEZ', 'JUZGADO', 'ORGANO_JUDICIAL', 'ÓRGANO_JUDICIAL', 'SEPDAVI', 'SEPDEP', 'VOLVER', 'ESPERAR', 'AVISAR', 'TERMINAR', 'CONTINUAR', 'RESOLUCION', 'RESOLUCIÓN', 'INTÉRPRETE', 'INTERPRETE', 'GRATIS', 'ASISTENCIA'}.contains(g)) {
      c.add('seguimiento');
    }
    if (const {'NOMBRE', 'APELLIDO', 'IDENTIDAD', 'PAPEL', 'CELULAR', 'ESCRIBIR', 'LEER', 'SORDO', 'ACOMPANAR', 'ACOMPAÑAR', 'EDAD'}.contains(g)) {
      c.add('identificacion');
    }
    if (category == 'Tiempo' || category == 'Lugares' || category == 'Documentos' || category == 'Objetos' || category == 'Descripción') {
      return ['denuncia_robo', 'violencia', 'amenaza_digital', 'engano_dinero', 'seguimiento', 'identificacion', 'preguntas', 'otro'];
    }
    return c.toList();
  }

  String assignSemanticIcon(String category, String gloss) {
    final g = gloss.toUpperCase().replaceAll('-', '_');
    if (g == 'CELULAR' || g == 'TELEFONO') return 'phone_android';
    if (g == 'DINERO' || g == 'BILLETES') return 'attach_money';
    if (g == 'MOCHILA' || g == 'BOLSA') return 'backpack';
    if (g == 'AUTO' || g == 'TRUFI') return 'directions_car';
    if (g == 'MICRO') return 'directions_bus';
    if (g == 'HOSPITAL') return 'local_hospital';
    if (g == 'DOCTOR') return 'medical_services';
    if (g == 'POLICIA' || g == 'POLICÍA' || g == 'FELCC' || g == 'FELCV') return 'local_police';
    if (g == 'JUEZ' || g == 'JUZGADO' || g == 'ORGANO_JUDICIAL' || g == 'ÓRGANO_JUDICIAL') return 'gavel';
    if (g == 'FISCAL' || g == 'FISCALIA' || g == 'FISCALÍA' || g == 'SEPDAVI' || g == 'SEPDEP') return 'account_balance';
    if (g == 'ABOGADO' || g == 'INTERPRETE' || g == 'INTÉRPRETE') return 'support_agent';
    if (g == 'ROBAR' || g == 'LADRON' || g == 'LADRÓN' || g == 'VIOLENCIA' || g == 'AMENAZAR' || g == 'PEGAR') return 'warning';
    if (g == 'HERIDA' || g == 'AUXILIO' || g == 'URGENTE') return 'emergency';
    if (g == 'FOTOS' || g == 'CAMARA_FOTOGRAFICA' || g == 'CÁMARA_FOTOGRÁFICA') return 'photo_camera';
    if (g == 'VIDEO' || g == 'FILMAR') return 'videocam';
    if (g == 'IDENTIDAD' || g == 'NOMBRE' || g == 'PAPEL') return 'badge';
    if (g == 'FACTURA' || g == 'CERTIFICADO' || g == 'RESOLUCION' || g == 'RESOLUCIÓN' || g == 'CARPETA') return 'receipt_long';
    if (g == 'CALLE' || g == 'AVENIDA' || g == 'PLAZA' || g == 'MERCADO' || g == 'CASA' || g == 'TIENDA') return 'place';
    if (g == 'HOY' || g == 'AYER' || g == 'MANANA' || g == 'MAÑANA' || g == 'DIA' || g == 'DÍA' || g == 'SEMANA' || g == 'MES' || g == 'HORA') return 'access_time';

    return switch (category) {
      'Tiempo' => 'access_time',
      'Lugares' => 'place',
      'Instituciones' => 'account_balance',
      'Objetos' => 'inventory_2',
      'Documentos' => 'description',
      'Identificación' => 'person',
      'Preguntas' => 'help',
      'Hechos y urgencia' => 'warning',
      'Estado y emoción' => 'psychology',
      'Cortesía' => 'waving_hand',
      'Respuesta' => 'check_circle',
      'Acciones' => 'pan_tool',
      'Abecedario' => 'text_fields',
      'Números' => 'tag',
      _ => 'sign_language',
    };
  }

  final categoryOrder = [
    'Cortesía',
    'Respuesta',
    'Preguntas',
    'Identificación',
    'Instituciones',
    'Conceptos jurídicos',
    'Acciones',
    'Hechos y urgencia',
    'Descripción',
    'Estado y emoción',
    'Tiempo',
    'Lugares',
    'Documentos',
    'Objetos',
    'Abecedario',
    'Números',
  ];

  final List<Map<String, dynamic>> finalEntries = [];
  int idCounter = 1;

  for (final raw in rawEntries) {
    final glossRaw = raw['gloss'] as String;
    final glossNorm = glossRaw.replaceAll('-', '_');
    final displayText = raw['spanish'] as String;
    final cat = assignCategory(glossRaw, raw['reference'] as String);
    final contexts = assignContexts(cat, glossRaw);
    final priority = raw['priority'] as int;

    final entry = <String, dynamic>{
      'id': 'g${idCounter.toString().padLeft(3, '0')}',
      'gloss': glossNorm,
      'canonicalGloss': glossRaw,
      'displayText': displayText.toUpperCase(),
      'iconUrl': '',
      'categoryId': cat,
      'subcategoryId': raw['reference'].toString().split('·').first.trim(),
      'contexts': contexts,
      'priority': priority,
      'suggestedNextCardIds': <String>[],
      'isFrequent': priority == 1,
      'isEmergency': cat == 'Hechos y urgencia' && (priority <= 2),
      'semanticIcon': assignSemanticIcon(cat, glossRaw),
      'dialect': 'cochabamba',
      'status': 'official',
      'animationFile': '',
      'corpusCategory': raw['reference'] as String,
      'source': '${raw['id']} · ${raw['reference']}',
      'audit': raw['audit'],
    };
    finalEntries.add(entry);
    idCounter++;
  }

  // Add Dactylology Alphabet (A-Z, Ñ)
  final alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'Ñ', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];
  for (final letter in alphabet) {
    finalEntries.add({
      'id': 'g${idCounter.toString().padLeft(3, '0')}',
      'gloss': letter,
      'canonicalGloss': letter,
      'displayText': letter,
      'iconUrl': '',
      'categoryId': 'Abecedario',
      'subcategoryId': 'dactilología',
      'contexts': ['identificacion', 'otro', 'seguimiento', 'denuncia_robo', 'violencia'],
      'priority': 3,
      'suggestedNextCardIds': <String>[],
      'isFrequent': false,
      'isEmergency': false,
      'semanticIcon': 'fingerprint',
      'dialect': 'nacional',
      'status': 'official',
      'animationFile': 'avatar_test.glb',
      'corpusCategory': 'Abecedario Dactilológico LSB',
      'source': 'M1, Alfabeto Dactilológico',
      'audit': 'Mecanismo oficial de deletreo',
    });
    idCounter++;
  }

  // Add Numbers (0-9)
  final digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  for (final d in digits) {
    finalEntries.add({
      'id': 'g${idCounter.toString().padLeft(3, '0')}',
      'gloss': d,
      'canonicalGloss': d,
      'displayText': d,
      'iconUrl': '',
      'categoryId': 'Números',
      'subcategoryId': 'números',
      'contexts': ['identificacion', 'otro', 'seguimiento', 'denuncia_robo', 'violencia', 'engano_dinero', 'amenaza_digital', 'preguntas'],
      'priority': 2,
      'suggestedNextCardIds': <String>[],
      'isFrequent': true,
      'isEmergency': false,
      'semanticIcon': 'tag',
      'dialect': 'nacional',
      'status': 'official',
      'animationFile': 'avatar_test.glb',
      'corpusCategory': 'Números LSB',
      'source': 'M1, Números',
      'audit': 'Mecanismo oficial de numeración',
    });
    idCounter++;
  }

  // Add Institutional Dactylology Entries audited in Corpus Maestro
  final instDact = [
    {'gloss': 'SEPDAVI', 'displayText': 'SEPDAVI', 'source': 'Dactilología institucional · SEPDAVI (Asistencia a la Víctima)'},
    {'gloss': 'SEPDEP', 'displayText': 'SEPDEP', 'source': 'Dactilología institucional · SEPDEP (Defensa Pública)'},
    {'gloss': 'FELCC', 'displayText': 'FELCC', 'source': 'Dactilología institucional · FELCC'},
    {'gloss': 'FELCV', 'displayText': 'FELCV', 'source': 'Dactilología institucional · FELCV'},
    {'gloss': 'FISCALIA', 'displayText': 'FISCALÍA', 'source': 'Dactilología institucional · Fiscalía'},
    {'gloss': 'JUZGADO', 'displayText': 'JUZGADO', 'source': 'Dactilología institucional · Juzgado'},
  ];
  for (final inst in instDact) {
    finalEntries.add({
      'id': 'g${idCounter.toString().padLeft(3, '0')}',
      'gloss': inst['gloss']!,
      'canonicalGloss': 'd(${inst['gloss']!})',
      'displayText': inst['displayText']!,
      'iconUrl': '',
      'categoryId': 'Instituciones',
      'subcategoryId': 'institución dactilológica',
      'contexts': ['seguimiento', 'denuncia_robo', 'violencia', 'preguntas', 'otro'],
      'priority': 1,
      'suggestedNextCardIds': <String>[],
      'isFrequent': true,
      'isEmergency': false,
      'semanticIcon': 'account_balance',
      'dialect': 'nacional',
      'status': 'official',
      'animationFile': '',
      'corpusCategory': 'Instituciones auditadas v4',
      'source': inst['source']!,
      'audit': 'Dactilología institucional oficial auditada',
    });
    idCounter++;
  }

  final finalJson = {
    'version': 6,
    'dialect': 'cochabamba',
    'origin': 'Corpus_Maestro_Unificado_LSB_v4_Auditado.md',
    'note': 'Catálogo maestro oficial generado directamente desde el Corpus Maestro Unificado LSB v4 Auditado (Sección 12) + mecanismos oficiales de dactilología y números.',
    'categoryOrder': categoryOrder,
    'entries': finalEntries,
  };

  final encoder = JsonEncoder.withIndent('  ');
  File('assets/dictionary/official_dictionary.json').writeAsStringSync(encoder.convert(finalJson));
  print('Generated assets/dictionary/official_dictionary.json successfully with ${finalEntries.length} entries.');
}
