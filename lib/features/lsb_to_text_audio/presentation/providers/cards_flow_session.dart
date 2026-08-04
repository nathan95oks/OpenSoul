import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/translation_controller.dart';
import '../widgets/card_grid.dart' show expandedAnswersProvider;
import 'cards_provider.dart';
import 'context_provider.dart';
import 'semantic_zones_provider.dart';
import 'sentence_provider.dart';

/// Sesión del flujo de tarjetas: sabe dejarlo como recién abierto.
///
/// La secuencia de limpieza estaba copiada en tres pantallas ("Cambiar
/// contexto", "Nueva declaración", "Enviar a la conversación") y cada copia
/// olvidaba algo distinto —ninguna reponía la categoría del filtro avanzado—.
/// Al no existir una sola operación de "empezar limpio", tampoco había forma
/// de invocarla al cambiar de superficie, que es justo cuando más falta hace.
class CardsFlowSession {
  final Ref ref;

  const CardsFlowSession(this.ref);

  /// Descarta declaración, contexto, recorrido y filtros.
  ///
  /// [keepContext] conserva el contexto situacional: lo usa "Nueva
  /// declaración", que empieza otro relato **dentro del mismo trámite** y no
  /// debe obligar a volver a elegirlo.
  Future<void> reset({bool keepContext = false}) async {
    // Primero el audio: detiene una locución en curso antes de que
    // desaparezca el texto que la originó.
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
