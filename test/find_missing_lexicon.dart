import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/data/datasources/local_cards_datasource.dart';

/// Pruebas de cobertura del lexicón.
///
/// Garantizan que NINGUNA glosa del catálogo local quede sin representación
/// semántica, comparando las 153 glosas de [LocalCardsDataSource] contra:
///   a) el lexicón del motor local (`LocalSentenceAssembler._lexicon`)
///   b) el `GLOSS_LEXICON` del backend (`aws/lambda_function.py`)
///
/// Ambos se leen como TEXTO porque sus mapas son privados (`_lexicon`) o están
/// en otro lenguaje (Python). Las claves de glosa incluyen la letra `Ñ`
/// (NIÑO, MAÑANA), por eso el patrón añade `Ñ` al rango `[A-Z0-9_]`.
void main() {
  final dataSource = LocalCardsDataSource();
  final catalogGlosses =
      dataSource.cards.map((c) => c.gloss).toSet();

  test('todas las glosas del catálogo están en el lexicón del motor local', () {
    final content = File(
      'lib/features/lsb_to_text_audio/domain/services/local_sentence_assembler.dart',
    ).readAsStringSync();

    final regex = RegExp(r"'([A-Z0-9_Ñ]+)':\s*_Lex\(");
    final lexiconKeys =
        regex.allMatches(content).map((m) => m.group(1)!).toSet();

    final missing = catalogGlosses.difference(lexiconKeys).toList()..sort();
    for (final g in missing) {
      // ignore: avoid_print
      print('MISSING en LocalSentenceAssembler: $g');
    }
    expect(missing, isEmpty,
        reason: 'Glosas del catálogo sin entrada en _lexicon: $missing');
  });

  test('todas las glosas del catálogo están en el GLOSS_LEXICON del backend',
      () {
    final lambda = File('aws/lambda_function.py').readAsStringSync();

    // Acota la búsqueda al bloque del diccionario GLOSS_LEXICON.
    final start = lambda.indexOf('GLOSS_LEXICON = {');
    final end = lambda.indexOf('def analyze_glosses');
    expect(start >= 0 && end > start, isTrue,
        reason: 'No se encontró el bloque GLOSS_LEXICON en lambda_function.py');
    final segment = lambda.substring(start, end);

    final regex = RegExp(r'"([A-Z0-9_Ñ]+)":\s*\{');
    final lambdaKeys =
        regex.allMatches(segment).map((m) => m.group(1)!).toSet();

    final missing = catalogGlosses.difference(lambdaKeys).toList()..sort();
    for (final g in missing) {
      // ignore: avoid_print
      print('MISSING en GLOSS_LEXICON (Lambda): $g');
    }
    expect(missing, isEmpty,
        reason: 'Glosas del catálogo no reconocidas por el backend: $missing');
  });
}
