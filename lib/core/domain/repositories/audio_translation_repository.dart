import 'package:lsb_legal_app/core/domain/entities/lsb_translation.dart';

abstract class AudioTranslationRepository {
  Future<LsbTranslation> translateText(String text, {String? situation});
}
