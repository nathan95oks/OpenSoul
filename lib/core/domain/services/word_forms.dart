/// Plural y femenino de una seña: «abogadas» es ABOGADO, «papeles» es PAPEL.
///
/// La traducción deletreaba esas palabras aunque la seña existe: es la misma
/// seña con otro número o género. Solo se reconoce si [known] dice que la
/// base es una seña del catálogo: no inventa. La misma regla está en
/// `forma_base` de `aws/lambda_text_to_lsb.py`.
abstract final class WordForms {
  /// La seña de la que [word] (mayúsculas, sin tildes) es plural o femenino,
  /// o `null`.
  static String? baseOf(String word, bool Function(String) known) {
    if (word.length < 4 || !RegExp(r'^[A-ZÑ]+$').hasMatch(word)) return null;
    final singulares = <String>[
      if (word.endsWith('CES')) '${word.substring(0, word.length - 3)}Z',
      if (word.endsWith('ES')) word.substring(0, word.length - 2),
      if (word.endsWith('S')) word.substring(0, word.length - 1),
      word,
    ];
    for (final base in singulares) {
      final femenino = base.endsWith('A');
      for (final cand in [
        base,
        if (femenino) base.substring(0, base.length - 1),
        if (femenino) '${base.substring(0, base.length - 1)}O',
      ]) {
        if (cand.length >= 3 && cand != word && known(cand)) return cand;
      }
    }
    return null;
  }
}
