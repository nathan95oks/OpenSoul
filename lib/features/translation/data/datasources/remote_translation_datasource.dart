import '../../domain/repositories/translation_repository.dart';

abstract class RemoteTranslationDataSource {
  Future<TranslationResult> translateCards({required String context, required List<String> cards});
}

class RemoteTranslationDataSourceImpl implements RemoteTranslationDataSource {

  @override
  Future<TranslationResult> translateCards({
    required String context,
    required List<String> cards,
  }) async {
    await Future.delayed(const Duration(seconds: 2)); // Simular latencia de red

    final generatedText = cards.join(" ");
    
    return TranslationResult(
      generatedText: generatedText,
    );
  }
}
