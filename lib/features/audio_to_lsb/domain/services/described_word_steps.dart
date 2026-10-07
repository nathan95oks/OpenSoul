import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';

/// Una palabra que no es una seña del catálogo no se deletrea si se puede
/// decir de otra forma.
///
/// El backend deletrea cada palabra que no es una seña del catálogo y la
/// informa en [LsbTranslation.spelledWords]. Por orden:
/// 1. Si tiene una seña equivalente aprobada (la misma de las tarjetas:
///    «comprobante» → FACTURA) y el avatar tiene sus clips, se seña.
/// 2. Si tiene descripción («¿Qué es?» de las palabras en azul), sus letras
///    se cambian por un solo paso `SENA_PENDIENTE:PALABRA`: el avatar
///    muestra la descripción delante y, leída, sigue con la seña siguiente.
/// 3. Si no (o es un nombre propio), se sigue deletreando.
abstract final class DescribedWordSteps {
  static const _resolver = AnimationUrlResolver();
  static LsbTranslation apply(
    LsbTranslation translation,
    PendingSignCatalog catalog,
  ) {
    final steps = translation.animationGlosses;
    final urls = translation.animationUrls;
    if (translation.spelledWords.isEmpty ||
        steps.isEmpty ||
        steps.length != urls.length) {
      return translation;
    }

    final words = [...translation.spelledWords];
    final outSteps = <String>[];
    final outUrls = <String>[];
    var changed = false;
    var i = 0;
    while (i < steps.length) {
      if (!_isLetter(steps[i]) || words.isEmpty) {
        outSteps.add(steps[i]);
        outUrls.add(urls[i]);
        i++;
        continue;
      }
      // Las palabras llegan en el orden del español y las letras en el de
      // LSB: se busca la que empieza aquí, la más larga («DE» no se come el
      // comienzo de «DENUNCIA»).
      final candidates = [
        for (final w in words)
          if (_matchesAt(steps, i, _letters(w))) w,
      ];
      if (candidates.isEmpty) {
        outSteps.add(steps[i]);
        outUrls.add(urls[i]);
        i++;
        continue;
      }
      final word = candidates.reduce(
        (a, b) => _letters(b).length > _letters(a).length ? b : a,
      );
      words.remove(word);
      final length = _letters(word).length;
      final signs = catalog.equivalentSigns(word);
      if (signs != null &&
          signs.every(
            (g) => AnimationUrlResolver.available3DGlosses.contains(
              AnimationUrlResolver.canonicalFor(g),
            ),
          )) {
        for (final g in signs) {
          outSteps.add(g);
          outUrls.add(_resolver.resolveAll(gloss: g).first);
        }
        changed = true;
        i += length;
        continue;
      }
      final gloss = catalog.describedGloss(word);
      if (gloss == null) {
        outSteps.addAll(steps.sublist(i, i + length));
        outUrls.addAll(urls.sublist(i, i + length));
      } else {
        outSteps.add(gloss);
        outUrls.add('${AnimationUrlResolver.placeholderScheme}$gloss');
        changed = true;
      }
      i += length;
    }
    if (!changed) return translation;

    return LsbTranslation(
      glosses: translation.glosses,
      animationUrl: outUrls.first,
      animationUrls: outUrls,
      animationGlosses: outSteps,
      disambiguations: translation.disambiguations,
      pendingClarifications: translation.pendingClarifications,
      semanticStatus: translation.semanticStatus,
      representationStatus: translation.representationStatus,
      semanticTurn: translation.semanticTurn,
      spelledWords: translation.spelledWords,
    );
  }

  static bool _isLetter(String step) =>
      step.length == 1 && RegExp(r'[\wÑñ]', unicode: true).hasMatch(step);

  static List<String> _letters(String word) =>
      AnimationUrlResolver.stripAccents(
        word.toUpperCase(),
      ).split('').where((c) => RegExp(r'[A-Z0-9Ñ]').hasMatch(c)).toList();

  static bool _matchesAt(List<String> steps, int start, List<String> letters) {
    if (letters.isEmpty || start + letters.length > steps.length) return false;
    for (var k = 0; k < letters.length; k++) {
      if (AnimationUrlResolver.canonicalFor(steps[start + k]) != letters[k]) {
        return false;
      }
    }
    return true;
  }
}
