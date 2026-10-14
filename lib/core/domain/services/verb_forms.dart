import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';
import 'package:lsb_legal_app/core/domain/services/verb_forms_data.g.dart';
import 'package:lsb_legal_app/core/domain/text/spanish_text.dart';

/// Formas conjugadas cuyo verbo SÍ tiene seña: «va», «tiene», «da»…
///
/// La traducción las deletreaba cuando el modelo no las llevaba a su verbo:
/// dictada sola, «va» volvía V-A y «van» VAN, aunque IR tiene seña. Es la misma
/// palabra con otra desinencia, así que se vuelve a su verbo. «pasar» no está
/// aquí porque no tiene seña: de sus sentidos se ocupa la descripción de la
/// palabra (ver `PendingSignCatalog.infoOf`, «contextos»).
///
/// La misma tabla la lee la Lambda (`aws/formas_verbales.json`);
/// `test/formas_verbales_test.dart` comprueba que no se separen.
abstract final class VerbForms {
  static const _resolver = AnimationUrlResolver();

  /// Forma (sin tildes, en mayúsculas) → verbo con seña. Generada por
  /// `tool/build_formas_verbales.py`: conjuga los verbos del léxico LSB.
  static const Map<String, String> lemmas = verbFormsData;

  /// «voy a denunciar», «va a empezar»: IR no es el verbo sino el futuro
  /// próximo. Termina como un infinitivo pero es un lugar: «voy a un bar».
  static final _irAInfinitivo = RegExp(
    r'\b(?:voy|vas|va|vamos|van|vaya|vayan)\s+a\s+([a-zñ]{2,}(?:ar|er|ir))\b',
  );
  static const _noInfinitivo = {
    'bar', 'taller', 'hogar', 'lugar', 'mujer', 'mar', 'hospital', //
  };

  static final _palabra = RegExp(r'[A-ZÑ]{2,}');

  static String _plain(String s) => SpanishText.stripAccents(s.toUpperCase());

  static Set<String> _palabras(String text) => {
    for (final m in _palabra.allMatches(_plain(text))) m.group(0)!,
  };

  /// ¿La frase dice «va a + infinitivo»?
  static bool diceFuturoProximo(String text) {
    final t = SpanishText.stripAccents(text.toLowerCase());
    return _irAInfinitivo
        .allMatches(t)
        .any((m) => !_noInfinitivo.contains(m.group(1)));
  }

  /// [glosses] con FUTURO al inicio si [text] dice «va a + infinitivo», y sin
  /// el IR que era solo el auxiliar. Sin eso, devuelve [glosses] igual.
  static List<String> applyFuture(List<String> glosses, String text) {
    if (!diceFuturoProximo(text)) return glosses;
    final sinIr = [
      for (final g in glosses)
        if (AnimationUrlResolver.canonicalFor(g) != 'IR') g,
    ];
    if (sinIr.any((g) => AnimationUrlResolver.canonicalFor(g) == 'FUTURO')) {
      return sinIr;
    }
    return ['FUTURO', ...sinIr];
  }

  /// [translation] con las formas conjugadas que dijo [text] llevadas a su
  /// verbo (IR, TENER, VENIR, DAR) y el futuro próximo marcado. Lo que no
  /// cambia, se devuelve igual (misma instancia).
  static LsbTranslation apply(String text, LsbTranslation translation) {
    final dichas = {
      for (final w in _palabras(text))
        if (lemmas.containsKey(w)) w,
    };
    final futuro = diceFuturoProximo(text);
    if (dichas.isEmpty && !futuro) return translation;

    final glosses = _swapRuns(translation.glosses, null, dichas).$1;
    var (steps, urls) = _swapRuns(
      translation.animationGlosses,
      translation.animationUrls,
      dichas,
    );
    var finalGlosses = glosses;
    if (futuro) {
      finalGlosses = applyFuture(glosses, text);
      if (steps.isNotEmpty && steps.length == urls!.length) {
        final k = steps.indexOf('IR');
        if (k >= 0) {
          steps = [...steps]..removeAt(k);
          urls = [...urls]..removeAt(k);
        }
        if (!steps.contains('FUTURO')) {
          steps = ['FUTURO', ...steps];
          urls = [_resolver.resolveAll(gloss: 'FUTURO').first, ...urls];
        }
      }
    }
    final spelled = [
      for (final w in translation.spelledWords)
        if (!dichas.contains(_plain(w))) w,
    ];
    if (_igual(finalGlosses, translation.glosses) &&
        _igual(steps, translation.animationGlosses) &&
        spelled.length == translation.spelledWords.length) {
      return translation;
    }
    return LsbTranslation(
      glosses: finalGlosses,
      animationUrl: urls != null && urls.isNotEmpty
          ? urls.first
          : translation.animationUrl,
      animationUrls: urls ?? translation.animationUrls,
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

  /// Las letras sueltas que forman una de las [formas] (o la forma entera
  /// como un solo paso) pasan a su verbo. [urls] va en paralelo a [items].
  static (List<String>, List<String>?) _swapRuns(
    List<String> items,
    List<String>? urls,
    Set<String> formas,
  ) {
    if (formas.isEmpty) return (items, urls);
    final paralelo = urls != null && urls.length == items.length;
    final out = <String>[];
    final outUrls = <String>[];
    var i = 0;
    while (i < items.length) {
      String? forma;
      var largo = 0;
      for (final f in formas) {
        final n = f.length;
        if (n <= largo || i + n > items.length) continue;
        var calza = true;
        for (var k = 0; k < n && calza; k++) {
          calza = _plain(items[i + k]) == f[k];
        }
        if (calza && items.sublist(i, i + n).every((s) => s.length == 1)) {
          forma = f;
          largo = n;
        }
      }
      if (forma == null && formas.contains(_plain(items[i]))) {
        forma = _plain(items[i]);
        largo = 1;
      }
      if (forma == null) {
        out.add(items[i]);
        if (paralelo) outUrls.add(urls[i]);
        i++;
        continue;
      }
      final lema = lemmas[forma]!;
      out.add(lema);
      if (paralelo) outUrls.add(_resolver.resolveAll(gloss: lema).first);
      i += largo;
    }
    return (out, paralelo ? outUrls : urls);
  }

  static bool _igual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
