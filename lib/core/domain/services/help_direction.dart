import 'package:lsb_legal_app/core/domain/text/spanish_text.dart';

/// Quién ayuda a quién: el avatar no tiene una seña AYUDAR, tiene
/// AYUDAR_DAR (yo te ayudo) y AYUDAR_PEDIR (ayúdame, necesito ayuda).
///
/// Es la misma regla que `enforce_help_direction` de la Lambda Texto→LSB:
/// «¿En qué le puedo ayudar?» es DAR; «necesito ayuda», «¿me puede
/// ayudar?», «ayúdeme» son PEDIR. Aquí la usan la traducción sin conexión y
/// las respuestas de una Lambda anterior, que mandaban AYUDAR deletreado.
class HelpDirection {
  HelpDirection._();

  static const dar = 'AYUDAR_DAR';
  static const pedir = 'AYUDAR_PEDIR';

  /// Glosas que se reemplazan por la dirección que dice el español.
  static const familia = {'AYUDAR', 'AYUDA', dar, pedir};

  /// «auxilio» y «socorro» también cuentan: sin conexión se dicen con
  /// AYUDAR_PEDIR.
  static final _palabra = RegExp(r'\bayud\w*|\bauxilio\b|\bsocorro\b');
  static final _pidePalabra = RegExp(
    r'^ayud\w*(me|nos)$|^ayudame$|^ayudeme$|^ayudenme$',
  );
  static final _pideAntes = [
    RegExp(
      r'\b(necesit|pid|ped|pedi|quier|quer|requier|busc)\w*(\s+\w+){0,3}\s*$',
    ),
    RegExp(r'\b(me|nos)(\s+\w+){0,2}\s*$'),
  ];
  static final _auxilio = RegExp(r'\b(socorro|auxilio)\b');

  static String _plano(String texto) =>
      SpanishText.stripAccents(texto.toUpperCase()).toLowerCase();

  /// La dirección de la palabra [m] de [plano].
  static String _direccion(String plano, RegExpMatch m) {
    final palabra = m.group(0)!;
    if (!palabra.startsWith('ayud') || _pidePalabra.hasMatch(palabra)) {
      return pedir;
    }
    final antes = plano.substring(0, m.start).split(RegExp(r'[.?!¿¡;]')).last;
    return _pideAntes.any((r) => r.hasMatch(antes)) ? pedir : dar;
  }

  /// Una dirección por cada «ayud…» de [texto], en orden. Sin ninguna, una
  /// sola: PEDIR si se dice «auxilio» o «socorro», DAR si no.
  static List<String> forText(String texto) {
    // La Ñ se vuelve N: aquí solo importan las palabras de «ayuda».
    final plano = _plano(texto).replaceAll('ñ', 'n');
    final direcciones = [
      for (final m in _palabra.allMatches(plano)) _direccion(plano, m),
    ];
    if (direcciones.isNotEmpty) return direcciones;
    return [_auxilio.hasMatch(plano) ? pedir : dar];
  }

  /// [glosses] con cada glosa de la familia de AYUDAR cambiada por su
  /// dirección, en el orden en que aparecen en [texto].
  static List<String> apply(List<String> glosses, String texto) {
    if (!glosses.any((g) => familia.contains(_clave(g)))) return glosses;
    final direcciones = forText(texto);
    var i = 0;
    return [
      for (final g in glosses)
        if (familia.contains(_clave(g)))
          direcciones[(i++).clamp(0, direcciones.length - 1)]
        else
          g,
    ];
  }

  static String _clave(String g) =>
      SpanishText.stripAccents(g.toUpperCase().trim());
}
