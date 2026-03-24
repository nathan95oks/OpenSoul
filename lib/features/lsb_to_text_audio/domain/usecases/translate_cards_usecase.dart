import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/translation_repository.dart';

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
