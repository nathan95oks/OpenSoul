import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';

/// Ayuda para una palabra que el avatar deletrea: un sinónimo en LSB o, si
/// no hay, qué es (la misma descripción de las tarjetas LSB). Se muestra
/// abajo mientras se deletrea, con «Siguiente» para saltar el deletreo.
class SpellingHelp {
  /// Primer y último paso (incluido) de las letras de [word] en la secuencia
  /// del avatar.
  final int start;
  final int end;

  /// La palabra, como se muestra: «REALIZAR».
  final String word;

  /// Señas con que se puede decir la palabra (equivalencia aprobada, la misma
  /// que usan las tarjetas): «realizar» → HACER.
  final List<String> synonyms;

  /// Qué es, cuando no tiene sinónimo.
  final PendingSignInfo? description;

  const SpellingHelp({
    required this.start,
    required this.end,
    required this.word,
    this.synonyms = const [],
    this.description,
  });

  bool contains(int step) => step >= start && step <= end;

  /// Una ayuda por cada palabra deletreada de [steps]: las que el backend
  /// informó ([words]: palabras sin seña del catálogo y señas sin animación).
  /// Las letras se buscan en orden; si dos palabras empiezan en el mismo
  /// paso, gana la más larga («DE» no se come el comienzo de «DENUNCIA»).
  static List<SpellingHelp> forSteps(
    List<String> steps,
    List<String> words,
    PendingSignCatalog catalog,
  ) {
    final pending = [...words];
    final out = <SpellingHelp>[];
    var i = 0;
    while (i < steps.length && pending.isNotEmpty) {
      final aqui = [
        for (final w in pending)
          if (_matchesAt(steps, i, _letters(w))) w,
      ];
      if (aqui.isEmpty) {
        i++;
        continue;
      }
      final word = aqui.reduce(
        (a, b) => _letters(b).length > _letters(a).length ? b : a,
      );
      pending.remove(word);
      final length = _letters(word).length;
      final shown = word.toUpperCase().replaceAll('_', ' ');
      final synonyms = [
        for (final g in catalog.equivalentSigns(word) ?? const <String>[])
          if (_plain(g) != _plain(word)) g,
      ];
      final gloss = synonyms.isEmpty ? catalog.describedGloss(word) : null;
      out.add(
        SpellingHelp(
          start: i,
          end: i + length - 1,
          word: shown,
          synonyms: synonyms,
          description: gloss == null ? null : catalog.infoOf(gloss),
        ),
      );
      i += length;
    }
    return out;
  }

  static String _plain(String word) => AnimationUrlResolver.stripAccents(
    word.toUpperCase(),
  ).replaceAll(RegExp(r'[^A-Z0-9Ñ]'), '');

  static List<String> _letters(String word) => _plain(word).split('');

  static bool _matchesAt(List<String> steps, int start, List<String> letters) {
    if (letters.length < 2 || start + letters.length > steps.length) {
      return false;
    }
    for (var k = 0; k < letters.length; k++) {
      final step = steps[start + k];
      if (step.length != 1 ||
          AnimationUrlResolver.stripAccents(step.toUpperCase()) != letters[k]) {
        return false;
      }
    }
    return true;
  }
}
