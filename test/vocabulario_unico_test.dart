import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Los dos módulos hablan el mismo idioma.
///
/// El de tarjetas lee `official_dictionary.json`; el del avatar lee la
/// constante `AVAILABLE_GLOSSES` de su Lambda. Cuando cada uno mantenía su
/// lista a mano, el catálogo tenía 208 glosas y la Lambda 68, con 18 en común:
/// en la misma aplicación, "denuncia" existía para quien elegía tarjetas y no
/// para el avatar que debía representarla.
///
/// La Lambda se genera desde el catálogo con `tool/sync_vocabulary.dart`. Esta
/// prueba es lo que hace que esa regla se cumpla en lugar de confiarse.
void main() {
  test('la Lambda del avatar declara exactamente el catálogo de tarjetas', () {
    final doc = jsonDecode(
      File('assets/dictionary/official_dictionary.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final catalogo = {
      for (final e in (doc['entries'] as List).cast<Map<String, dynamic>>())
        e['gloss'] as String,
    };

    final fuente = File('aws/lambda_text_to_lsb.py').readAsStringSync();
    final bloque = RegExp(r'AVAILABLE_GLOSSES = \{(.*?)\n\}', dotAll: true)
        .firstMatch(fuente);
    expect(bloque, isNotNull,
        reason: 'no se encontró AVAILABLE_GLOSSES en la Lambda');

    final lambda = RegExp('"([^"]+)"')
        .allMatches(bloque!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();

    final soloEnCatalogo = catalogo.difference(lambda);
    final soloEnLambda = lambda.difference(catalogo);

    expect(
      soloEnCatalogo,
      isEmpty,
      reason: 'el avatar no sabría representar estas glosas: $soloEnCatalogo\n'
          'ejecuta: dart run tool/sync_vocabulary.dart',
    );
    expect(
      soloEnLambda,
      isEmpty,
      reason: 'la Lambda ofrece glosas que no existen como tarjeta: '
          '$soloEnLambda\nejecuta: dart run tool/sync_vocabulary.dart',
    );
  });
}
