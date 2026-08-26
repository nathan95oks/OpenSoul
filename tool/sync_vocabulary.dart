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
const _ensamblador = 'lib/core/engines/semantic_engine/local_sentence_assembler.dart';
const _lambdaCards = 'aws/lambda_function.py';
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
    sincronizarLexicon(soloVerificar);
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

  sincronizarLexicon(soloVerificar);
}

/// Regenera el `GLOSS_LEXICON` del backend de tarjetas desde el del cliente.
void sincronizarLexicon(bool soloVerificar) {
  final cliente = leerLexiconCliente();
  if (cliente.isEmpty) {
    stderr.writeln('No se pudo leer el lexicón de $_ensamblador');
    exit(1);
  }

  final glosas = cliente.keys.toList()..sort();
  final buffer = StringBuffer()
    ..writeln('GLOSS_LEXICON = {')
    ..writeln('    # GENERADO por tool/sync_vocabulary.dart — no editar a mano.')
    ..writeln('    # Fuente: el lexicón del cliente, para que servidor y cliente')
    ..writeln('    # compongan la misma oración a partir de las mismas glosas.');
  for (final g in glosas) {
    final e = cliente[g]!;
    final rol = _roles[e.rol];
    if (rol == null) {
      stderr.writeln('Rol sin equivalencia en el backend: ${e.rol} (glosa $g)');
      exit(1);
    }
    final es = e.es.replaceAll(r"\'", "'").replaceAll('"', r'\"');
    final extras = StringBuffer();
    if (e.rol == 'personaDesc') {
      extras.write(', "persona": True');
    }
    if (e.rol == 'verboAgresion') {
      extras.write(', "agresor": "$es"');
    }
    buffer.writeln('    "$g": {"rol": "$rol", "es": "$es"$extras},');
  }
  buffer.write('}');
  final bloqueNuevo = buffer.toString();

  final fuente = File(_lambdaCards).readAsStringSync();
  final desde = fuente.indexOf('GLOSS_LEXICON = {');
  if (desde < 0) {
    stderr.writeln('No se encontró GLOSS_LEXICON en $_lambdaCards');
    exit(1);
  }
  final hasta = fuente.indexOf('\n}', desde) + 2;
  if (fuente.substring(desde, hasta).trim() == bloqueNuevo.trim()) {
    stdout.writeln('lexicón sincronizado (${glosas.length} glosas)');
    return;
  }
  if (soloVerificar) {
    stderr.writeln('El lexicón del backend no coincide con el del cliente.\n'
        'Ejecuta: dart run tool/sync_vocabulary.dart');
    exit(1);
  }
  File(_lambdaCards)
      .writeAsStringSync(fuente.replaceRange(desde, hasta, bloqueNuevo));
  stdout.writeln('lexicón regenerado: ${glosas.length} glosas');
}

/// Roles del ensamblador del cliente y su nombre en el backend.
/// Roles del ensamblador del cliente y su nombre en el backend.
///
/// No son la misma lista: el backend agrupa más grueso —un verbo es VERBO
/// venga de una agresión o de un trámite, y una persona y un rasgo son ambos
/// DESCRIPTOR—. Traducir mal esta tabla no rompe nada visiblemente: las glosas
/// caen en "desconocidos" y la oración sale gramatical pero incompleta, que es
/// justo lo que pasó con "HOMBRE ROBAR TELEFONO CALLE" -> "Un hombre robó."
const _roles = {
  'sujeto': 'SUJETO',
  'personaDesc': 'DESCRIPTOR',
  'rasgo': 'DESCRIPTOR',
  'verboAgresion': 'VERBO',
  'verboAccion': 'VERBO',
  'arma': 'OBJETO',
  'objeto': 'OBJETO',
  'documento': 'DOCUMENTO',
  'lugar': 'LUGAR',
  'institucion': 'INSTITUCION',
  'servicio': 'SERVICIO',
  'emocion': 'ESTADO',
  'urgencia': 'URGENCIA',
  'tramite': 'TRAMITE',
  'motivo': 'ESTADO',
  'tiempo': 'TIEMPO',
  // El backend no tiene concepto de cortesía ni de interrogativa: caen en
  // "desconocidos" y los recupera su regla de cobertura. El cliente sí las
  // compone, y es su versión la que manda cuando ambas difieren.
  'marcador': 'DESCONOCIDO',
  'interrogativa': 'DESCONOCIDO',
};

/// Lexicón del cliente: glosa → (rol, forma en español).
///
/// Es la fuente porque es donde se redacta la oración cuando no hay red, y esa
/// versión tiene que ser la buena: si el backend compusiera distinto, la
/// declaración cambiaría según hubiera cobertura.
Map<String, ({String rol, String es})> leerLexiconCliente() {
  final fuente = File(_ensamblador).readAsStringSync();
  final patron = RegExp(
      r"'([A-ZÑ_0-9]+)':\s*_Lex\(_Role\.(\w+),\s*'((?:[^'\\]|\\')*)'\)");
  return {
    for (final m in patron.allMatches(fuente))
      m.group(1)!: (rol: m.group(2)!, es: m.group(3)!),
  };
}
