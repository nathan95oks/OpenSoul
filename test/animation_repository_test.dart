import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lsb_legal_app/core/data/datasources/animation_cache.dart';
import 'package:lsb_legal_app/core/data/repositories/animation_repository_impl.dart';
import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

/// El repositorio de animaciones: la traducción de "URLs que el motor pidió"
/// a "fuentes que el visor puede reproducir".
///
/// Esta lógica vivía dentro del widget del avatar, que además abría el
/// directorio temporal por su cuenta. Aquí queda detrás del contrato
/// `AnimationRepository`, así que la presentación ya no toca ni disco ni red.
///
/// Las tres salidas posibles son las tres ramas que el visor sabe interpretar,
/// y ninguna de ellas puede faltar: si una URL no produce fuente, el avatar se
/// queda mudo en esa seña.
void main() {
  const bucket = 'https://test-animations-bucket.s3.us-east-1.amazonaws.com/';
  final bucketHost = Uri.parse(bucket).host;

  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('anim_repo_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  AnimationRepositoryImpl repositoryWith(AnimationCache cache) =>
      AnimationRepositoryImpl(
        cache: cache,
        temporaryDirectory: () async => temp,
      );

  AnimationCache cacheThatServes(String body) => AnimationCache(
        client: MockClient((_) async => http.Response(body, 200)),
        allowedHosts: {bucketHost},
      );

  test('un modelo descargable se sirve desde el archivo local', () async {
    final repo = repositoryWith(cacheThatServes('modelo'));

    final sources = await repo.playableSources(['${bucket}avatar_test.glb']);

    expect(sources, hasLength(1));
    expect(sources.single, startsWith('file://'));
    expect(sources.single, contains(temp.path));
  });

  test('un placeholder pasa intacto y no toca la red', () async {
    final repo = repositoryWith(AnimationCache(
      client: MockClient((_) async => throw StateError('no debe descargar')),
      allowedHosts: {bucketHost},
    ));

    const placeholder = '${AnimationUrlResolver.placeholderScheme}TESTIGO';
    expect(await repo.playableSources([placeholder]), [placeholder]);
  });

  test('un origen no permitido degrada a placeholder, no a la URL', () async {
    final repo = repositoryWith(cacheThatServes('modelo'));

    final sources =
        await repo.playableSources(['https://atacante.example/evil.glb']);

    expect(sources, [
      '${AnimationUrlResolver.placeholderScheme}https://atacante.example/evil.glb'
    ]);
    expect(temp.listSync(), isEmpty,
        reason: 'Un origen rechazado no escribe nada en la caché.');
  });

  test('sin URLs no se abre siquiera el directorio temporal', () async {
    final repo = AnimationRepositoryImpl(
      cache: cacheThatServes('modelo'),
      temporaryDirectory: () async => throw StateError('no debe abrirse'),
    );

    expect(await repo.playableSources(const []), isEmpty);
  });

  test('cada URL produce exactamente una fuente, en orden', () async {
    final repo = repositoryWith(cacheThatServes('modelo'));

    final sources = await repo.playableSources([
      '${AnimationUrlResolver.placeholderScheme}A',
      '${bucket}avatar_test.glb',
      'https://atacante.example/evil.glb',
    ]);

    expect(sources, hasLength(3));
    expect(sources[0], '${AnimationUrlResolver.placeholderScheme}A');
    expect(sources[1], startsWith('file://'));
    expect(sources[2],
        startsWith(AnimationUrlResolver.placeholderScheme));
  });
}
