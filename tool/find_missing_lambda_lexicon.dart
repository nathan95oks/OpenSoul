// ignore_for_file: avoid_print
// Utilidad de diagnóstico — NO es una prueba.
//
// Reporta, sin depender del runner de pruebas, qué glosas del diccionario
// oficial (assets/dictionary/official_dictionary.json) no tienen representación
// en el lexicón del motor local (LocalSentenceAssembler) ni en el
// GLOSS_LEXICON del backend (lambda_function.py).
//
// El motor local y GLOSS_LEXICON se leen como TEXTO (regex), así que corre
// sin compilar Flutter. El catálogo sí se parsea como JSON, para poder
// excluir las glosas `mechanism` (Abecedario, Números): esas son dactilología
// — se deletrean letra por letra, nunca entran al lexicón compositivo por
// diseño — y contarlas como "faltantes" es un falso positivo.
//
//   dart run tool/find_missing_lambda_lexicon.dart
//
// Salida con código 1 si falta alguna glosa; 0 si la cobertura es completa.
import 'dart:convert';
import 'dart:io';

Set<String> _matchAll(String content, RegExp re) =>
    re.allMatches(content).map((m) => m.group(1)!).toSet();

void main() {
  const dsPath = 'assets/dictionary/official_dictionary.json';
  final asmPath =
      'lib/core/engines/semantic_engine/local_sentence_assembler.dart';
  const lambdaPath = 'aws/lambda_function.py';

  final catalogJson =
      jsonDecode(File(dsPath).readAsStringSync()) as Map<String, dynamic>;
  final catalog = (catalogJson['entries'] as List)
      .cast<Map<String, dynamic>>()
      .where((e) => e['mechanism'] == null)
      .map((e) => e['gloss'] as String)
      .toSet();
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
