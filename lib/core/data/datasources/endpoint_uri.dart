/// Validación de los endpoints configurados en compilación (`--dart-define`).
///
/// Vive aparte de los datasources porque los dos sentidos de traducción —y el
/// resolutor de animaciones— comparten el mismo modo de fallo: una variable
/// definida pero vacía anula el `defaultValue` de `String.fromEnvironment`, y
/// el `ArgumentError` resultante («No host specified in URI») aparece dentro
/// del `try` de la petición, disfrazado de error de red.
library;

/// Devuelve [url] como [Uri] absoluto, o lanza [StateError] describiendo qué
/// `--dart-define` hay que revisar.
///
/// Debe invocarse **fuera** del `try` que captura los fallos de red: un
/// endpoint mal configurado es un error de compilación, no de conectividad, y
/// mezclarlos desvía el diagnóstico hacia la nube.
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
