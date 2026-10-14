import 'package:lsb_legal_app/core/data/models/lsb_translation_model.dart';
import 'package:lsb_legal_app/core/domain/conversation/lsb_gloss_semantics.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/help_direction.dart';
import 'package:lsb_legal_app/core/domain/services/verb_forms.dart';
import 'package:lsb_legal_app/core/domain/text/spanish_text.dart';

/// Motor de traducción y desambiguación local en Dart para modo sin conexión (Offline).
///
/// Si no hay internet hacia AWS Lambda, este motor toma la frase en español,
/// busca correspondencias directas y compuestas en el léxico LSB y las 200 señas
/// horneadas del modelo 3D `avatar_test.glb`, aplicando heurísticas de gramática
/// LSB (OSV) y resolución de clips en disco para que el avatar se mueva sin fallar.
class LocalAudioTranslator {
  final AnimationUrlResolver animationResolver;

  const LocalAudioTranslator({
    this.animationResolver = const AnimationUrlResolver(),
  });

  /// Mapeos léxicos directos y sinónimos comunes del español a glosas de las 200 señas horneadas.
  static const Map<String, String> _lexicalMap = {
    // Saludos y cortesía
    'HOLA': 'HOLA',
    'BUENOS DIAS': 'BUENOS_DIAS',
    'BUENAS TARDES': 'BUENAS_TARDES',
    'BUENAS NOCHES': 'BUENAS_NOCHES',
    'HASTA LUEGO': 'HASTA_LUEGO',
    'GRACIAS': 'GRACIAS',
    'POR FAVOR': 'POR_FAVOR',
    'LO SIENTO': 'LO_SIENTO',
    'COMO ESTAS': 'COMO_ESTAS',

    // Personas y pronombres
    'YO': 'YO',
    'MI': 'MIO',
    'MIO': 'MIO',
    'MIA': 'MIO',
    'TU': 'TU',
    'USTED': 'TU',
    'TUYO': 'TUYO',
    'USTEDES': 'USTEDES',
    'EL': 'EL',
    'ELLA': 'ELLA',
    'ELLOS': 'ELLOS',
    'ELLAS': 'ELLOS',
    'NOSOTROS': 'NOSOTROS',
    'NOSOTRAS': 'NOSOTROS',
    'HOMBRE': 'HOMBRE',
    'MUJER': 'MUJER',
    'HIJO': 'HIJO',
    'HIJA': 'HIJA',
    'AMIGO': 'AMIGO',
    'AMIGA': 'AMIGO',
    'SORDO': 'SORDO',
    'SORDA': 'SORDO',

    // Actores judiciales y autoridades
    'ABOGADO': 'ABOGADO',
    'ABOGADA': 'ABOGADO',
    'JUEZ': 'JUEZ',
    'JUEZA': 'JUEZ',
    'POLICIA': 'POLICIA',
    'AUTORIDAD': 'AUTORIDAD',
    'DOCTOR': 'DOCTOR',
    'DOCTORA': 'DOCTOR',
    'INTERPRETE': 'INTERPRETE',
    'TESTIGO': 'TESTIGO',
    'LADRON': 'LADRON',
    'LADRONA': 'LADRON',

    // Lugares e instituciones
    'CASA': 'CASA',
    'OFICINA': 'OFICINA',
    'BANCO': 'BANCO',
    'HOSPITAL': 'HOSPITAL',
    'TIENDA': 'TIENDA',
    'ALCALDIA': 'ALCALDIA',
    'COCHABAMBA': 'COCHABAMBA',
    'CALLE': 'CALLE',
    'AVENIDA': 'AVENIDA',
    'DIRECCION': 'DIRECCION',
    'AQUI': 'AQUI',
    'ALLI': 'ALLI',
    'CERCA': 'CERCA',
    'DENTRO': 'DENTRO',

    // Documentos y objetos
    'CELULAR': 'CELULAR',
    'TELEFONO': 'CELULAR',
    'MOVIL': 'CELULAR',
    'PAPEL': 'PAPEL',
    'CARPETA': 'CARPETA',
    'FOTOCOPIA': 'FOTOCOPIA',
    'FOTOS': 'FOTOS',
    'FOTO': 'FOTOS',
    'VIDEO': 'VIDEO',
    'BILLETES': 'BILLETES',
    'DINERO': 'BILLETES',
    'CERTIFICADO': 'CERTIFICADO',
    'FACTURA': 'FACTURA',
    'SELLO': 'SELLO',
    'IDENTIDAD': 'IDENTIDAD',
    'CARNET': 'IDENTIDAD',
    'CEDULA': 'IDENTIDAD',

    // Delitos, hechos y situaciones
    'ROBAR': 'ROBAR',
    'ROBO': 'ROBAR',
    'ROBARON': 'ROBAR',
    'HURTO': 'ROBAR',
    'PEGAR': 'PEGAR',
    'GOLPEAR': 'PEGAR',
    'GOLPE': 'PEGAR',
    'PELEAR': 'PELEAR',
    'PELEA': 'PELEAR',
    'AMENAZAR': 'AMENAZAR',
    'AMENAZA': 'AMENAZAR',
    'VIOLENCIA': 'VIOLENCIA',
    'ENGANAR': 'ENGANAR',
    'ESTAFA': 'ENGANAR',
    'HERIDA': 'HERIDA',
    'DANAR': 'DANAR',
    'DANO': 'DANAR',
    'MIEDO': 'MIEDO',
    'BULLYING': 'BULLYING',
    'ACOSO': 'ACOSO',
    'ACOSAR': 'ACOSO',
    'TRATA': 'TRATA_TRAFICO',
    'TRAFICO': 'TRATA_TRAFICO',
    'ESCAPAR': 'ESCAPAR',
    'HUIR': 'ESCAPAR',
    'PERDER': 'PERDER',
    'EXTRAVIAR': 'PERDER',
    'PERDI': 'PERDER',
    'URGENTE': 'URGENTE',

    // Términos procesales y justicia
    'JUSTICIA': 'JUSTICIA',
    'JUICIO': 'JUICIO',
    'LEY': 'LEY',
    'LEYES': 'LEY',
    'TRAMITE': 'TRAMITE',
    'TESTIMONIO': 'TESTIMONIO',
    'INVESTIGACION': 'INVESTIGACION',
    'RESOLUCION': 'RESOLUCION',
    'QUEJAR': 'QUEJAR',
    'QUEJA': 'QUEJAR',
    'DENUNCIA': 'QUEJAR',
    'ASISTENCIA': 'ASISTENCIA',
    'PERMISO': 'PERMISO',

    // Acciones y verbos
    'AYUDAR': 'AYUDAR_DAR',
    'AYUDA': 'AYUDAR_DAR',
    'AUXILIO': 'AYUDAR_PEDIR',
    'ATENDER': 'ATENDER',
    'ATENCION': 'ATENDER',
    'BUSCAR': 'BUSCAR',
    'ESCRIBIR': 'ESCRIBIR',
    'LEER': 'LEER',
    'EXPLICAR': 'EXPLICAR',
    'MOSTRAR': 'MOSTRAR',
    'VER': 'VER',
    'OBSERVAR': 'OBSERVAR',
    'FILMAR': 'FILMAR',
    'GRABAR': 'FILMAR',
    'HABLAR': 'HABLAR',
    'NARRAR': 'NARRAR',
    'CONTAR': 'NARRAR',
    'RELATAR': 'NARRAR',
    'SABER': 'SABER',
    'NO SABER': 'NO_SABER',
    'COMPRENDER': 'COMPRENDER',
    'ENTENDER': 'COMPRENDER',
    'CONOCER': 'CONOCER',
    'RECORDAR': 'RECORDAR',
    'ESPERAR': 'ESPERAR',
    'ENVIAR': 'ENVIAR',
    'MANDAR': 'ENVIAR',
    'GUARDAR': 'GUARDAR',
    'RECIBIR': 'RECIBIR',
    'DAR': 'DAR',
    'DEVOLVER': 'DEVOLVER',
    'TRAER': 'TRAER',
    'LLEVAR': 'LLEVAR',
    'IR': 'IR',
    'VENIR': 'VENIR',
    'VOLVER': 'VOLVER',
    'REGRESAR': 'VOLVER',
    'HACER': 'HACER',
    'CONTESTAR': 'CONTESTAR',
    'RESPONDER': 'CONTESTAR',
    'CONVOCAR': 'CONVOCAR',
    'CITAR': 'CONVOCAR',
    'ACEPTAR': 'ACEPTAR',
    'RECHAZAR': 'RECHAZAR',
    'ACOMPANAR': 'ACOMPANAR',
    'PEDIR': 'PEDIR',
    'SOLICITAR': 'PEDIR',
    'NECESITAR': 'NECESITAR',
    'QUERER': 'QUERER',
    'PUEDO': 'PUEDO',
    'PODER': 'PUEDO',
    'NO PUEDO': 'NO_PUEDO',
    'TERMINAR': 'TERMINAR',
    'FINALIZAR': 'TERMINAR',
    'ABRIR': 'ABRIR',
    'CONTINUAR': 'CONTINUAR',
    'SEGUIR': 'CONTINUAR',

    // Modificadores, tiempo y preguntas
    'SI': 'SI',
    'NO': 'NO',
    'MUCHO': 'MUCHO',
    'TOTAL': 'TOTAL',
    'TODO': 'TOTAL',
    'TODOS': 'TOTAL',
    'MAS O MENOS': 'MAS_O_MENOS',
    'LENTO': 'LENTO',
    'DESPACIO': 'LENTO',
    'NUEVO': 'NUEVO',
    'AMBOS': 'AMBOS',
    'PRIMERA VEZ': 'PRIMERA_VEZ',
    'ULTIMO': 'ULTIMO',
    'HOY': 'HOY',
    'AYER': 'AYER',
    'MANANA': 'MANANA',
    'AHORA': 'AHORA',
    'PASADO': 'PASADO',
    'FUTURO': 'FUTURO',
    'AUN': 'AUN',
    'TODAVIA': 'AUN',
    'DIA': 'DIA',
    'TARDE': 'TARDE',
    'SEMANA': 'SEMANA',
    'FECHA': 'FECHA',
    'HORA': 'HORA',

    // Preguntas
    'QUE': 'QUE',
    'QUIEN': 'QUIEN',
    'CUANDO': 'CUANDO',
    'DONDE': 'DONDE',
    'COMO': 'COMO',
    'POR QUE': 'POR_QUE',
    'PORQUE': 'POR_QUE',
    'PARA QUE': 'PARA_QUE',
    'CUAL': 'CUAL',
    'CUANTOS': 'CUANTOS',
    'CUANTO': 'CUANTOS',
    'NOMBRE': 'NOMBRE',
  };

  /// Lista de palabras ignorables (artículos, preposiciones menores) para simplificar sintaxis a LSB.
  static const Set<String> _stopwords = {
    'EL', 'LA', 'LOS', 'LAS', 'UN', 'UNA', 'UNOS', 'UNAS',
    'DE', 'DEL', 'AL', 'A', 'EN', 'CON', 'POR', 'PARA', 'Y', 'O', 'E',
    'SE', 'LE', 'LES', 'ME', 'TE', 'NOS',
  };

  /// Traduce [rawText] localmente sin requerir AWS Lambda.
  LsbTranslationModel translate(String rawText, {String? situation}) {
    final text = SpanishText.stripAccents(rawText.toUpperCase().trim());
    if (text.isEmpty) {
      return LsbTranslationModel(
        glosses: const [],
        animationUrl: '',
      );
    }

    // 1. Extraer palabras limpias
    final cleanWords = text
        // `\w` es solo ASCII: sin `Ñ` explícita, "mañana" se partía en
        // "MA" + "ANA" y "ñandu" perdía la Ñ.
        .replaceAll(RegExp(r'[^\wÑ\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Las claves del léxico van sin Ñ (MANANA, ENGANAR): se busca con la Ñ
    // plegada a N, pero la palabra original se conserva para el deletreo.
    final foldedWords = cleanWords.map(_fold).toList();

    final foundGlosses = <String>[];
    int i = 0;

    // 2. Búsqueda con ventana de hasta 3 palabras para capturar compuestos
    while (i < cleanWords.length) {
      String? matchedGloss;
      int matchLen = 0;

      // Probar trigrama
      if (i + 2 < cleanWords.length) {
        final tri = '${foldedWords[i]} ${foldedWords[i + 1]} ${foldedWords[i + 2]}';
        if (_lexicalMap.containsKey(tri)) {
          matchedGloss = _lexicalMap[tri];
          matchLen = 3;
        }
      }

      // Probar bigrama
      if (matchedGloss == null && i + 1 < cleanWords.length) {
        final bi = '${foldedWords[i]} ${foldedWords[i + 1]}';
        if (_lexicalMap.containsKey(bi)) {
          matchedGloss = _lexicalMap[bi];
          matchLen = 2;
        }
      }

      // Probar palabra simple
      if (matchedGloss == null) {
        final single = cleanWords[i];
        final foldedSingle = foldedWords[i];
        if (_lexicalMap.containsKey(foldedSingle)) {
          matchedGloss = _lexicalMap[foldedSingle];
          matchLen = 1;
        } else if (VerbForms.lemmas.containsKey(foldedSingle)) {
          // «va», «tiene», «da»: la forma conjugada de un verbo con seña.
          matchedGloss = VerbForms.lemmas[foldedSingle];
          matchLen = 1;
        } else if (foldedSingle.startsWith('AYUD')) {
          // «ayúdeme», «ayudarle», «ayudamos»…: la dirección se decide abajo.
          matchedGloss = HelpDirection.dar;
          matchLen = 1;
        } else if (!_stopwords.contains(single)) {
          // Si no está en el mapa y es relevante, comprobar si es número o si existe directamente en las 200 señas
          if (AnimationUrlResolver.digitToNumeral.containsKey(single)) {
            matchedGloss = AnimationUrlResolver.digitToNumeral[single];
            matchLen = 1;
          } else if (AnimationUrlResolver.available3DGlosses.contains(single)) {
            matchedGloss = single;
            matchLen = 1;
          } else {
            // Palabra sin seña directa: se mantendrá para deletreo o análisis
            matchedGloss = single;
            matchLen = 1;
          }
        } else {
          // Es stopword (ej: "de", "la"), avanzamos
          i++;
          continue;
        }
      }

      if (matchedGloss != null) {
        foundGlosses.add(matchedGloss);
        i += matchLen;
      }
    }

    // 3. Estructuración sintáctica básica LSB (Orden OSV / Interrogación al final)
    // Quién ayuda a quién: «¿en qué le puedo ayudar?» es AYUDAR_DAR;
    // «necesito ayuda», «ayúdeme», AYUDAR_PEDIR (misma regla que la Lambda).
    // «voy a denunciar»: futuro, no el verbo ir.
    final dirigidas = HelpDirection.apply(
      VerbForms.applyFuture(foundGlosses, rawText),
      rawText,
    );
    final semanticGlosses = _reorderToLsb(dirigidas, rawText);

    // 4. Resolver clips de animación para el avatar 3D
    final animationGlosses = <String>[];
    final animationUrls = <String>[];
    final modelUrl = '${animationResolver.baseUrl}${AnimationUrlResolver.bundledModelFileName}';

    for (final gloss in semanticGlosses) {
      final canonical = AnimationUrlResolver.canonicalFor(gloss);

      if (AnimationUrlResolver.available3DGlosses.contains(canonical)) {
        animationGlosses.add(canonical);
        animationUrls.add(modelUrl);
      } else {
        // Si no está horneada como seña completa, se deletrea con las letras de A..Z del modelo
        final letters = canonical.split('');
        for (final char in letters) {
          final charCanonical = AnimationUrlResolver.canonicalFor(char);
          if (AnimationUrlResolver.available3DGlosses.contains(charCanonical)) {
            animationGlosses.add(charCanonical);
            animationUrls.add(modelUrl);
          }
        }
      }
    }

    final primaryUrl = animationUrls.isNotEmpty ? animationUrls.first : '';

    return LsbTranslationModel(
      glosses: semanticGlosses,
      animationUrl: primaryUrl,
      animationUrls: animationUrls,
      animationGlosses: animationGlosses,
      semanticStatus: SemanticStatus.resolved,
      representationStatus: RepresentationStatus.complete,
    );
  }

  static String _fold(String w) => w.replaceAll('Ñ', 'N');

  /// Reglas sintácticas heurísticas de la LSB:
  /// - Mover palabras interrogativas (QUE, QUIEN, DONDE, etc.) hacia el final.
  /// - Colocar negación (NO) cerca del verbo o al final.
  List<String> _reorderToLsb(List<String> glosses, String originalText) {
    if (glosses.length <= 1) return glosses;

    final interrogatives = {'QUE', 'QUIEN', 'CUANDO', 'DONDE', 'COMO', 'POR_QUE', 'PARA_QUE', 'CUAL', 'CUANTOS'};
    final withoutQuestions = <String>[];
    final questions = <String>[];

    for (final g in glosses) {
      if (interrogatives.contains(g)) {
        questions.add(g);
      } else {
        withoutQuestions.add(g);
      }
    }

    // En LSB, la interrogación va al final
    final reordered = [...withoutQuestions, ...questions];
    return LsbGlossSemantics.reconcileQuestionGlosses(originalText, reordered);
  }
}
