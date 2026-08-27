import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';
import 'package:lsb_legal_app/core/domain/repositories/audio_translation_repository.dart';

class CachingAudioTranslationRepository implements AudioTranslationRepository {
  final AudioTranslationRepository inner;
  final int maxEntries;

  final Map<String, LsbTranslation> _cache = {};

  CachingAudioTranslationRepository(this.inner, {this.maxEntries = 64});

  static String _keyOf(String text, String? situation) =>
      '${text.trim().toLowerCase()}|${situation ?? ''}';

  @override
  Future<LsbTranslation> translateText(String text, {String? situation}) async {
    final key = _keyOf(text, situation);
    final hit = _cache[key];
    if (hit != null) return hit;

    final translation = await inner.translateText(text, situation: situation);
    if (translation.glosses.isNotEmpty) {
      if (_cache.length >= maxEntries) _cache.remove(_cache.keys.first);
      _cache[key] = translation;
    }
    return translation;
  }
}
