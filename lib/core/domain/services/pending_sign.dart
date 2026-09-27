/// Una palabra sin seña en el catálogo del avatar.
///
/// El corpus RAG la trae como `SENA_PENDIENTE:FOLIO_REAL` en lugar del
/// deletreo que devolvía la Lambda (F-O-L-I-O…): deletrear una palabra común
/// no es LSB, es una seña que falta. Se muestra como «seña a incorporar» y el
/// avatar no la inventa. Las siglas (NUREJ, CRPVA) sí se deletrean y no llegan
/// con esta marca. La misma constante está en `tool/build_rag_corpus.py`.
abstract final class PendingSign {
  static const String prefix = 'SENA_PENDIENTE:';

  /// Lo que se muestra en lugar de la seña.
  static const String label = 'Seña a incorporar';

  /// Lo que dice el avatar cuando llega a esa palabra.
  static const String avatarLabel = 'En espera para su avatar';

  static bool isPending(String gloss) => gloss.startsWith(prefix);

  /// La palabra en español: `SENA_PENDIENTE:FOLIO_REAL` → `FOLIO REAL`.
  static String wordOf(String gloss) =>
      gloss.substring(prefix.length).replaceAll('_', ' ');
}
