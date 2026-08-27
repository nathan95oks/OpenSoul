import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

abstract class TranslationRepository {
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  });
}
