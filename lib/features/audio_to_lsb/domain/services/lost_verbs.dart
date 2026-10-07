import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/pending_sign_info.dart';

/// Devuelve a la seña el verbo que la traducción perdió.
///
/// El modelo a veces se salta el verbo que sigue a «quiere», «necesito» o
/// «para»: «¿quiere realizar un trámite en la FELCC?» volvía como QUERER
/// TRÁMITE FELCC, sin REALIZAR, mientras que «quiero realizar un trámite» sí
/// lo traía deletreado. Solo se recupera ese caso, que se puede demostrar
/// mirando el texto: un infinitivo justo después de un verbo o una palabra que
/// lo pide, que ninguna seña de la traducción representa (ni la misma palabra,
/// ni su seña equivalente, ni su deletreo). Se pone antes de la palabra que lo
/// seguía en la frase: con seña si el avatar la tiene; si no, deletreado, como
/// el resto de Voz a LSB.
abstract final class LostVerbs {
  static const _resolver = AnimationUrlResolver();

  /// Formas que piden un infinitivo después: «quiere realizar», «necesito
  /// pagar», «puede presentar», «debo firmar», «para denunciar».
  static const _piden = {
    'QUIERO', 'QUIERE', 'QUIERES', 'QUEREMOS', 'QUIEREN', 'QUERIA', //
    'DESEO', 'DESEA', 'DESEAS', 'DESEAMOS', 'DESEAN', //
    'NECESITO', 'NECESITA', 'NECESITAS', 'NECESITAMOS', 'NECESITAN', //
    'PUEDO', 'PUEDE', 'PUEDES', 'PODEMOS', 'PUEDEN', //
    'DEBO', 'DEBE', 'DEBES', 'DEBEMOS', 'DEBEN', //
    'PARA', 'SIN', 'AL',
  };

  /// «tengo que pagar», «hay que firmar».
  static const _tenerQue = {
    'TENGO', 'TIENE', 'TIENES', 'TENEMOS', 'TIENEN', 'HAY', //
  };

  /// «voy a denunciar».
  static const _irA = {'VOY', 'VA', 'VAS', 'VAMOS', 'VAN', 'IR'};

  /// Infinitivos que LSB no seña (cópula, auxiliares).
  static const _sinSena = {'SER', 'ESTAR', 'HABER'};

  static final _palabra = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+');
  static final _infinitivo = RegExp(r'^[A-ZÑ]{2,}(AR|ER|IR)$');

  static LsbTranslation apply(
    String text,
    LsbTranslation translation,
    PendingSignCatalog catalog,
  ) {
    final steps = [...translation.animationGlosses];
    final urls = [...translation.animationUrls];
    if (steps.isEmpty || steps.length != urls.length) return translation;
    final glosses = [...translation.glosses];
    final spelled = [...translation.spelledWords];

    final palabras = [
      for (final m in _palabra.allMatches(text)) _plain(m.group(0)!),
    ];
    var changed = false;
    for (var i = 1; i < palabras.length; i++) {
      final verbo = palabras[i];
      if (!_infinitivo.hasMatch(verbo) || _sinSena.contains(verbo)) continue;
      if (!_pedido(palabras, i)) continue;
      final signs = catalog.equivalentSigns(verbo) ?? const <String>[];
      if (_cubierto(verbo, signs, steps)) continue;

      // Va antes de la primera palabra que lo seguía y sí tiene paso.
      var at = steps.length;
      for (final siguiente in palabras.skip(i + 1)) {
        final j = _pasoDe(siguiente, steps, catalog);
        if (j != null) {
          at = j;
          break;
        }
      }
      final List<String> nuevos;
      if (_hasClip(verbo)) {
        nuevos = [verbo];
      } else {
        nuevos = verbo.split('');
        spelled.add(verbo);
      }
      steps.insertAll(at, nuevos);
      urls.insertAll(at, [
        for (final g in nuevos) _resolver.resolveAll(gloss: g).first,
      ]);
      glosses.add(verbo);
      changed = true;
    }
    if (!changed) return translation;

    return LsbTranslation(
      glosses: glosses,
      animationUrl: urls.first,
      animationUrls: urls,
      animationGlosses: steps,
      disambiguations: translation.disambiguations,
      pendingClarifications: translation.pendingClarifications,
      semanticStatus: translation.semanticStatus,
      representationStatus: translation.representationStatus,
      semanticTurn: translation.semanticTurn,
      spelledWords: spelled,
      unanimatedSigns: translation.unanimatedSigns,
      stepDescriptions: translation.stepDescriptions,
    );
  }

  static bool _pedido(List<String> palabras, int i) {
    final antes = palabras[i - 1];
    if (_piden.contains(antes)) return true;
    if (i < 2) return false;
    final dosAntes = palabras[i - 2];
    return (antes == 'QUE' && _tenerQue.contains(dosAntes)) ||
        (antes == 'A' && _irA.contains(dosAntes));
  }

  /// Alguna seña lo dice: la misma palabra, su equivalente o su deletreo.
  static bool _cubierto(String verbo, List<String> signs, List<String> steps) {
    final claves = {
      verbo,
      for (final g in signs) AnimationUrlResolver.canonicalFor(g),
    };
    if (steps.any(
      (s) => claves.contains(AnimationUrlResolver.canonicalFor(s)),
    )) {
      return true;
    }
    final letras = [
      for (final s in steps)
        if (s.length == 1) _plain(s) else ' ',
    ].join();
    return letras.contains(verbo);
  }

  /// El paso donde está [palabra] (su seña, su equivalente o el comienzo de
  /// su deletreo), o `null`.
  static int? _pasoDe(
    String palabra,
    List<String> steps,
    PendingSignCatalog catalog,
  ) {
    if (palabra.length < 2) return null;
    final claves = {
      palabra,
      for (final g in catalog.equivalentSigns(palabra) ?? const <String>[])
        AnimationUrlResolver.canonicalFor(g),
    };
    for (var j = 0; j < steps.length; j++) {
      if (claves.contains(AnimationUrlResolver.canonicalFor(steps[j]))) {
        return j;
      }
      if (steps[j].length == 1 &&
          j + palabra.length <= steps.length &&
          steps.sublist(j, j + palabra.length).map(_plain).join() == palabra) {
        return j;
      }
    }
    return null;
  }

  static bool _hasClip(String gloss) => AnimationUrlResolver.available3DGlosses
      .contains(AnimationUrlResolver.canonicalFor(gloss));

  static String _plain(String word) =>
      AnimationUrlResolver.stripAccents(word.toUpperCase());
}
