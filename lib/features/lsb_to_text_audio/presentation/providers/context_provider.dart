import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';

export 'package:lsb_legal_app/core/domain/services/context_catalog.dart';

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

final contextProvider = NotifierProvider<ContextNotifier, SemanticContext?>(
  ContextNotifier.new,
);

/// La familia de contextos que la persona abrió en la selección (Denuncias,
/// Trámites…). Al volver de uno de sus contextos con la flecha, la selección
/// reabre esa lista en vez del menú principal. «Volver» de la lista la olvida.
class OpenFamilyNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String familyId) => state = familyId;

  void clear() => state = null;
}

final openFamilyProvider = NotifierProvider<OpenFamilyNotifier, String?>(
  OpenFamilyNotifier.new,
);
