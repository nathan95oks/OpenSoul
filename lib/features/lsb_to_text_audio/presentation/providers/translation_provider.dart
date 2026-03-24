import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:lsb_legal_app/features/lsb_to_text_audio/data/datasources/remote_translation_datasource.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/repositories/translation_repository_impl.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/translate_cards_usecase.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

final remoteTranslationDataSourceProvider = Provider<RemoteTranslationDataSource>((ref) {
  final client = ref.watch(httpClientProvider);
  return RemoteTranslationDataSourceImpl(client: client);
});

final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  final dataSource = ref.watch(remoteTranslationDataSourceProvider);
  return TranslationRepositoryImpl(dataSource);
});

final translateCardsUseCaseProvider = Provider<TranslateCardsUseCase>((ref) {
  final repository = ref.watch(translationRepositoryProvider);
  return TranslateCardsUseCase(repository);
});
