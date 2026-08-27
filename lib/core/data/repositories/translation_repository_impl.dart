import 'package:lsb_legal_app/core/domain/repositories/translation_repository.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_translation_datasource.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

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
