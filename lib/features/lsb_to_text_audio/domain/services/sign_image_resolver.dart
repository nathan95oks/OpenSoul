import 'package:lsb_legal_app/core/domain/text/spanish_text.dart';

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
    final normalizada = SpanishText.stripAccents(
      gloss.trim().toUpperCase(),
      foldEnye: true,
    ).replaceAll(' ', '_');
    return _admitido.hasMatch(normalizada) ? normalizada : null;
  }
}
