class SignImageResolver {
  static const String defaultBaseUrl =
      String.fromEnvironment('LSB_SIGN_IMAGES_BASE_URL');

  final String baseUrl;

  const SignImageResolver({this.baseUrl = defaultBaseUrl});

  bool get isConfigured {
    final uri = Uri.tryParse(baseUrl);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  String? urlFor(String gloss) => urlsFor(gloss).firstOrNull;

  List<String> urlsFor(String gloss, {int frames = 1}) {
    if (!isConfigured) return const [];
    final safe = _sanitize(gloss);
    if (safe == null || safe.isEmpty) return const [];
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    if (frames <= 1) return ['$base$safe.png'];
    return [for (var i = 1; i <= frames; i++) '$base${safe}_$i.png'];
  }

  static final RegExp _admitido = RegExp(r'^[A-Z0-9_-]+$');

  static String? _sanitize(String gloss) {
    const equivalencias = {
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N',
    };
    var normalizada = gloss.trim().toUpperCase();
    equivalencias.forEach((con, sin) => normalizada = normalizada.replaceAll(con, sin));
    normalizada = normalizada.replaceAll(' ', '_');
    return _admitido.hasMatch(normalizada) ? normalizada : null;
  }
}
