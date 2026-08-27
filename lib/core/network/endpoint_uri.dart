Uri requireAbsoluteUrl(String url, String defineName) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw StateError(
      'Endpoint inválido: "$url". Revisa --dart-define=$defineName '
      '(no puede quedar vacío ni ser una ruta relativa).',
    );
  }
  return uri;
}
