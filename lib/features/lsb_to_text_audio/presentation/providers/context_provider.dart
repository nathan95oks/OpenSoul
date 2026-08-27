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

final contextProvider =
    NotifierProvider<ContextNotifier, SemanticContext?>(ContextNotifier.new);
