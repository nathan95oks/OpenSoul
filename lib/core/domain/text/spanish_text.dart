/// Utilidades de texto en español compartidas por el dominio.
library;

/// Normalización de texto en español: una sola regla para quitar tildes,
/// en lugar de una copia por archivo.
abstract final class SpanishText {
  static const _from = 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛáàäâéèëêíìïîóòöôúùüû';
  static const _to = 'AAAAEEEEIIIIOOOOUUUUaaaaeeeeiiiioooouuuu';

  /// [text] sin tildes ni diéresis, en mayúsculas o minúsculas tal como
  /// venga («Cédula» → «Cedula»). La ñ se conserva salvo que [foldEnye] la
  /// convierta en n (para comparar palabras escritas sin ella).
  static String stripAccents(String text, {bool foldEnye = false}) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final i = _from.indexOf(char);
      if (i >= 0) {
        out.write(_to[i]);
      } else if (foldEnye && char == 'ñ') {
        out.write('n');
      } else if (foldEnye && char == 'Ñ') {
        out.write('N');
      } else {
        out.write(char);
      }
    }
    return out.toString();
  }
}
