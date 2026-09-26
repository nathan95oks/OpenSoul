import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:lsb_legal_app/core/data/datasources/animation_cache.dart';
import 'package:lsb_legal_app/core/domain/repositories/animation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

class AnimationRepositoryImpl implements AnimationRepository {
  final AnimationCache cache;
  final Future<Directory> Function() cacheDirectory;

  AnimationRepositoryImpl({
    AnimationCache? cache,
    Future<Directory> Function()? cacheDirectory,
    @Deprecated('Usa cacheDirectory')
    Future<Directory> Function()? temporaryDirectory,
  }) : cache = cache ?? AnimationCache(),
       cacheDirectory =
           cacheDirectory ??
           temporaryDirectory ??
           _persistentAnimationDirectory;

  static Future<Directory> _persistentAnimationDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}animations',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  bool _isBundledModel(String source) {
    if (source == AnimationUrlResolver.bundledModelAsset ||
        source == AnimationUrlResolver.bundledModelFileName) {
      return true;
    }
    final uri = Uri.tryParse(source);
    return uri != null &&
        cache.isAllowed(source) &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.last == AnimationUrlResolver.bundledModelFileName;
  }

  @override
  Future<List<String>> playableSources(List<String> animationUrls) async {
    if (animationUrls.isEmpty) return const [];

    final sources = <String>[];
    final resolvedMap = <String, String>{};
    Directory? directory;

    for (final url in animationUrls) {
      if (url.startsWith(AnimationUrlResolver.placeholderScheme)) {
        sources.add(url);
        continue;
      }
      if (_isBundledModel(url)) {
        sources.add(AnimationUrlResolver.bundledModelAsset);
        continue;
      }
      if (resolvedMap.containsKey(url)) {
        sources.add(resolvedMap[url]!);
        continue;
      }
      directory ??= await cacheDirectory();
      final localPath = await cache.localPathFor(url, directory);
      String resolved;
      if (localPath != null) {
        resolved = 'file://$localPath';
      } else if (cache.isAllowed(url)) {
        resolved = url;
      } else {
        resolved = '${AnimationUrlResolver.placeholderScheme}$url';
      }
      resolvedMap[url] = resolved;
      sources.add(resolved);
    }
    return sources;
  }

  @override
  Future<bool> isCached(String url) async {
    if (_isBundledModel(url)) return true;
    final directory = await cacheDirectory();
    return cache.isCached(url, directory);
  }

  @override
  Future<void> precacheDefaultModel() async {
    // El modelo predeterminado forma parte del paquete de instalación. Copiarlo
    // a otra carpeta duplicaría casi 20 MB sin mejorar el tiempo de carga.
  }
}
