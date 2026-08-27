import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';

import 'helpers/official_dictionary.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';

/// Auditoría de cobertura semántica del motor local.
/// Para cada caso comprueba que TODA glosa quede representada en el texto.
void main() {
  const asm = LocalSentenceAssembler();

  // Casos por contexto: mínimos, medios, complejos y selección múltiple.
  // Todos los casos usan **solo** vocabulario del corpus verificado. Lo que el
  // corpus no trae —un arma, una sigla institucional— no se inventa: se
  // deletrea, que es lo que hace la LSB y lo que el sistema ahora soporta.
  final cases = <(String, List<String>)>[
    // robo
    ('denuncia_robo', ['ROBAR']),
    ('denuncia_robo', ['HOMBRE', 'ROBAR', 'TELEFONO']),
    ('denuncia_robo', ['HOMBRE', 'ROBAR', 'TELEFONO', 'CALLE', 'AYER']),
    ('denuncia_robo', ['ROBAR', 'TELEFONO', 'DINERO', 'POLICIA', 'TEMOR', 'HOY']),
    // robo con arma deletreada: CUCHILLO no está en el corpus
    ('denuncia_robo',
        ['HOMBRE', 'ROBAR', 'TELEFONO', 'C', 'U', 'C', 'H', 'I', 'L', 'L', 'O']),
    // violencia
    ('violencia', ['AMENAZAR']),
    ('violencia', ['AMENAZAR', 'AUXILIO', 'POLICIA', 'TEMOR']),
    ('violencia', ['ABUSAR', 'MAL', 'AUXILIO', 'HOY']),
    ('violencia', ['MALTRATAR', 'HOMBRE', 'TEMOR', 'POLICIA', 'ABOGADO']),
    // accidente
    ('accidente', ['MAL']),
    ('accidente', ['MAL', 'ASISTENCIA', 'CALLE', 'HOY']),
    ('accidente', ['HERIDA', 'TEMOR', 'ASISTENCIA', 'HOSPITAL', 'AUXILIO']),
    // emergencia
    ('emergencia', ['CRISIS']),
    ('emergencia', ['HERIDA', 'ASISTENCIA', 'AUXILIO', 'HOSPITAL']),
    // trámites
    ('tramite_id', ['GESTIONAR', 'IDENTIDAD']),
    ('tramite_id', ['GESTIONAR', 'LICENCIA_DECONDUCIR', 'ALCALDIA']),
    ('tramite_id', ['INVESTIGACION', 'FISCAL']),
    ('tramite_id', ['GESTIONAR', 'INVESTIGACION', 'FISCAL', 'INTERPRETE', 'HOY']),
    ('tramite_id', ['PEDIR', 'FOTOCOPIA', 'PODER', 'ORGANO_JUDICIAL', 'ABOGADO']),
    ('tramite_id', ['SOLUCIONAR', 'TESTIMONIO', 'INSTITUCION', 'AHORA']),
    // trámite en una institución cuya sigla se deletrea
    ('tramite_id', ['GESTIONAR', 'IDENTIDAD', 'S', 'E', 'G', 'I', 'P']),
    // orientación
    ('orientacion', ['ABOGADO', 'INSTITUCION']),
    ('orientacion', ['HABLAR', 'INTERPRETE', 'INSTITUCION', 'HOY']),
    // cortesía: saludo y respuesta no ocupan lugar en la oración
    ('orientacion', ['HOLA', 'PEDIR', 'INTERPRETE']),
    ('orientacion', ['SI', 'HABLAR', 'ABOGADO']),
    // pérdida
    ('perdida', ['FALTA', 'IDENTIDAD']),
    ('perdida', ['PAPEL', 'CALLE', 'AYER', 'POLICIA', 'AUXILIO']),
    // testigo
    ('otro', ['ROBAR']),
    ('otro', ['HOMBRE', 'MALTRATAR', 'CALLE', 'AYER', 'INSTITUCION']),
  ];

  // Glosas inherentemente implícitas (1ª persona) que no exigen aparición literal.
  const implicit = {'YO'};

  test('cobertura semántica por contexto', () {
    var totalMissing = 0;
    for (final (ctx, glosses) in cases) {
      final out = asm.assemble(contextId: ctx, glosses: glosses);
      final hay = _strip(out.toLowerCase());
      final missing = _joinSpelled(glosses)
          .where((g) => !implicit.contains(g))
          .where((g) => !_covered(g, hay))
          .toList();
      totalMissing += missing.length;
      // ignore: avoid_print
      print('[$ctx] ${glosses.join('+')}\n   → "$out"'
          '${missing.isEmpty ? '' : '\n   ✗ FALTAN: $missing'}\n');
    }
    expect(totalMissing, 0, reason: 'Hay glosas no representadas.');
  });

  // ── 6 contextos: Trámites y Consultas dejaron de ser el mismo flujo ──
  test('6 contextos oficiales con enrutado por intención', () async {
    // 1) La UI ofrece exactamente 6 contextos.
    final ids = availableContexts.map((c) => c.id).toList();
    final names = availableContexts.map((c) => c.name).toList();
    // ignore: avoid_print
    print('CONTEXTOS (${ids.length}): $names');
    expect(ids,
        ['denuncia_robo', 'violencia', 'accidente', 'otro', 'tramite', 'consulta']);
    // 'preguntas' se ofrece en la interfaz pero no narra un hecho, así que
    // queda fuera de la lista que alimenta la inferencia de contexto.
    expect(allSelectableContexts.map((c) => c.id), contains('preguntas'));

    // 2) Mapa glosa → categoría desde el diccionario canónico.
    final List<LsbCard> all = loadOfficialEntries();
    String? catOf(String g) {
      for (final c in all) {
        if (c.gloss == g) return c.categoryId;
      }
      return null;
    }

    // 3) Enrutado interno de 'tramite': reparte entre los tres compositores
    //    del antiguo contexto fusionado según lo que la persona eligió.
    String route(List<String> gl) =>
        resolveAssemblerContext('tramite', gl, catOf);
    expect(route(['FALTA', 'TELEFONO']), 'perdida');
    expect(route(['TELEFONO', 'CALLE']), 'perdida'); // objeto → pérdida
    expect(route(['PASAPORTE']), 'tramite_id');
    expect(route(['INVESTIGACION', 'FISCAL']), 'tramite_id');
    expect(route(['GESTIONAR', 'FOTOCOPIA', 'ORGANO_JUDICIAL']), 'tramite_id');
    expect(route(['INTERPRETE', 'INSTITUCION']), 'orientacion');
    expect(route(['HABLAR', 'ABOGADO']), 'orientacion');
    expect(route(['PERDER', 'CARNET']), 'perdida',
        reason: 'la pérdida ya no depende solo de que aparezca un objeto');
    // Consultas usa siempre el compositor de orientación, sin repartos.
    expect(resolveAssemblerContext('consulta', ['ESTADO'], catOf), 'orientacion');
    // Los contextos directos no se reenrutan.
    expect(resolveAssemblerContext('denuncia_robo', ['ROBAR'], catOf),
        'denuncia_robo');

    // 4) Cobertura end-to-end del contexto fusionado (las pruebas del enunciado).
    const asm = LocalSentenceAssembler();
    final mergedCases = <List<String>>[
      ['FALTA', 'TELEFONO', 'CALLE', 'AYER'], // documento/objeto perdido
      ['PAPEL', 'FALTA', 'POLICIA'],
      ['GESTIONAR', 'INVESTIGACION', 'FISCAL', 'INTERPRETE', 'HOY'],
      ['PEDIR', 'FOTOCOPIA', 'PODER', 'ORGANO_JUDICIAL', 'ABOGADO'],
      ['HABLAR', 'INTERPRETE', 'INSTITUCION'], // consulta / derechos
      ['PAPEL', 'INSTITUCION', 'AHORA'],
    ];
    const implicit = {'YO'};
    var missing = 0;
    for (final gl in mergedCases) {
      final ctx = route(gl);
      final out = asm.assemble(contextId: ctx, glosses: gl);
      final hay = _strip(out.toLowerCase());
      final miss = _joinSpelled(gl)
          .where((g) => !implicit.contains(g))
          .where((g) => !_covered(g, hay))
          .toList();
      missing += miss.length;
      // ignore: avoid_print
      print('[orientacion→$ctx] ${gl.join('+')}\n   → "$out"'
          '${miss.isEmpty ? '' : '\n   ✗ FALTAN: $miss'}\n');
    }
    expect(missing, 0, reason: 'El contexto fusionado pierde glosas.');
  });
}

// Sinónimos de lexema para glosas no cognadas con su forma en español.
const _synonyms = {
  // Glosas de una o dos letras: la regla de raíz de 3 no puede alcanzarlas.
  'SI': 'sí',
  'NO': 'no',
  'EL': 'él',
  'TU': 'tú',
  'YO': 'yo',
  // Corpus: la forma natural en español no comparte raíz con la glosa.
  'MAL': 'mal',
  'FALTA': 'falta',
  'HABLAR': 'habl',
  'PEDIR': 'solicit',
  'AUXILIO': 'auxilio',
  'ABUSO': 'agredi', // "agredió sexualmente"
  'PELO_CORTO': 'cabello',
  'PELO_LARGO': 'cabello',
  'BLANCO_PIEL': 'piel',
  'GORDO': 'robust',
  'MOCHILA_USADA': 'mochila',
  'TRES': 'personas',
  'DOS': 'personas',
  'SOLO': 'persona',
  'MAÑANA': 'mañana',
  'PEGAR': 'golpe',
  'PAPEL': 'documento',
  'DINERO': 'dinero',
};

/// Une las rachas de letras en la palabra que deletrean, igual que hace el
/// ensamblador. Sin esto la prueba buscaría cada letra por separado y daría
/// por perdida una palabra que sí está representada.
List<String> _joinSpelled(List<String> glosses) {
  final salida = <String>[];
  var i = 0;
  while (i < glosses.length) {
    final esLetra = RegExp(r'^[A-ZÑ]$');
    if (esLetra.hasMatch(glosses[i])) {
      var j = i;
      while (j < glosses.length && esLetra.hasMatch(glosses[j])) {
        j++;
      }
      if (j - i >= 2) {
        salida.add(glosses.sublist(i, j).join());
        i = j;
        continue;
      }
    }
    salida.add(glosses[i]);
    i++;
  }
  return salida;
}

bool _covered(String gloss, String hayLower) {
  final syn = _synonyms[gloss];
  if (syn != null && hayLower.contains(_strip(syn))) return true;
  final parts = _strip(gloss.toLowerCase())
      .split(RegExp(r'[ _/]+'))
      .where((p) => p.length >= 3);
  for (final p in parts) {
    // Raíz de 3 letras: tolera conjugación (robar/robó comparten "rob").
    final stem = p.length <= 3 ? p : p.substring(0, 3);
    if (hayLower.contains(stem)) return true;
  }
  return false;
}

String _strip(String input) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  var out = input;
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}
