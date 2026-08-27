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

    for (final url in animationUrls) {
      if (url.startsWith(AnimationUrlResolver.placeholderScheme)) {
        sources.add(url);
        continue;
      }
      final localPath = await cache.localPathFor(url, directory);
      if (localPath != null) {
        sources.add('file://$localPath');
      } else if (cache.isAllowed(url)) {
        sources.add(url);
      } else {
        sources.add('${AnimationUrlResolver.placeholderScheme}$url');
      }
    }
    return sources;
  }
}
