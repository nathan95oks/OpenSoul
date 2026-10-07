import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';

/// Qué hace el avatar con cada palabra que el backend tuvo que deletrear.
///
/// El backend deletrea dos cosas: las palabras que no son una seña del
/// catálogo ([LsbTranslation.spelledWords]) y las señas del catálogo que el
/// avatar todavía no tiene animadas ([LsbTranslation.unanimatedSigns]).
/// Deletrear solo es correcto si la palabra no existe en LSB. Por orden:
/// 1. Tiene una seña equivalente aprobada («comprobante» → FACTURA) y el
///    avatar tiene sus clips: se seña.
/// 2. Existe en LSB pero no está animada (VERDAD; «realizar» → HACER), o es
///    una palabra en azul con descripción: un solo paso
///    `SENA_PENDIENTE:PALABRA` y la pantalla amarilla dice qué es
///    ([LsbTranslation.stepDescriptions]); al leerla el avatar sigue.
/// 3. No existe en LSB (ni descripción): se deletrea.
abstract final class DescribedWordSteps {
  static const _resolver = AnimationUrlResolver();

  /// [signSources]: dónde está cada seña del catálogo («M3 · General I ·
  /// p.111»), por su forma canónica.
  static LsbTranslation apply(
    LsbTranslation translation,
    PendingSignCatalog catalog, {
    Map<String, String> signSources = const {},
  }) {
    final steps = translation.animationGlosses;
    final urls = translation.animationUrls;
    final candidates = [
      for (final s in translation.unanimatedSigns) (word: s, isSign: true),
      for (final w in translation.spelledWords) (word: w, isSign: false),
    ];
    if (candidates.isEmpty || steps.isEmpty || steps.length != urls.length) {
      return translation;
    }

    final outSteps = <String>[];
    final outUrls = <String>[];
    final descriptions = <String, PendingSignInfo>{
      ...translation.stepDescriptions,
    };
    var changed = false;
    var i = 0;
    while (i < steps.length) {
      if (!_isLetter(steps[i]) || candidates.isEmpty) {
        outSteps.add(steps[i]);
        outUrls.add(urls[i]);
        i++;
        continue;
      }
      // Las palabras llegan en el orden del español y las letras en el de
      // LSB: se busca la que empieza aquí, la más larga («DE» no se come el
      // comienzo de «DENUNCIA»).
      final aqui = [
        for (final c in candidates)
          if (_matchesAt(steps, i, _letters(c.word))) c,
      ];
      if (aqui.isEmpty) {
        outSteps.add(steps[i]);
        outUrls.add(urls[i]);
        i++;
        continue;
      }
      final c = aqui.reduce(
        (a, b) => _letters(b.word).length > _letters(a.word).length ? b : a,
      );
      candidates.remove(c);
      final length = _letters(c.word).length;
      i += length;

      final signs = c.isSign ? [c.word] : catalog.equivalentSigns(c.word);
      if (signs != null && signs.every(_hasClip)) {
        for (final g in signs) {
          outSteps.add(g);
          outUrls.add(_resolver.resolveAll(gloss: g).first);
        }
        changed = true;
        continue;
      }
      final info = signs != null
          ? PendingSignInfo(
              word: _shown(c.word),
              description: signs.join(' '),
              lsbDescription: signs,
              hasLsbSign: true,
              source: _sourceOf(signs, signSources),
            )
          : _describedWord(c.word, catalog);
      if (info == null) {
        // No existe en LSB: se deletrea, como lo dejó el backend.
        outSteps.addAll(steps.sublist(i - length, i));
        outUrls.addAll(urls.sublist(i - length, i));
        continue;
      }
      final gloss = '${PendingSign.prefix}${_key(c.word)}';
      outSteps.add(gloss);
      outUrls.add('${AnimationUrlResolver.placeholderScheme}$gloss');
      descriptions[gloss] = info;
      changed = true;
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
      unanimatedSigns: translation.unanimatedSigns,
      stepDescriptions: descriptions,
    );
  }

  /// La descripción de una palabra en azul, o `null` si no hay (o es un
  /// nombre propio: se deletrea).
  static PendingSignInfo? _describedWord(
    String word,
    PendingSignCatalog catalog,
  ) {
    final gloss = catalog.describedGloss(word);
    return gloss == null ? null : catalog.infoOf(gloss);
  }

  static bool _hasClip(String gloss) => AnimationUrlResolver.available3DGlosses
      .contains(AnimationUrlResolver.canonicalFor(gloss));

  static String _sourceOf(List<String> signs, Map<String, String> sources) {
    for (final g in signs) {
      final s = sources[AnimationUrlResolver.canonicalFor(g)];
      if (s != null && s.isNotEmpty) return s;
    }
    return '';
  }

  static String _shown(String word) => word.toUpperCase().replaceAll('_', ' ');

  static String _key(String word) =>
      word.toUpperCase().trim().replaceAll(RegExp(r'\s+'), '_');

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
