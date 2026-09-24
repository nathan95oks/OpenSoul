import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/domain/services/animation_url_resolver.dart';

/// Los numerales del catálogo frente a las animaciones declaradas.
///
/// El catálogo ofrece los números como dígitos ('0'…'9'); el resolutor declara
/// las animaciones con su nombre en letras (CERO…DIEZ). La comparación directa
/// nunca casaba, y como esas entradas tienen `animationFile` no vacío tampoco
/// caían por la rama del marcador de posición: se devolvía la URL real y se le
/// pedía al visor una animación llamada '0'. El backend ya traducía
/// (`_DIGITO_A_GLOSA`); faltaba en el cliente.
///
/// **Lo que esta prueba NO demuestra:** que el modelo contenga esas
/// animaciones. El `.glb` no forma parte del repositorio. Aquí se comprueba
/// que el cliente pide el nombre que el propio sistema declara tener, y que
/// cliente y backend usan el mismo mapa. La reproducción real en el avatar
/// queda pendiente de comprobarse en dispositivo.
const _resolver = AnimationUrlResolver(baseUrl: 'https://cdn.example/');

Set<String> _digitosDelCatalogo() {
  final doc = jsonDecode(
      File('assets/dictionary/official_dictionary.json').readAsStringSync());
  return {
    for (final e in (doc['entries'] as List))
      if ((e['gloss'] as String).length == 1 &&
          int.tryParse(e['gloss'] as String) != null)
        e['gloss'] as String,
  };
}

void main() {
  group('el cliente pide el nombre que el sistema declara', () {
    test('un dígito se traduce a su numeral', () {
      expect(AnimationUrlResolver.animationNameFor('0'), 'CERO');
      expect(AnimationUrlResolver.animationNameFor('7'), 'SIETE');
    });

    test('todos los dígitos del catálogo tienen numeral declarado', () {
      final digitos = _digitosDelCatalogo();
      expect(digitos, hasLength(10), reason: 'El catálogo trae 0..9.');

      for (final d in digitos) {
        final nombre = AnimationUrlResolver.animationNameFor(d);
        expect(AnimationUrlResolver.available3DGlosses, contains(nombre),
            reason: 'El dígito $d pedía "$d", que el resolutor no declara.');
      }
    });

    test('un dígito ya no cae en marcador de posición', () {
      final urls = _resolver.resolveAll(
          gloss: '3', animationFile: 'avatar_test.glb');
      expect(urls.single,
          isNot(startsWith(AnimationUrlResolver.placeholderScheme)));
      expect(urls.single, 'https://cdn.example/avatar_test.glb');
    });

    test('un dígito sin animationFile también resuelve', () {
      // La cobertura no puede depender de un campo de datos: el resolutor
      // sabe por sí mismo que los numerales están declarados.
      final urls = _resolver.resolveAll(gloss: '5');
      expect(urls.single, 'https://cdn.example/avatar_test.glb');
    });

    test('DIEZ sigue funcionando por su nombre', () {
      expect(AnimationUrlResolver.animationNameFor('DIEZ'), 'DIEZ');
      expect(_resolver.resolveAll(gloss: 'DIEZ').single,
          'https://cdn.example/avatar_test.glb');
    });

    test('la Ñ conserva su nombre propio de animación', () {
      expect(AnimationUrlResolver.animationNameFor('Ñ'), 'ENE');
    });

    test('una glosa sin animación sigue siendo marcador', () {
      final urls = _resolver.resolveAll(gloss: 'CELULAR');
      expect(urls.single,
          startsWith(AnimationUrlResolver.placeholderScheme));
    });
  });

  group('cliente y backend usan el mismo mapa', () {
    test('coincide con _DIGITO_A_GLOSA de lambda_text_to_lsb.py', () {
      final fuente = File('aws/lambda_text_to_lsb.py').readAsStringSync();
      final bloque = RegExp(r'_DIGITO_A_GLOSA = \{(.*?)\}', dotAll: true)
          .firstMatch(fuente);
      expect(bloque, isNotNull, reason: 'El mapa del backend desapareció.');

      final pares = RegExp(r'"(\d)":\s*"([A-ZÑ]+)"')
          .allMatches(bloque!.group(1)!);
      expect(pares, isNotEmpty);

      for (final m in pares) {
        expect(AnimationUrlResolver.digitToNumeral[m.group(1)], m.group(2),
            reason: 'El dígito ${m.group(1)} se traduce distinto en cada lado.');
      }
    });
  });

  group('límites declarados sin exagerar', () {
    test('el modelo no está en el repositorio', () {
      // Si algún día se añade, esta prueba lo dice y toca revisar las
      // afirmaciones de cobertura, que hoy salen de una constante.
      final glbs = Directory('.')
          .listSync(recursive: false)
          .whereType<Directory>()
          .where((d) => !d.path.contains('build'))
          .expand((d) {
            try {
              return d.listSync(recursive: true);
            } catch (_) {
              return const <FileSystemEntity>[];
            }
          })
          .whereType<File>()
          .where((f) => f.path.endsWith('.glb'));

      expect(glbs, isEmpty,
          reason: 'Las cifras de cobertura del avatar se declaran como '
              'lectura de código, no como inspección del modelo.');
    });
  });
}
