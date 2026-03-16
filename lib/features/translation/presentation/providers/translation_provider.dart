import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/translation/data/datasources/remote_translation_datasource.dart';
import 'package:lsb_legal_app/features/translation/data/repositories/translation_repository_impl.dart';
import 'package:lsb_legal_app/features/translation/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/features/translation/domain/usecases/translate_cards_usecase.dart';

final remoteTranslationDataSourceProvider = Provider<RemoteTranslationDataSource>((ref) {
  return RemoteTranslationDataSourceImpl();
});

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  final dataSource = ref.watch(remoteTranslationDataSourceProvider);
  return TranslationRepositoryImpl(dataSource);
});

final translateCardsUseCaseProvider = Provider<TranslateCardsUseCase>((ref) {
  final repository = ref.watch(translationRepositoryProvider);
  return TranslateCardsUseCase(repository);
});
