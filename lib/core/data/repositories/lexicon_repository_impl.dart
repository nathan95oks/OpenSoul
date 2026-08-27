import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/entities/dictionary_document.dart';
import 'package:lsb_legal_app/core/domain/repositories/lexicon_repository.dart';
import 'package:lsb_legal_app/core/data/datasources/asset_lexicon_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/lexicon_local_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_lexicon_datasource.dart';

class LexiconRepositoryImpl implements LexiconRepository {
  final AssetLexiconDataSource assetDataSource;
  final RemoteLexiconDataSource remoteDataSource;
  final LexiconLocalDataSource localDataSource;

  DictionaryDocument? _active;
  Future<DictionaryDocument>? _loading;
  bool _backgroundRefreshStarted = false;

  LexiconRepositoryImpl({
    required this.assetDataSource,
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<DictionaryDocument> getDocument() {
    final active = _active;
    if (active != null) return Future.value(active);
    return _loading ??= _loadLocal();
  }

  Future<DictionaryDocument> _loadLocal() async {
    final asset = await assetDataSource.load();
    final cached = await localDataSource.read();
    _active = (cached != null && cached.version > asset.version)
        ? cached
        : asset;

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
      await localDataSource.write(remote);
      _active = remote;
      return true;
    } catch (_) {
      return false;
    }
  }
}
