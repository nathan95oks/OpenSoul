import '../../domain/entities/lsb_translation.dart';
import '../../domain/repositories/audio_translation_repository.dart';

/// Memoria de las frases ya traducidas a señas en esta sesión.
///
/// Una toma de declaración no es una conversación cualquiera: el mismo
/// funcionario repite las mismas preguntas —«¿me da su nombre?», «¿dónde
/// ocurrió?», «¿recuerda la hora?»— con cada persona y varias veces con la
/// misma. Hoy cada repetición vuelve a pagar el viaje completo a Bedrock:
/// uno o dos segundos de espera para producir, palabra por palabra, la misma
/// secuencia de glosas que la vez anterior.
///
/// Decorador, no un `if` dentro del repositorio: la caché es una decisión de
/// composición, y así el repositorio real sigue siendo el que traduce y este
/// el que recuerda. El backend ya calcula la misma clave
/// (`generate_cache_key` en `lambda_text_to_lsb.py`), pero su caché en
/// DynamoDB está declarada como trabajo futuro; mientras tanto, esta ahorra
/// el viaje entero, no solo la invocación del modelo.
class CachingAudioTranslationRepository implements AudioTranslationRepository {
  final AudioTranslationRepository inner;

  /// Tope de entradas. Una conversación real no pasa de unas decenas de
  /// frases distintas; el tope solo evita que una sesión larguísima crezca
  /// sin control.
  final int maxEntries;

  final Map<String, LsbTranslation> _cache = {};

  CachingAudioTranslationRepository(this.inner, {this.maxEntries = 64});

  /// La situación forma parte de la clave porque forma parte del resultado:
  /// la misma frase bajo 'denuncia_robo' y bajo 'violencia' puede producir
  /// glosas distintas, y servir una por la otra sería devolver la traducción
  /// de otra conversación.
  static String _keyOf(String text, String? situation) =>
      '${text.trim().toLowerCase()}|${situation ?? ''}';

  @override
  Future<LsbTranslation> translateText(String text, {String? situation}) async {
    final key = _keyOf(text, situation);
    final hit = _cache[key];
    if (hit != null) return hit;

    final translation = await inner.translateText(text, situation: situation);
    // Solo se recuerdan las traducciones útiles: una respuesta sin glosas
    // suele ser un fallo del modelo, y cachearla congelaría el error para el
    // resto de la sesión.
    if (translation.glosses.isNotEmpty) {
      if (_cache.length >= maxEntries) _cache.remove(_cache.keys.first);
      _cache[key] = translation;
    }
    return translation;
  }

  @override
  Future<LsbTranslation> translateAudio(String audioPath) =>
      inner.translateAudio(audioPath);
}
