import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';

/// El catálogo de contextos situacionales vive en el núcleo
/// ([context_catalog.dart]) desde la Fase 4: el `ContextInferenceEngine`
/// necesita conocerlo y un motor del núcleo no puede depender de la capa
/// de presentación de un feature.
///
/// Se re-exporta desde su ubicación histórica —mismo patrón que la Fase 1—
/// para que los consumidores existentes de `availableContexts`,
/// `cardSourceContexts` y `resolveAssemblerContext` no cambien.
export 'package:lsb_legal_app/core/engines/context_engine/context_catalog.dart';

class ContextNotifier extends Notifier<SemanticContext?> {
  @override
  SemanticContext? build() => null;

  void setContext(SemanticContext context) {
    state = context;
  }

  void clearContext() {
    state = null;
  }
}

final contextProvider =
    NotifierProvider<ContextNotifier, SemanticContext?>(ContextNotifier.new);
