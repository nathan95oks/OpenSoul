import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

class AnimationCache {
  final Set<String> allowedHosts;
  final int maxBytes;
  final Duration timeout;
  final http.Client client;

  final void Function(String url, String reason)? onRejected;

  AnimationCache({
    http.Client? client,
    Set<String>? allowedHosts,
    this.maxBytes = 12 * 1024 * 1024,
    this.timeout = const Duration(seconds: 20),
    this.onRejected,
  })  : client = client ?? http.Client(),
        allowedHosts = allowedHosts ?? defaultAllowedHosts();

  static Set<String> defaultAllowedHosts() {
    final host = Uri.tryParse(AnimationUrlResolver.defaultBaseUrl)?.host;
    return {if (host != null && host.isNotEmpty) host};
  }

  static String fileNameFor(String url) =>
      '${sha256.convert(utf8.encode(url))}.glb';

  bool isAllowed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    if (uri.host.isEmpty || !allowedHosts.contains(uri.host)) return false;
    return true;
  }

  Future<String?> localPathFor(String url, Directory directory) async {
    if (!isAllowed(url)) {
      onRejected?.call(url, 'origen no permitido');
      return null;
    }

    final file = File('${directory.path}/${fileNameFor(url)}');

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
