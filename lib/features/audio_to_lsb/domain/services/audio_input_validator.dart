/// Por qué un texto no se manda a traducir a LSB.
enum AudioInputIssue {
  /// Vacío, o solo espacios: un audio sin voz, o nada escrito.
  empty('No escuché nada. Escribe o di tu mensaje otra vez.'),

  /// Más largo de lo que se puede señar de una vez.
  tooLong(
    'El mensaje es muy largo. Escríbelo en frases más cortas '
    '(máximo ${AudioInputValidator.maxLength} caracteres).',
  ),

  /// Solo símbolos, o casi: no hay palabras que traducir.
  noWords('Escribe palabras para traducir: solo hay símbolos o signos.'),

  /// Letras sin sentido («ljalskalksjlakj»).
  gibberish(
    'No entendí el texto. Revisa que las palabras estén bien escritas.',
  ),

  /// Otro idioma u otro alfabeto: solo se traduce el español.
  otherLanguage(
    'Solo se traduce el español. Escribe o di el mensaje en español.',
  );

  /// Lo que se le dice a la persona.
  final String message;

  const AudioInputIssue(this.message);
}

/// Control de calidad de lo que se escribe o se dicta en Voz a LSB, antes de
/// llamar al traductor: un texto sin sentido, vacío o en otro idioma no se
/// traduce (el modelo inventaría señas o deletrearía basura).
abstract final class AudioInputValidator {
  /// Largo máximo de un mensaje, en caracteres.
  static const int maxLength = 300;

  /// El texto sin caracteres de control y con los espacios normalizados.
  static String clean(String text) => text
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F​-‏﻿]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// `null` si [text] se puede traducir; si no, el motivo.
  static AudioInputIssue? validate(String text) {
    final limpio = clean(text);
    if (limpio.isEmpty) return AudioInputIssue.empty;
    if (limpio.length > maxLength) return AudioInputIssue.tooLong;

    final letras = _letra.allMatches(limpio).length;
    final cifras = RegExp(r'\d').allMatches(limpio).length;
    final visibles = limpio.replaceAll(' ', '').length;
    // Letras y cifras son el mensaje; lo demás (puntuación y signos) lo
    // acompaña. Si es la minoría, no hay mensaje.
    if (letras + cifras == 0 || (letras + cifras) / visibles < 0.6) {
      return AudioInputIssue.noWords;
    }

    final palabras = [for (final m in _palabra.allMatches(limpio)) m.group(0)!];
    if (_otroIdioma(limpio, palabras)) return AudioInputIssue.otherLanguage;
    if (_sinSentido(palabras)) return AudioInputIssue.gibberish;
    return null;
  }

  static final _letra = RegExp(r'\p{L}', unicode: true);
  static final _palabra = RegExp(r'[\p{L}\p{M}]+', unicode: true);
  static const _vocales = 'aeiouáéíóúü';

  // ---- Otro idioma -------------------------------------------------------

  /// Letras con tilde o signo que el español no usa.
  static const _ajenas = 'ãõçâêôàèìòùäößøåœæëï';

  /// Palabras muy comunes que no son españolas, de inglés, portugués,
  /// francés, italiano y alemán. Solo las que no existen en español.
  static const _extranjeras = {
    // Inglés
    'the', 'and', 'you', 'your', 'are', 'is', 'was', 'were', 'have', 'has', //
    'with', 'what', 'where', 'when', 'how', 'who', 'this', 'that', 'there', //
    'want', 'need', 'please', 'hello', 'thanks', 'thank', 'help', 'can', //
    'would', 'should', 'not', 'it', 'to', 'of', 'at', 'from', 'about', //
    'because', 'she', 'they', 'them', 'do', 'does', 'my', 'name', 'house', //
    'police', 'lawyer', 'court', 'judge', 'money', 'phone', 'school', //
    // Portugués
    'não', 'você', 'obrigado', 'obrigada', 'olá', 'quero', 'preciso', //
    'também', 'muito', 'isso', 'nós', 'então', 'ajuda', 'polícia', //
    // Francés
    'bonjour', 'merci', 'vous', 'voudrais', 'avec', 'suis', 'oui', 'je', //
    // Italiano
    'ciao', 'grazie', 'buongiorno', 'aiuto', 'voglio', 'sono', 'ho', //
    // Alemán
    'ich', 'bitte', 'danke', 'hallo', 'nicht', 'und', 'ist', 'brauche', //
    'hilfe', 'polizei',
  };

  /// Palabras muy comunes del español que no existen en otro de esos
  /// idiomas (se dejan fuera «me», «no», «a», «he»: son de varios).
  static const _espanolas = {
    'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'de', 'del', 'en', //
    'y', 'que', 'por', 'para', 'con', 'es', 'son', 'soy', 'estoy', 'está', //
    'quiero', 'quiere', 'necesito', 'necesita', 'mi', 'tu', 'su', 'al', //
    'se', 'lo', 'yo', 'hola', 'buenos', 'buenas', 'días', 'tardes', 'noches', //
    'gracias', 'favor', 'tengo', 'tiene', 'fui', 'fue', 'hay', 'qué', 'cómo', //
    'dónde', 'cuándo', 'quién', 'mis', 'sus', 'este', 'esta', 'esto', 'ese', //
    'esa', 'eso', 'muy', 'pero', 'como', 'más', 'sí', 'ayuda', 'denuncia', //
    'trámite', 'tramite', 'policía', 'felcc', 'felcv', 'fiscalía',
  };

  static bool _otroIdioma(String texto, List<String> palabras) {
    var fuera = false;
    for (final r in texto.toLowerCase().runes) {
      // Otro alfabeto (cirílico, griego, árabe, chino…), o letras que el
      // español no usa.
      if (r > 0x24F && !_esMarca(r) && _esLetra(r)) return true;
      if (_ajenas.contains(String.fromCharCode(r))) fuera = true;
    }
    if (fuera) return true;

    final minusculas = [for (final p in palabras) p.toLowerCase()];
    final ajenas = minusculas.where(_extranjeras.contains).length;
    final propias = minusculas.where(_espanolas.contains).length;
    return ajenas >= 2 || (ajenas == 1 && ajenas > propias);
  }

  static bool _esLetra(int rune) => _letra.hasMatch(String.fromCharCode(rune));

  static bool _esMarca(int rune) =>
      (rune >= 0x300 && rune <= 0x36F) || rune == 0x200D;

  // ---- Letras sin sentido -----------------------------------------------

  static bool _sinSentido(List<String> palabras) {
    final conLetras = [
      for (final p in palabras)
        if (p.length >= 3) p,
    ];
    if (conLetras.isEmpty) return false;
    final malas = [
      for (final p in conLetras)
        if (_palabraSinSentido(p)) p,
    ];
    if (malas.isEmpty) return false;
    return malas.length * 2 >= conLetras.length ||
        malas.any((p) => p.length >= 8);
  }

  /// Filas del teclado: cuatro teclas seguidas («qwer», «asdf», «zxcv»), de
  /// ida o de vuelta, es golpear el teclado y no una palabra.
  static const _filas = ['qwertyuiop', 'asdfghjklñ', 'zxcvbnm'];

  static bool _filaDeTeclado(String p) {
    for (final fila in _filas) {
      final alReves = fila.split('').reversed.join();
      for (var i = 0; i + 4 <= fila.length; i++) {
        if (p.contains(fila.substring(i, i + 4)) ||
            p.contains(alReves.substring(i, i + 4))) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _palabraSinSentido(String palabra) {
    final p = palabra.toLowerCase();
    // Una sigla en mayúsculas (FELCC, SIPRUNPCD) tiene pocas vocales.
    final sigla = palabra == palabra.toUpperCase() && palabra.length <= 10;
    if (palabra.length >= 25) return true;
    if (RegExp(r'(.)\1{3,}').hasMatch(p)) return true;
    if (_filaDeTeclado(p)) return true;

    var vocales = 0;
    var racha = 0;
    var maxRacha = 0;
    for (final c in p.split('')) {
      if (_vocales.contains(c)) {
        vocales++;
        racha = 0;
      } else {
        racha++;
        if (racha > maxRacha) maxRacha = racha;
      }
    }
    if (maxRacha >= 5) return true;
    if (vocales == 0 && p.length >= 4) return true;
    return !sigla && p.length >= 6 && vocales / p.length <= 0.2;
  }
}
