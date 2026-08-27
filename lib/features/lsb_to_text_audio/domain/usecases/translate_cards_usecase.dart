import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

class TranslateCardsUseCase {
  final TranslationRepository repository;

  TranslateCardsUseCase(this.repository);

  Future<TranslationResult> call({
    required String context,
    required List<String> cards,
  }) {
    return repository.translateCards(
      context: context,
      cards: cards,
    );
  }
}
