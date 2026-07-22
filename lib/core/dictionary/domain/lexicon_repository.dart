import '../../domain/entities/lsb_card.dart';
import 'dictionary_document.dart';
import 'dictionary_proposal.dart';

/// Puerto del diccionario evolutivo LSB.
///
/// Única fuente de vocabulario para toda la aplicación (ambas direcciones
/// de la conversación). La implementación resuelve el origen con política
/// offline-first: caché de la última sincronización → asset empaquetado,
/// con refresco remoto en segundo plano.
abstract class LexiconRepository {
  /// Documento activo del diccionario (memoizado).
  Future<DictionaryDocument> getDocument();

  /// Entradas visibles (oficiales + comunitarias), sin propuestas pendientes.
  Future<List<LsbCard>> getEntries();

  /// Categorías presentes, en el orden semántico definido por el documento.
  Future<List<String>> getCategories();

  /// Intenta sincronizar con el diccionario remoto. Devuelve `true` si se
  /// aplicó una versión más nueva. Nunca lanza: sin red, el diccionario
  /// local sigue siendo válido. También reintenta el envío de propuestas
  /// encoladas offline.
  Future<bool> refresh();

  /// Envía una propuesta de la comunidad al backend (queda `pending`).
  /// Sin conexión, la encola en disco y la reenviará en la próxima
  /// sincronización. Nunca lanza: el desenlace viaja en el resultado.
  Future<ProposalSubmissionResult> submitProposal(DictionaryProposal proposal);
}
