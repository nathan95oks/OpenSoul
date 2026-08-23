// Genera el vocabulario de la Lambda del avatar a partir del catálogo de
// tarjetas, para que los dos módulos hablen el mismo idioma.
//
// Antes cada módulo tenía su propia lista escrita a mano: 208 glosas en el
// catálogo y 68 en la Lambda, con solo 18 en común. En la misma aplicación,
// "denuncia" podía existir para quien elige tarjetas y no para el avatar.
//
//   dart run tool/sync_vocabulary.dart          # regenera
//   dart run tool/sync_vocabulary.dart --check   # solo verifica (para CI)
import 'dart:convert';
import 'dart:io';

const _catalogo = 'assets/dictionary/official_dictionary.json';
const _lambda = 'aws/lambda_text_to_lsb.py';
const _inicio = 'AVAILABLE_GLOSSES = {';
const _fin = '}';

void main(List<String> args) {
  final soloVerificar = args.contains('--check');

  final doc = jsonDecode(File(_catalogo).readAsStringSync()) as Map<String, dynamic>;
  final entradas = (doc['entries'] as List).cast<Map<String, dynamic>>();

  // Agrupadas por categoría para que el archivo generado se pueda leer.
  final porCategoria = <String, List<String>>{};
  for (final e in entradas) {
    porCategoria.putIfAbsent(e['categoryId'] as String, () => []).add(e['gloss'] as String);
  }
  for (final lista in porCategoria.values) {
    lista.sort();
  }

  final buffer = StringBuffer()
    ..writeln(_inicio)
    ..writeln('    # GENERADO por tool/sync_vocabulary.dart — no editar a mano.')
    ..writeln('    # Fuente: $_catalogo');
  for (final categoria in (doc['categoryOrder'] as List).cast<String>()) {
    final glosas = porCategoria[categoria];
    if (glosas == null || glosas.isEmpty) continue;
    buffer.writeln('    # --- $categoria (${glosas.length}) ---');
    for (var i = 0; i < glosas.length; i += 6) {
      final fila = glosas.skip(i).take(6).map((g) => '"$g"').join(', ');
      buffer.writeln('    $fila,');
    }
  }
  buffer.write(_fin);
  final bloqueNuevo = buffer.toString();

  final fuente = File(_lambda).readAsStringSync();
  final desde = fuente.indexOf(_inicio);
  if (desde < 0) {
    stderr.writeln('No se encontró $_inicio en $_lambda');
    exit(1);
  }
  final hasta = fuente.indexOf('\n$_fin', desde) + _fin.length + 1;
  final bloqueActual = fuente.substring(desde, hasta);

  if (bloqueActual.trim() == bloqueNuevo.trim()) {
    stdout.writeln('vocabulario sincronizado (${entradas.length} glosas)');
    return;
  }
  if (soloVerificar) {
    stderr.writeln('El vocabulario de la Lambda no coincide con el catálogo.\n'
        'Ejecuta: dart run tool/sync_vocabulary.dart');
    exit(1);
  }
  File(_lambda).writeAsStringSync(fuente.replaceRange(desde, hasta, bloqueNuevo));
  stdout.writeln('vocabulario regenerado: ${entradas.length} glosas '
      'en ${porCategoria.length} categorías');
}
