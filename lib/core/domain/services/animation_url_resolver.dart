import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/domain/text/spanish_text.dart';

class AnimationUrlResolver {
  /// Modelo distribuido dentro del APK/IPA. Todos los clips disponibles viven
  /// en este GLB, por lo que queda precargado desde la instalacion.
  static const String bundledModelAsset = 'assets/models/avatar_test.glb';
  static const String bundledModelFileName = 'avatar_test.glb';

  static const String defaultBaseUrl = String.fromEnvironment(
    'LSB_ANIMATIONS_BASE_URL',
  );

  static const String placeholderScheme = 'placeholder://';
  final String baseUrl;

  const AnimationUrlResolver({this.baseUrl = defaultBaseUrl});

  static const String compositeSeparator = '+';

  /// Senas horneadas en `avatar_test.glb`, tomadas del propio modelo: son los
  /// 200 clips de su lista de animaciones (menos NEUTRO1..3, los movimientos de reposo, que no son señas), en su forma canonica.
  ///
  /// Las cuatro palabras con ene se hornearon con N (`DANAR`) y ademas se
  /// listan con su grafia de glosa (`DAÑAR`), que es la que llega aqui;
  /// [animationNameFor] la devuelve al nombre del clip. La 'Ñ' suelta es el
  /// clip `ENIE`: pedir una animacion inexistente no emite 'finished' y deja
  /// la secuencia esperando al reloj de seguridad, asi que solo se piden
  /// clips que el modelo trae.
  ///
  /// Si se hornea un .glb nuevo, esta lista se actualiza con el.
  static const Set<String> available3DGlosses = {
    // Letras del alfabeto dactilologico (la Ñ es el clip `ENIE`).
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O',
    'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'Ñ', 'ENIE',
    // Numerales.
    'CERO', 'UNO', 'DOS', 'TRES', 'CUATRO', 'CINCO', 'SEIS', 'SIETE', 'OCHO',
    'NUEVE', 'DIEZ',
    // Senas.
    'ABOGADO', 'ABRIR', 'ACEPTAR', 'ACOMPANAR', 'ACOSO', 'AHORA', 'ALCALDIA',
    'ALLI', 'AMBOS', 'AMENAZAR', 'AMIGO', 'AQUI', 'ASISTENCIA', 'ATENDER',
    'AUN', 'AUTORIDAD', 'AVENIDA', 'AYER', 'AYUDAR_DAR', 'AYUDAR_PEDIR',
    'BANCO', 'BILLETES', 'BUENAS_NOCHES', 'BUENAS_TARDES', 'BUENOS_DIAS',
    'BULLYING', 'BUSCAR', 'CALLE', 'CARPETA', 'CASA', 'CELULAR', 'CERCA',
    'CERTIFICADO', 'COCHABAMBA', 'COMO', 'COMO_ESTAS', 'COMPRENDER', 'CONOCER',
    'CONTESTAR', 'CONTINUAR', 'CONVOCAR', 'CUAL', 'CUANDO', 'CUANTOS', 'DANAR',
    'DAR', 'DENTRO', 'DEVOLVER', 'DIA', 'DIRECCION', 'DOCTOR', 'DONDE', 'EL',
    'ELLA', 'ELLOS', 'ENGANAR', 'ENVIAR', 'ESCAPAR', 'ESCRIBIR', 'ESPERAR',
    'EXPLICAR', 'FACTURA', 'FECHA', 'FILMAR', 'FOTOCOPIA', 'FOTOS', 'FUTURO',
    'GRACIAS', 'GUARDAR', 'HABLAR', 'HACER', 'HASTA_LUEGO', 'HERIDA', 'HIJA',
    'HIJO', 'HOLA', 'HOMBRE', 'HORA', 'HOSPITAL', 'HOY', 'IDENTIDAD',
    'INTERPRETE', 'INVESTIGACION', 'IR', 'JUEZ', 'JUICIO', 'JUSTICIA', 'LADRON',
    'LEER', 'LENTO', 'LEY', 'LLEVAR', 'LO_SIENTO', 'MANANA', 'MAS_O_MENOS',
    'MIEDO', 'MIO', 'MOSTRAR', 'MUCHO', 'MUJER', 'NARRAR', 'NECESITAR', 'NO',
    'NOMBRE', 'NOSOTROS', 'NO_PUEDO', 'NO_SABER', 'NUEVO', 'OBSERVAR',
    'OFICINA', 'PAPEL', 'PARA_QUE', 'PASADO', 'PEDIR', 'PEGAR', 'PELEAR',
    'PERDER', 'PERMISO', 'POLICIA', 'POR_FAVOR', 'POR_QUE', 'PRIMERA_VEZ',
    'PROTEGER', 'PUEDO', 'QUE', 'QUEJAR', 'QUERER', 'QUIEN', 'RECHAZAR',
    'RECIBIR', 'RECORDAR', 'RESOLUCION', 'ROBAR', 'SABER', 'SELLO', 'SEMANA',
    'SI', 'SORDO', 'TARDE', 'TENER', 'TERMINAR', 'TESTIGO', 'TESTIMONIO',
    'TIENDA', 'TOTAL', 'TRAER', 'TRAMITE', 'TRATA_TRAFICO', 'TU', 'TUYO',
    'ULTIMO', 'URGENTE', 'USTEDES', 'VENIR', 'VER', 'VIDEO', 'VIOLENCIA',
    'VOLVER', 'YO',
    // Grafia de glosa de los clips horneados con N.
    'ACOMPAÑAR', 'DAÑAR', 'ENGAÑAR', 'MAÑANA',
  };

  /// Los numerales se hornearon con su nombre en letras, pero el catalogo los
  /// ofrece como digitos.
  ///
  /// `official_dictionary.json` trae las entradas '0'..'9' y
  /// [available3DGlosses] declara CERO..DIEZ, asi que la comparacion directa
  /// nunca casaba. Como ademas esas entradas tienen `animationFile` no vacio,
  /// tampoco caian por la rama del marcador de posicion: se devolvia la URL
  /// real y se le pedia al visor una animacion llamada '0', que el modelo no
  /// tiene. El backend ya hacia esta traduccion
  /// (`lambda_text_to_lsb.py`, `_DIGITO_A_GLOSA`); faltaba en el cliente.
  static const Map<String, String> digitToNumeral = {
    '0': 'CERO',
    '1': 'UNO',
    '2': 'DOS',
    '3': 'TRES',
    '4': 'CUATRO',
    '5': 'CINCO',
    '6': 'SEIS',
    '7': 'SIETE',
    '8': 'OCHO',
    '9': 'NUEVE',
  };

  /// Glosas cuyo nombre de animacion dentro del .glb no coincide con la glosa.
  static const Map<String, String> animationNameOverrides = {'Ñ': 'ENIE'};

  /// Forma canonica de la glosa para buscarla entre las animaciones.
  static String canonicalFor(String gloss) {
    final clean = stripAccents(gloss.toUpperCase().trim()).replaceAll(' ', '_');
    return digitToNumeral[clean] ?? clean;
  }

  /// Nombre con el que hay que pedirle la sena al `model-viewer`.
  ///
  /// En S3 los clips están en mayúsculas con barra baja (ej: PRIMERA_VEZ)
  /// y las palabras que llevan Ñ usan N (ej: ACOMPANAR), mientras que
  /// la letra suelta Ñ se mapea a ENIE.
  static String animationNameFor(String gloss) {
    final canonical = canonicalFor(gloss);
    if (animationNameOverrides.containsKey(canonical)) {
      return animationNameOverrides[canonical]!;
    }
    if (canonical.length > 1 && canonical.contains('Ñ')) {
      return canonical.replaceAll('Ñ', 'N');
    }
    return canonical;
  }

  static const Set<String> wordsToSpell = {
    'DENUNCIA',
    'DENUNCIAR',
    'DENUNCIANTE',
    'DENUNCIADO',
    'FISCALIA',
    'JUZGADO',
    'COMISARIA',
    'QUERELLA',
    'IMPUTACION',
    'IMPUTADO',
    'VICTIMA',
    'SOSPECHOSO',
    'DETENIDO',
    'ACTA',
    'CEDULA',
    'CEDULA DE IDENTIDAD',
    'FIRMA',
    'FIRMAR',
    'DECLARACION',
    'DECLARAR',
    'MINISTERIO PUBLICO',
    'FELCC',
    'FELCV',
    'SEPDAVI',
    'SEPDEP',
    'AUDIENCIA',
  };

  /// Quita las tildes de una glosa conservando la N con virgulilla, que es una
  /// letra del alfabeto dactilologico y no un acento.
  static String stripAccents(String gloss) => SpanishText.stripAccents(gloss);

  /// Letras con las que se deletrea [gloss], o `null` si [gloss] no se
  /// deletrea. Incluye las que no tienen animacion: se representan con un
  /// placeholder, pero la palabra se deletrea entera.
  static List<String>? spelledLetters(String gloss) {
    final clean = stripAccents(gloss.toUpperCase().trim());
    if (!wordsToSpell.contains(clean) || clean.length <= 1) return null;
    return clean.split('');
  }

  String resolve({required String gloss, String? animationFile}) =>
      resolveAll(gloss: gloss, animationFile: animationFile).first;

  List<String> resolveAll({required String gloss, String? animationFile}) {
    // Sin seña en el catálogo: un solo paso con el aviso, sin deletrear.
    if (PendingSign.isPending(gloss)) return ['$placeholderScheme$gloss'];

    // Se compara por la forma canonica: los digitos del catalogo tienen que
    // encontrar la animacion que se horneo con su nombre en letras.
    final cleanGloss = canonicalFor(gloss);

    if (available3DGlosses.contains(cleanGloss)) {
      return ['$baseUrl$bundledModelFileName'];
    }

    if (wordsToSpell.contains(cleanGloss) && cleanGloss.length > 1) {
      // Una letra sin animacion no se descarta: se deletrea como placeholder.
      // Descartarla cambiaba la palabra en silencio (FISCALIA se deletreaba
      // "FSCALA" al no estar la I).
      final letters = spelledLetters(cleanGloss)!
          .map(
            (char) => available3DGlosses.contains(char)
                ? '$baseUrl$bundledModelFileName'
                : '$placeholderScheme$char',
          )
          .toList();
      if (letters.isNotEmpty) {
        return letters;
      }
    }

    if (animationFile != null && animationFile.isNotEmpty) {
      if (animationFile.endsWith('.glb')) {
        return ['$baseUrl$bundledModelFileName'];
      }
    }

    return ['$placeholderScheme$cleanGloss'];
  }
}
