import '../../domain/repositories/translation_repository.dart';
import '../datasources/remote_translation_datasource.dart';

class TranslationRepositoryImpl implements TranslationRepository {
  final RemoteTranslationDataSource remoteDataSource;

  TranslationRepositoryImpl(this.remoteDataSource);

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  }) async {
    return await remoteDataSource.translateCards(context: context, cards: cards);
  }
}
