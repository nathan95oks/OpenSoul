import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';

/// Versión de la forma de la clave de caché. Súbela si cambia qué distingue
/// dos traducciones (p. ej. si se agrega un nuevo dato del que depende el
/// resultado) para que las entradas antiguas, con clave más corta, dejen de
/// coincidir en vez de servirse por error para una combinación distinta.
const _cacheKeyVersion = 'v2';

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

  @override
  Future<LsbTranslation> translateText(
    String text, {
    String? situation,
    Map<String, String>? resolvedSenses,
  }) async {
    final key = _keyOf(text, situation, resolvedSenses);
    final hit = _cache[key];
    if (hit != null) return hit;

    final translation = await inner.translateText(
      text,
      situation: situation,
      resolvedSenses: resolvedSenses,
    );
    // Una aclaración sin resolver todavía no es una traducción completa: no
    // se guarda como si lo fuera, para que la próxima consulta de la misma
    // frase vuelva a evaluarse (y pueda, por ejemplo, encontrar evidencia de
    // contexto nueva) en vez de repetir la misma pregunta pendiente desde la
    // caché indefinidamente disfrazada de resultado estable.
    if (translation.glosses.isNotEmpty && !translation.needsClarification) {
      if (_cache.length >= maxEntries) _cache.remove(_cache.keys.first);
      _cache[key] = translation;
    }
    return translation;
  }
}
