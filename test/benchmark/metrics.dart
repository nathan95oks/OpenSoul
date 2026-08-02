/// Métricas de evaluación de una declaración generada.
///
/// Se dividen en dos familias porque tienen costes muy distintos:
///
/// - **Sin referencia** (cobertura, buena formación, glosas crudas): se
///   calculan hoy, sobre cualquier salida, sin necesidad de que un humano
///   escriba nada. Dan cifras comparables entre motor local, remoto e híbrido.
/// - **Con referencia** (coincidencia exacta, F1 por palabra): solo para los
///   casos del corpus con estándar de oro validado por una persona.
library;

/// Resultado de evaluar una sola declaración.
class CaseScore {
  final String label;
  final String output;

  /// Glosas que no aparecen representadas en el texto.
  final List<String> missingGlosses;

  /// Glosas que aparecen crudas, en mayúsculas, dentro del texto. Delatan
  /// que el generador se rindió y concatenó en vez de redactar.
  final List<String> rawGlosses;

  /// Defectos duros de forma: dejan la declaración inservible como documento
  /// (vacía, sin mayúscula inicial, sin cierre, espaciado roto).
  final List<String> formIssues;

  /// Defectos de estilo: el texto es válido pero se lee mal.
  final List<String> styleIssues;

  /// Glosas exigibles en el texto (excluye las implícitas de 1ª persona).
  final int evaluatedGlosses;

  /// Coincidencia exacta con la referencia, o `null` si no hay referencia.
  final bool? exactMatch;

  /// F1 por palabra contra la referencia, o `null` si no hay referencia.
  final double? tokenF1;

  const CaseScore({
    required this.label,
    required this.output,
    required this.missingGlosses,
    required this.rawGlosses,
    required this.formIssues,
    required this.styleIssues,
    required this.evaluatedGlosses,
    this.exactMatch,
    this.tokenF1,
  });

  bool get covers => missingGlosses.isEmpty;
  bool get wellFormed => formIssues.isEmpty && rawGlosses.isEmpty;
  bool get clean => wellFormed && styleIssues.isEmpty;
}

/// Agregado de todos los casos de una vía de generación.
class BenchmarkReport {
  /// Vía evaluada: 'motor local', 'Bedrock', 'híbrido'.
  final String variant;
  final List<CaseScore> scores;

  const BenchmarkReport({required this.variant, required this.scores});

  int get total => scores.length;
  int get covered => scores.where((s) => s.covers).length;
  int get wellFormed => scores.where((s) => s.wellFormed).length;
  int get clean => scores.where((s) => s.clean).length;

  double get coverageRate => total == 0 ? 0 : covered / total;
  double get wellFormedRate => total == 0 ? 0 : wellFormed / total;

  /// Sin defectos de ningún tipo, ni siquiera de estilo.
  double get cleanRate => total == 0 ? 0 : clean / total;

  /// Glosas representadas sobre el total de glosas del corpus. Es una medida
  /// más fina que [coverageRate]: distingue perder una glosa de perder cinco.
  double get glossRecall {
    var lost = 0;
    var total = 0;
    for (final s in scores) {
      lost += s.missingGlosses.length;
      total += s.evaluatedGlosses;
    }
    return total == 0 ? 0 : (total - lost) / total;
  }

  List<CaseScore> get withReference =>
      scores.where((s) => s.exactMatch != null).toList();

  double? get exactMatchRate {
    final refs = withReference;
    if (refs.isEmpty) return null;
    return refs.where((s) => s.exactMatch == true).length / refs.length;
  }

  double? get averageTokenF1 {
    final refs = withReference;
    if (refs.isEmpty) return null;
    final sum = refs.fold<double>(0, (a, s) => a + (s.tokenF1 ?? 0));
    return sum / refs.length;
  }
}

/// Sinónimos de lexema para glosas que no comparten raíz con su forma en
/// español.
///
/// Incluye el **registro jurídico formal** que emplea el refinador remoto
/// ("sustrajo" por ROBAR, "individuo" por HOMBRE). Sin ellos la comparación
/// estaría sesgada a favor del motor local, que redacta con el mismo léxico
/// de las glosas: se estarían contando como pérdidas paráfrasis correctas.
/// Solo se admiten equivalencias que no alteran el contenido declarado —
/// "madrugada" por NOCHE, por ejemplo, NO está aquí: cambia el hecho.
const _synonyms = {
  'ABUSO': 'agredi',
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
  'PEDIR': 'solicitar',
  'DINERO': 'dinero',
};

/// Segunda forma admisible de una glosa, propia del registro jurídico formal.
/// Se consulta además de [_synonyms] (una glosa puede tener las dos).
const _formalRegister = {
  'ROBAR': 'sustra', // sustrajo / sustracción
  'HOMBRE': 'individuo',
  'MIEDO': 'temor',
  'ASUSTADO': 'temor',
  'ALTO': 'estatura',
  'CALLE': 'via publica',
  'CELULAR': 'telefono',
  'AMENAZAR': 'amenaz',
  'AYUDA': 'asistencia',
};

/// Glosas de primera persona: el español las expresa con la conjugación, no
/// con una palabra, así que no se exige su aparición literal.
const implicitGlosses = {'YO'};

/// Siglas de instituciones bolivianas que en español se escriben en
/// mayúsculas: verlas así en el texto es correcto, no una glosa sin redactar.
const institutionalAcronyms = {'SEGIP', 'FELCC', 'SLIM', 'DNA', 'IDIF'};

String stripAccents(String input) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  var out = input;
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}

bool glossCovered(String gloss, String textLower) {
  final hay = stripAccents(textLower);
  for (final table in [_synonyms, _formalRegister]) {
    final syn = table[gloss];
    if (syn != null && hay.contains(stripAccents(syn))) return true;
  }
  final parts = stripAccents(gloss.toLowerCase())
      .split(RegExp(r'[ _/]+'))
      .where((p) => p.length >= 3);
  for (final p in parts) {
    final stem = p.length <= 3 ? p : p.substring(0, 3);
    if (hay.contains(stem)) return true;
  }
  return false;
}

/// Evalúa una declaración generada contra sus glosas de origen.
CaseScore scoreOutput({
  required String label,
  required String output,
  required List<String> glosses,
  String reference = '',
}) {
  final lower = output.toLowerCase();

  final evaluated =
      glosses.where((g) => !implicitGlosses.contains(g)).toList();
  final missing = evaluated.where((g) => !glossCovered(g, lower)).toList();

  // Una glosa cruda en el texto (ROBAR, COPIA_DENUNCIA) significa que no se
  // redactó: se volcó el símbolo tal cual. Las siglas quedan fuera porque en
  // español van en mayúsculas de forma legítima ("en el SEGIP").
  final raw = glosses
      .where((g) => g.length > 2 && !institutionalAcronyms.contains(g))
      .where(output.contains)
      .toList();

  // Defectos duros: hacen que la declaración no sirva como documento.
  final form = <String>[];
  // Defectos de estilo: se leen mal, pero el texto es válido. Se reportan
  // aparte para no mezclar "inservible" con "mejorable".
  final style = <String>[];

  final trimmed = output.trim();
  if (trimmed.isEmpty) {
    form.add('vacía');
  } else {
    if (trimmed[0] != trimmed[0].toUpperCase()) form.add('sin mayúscula inicial');
    if (!RegExp(r'[.!?]$').hasMatch(trimmed)) form.add('sin cierre');
    if (trimmed.contains('  ')) form.add('espacios dobles');
    if (RegExp(r'\s,|\s\.').hasMatch(trimmed)) form.add('espacio antes de puntuación');
    final words = stripAccents(lower).split(RegExp(r'[^a-z0-9]+'))
      ..removeWhere((w) => w.isEmpty);
    for (var i = 1; i < words.length; i++) {
      if (words[i] == words[i - 1] && words[i].length > 2) {
        style.add('palabra repetida "${words[i]}"');
        break;
      }
    }
  }

  bool? exact;
  double? f1;
  if (reference.trim().isNotEmpty) {
    exact = _normalize(output) == _normalize(reference);
    f1 = _tokenF1(output, reference);
  }

  return CaseScore(
    label: label,
    output: output,
    missingGlosses: missing,
    rawGlosses: raw,
    formIssues: form,
    styleIssues: style,
    evaluatedGlosses: evaluated.length,
    exactMatch: exact,
    tokenF1: f1,
  );
}

String _normalize(String s) => stripAccents(s.toLowerCase())
    .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<String> _tokens(String s) =>
    _normalize(s).split(' ').where((t) => t.isNotEmpty).toList();

/// F1 por palabra: mide solapamiento de vocabulario sin exigir el mismo
/// orden. Más informativo que la coincidencia exacta cuando hay varias
/// redacciones válidas para el mismo contenido.
double _tokenF1(String output, String reference) {
  final a = _tokens(output);
  final b = _tokens(reference);
  if (a.isEmpty || b.isEmpty) return 0;

  final remaining = [...b];
  var hits = 0;
  for (final token in a) {
    final i = remaining.indexOf(token);
    if (i >= 0) {
      hits++;
      remaining.removeAt(i);
    }
  }
  if (hits == 0) return 0;
  final precision = hits / a.length;
  final recall = hits / b.length;
  return 2 * precision * recall / (precision + recall);
}
