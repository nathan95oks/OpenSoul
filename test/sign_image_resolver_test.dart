import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/generators/sign_image/sign_image_resolver.dart';

/// El resolutor decide de dónde sale la imagen de una seña y, sobre todo,
/// cuándo **no** hay imagen. Ese `null` es la red de seguridad de la tarjeta:
/// si se colara una ruta inventada, la cuadrícula se llenaría de huecos rotos.
void main() {
  const base = 'https://ejemplo.test/lsb/';
  const resolver = SignImageResolver(baseUrl: base);

  test('sin almacén configurado no hay imagen', () {
    const sinBase = SignImageResolver(baseUrl: '');
    expect(sinBase.isConfigured, isFalse);
    expect(sinBase.urlFor('DENUNCIA'), isNull);
  });

  test('una base relativa no se acepta como almacén', () {
    const relativa = SignImageResolver(baseUrl: '/lsb/');
    expect(relativa.isConfigured, isFalse);
    expect(relativa.urlFor('DENUNCIA'), isNull);
  });

  test('construye la URL de la glosa', () {
    expect(resolver.urlFor('DENUNCIA'), '${base}DENUNCIA.png');
  });

  test('añade la barra final que falte en la base', () {
    const sinBarra = SignImageResolver(baseUrl: 'https://ejemplo.test/lsb');
    expect(sinBarra.urlFor('JUEZ'), 'https://ejemplo.test/lsb/JUEZ.png');
  });

  test('normaliza tildes y eñes, que los archivos no llevan', () {
    expect(resolver.urlFor('POLICÍA'), '${base}POLICIA.png');
    expect(resolver.urlFor('SEÑA'), '${base}SENA.png');
  });

  test('las glosas del corpus con espacios usan guion bajo', () {
    expect(resolver.urlFor('POR FAVOR'), '${base}POR_FAVOR.png');
  });

  test('minúsculas y espacios sobrantes no generan una URL distinta', () {
    expect(resolver.urlFor('  juez '), '${base}JUEZ.png');
  });

  group('nombres que no pueden formar un archivo', () {
    for (final entrada in ['../secreto', 'A/B', '¿QUIÉN?', '', '   ', 'A%2E%2E']) {
      test('rechaza ${entrada.isEmpty ? "(vacío)" : entrada}', () {
        expect(resolver.urlFor(entrada), isNull,
            reason: 'debe caer al ícono, no apuntar a una ruta construida');
      });
    }
  });
}
