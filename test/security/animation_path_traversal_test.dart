import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lsb_legal_app/core/generators/avatar_generator/animation_cache.dart';
import 'package:lsb_legal_app/core/generators/avatar_generator/animation_url_resolver.dart';

/// Regresión del path traversal en la caché de animaciones.
///
/// El visor derivaba el nombre del archivo local de `Uri.pathSegments.last`.
/// Como `pathSegments` **decodifica** el porcentaje, un `animationFile` con
/// `%2F` producía un "nombre" que en realidad era una ruta relativa, y la
/// escritura se salía del directorio de caché hacia el resto del sandbox
/// —incluida `dictionary_cache.json`, que se lee en el arranque siguiente—.
///
/// El `animationFile` llega en la respuesta del backend y en el diccionario
/// remoto: es entrada no confiable.
///
/// Cada prueba ejecuta el payload original contra el código parcheado y pasa
/// solo si el ataque queda bloqueado.
void main() {
  const bucket = 'https://opensoul-3d-animations.s3.us-east-1.amazonaws.com/';

  /// Payloads de la fase de explotación, tal cual.
  const traversalPayloads = <String>[
    '..%2F..%2Fapp_flutter%2Fdictionary_cache.json',
    '%2E%2E%2F%2E%2E%2Fshared_prefs%2Fowned.xml',
    '..%2F..%2F..%2Fetc%2Fpasswd',
  ];

  group('el nombre local no sale nunca del URL', () {
    test('un segmento con %2F ya no produce una ruta relativa', () {
      for (final payload in traversalPayloads) {
        final url = '$bucket$payload';

        // El comportamiento vulnerable, reproducido aquí para dejar
        // constancia de que la decodificación sigue ocurriendo: lo que
        // cambia es que ya nadie usa este valor como nombre de archivo.
        final decoded = Uri.parse(url).pathSegments.last;
        expect(decoded, contains('../'),
            reason: 'Uri.pathSegments sigue decodificando %2F; por eso el '
                'nombre no puede derivarse de ahí.');

        final safe = AnimationCache.fileNameFor(url);
        expect(safe, matches(RegExp(r'^[0-9a-f]{64}\.glb$')),
            reason: 'El nombre debe ser un hash de longitud fija.');
        expect(safe, isNot(contains('/')));
        expect(safe, isNot(contains('..')));
      }
    });

    test('dos URLs distintas no comparten archivo local', () {
      // Antes `bucket/a/ROBAR.glb` y `bucket/b/ROBAR.glb` colisionaban y se
      // servían el uno por el otro.
      expect(
        AnimationCache.fileNameFor('${bucket}a/ROBAR.glb'),
        isNot(AnimationCache.fileNameFor('${bucket}b/ROBAR.glb')),
      );
    });
  });

  group('la descarga aplica allowlist de origen', () {
    late AnimationCache cache;
    late List<String> rejected;

    setUp(() {
      rejected = [];
      cache = AnimationCache(
        client: MockClient((_) async => http.Response('modelo', 200)),
        onRejected: (url, reason) => rejected.add('$url :: $reason'),
      );
    });

    test('acepta el bucket configurado por https', () {
      expect(cache.isAllowed('${bucket}ROBAR.glb'), isTrue);
    });

    test('rechaza otro host', () {
      expect(cache.isAllowed('https://atacante.example/evil.glb'), isFalse);
    });

    test('rechaza http en claro', () {
      expect(
        cache.isAllowed(
            'http://opensoul-3d-animations.s3.us-east-1.amazonaws.com/a.glb'),
        isFalse,
      );
    });

    test('rechaza file:// y otros esquemas', () {
      expect(cache.isAllowed('file:///etc/passwd'), isFalse);
      expect(cache.isAllowed('data:text/html,<script>'), isFalse);
    });

    test('un origen no permitido no escribe nada en disco', () async {
      final dir = await Directory.systemTemp.createTemp('anim_cache_test');
      addTearDown(() => dir.delete(recursive: true));

      final path = await cache.localPathFor(
          'https://atacante.example/evil.glb', dir);

      expect(path, isNull);
      expect(dir.listSync(), isEmpty);
      expect(rejected, hasLength(1),
          reason: 'Un intento rechazado debe dejar rastro, no degradarse '
              'en silencio.');
    });

    test('el payload de traversal no escapa del directorio', () async {
      final root = await Directory.systemTemp.createTemp('anim_root');
      addTearDown(() => root.delete(recursive: true));
      final cacheDir = Directory('${root.path}/cache')..createSync();
      final victim = Directory('${root.path}/app_flutter')..createSync();

      for (final payload in traversalPayloads) {
        await cache.localPathFor('$bucket$payload', cacheDir);
      }

      expect(victim.listSync(), isEmpty,
          reason: 'La escritura no puede alcanzar directorios hermanos.');
      // Lo que sí se escribió vive dentro de la caché y tiene nombre de hash.
      for (final entity in cacheDir.listSync()) {
        expect(entity.path.split('/').last, matches(RegExp(r'^[0-9a-f]{64}\.glb$')));
      }
    });
  });

  group('rechazar por política y fallar la descarga son casos distintos', () {
    // El visor los trata distinto y debe seguir haciéndolo: un origen
    // rechazado se rotula como texto, pero un origen legítimo cuya descarga
    // falló se carga desde la red —como antes de existir la caché—, porque
    // degradarlo a texto dejaría sin señas a quien esté con mala cobertura.
    test('un origen legítimo sigue siendo legítimo aunque no se descargue',
        () async {
      final dir = await Directory.systemTemp.createTemp('anim_offline');
      addTearDown(() => dir.delete(recursive: true));

      final cache = AnimationCache(
        client: MockClient((_) async => throw const SocketException('sin red')),
      );
      const url = '${bucket}ROBAR.glb';

      expect(await cache.localPathFor(url, dir), isNull);
      expect(cache.isAllowed(url), isTrue,
          reason: 'Es lo que permite al visor caer al URL remoto en vez de '
              'perder la seña.');
    });

    test('un origen rechazado no se vuelve legítimo por reintentar', () {
      final cache = AnimationCache(
        client: MockClient((_) async => http.Response('x', 200)),
      );
      expect(cache.isAllowed('https://atacante.example/evil.glb'), isFalse);
    });
  });

  group('el tope de tamaño corta un archivo desmedido', () {
    test('un modelo por encima del tope no se escribe', () async {
      final dir = await Directory.systemTemp.createTemp('anim_size_test');
      addTearDown(() => dir.delete(recursive: true));

      final cache = AnimationCache(
        maxBytes: 1024,
        client: MockClient(
            (_) async => http.Response.bytes(List.filled(4096, 65), 200)),
      );

      final path = await cache.localPathFor('${bucket}ROBAR.glb', dir);

      expect(path, isNull);
      expect(dir.listSync(), isEmpty);
    });
  });

  group('el resolutor rechaza nombres que no son nombres de archivo', () {
    const resolver = AnimationUrlResolver();

    test('un animationFile con traversal cae a placeholder', () {
      for (final payload in traversalPayloads) {
        final urls =
            resolver.resolveAll(gloss: 'ROBAR', animationFile: payload);
        expect(urls, ['${AnimationUrlResolver.placeholderScheme}ROBAR'],
            reason: 'Un nombre inadmisible equivale a no tener animación.');
      }
    });

    test('rechaza separadores y esquemas embebidos', () {
      for (final payload in [
        '../evil.glb',
        r'..\evil.glb',
        'https://atacante.example/evil.glb',
        'a/b.glb',
      ]) {
        expect(
          resolver.resolveAll(gloss: 'X', animationFile: payload),
          ['${AnimationUrlResolver.placeholderScheme}X'],
        );
      }
    });

    test('los nombres legítimos siguen funcionando', () {
      expect(
        resolver.resolveAll(gloss: 'ABOGADO', animationFile: 'ABOGADO.glb'),
        ['${bucket}ABOGADO.glb'],
      );
      // Seña compuesta: varias animaciones para una sola glosa.
      expect(
        resolver.resolveAll(gloss: 'FISCAL', animationFile: 'F.glb+ABOGADO.glb'),
        ['${bucket}F.glb', '${bucket}ABOGADO.glb'],
      );
      // Acentos y eñes se normalizan como siempre.
      expect(
        resolver.resolveAll(gloss: 'NIÑO', animationFile: 'NIÑO.glb'),
        ['${bucket}NINO.glb'],
      );
      // Un tramo inválido no arrastra al válido de la misma seña compuesta.
      expect(
        resolver.resolveAll(gloss: 'FISCAL', animationFile: 'F.glb+../x.glb'),
        ['${bucket}F.glb'],
      );
    });
  });
}
