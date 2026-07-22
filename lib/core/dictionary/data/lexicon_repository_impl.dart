import '../../domain/entities/lsb_card.dart';
import '../domain/dictionary_document.dart';
import '../domain/lexicon_repository.dart';
import 'asset_lexicon_datasource.dart';
import 'lexicon_cache.dart';
import 'remote_lexicon_datasource.dart';

/// Implementación offline-first del diccionario evolutivo.
///
/// Resolución del documento activo:
///   1. Memoria (memoizado tras la primera carga).
///   2. Caché en disco de la última sincronización, si su versión supera
///      a la del asset empaquetado.
///   3. Asset empaquetado (siempre disponible).
///
/// En la primera carga dispara [refresh] en segundo plano: si el backend
/// publica una versión más nueva (palabras aprobadas en el portal), se
/// persiste en caché y queda activa sin intervención de desarrolladores.
class LexiconRepositoryImpl implements LexiconRepository {
  final AssetLexiconDataSource assetDataSource;
  final RemoteLexiconDataSource remoteDataSource;
  final LexiconCache cache;

  DictionaryDocument? _active;
  Future<DictionaryDocument>? _loading;
  bool _backgroundRefreshStarted = false;

  LexiconRepositoryImpl({
    required this.assetDataSource,
    required this.remoteDataSource,
    required this.cache,
  });

  @override
  Future<DictionaryDocument> getDocument() {
    final active = _active;
    if (active != null) return Future.value(active);
    return _loading ??= _loadLocal();
  }

  Future<DictionaryDocument> _loadLocal() async {
    final asset = await assetDataSource.load();
    final cached = await cache.read();
    _active = (cached != null && cached.version > asset.version)
        ? cached
        : asset;

    // Primer arranque de la sesión: buscar novedades sin bloquear la UI.
    if (!_backgroundRefreshStarted) {
      _backgroundRefreshStarted = true;
      // ignore: unawaited_futures
      refresh();
    }
    return _active!;
  }

  @override
  Future<List<LsbCard>> getEntries() async =>
      (await getDocument()).visibleEntries;

  @override
  Future<List<String>> getCategories() async {
    final doc = await getDocument();
    final present = doc.visibleEntries.map((e) => e.categoryId).toSet();
    final ordered =
        doc.categoryOrder.where(present.contains).toList(growable: true);
    // Categorías nuevas llegadas por sincronización que aún no figuran en
    // el orden declarado: se anexan al final en vez de perderse.
    for (final cat in present) {
      if (!ordered.contains(cat)) ordered.add(cat);
    }
    return ordered;
  }

  @override
  Future<bool> refresh() async {
    if (!remoteDataSource.isConfigured) return false;
    try {
      final current = await getDocument();
      final remote = await remoteDataSource.fetch();
      if (remote.version <= current.version) return false;
      await cache.write(remote);
      _active = remote;
      return true;
    } catch (_) {
      // Sin red o backend caído: el diccionario local sigue vigente.
      return false;
    }
  }
}
