import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cliente y servidor componen la misma oración a partir de las mismas glosas.
///
/// El ensamblador local redacta cuando no hay red; la Lambda redacta cuando la
/// hay. Si sus lexicones divergen, la misma declaración cambia según la
/// cobertura del momento —y la compuerta de degeneración no lo detecta, porque
/// ambas salidas son gramaticales.
///
/// Ya había pasado: el servidor conservaba 230 glosas del vocabulario anterior
/// mientras el cliente usaba las 208 del corpus, así que "HOMBRE ROBAR
/// TELEFONO" se redactaba como "Un hombre me robó." y el objeto del delito
/// desaparecía del acta.
void main() {
  Map<String, String> leerCliente() {
    final fuente = File(
      'lib/core/engines/semantic_engine/local_sentence_assembler.dart',
    ).readAsStringSync();
    final patron =
        RegExp(r"'([A-ZÑ_0-9]+)':\s*_Lex\(_Role\.(\w+),\s*'((?:[^'\\]|\\')*)'\)");
    return {
      for (final m in patron.allMatches(fuente)) m.group(1)!: m.group(3)!,
    };
  }

  Map<String, String> leerServidor() {
    final fuente = File('aws/lambda_function.py').readAsStringSync();
    final bloque =
        RegExp(r'GLOSS_LEXICON = \{(.*?)\n\}', dotAll: true).firstMatch(fuente);
    expect(bloque, isNotNull, reason: 'no se encontró GLOSS_LEXICON');
    final patron = RegExp(r'"([A-ZÑ_0-9]+)":\s*\{"rol": "[A-Z_]+", "es": "([^"]*)"\}');
    return {
      for (final m in patron.allMatches(bloque!.group(1)!))
        m.group(1)!: m.group(2)!,
    };
  }

  test('el servidor conoce exactamente las glosas del cliente', () {
    final cliente = leerCliente();
    final servidor = leerServidor();

    expect(cliente, isNotEmpty, reason: 'no se pudo leer el lexicón del cliente');
    expect(
      servidor.keys.toSet().difference(cliente.keys.toSet()),
      isEmpty,
      reason: 'el servidor redactaría glosas que el cliente no tiene\n'
          'ejecuta: dart run tool/sync_vocabulary.dart',
    );
    expect(
      cliente.keys.toSet().difference(servidor.keys.toSet()),
      isEmpty,
      reason: 'el servidor perdería estas glosas al redactar\n'
          'ejecuta: dart run tool/sync_vocabulary.dart',
    );
  });

  test('una glosa se redacta igual en los dos lados', () {
    final cliente = leerCliente();
    final servidor = leerServidor();

    final discrepantes = [
      for (final g in cliente.keys)
        if (servidor.containsKey(g) && servidor[g] != cliente[g])
          '$g: cliente "${cliente[g]}" ≠ servidor "${servidor[g]}"',
    ];

    expect(discrepantes, isEmpty,
        reason: 'la declaración cambiaría según haya red o no:\n'
            '${discrepantes.take(8).join('\n')}');
  });

  test('todo rol generado es uno que el backend sabe leer', () {
    final fuente = File('aws/lambda_function.py').readAsStringSync();

    // Tabla con la que el backend reparte cada glosa en su cubo de análisis.
    final tabla = RegExp(r'mapping = \{(.*?)\}', dotAll: true).firstMatch(fuente);
    expect(tabla, isNotNull, reason: 'no se encontró el mapping de roles');
    final reconocidos = RegExp('"([A-Z_]+)":')
        .allMatches(tabla!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();

    final bloque =
        RegExp(r'GLOSS_LEXICON = \{(.*?)\n\}', dotAll: true).firstMatch(fuente);
    final usados = RegExp('"rol": "([A-Z_]+)"')
        .allMatches(bloque!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();

    // DESCONOCIDO es deliberado: cortesías e interrogativas no tienen cubo en
    // el backend y las recupera su regla de cobertura.
    final huerfanos = usados.difference(reconocidos)..remove('DESCONOCIDO');

    expect(
      huerfanos,
      isEmpty,
      reason: 'estos roles caerían en "desconocidos" sin querer, y la oración '
          'saldría gramatical pero incompleta: $huerfanos\n'
          'revisa la tabla _roles de tool/sync_vocabulary.dart',
    );
  });
}
