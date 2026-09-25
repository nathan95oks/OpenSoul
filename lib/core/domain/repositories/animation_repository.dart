abstract class AnimationRepository {
  Future<List<String>> playableSources(List<String> animationUrls);
  Future<bool> isCached(String url);
  Future<void> precacheDefaultModel();
}
