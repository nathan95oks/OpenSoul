import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/repositories/cards_repository_impl.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/cards_repository.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/sign_image_resolver.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/get_cards_by_category_usecase.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/get_categories_usecase.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/suggest_next_step_usecase.dart';

final cardsRepositoryProvider = Provider<CardsRepository>((ref) {
  return CardsRepositoryImpl(ref.watch(lexiconRepositoryProvider));
});

final getCategoriesUseCaseProvider = Provider<GetCategoriesUseCase>((ref) {
  return GetCategoriesUseCase(ref.watch(cardsRepositoryProvider));
});

final getCardsByCategoryUseCaseProvider =
    Provider<GetCardsByCategoryUseCase>((ref) {
  return GetCardsByCategoryUseCase(ref.watch(cardsRepositoryProvider));
});

final suggestNextStepUseCaseProvider = Provider<SuggestNextStepUseCase>((ref) {
  return SuggestNextStepUseCase(ref.watch(suggestionRepositoryProvider));
});

final signImageResolverProvider = Provider<SignImageResolver>(
  (ref) => const SignImageResolver(),
);
