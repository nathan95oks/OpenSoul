import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/local_sentence_assembler.dart';

/// Auditoría de cobertura semántica del motor local.
/// Para cada caso comprueba que TODA glosa quede representada en el texto.
void main() {
  const asm = LocalSentenceAssembler();

  // Casos por contexto: mínimos, medios, complejos y selección múltiple.
  final cases = <(String, List<String>)>[
    // robo
    ('denuncia_robo', ['ROBAR']),
    ('denuncia_robo', ['HOMBRE', 'ROBAR', 'CELULAR']),
    ('denuncia_robo', ['HOMBRE', 'ALTO', 'TATUAJE', 'ROBAR', 'CELULAR', 'CALLE', 'NOCHE']),
    ('denuncia_robo', ['ROBAR', 'CELULAR', 'DINERO', 'POLICIA', 'MIEDO', 'HOY']),
    // violencia (ejemplos del usuario)
    ('violencia', ['AMENAZAR']),
    ('violencia', ['AMENAZAR', 'AYUDA', 'PELO_CORTO', 'POLICIA', 'ASUSTADO']),
    ('violencia', ['ABUSO', 'TATUAJE', 'DEFENSORIA', 'TRISTE', 'URGENTE', 'HOY']),
    ('violencia', ['GOLPEAR', 'HOMBRE', 'ALTO', 'MIEDO', 'POLICIA', 'ABOGADO']),
    // accidente
    ('accidente', ['DOLOR']),
    ('accidente', ['DOLOR', 'AMBULANCIA', 'CALLE', 'HOY']),
    ('accidente', ['DOLOR', 'ASUSTADO', 'AMBULANCIA', 'HOSPITAL', 'URGENTE']),
    // emergencia
    ('emergencia', ['EMERGENCIA']),
    ('emergencia', ['ENFERMO', 'AMBULANCIA', 'URGENTE', 'HOSPITAL']),
    // documentos / trámite (contexto judicial ampliado)
    ('tramite_id', ['TRAMITAR', 'CARNET', 'SEGIP']),
    ('tramite_id', ['RENOVAR', 'LICENCIA', 'PAGO', 'SEGIP', 'HIJO']),
    ('tramite_id', ['ANTECEDENTES', 'FISCALIA']),
    ('tramite_id', ['TRAMITAR', 'ANTECEDENTES', 'DENUNCIA', 'FISCALIA', 'INTERPRETE', 'HOY']),
    ('tramite_id', ['SOLICITAR', 'COPIA_DENUNCIA', 'PODER', 'JUZGADO', 'ABOGADO']),
    ('tramite_id', ['CORREGIR', 'DECLARACION_JURADA', 'NOTARIA', 'HIJO', 'AHORA']),
    // orientación / asistencia legal
    ('orientacion', ['ABOGADO', 'DEFENSORIA']),
    ('orientacion', ['CONSULTAR', 'INTERPRETE', 'DEFENSORIA', 'HOY']),
    // pérdida de documentos
    ('perdida', ['PERDER', 'CARNET']),
    ('perdida', ['DOCUMENTO', 'CALLE', 'AYER', 'POLICIA', 'URGENTE']),
    // testigo
    ('otro', ['ROBAR']),
    ('otro', ['HOMBRE', 'TATUAJE', 'GOLPEAR', 'CALLE', 'NOCHE', 'DEFENSORIA']),
  ];

  // Glosas inherentemente implícitas (1ª persona) que no exigen aparición literal.
  const implicit = {'YO'};

  test('cobertura semántica por contexto', () {
    var totalMissing = 0;
    for (final (ctx, glosses) in cases) {
      final out = asm.assemble(contextId: ctx, glosses: glosses);
      final hay = _strip(out.toLowerCase());
      final missing = glosses
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
}

// Sinónimos de lexema para glosas no cognadas con su forma en español.
const _synonyms = {
  'ABUSO': 'agredi', // "agredió sexualmente"
  'PELO_CORTO': 'cabello',
  'PELO_LARGO': 'cabello',
  'BLANCO_PIEL': 'piel',
  'GORDO': 'robust',
  'MASCARA': 'rostro',
  'MOCHILA_USADA': 'mochila',
  'TRES_MAS': 'personas',
  'DOS': 'personas',
  'SOLO': 'persona',
  'MAÑANA': 'mañana',
};

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
