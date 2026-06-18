// ignore_for_file: avoid_print
// Utilidad de diagnóstico — NO es una prueba.
//
// Reporta, sin depender del runner de pruebas, qué glosas del catálogo local
// (LocalCardsDataSource) no tienen representación en el lexicón del motor local
// (LocalSentenceAssembler) ni en el GLOSS_LEXICON del backend (lambda_function.py).
//
// Lee los tres archivos como TEXTO, por lo que se ejecuta sin compilar Flutter:
//
//   dart run tool/find_missing_lambda_lexicon.dart
//
// Salida con código 1 si falta alguna glosa; 0 si la cobertura es completa.
import 'dart:io';

Set<String> _matchAll(String content, RegExp re) =>
    re.allMatches(content).map((m) => m.group(1)!).toSet();

void main() {
  final dsPath =
      'lib/features/lsb_to_text_audio/data/datasources/local_cards_datasource.dart';
  final asmPath =
      'lib/features/lsb_to_text_audio/domain/services/local_sentence_assembler.dart';
  const lambdaPath = 'aws/lambda_function.py';

  final catalog = _matchAll(
    File(dsPath).readAsStringSync(),
    RegExp(r"gloss:\s*'([A-Z0-9_Ñ]+)'"),
  );
  final assembler = _matchAll(
    File(asmPath).readAsStringSync(),
    RegExp(r"'([A-Z0-9_Ñ]+)':\s*_Lex\("),
  );

  final lambdaSrc = File(lambdaPath).readAsStringSync();
  final start = lambdaSrc.indexOf('GLOSS_LEXICON = {');
  final end = lambdaSrc.indexOf('def analyze_glosses');
  final lambda = _matchAll(
    lambdaSrc.substring(start, end),
    RegExp(r'"([A-Z0-9_Ñ]+)":\s*\{'),
  );

  final missingAsm = catalog.difference(assembler).toList()..sort();
  final missingLambda = catalog.difference(lambda).toList()..sort();

  print('Glosas en catálogo local : ${catalog.length}');
  print('Glosas en motor local    : ${assembler.length}');
  print('Glosas en GLOSS_LEXICON  : ${lambda.length}');
  print('---');
  print('Faltantes en motor local : ${missingAsm.isEmpty ? "ninguna" : missingAsm}');
  print('Faltantes en Lambda      : ${missingLambda.isEmpty ? "ninguna" : missingLambda}');

  if (missingAsm.isNotEmpty || missingLambda.isNotEmpty) {
    exitCode = 1;
  } else {
    print('\n✓ Cobertura completa: las ${catalog.length} glosas están representadas.');
  }
}
