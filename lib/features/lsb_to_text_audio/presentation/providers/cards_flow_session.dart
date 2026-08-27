import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/card_grid.dart' show expandedAnswersProvider;
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';

class CardsFlowSession {
  final Ref ref;

  const CardsFlowSession(this.ref);

  Future<void> reset({bool keepContext = false}) async {
    await ref.read(translationControllerProvider.notifier).reset();
    if (!keepContext) ref.read(contextProvider.notifier).clearContext();
    ref.read(sentenceProvider.notifier).clearSentence();
    ref.read(semanticZonesProvider.notifier).reset();
    ref.read(expandedAnswersProvider.notifier).collapse();
    ref.read(currentCategoryProvider.notifier).setCategory(kSuggestionsCategory);
  }
}

final cardsFlowSessionProvider =
    Provider<CardsFlowSession>(CardsFlowSession.new);
