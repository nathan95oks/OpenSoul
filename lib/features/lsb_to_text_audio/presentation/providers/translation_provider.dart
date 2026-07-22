import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/di/core_providers.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/usecases/translate_cards_usecase.dart';

/// La cadena http → datasource → repositorio vive ahora en el núcleo
/// compartido (`core/di`), común a ambas direcciones de la conversación.
/// Se re-exporta para no romper a los consumidores existentes (tests
/// incluidos), que siguen sobrescribiendo estos mismos providers.
export 'package:lsb_legal_app/core/di/core_providers.dart'
    show
        httpClientProvider,
        remoteTranslationDataSourceProvider,
        translationRepositoryProvider;

final translateCardsUseCaseProvider = Provider<TranslateCardsUseCase>((ref) {
  final repository = ref.watch(translationRepositoryProvider);
  return TranslateCardsUseCase(repository);
});
