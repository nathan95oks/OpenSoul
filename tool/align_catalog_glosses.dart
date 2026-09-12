import 'dart:convert';
import 'dart:io';

import 'package:lsb_legal_app/core/domain/services/context_catalog.dart';

void main() {
  final dictFile = File('assets/dictionary/official_dictionary.json');
  final doc = jsonDecode(dictFile.readAsStringSync()) as Map<String, dynamic>;
  final entries = (doc['entries'] as List).cast<Map<String, dynamic>>();
  final officialGlosses = entries.map((e) => e['gloss'] as String).toSet();

  print('Total official glosses in catalog: ${officialGlosses.length}');

  // Find map of unaccented -> official gloss
  final unaccentedToOfficial = <String, String>{};
  for (final g in officialGlosses) {
    unaccentedToOfficial[normalize(g)] = g;
  }

  final invalid = <String, Set<String>>{};
  for (final ctx in allSelectableContexts) {
    for (final z in ctx.zones) {
      for (final g in z.glossAllowlist) {
        if (!officialGlosses.contains(g)) {
          invalid.putIfAbsent('${ctx.id}/${z.id}', () => {}).add(g);
        }
      }
    }
  }

  if (invalid.isEmpty) {
    print('All glosses in allSelectableContexts match official_dictionary.json exactly!');
    return;
  }

  print('Found invalid/mismatched glosses:');
  invalid.forEach((zone, glosses) {
    print('  $zone: $glosses');
    for (final g in glosses) {
      final suggestion = unaccentedToOfficial[normalize(g)];
      print('    $g -> suggestion: $suggestion');
    }
  });

  // Auto fix context_catalog.dart
  final catFile = File('lib/core/domain/services/context_catalog.dart');
  var catContent = catFile.readAsStringSync();

  for (final g in unaccentedToOfficial.keys) {
    final official = unaccentedToOfficial[g]!;
    if (official != g) {
      // replace '$g' with '$official' when in allowlist
      catContent = catContent.replaceAll("'$g'", "'$official'");
    }
  }

  catFile.writeAsStringSync(catContent);
  print('Updated context_catalog.dart with canonical official glosses.');
}

String normalize(String input) {
  const from = 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛ';
  const to = 'AAAAEEEEIIIIOOOOUUUU';
  var out = input.replaceAll('-', '_');
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}
