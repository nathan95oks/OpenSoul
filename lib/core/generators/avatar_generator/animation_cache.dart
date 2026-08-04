import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'animation_url_resolver.dart';

/// Descarga y cachea en disco las animaciones del avatar.
///
/// ## Por qué esta clase existe
///
/// Antes el visor derivaba el nombre del archivo local del **propio URL**:
///
/// ```dart
/// final fileName = Uri.parse(urlStr).pathSegments.last;
/// await File('${tempDir.path}/$fileName').writeAsBytes(bytes);
/// ```
///
/// `Uri.pathSegments` **decodifica** el porcentaje, así que un segmento
/// `..%2F..%2Fapp_flutter%2Fdictionary_cache.json` se convierte en el string
/// `../../app_flutter/dictionary_cache.json` y la escritura se sale del
/// directorio de caché. Como el `animationFile` que forma ese URL viaja en la
/// respuesta del backend y en el diccionario remoto, un endpoint comprometido
/// —o un atacante en la red, porque no hay pinning de certificado— podía
/// escribir archivos arbitrarios dentro del sandbox de la app, incluida la
/// caché del diccionario, que se lee en el arranque siguiente.
///
/// La regla que lo cierra: **un nombre que viene de la red nunca decide dónde
/// se escribe**. El nombre local se deriva de un hash del URL, así que es
/// siempre un hexadecimal de longitud fija; el contenido de la ruta remota no
/// participa en la construcción del path. Alrededor hay defensa en
/// profundidad: allowlist de esquema y host, tope de tamaño, timeout y
/// verificación final de que el path resuelto sigue dentro del directorio.
class AnimationCache {
  /// Solo se descarga de los hosts declarados. Se deriva del `baseUrl` del
  /// resolutor, de modo que `--dart-define=LSB_ANIMATIONS_BASE_URL` sigue
  /// funcionando sin abrir la política a cualquier destino.
  final Set<String> allowedHosts;

  /// Tope por archivo. Una animación real ronda cientos de KB; el tope evita
  /// que un host comprometido llene el disco del dispositivo.
  final int maxBytes;

  final Duration timeout;

  final http.Client client;

  /// Se invoca con cada URL rechazada. Existe para que un intento de ataque
  /// deje rastro en vez de degradarse en silencio.
  final void Function(String url, String reason)? onRejected;

  AnimationCache({
    http.Client? client,
    Set<String>? allowedHosts,
    this.maxBytes = 12 * 1024 * 1024,
    this.timeout = const Duration(seconds: 20),
    this.onRejected,
  })  : client = client ?? http.Client(),
        allowedHosts = allowedHosts ?? defaultAllowedHosts();

  /// Host del bucket configurado en compilación.
  static Set<String> defaultAllowedHosts() {
    final host = Uri.tryParse(AnimationUrlResolver.defaultBaseUrl)?.host;
    return {if (host != null && host.isNotEmpty) host};
  }

  /// Nombre local de [url]: hash hexadecimal, jamás la ruta remota.
  ///
  /// Además de cerrar el path traversal, elimina una colisión real que había:
  /// `bucket/a/ROBAR.glb` y `bucket/b/ROBAR.glb` compartían archivo local y se
  /// servían el uno por el otro.
  static String fileNameFor(String url) =>
      '${sha256.convert(utf8.encode(url))}.glb';

  /// `true` si [url] es descargable según la política.
  bool isAllowed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    // https únicamente: sin esto un endpoint comprometido puede degradar a
    // http y exponer la descarga a manipulación en la red.
    if (uri.scheme != 'https') return false;
    if (uri.host.isEmpty || !allowedHosts.contains(uri.host)) return false;
    return true;
  }

  /// Ruta local del archivo de [url] dentro de [directory], descargándolo si
  /// hace falta. Devuelve `null` si la política lo rechaza o la descarga
  /// falla: el visor ya sabe caer al URL remoto o al placeholder.
  Future<String?> localPathFor(String url, Directory directory) async {
    if (!isAllowed(url)) {
      onRejected?.call(url, 'origen no permitido');
      return null;
    }

    final file = File('${directory.path}/${fileNameFor(url)}');

    // Cinturón y tirantes: aunque el nombre ya es un hash, se comprueba que
    // el path resuelto no salga del directorio. Si alguna vez alguien cambia
    // `fileNameFor`, esta línea sigue sosteniendo la garantía.
    if (!_isInside(directory, file)) {
      onRejected?.call(url, 'ruta fuera del directorio de caché');
      return null;
    }

    if (await file.exists()) return file.path;

    try {
      final response =
          await client.get(Uri.parse(url)).timeout(timeout);
      if (response.statusCode != 200) {
        onRejected?.call(url, 'HTTP ${response.statusCode}');
        return null;
      }
      if (response.bodyBytes.length > maxBytes) {
        onRejected?.call(url, 'excede ${maxBytes ~/ 1024} KB');
        return null;
      }
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (e) {
      onRejected?.call(url, 'descarga fallida');
      return null;
    }
  }

  static bool _isInside(Directory directory, File file) {
    final base = _normalize(directory.path);
    final target = _normalize(file.path);
    return target.startsWith(base.endsWith('/') ? base : '$base/');
  }

  static String _normalize(String path) =>
      Uri.file(path).normalizePath().toFilePath();
}
