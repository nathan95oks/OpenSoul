import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/local_audio_translator.dart';
import 'package:lsb_legal_app/core/domain/services/verb_forms.dart';

/// Versión de la forma de la clave de caché. Súbela si cambia qué distingue
/// dos traducciones (p. ej. si se agrega un nuevo dato del que depende el
/// resultado) para que las entradas antiguas, con clave más corta, dejen de
/// coincidir en vez de servirse por error para una combinación distinta.
///
/// v4: la traducción trae datos nuevos (palabras deletreadas, señas sin
/// animación). Una traducción guardada antes, sin ellos, no se puede servir:
/// al leerlos daba `type 'Null' is not a subtype of type 'List<String>'`.
const _cacheKeyVersion = 'v4';

class CachingAudioTranslationRepository implements AudioTranslationRepository {
  final AudioTranslationRepository inner;
  final int maxEntries;

  final Map<String, LsbTranslation> _cache = {};

  CachingAudioTranslationRepository(this.inner, {this.maxEntries = 64});

  // El sentido ya elegido para un término ambiguo ("AUTO": "vehiculo") forma
  // parte de la clave por la misma razón que la situación: la misma frase con
  // un sentido resuelto distinto es un resultado distinto, y sin esto una
  // reformulación con "auto" = vehículo podía servirse desde la caché de
  // "auto" = resolución de otra conversación (o de la misma, antes de elegir).
  static String _keyOf(
    String text,
    String? situation,
    Map<String, String>? resolvedSenses,
  ) {
    final sensesPart = (resolvedSenses == null || resolvedSenses.isEmpty)
        ? ''
        : (resolvedSenses.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
            .map((e) => '${e.key}=${e.value}')
            .join(',');
    return '$_cacheKeyVersion|${text.trim().toLowerCase()}|${situation ?? ''}|$sensesPart';
  }

  static final LocalAudioTranslator _localTranslator = const LocalAudioTranslator();

  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async {
    final key = _keyOf(text, situation, resolvedSenses);
    final hit = _cache[key];
    if (hit != null) return hit;

    try {
      // «va», «tiene», «da»… que el servidor dejó deletreadas vuelven a su
      // verbo (IR, TENER, DAR): tienen seña.
      final translation = VerbForms.apply(
        text,
        await inner.translateText(
          text,
          situation: situation,
          resolvedSenses: resolvedSenses,
        ),
      );
      if (translation.glosses.isNotEmpty && !translation.needsClarification) {
        if (_cache.length >= maxEntries) _cache.remove(_cache.keys.first);
        _cache[key] = translation;
      }
      return translation;
    } catch (networkError) {
      // MODO SIN CONEXIÓN (OFFLINE FALLBACK):
      // Si la conexión a AWS Lambda falla o el dispositivo está en Modo Avión,
      // se ejecuta el motor local en Dart usando el léxico y las 200 señas del avatar.
      final fallback = _localTranslator.translate(text, situation: situation);
      if (fallback.glosses.isNotEmpty) {
        return fallback;
      }
      rethrow;
    }
  }
}
