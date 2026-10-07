import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/case_search.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';

/// El índice del buscador: familias, instituciones y casos, con lo que se
/// pregunta y responde en cada uno. Se arma una vez.
final caseSearchProvider = Provider<CaseSearch>(
  (ref) => CaseSearch.fromCatalog(ref.watch(questionBankProvider)),
);

/// Lo que la persona escribió en el buscador. Vive fuera de la pantalla:
/// al entrar a un caso y volver con la flecha, la búsqueda sigue ahí para
/// corregirla.
class CaseSearchQueryNotifier extends Notifier<String> {
  /// Largo máximo de una búsqueda.
  static const maxLength = 60;

  @override
  String build() => '';

  void set(String query) => state = query;

  void clear() => state = '';
}

final caseSearchQueryProvider =
    NotifierProvider<CaseSearchQueryNotifier, String>(
      CaseSearchQueryNotifier.new,
    );

/// Los resultados de la búsqueda actual, agrupados.
final caseSearchResultsProvider = Provider<List<CaseSearchGroup>>(
  (ref) =>
      ref.watch(caseSearchProvider).search(ref.watch(caseSearchQueryProvider)),
);
