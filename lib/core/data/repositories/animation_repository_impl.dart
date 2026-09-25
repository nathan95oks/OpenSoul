import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:lsb_legal_app/core/data/datasources/animation_cache.dart';
import 'package:lsb_legal_app/core/domain/repositories/animation_repository.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

class AnimationRepositoryImpl implements AnimationRepository {
  final AnimationCache cache;
  final Future<Directory> Function() temporaryDirectory;

  AnimationRepositoryImpl({
    AnimationCache? cache,
    Future<Directory> Function()? temporaryDirectory,
  })  : cache = cache ?? AnimationCache(),
        temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  @override
  Future<List<String>> playableSources(List<String> animationUrls) async {
    if (animationUrls.isEmpty) return const [];

    final directory = await temporaryDirectory();
    final sources = <String>[];
    final resolvedMap = <String, String>{};

    for (final url in animationUrls) {
      if (url.startsWith(AnimationUrlResolver.placeholderScheme)) {
        sources.add(url);
        continue;
      }
      if (resolvedMap.containsKey(url)) {
        sources.add(resolvedMap[url]!);
        continue;
      }
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
    final directory = await temporaryDirectory();
    return cache.isCached(url, directory);
  }

  @override
  Future<void> precacheDefaultModel() async {
    final base = AnimationUrlResolver.defaultBaseUrl;
    if (base.isEmpty) return;
    final modelUrl = '${base}avatar_test.glb';
    try {
      final directory = await temporaryDirectory();
      await cache.localPathFor(modelUrl, directory);
    } catch (_) {
      // Ignorar si no hay conexión al arrancar; se reintentará en demanda
    }
  }
}
