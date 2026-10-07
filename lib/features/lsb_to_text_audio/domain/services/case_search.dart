import 'dart:math' as math;

import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/rag/rag_tramites.dart';

/// Qué abre un resultado del buscador.
enum CaseHitKind {
  /// Una familia del menú (Denuncias, Trámites…).
  family,

  /// Una institución dentro de Trámites (SEGIP, SERECI…).
  section,

  /// Un caso: entra directo a sus preguntas.
  context,
}

/// Algo que se puede encontrar con el buscador de la selección de contexto.
class CaseSearchEntry {
  final CaseHitKind kind;

  /// Id de la familia, de la sección o del contexto.
  final String id;
  final String title;
  final String subtitle;
  final String emoji;

  /// El grupo en el que se muestra: la familia o la institución del caso.
  final String groupId;
  final String groupName;
  final String groupEmoji;

  /// Lo que dice el grupo de sí mismo (la descripción de la institución):
  /// también encuentra al caso («impuesto moto» → deuda de moto).
  final String groupDescription;

  /// La familia (y en Trámites, la institución) a la que pertenece.
  final String? familyId;
  final String? sectionId;

  /// Lo que se pregunta y se responde dentro del caso: también se busca
  /// ahí («celular» encuentra «Denunciar robo»).
  final List<String> content;

  /// El caso que abre (solo [CaseHitKind.context]).
  final SemanticContext? context;

  /// La familia o la institución que abre ([CaseHitKind.family] y
  /// [CaseHitKind.section]).
  final ContextFamily? family;

  const CaseSearchEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.groupId,
    required this.groupName,
    required this.groupEmoji,
    this.groupDescription = '',
    this.familyId,
    this.sectionId,
    this.content = const [],
    this.context,
    this.family,
  });
}

/// Un resultado: la entrada, cuánto coincide y, si se encontró por lo que
/// hay dentro del caso, la frase que coincidió.
class CaseSearchHit {
  final CaseSearchEntry entry;
  final double score;
  final String? snippet;

  const CaseSearchHit(this.entry, this.score, {this.snippet});
}

/// Los resultados de un grupo (una familia o una institución), en orden.
class CaseSearchGroup {
  final String id;
  final String name;
  final String emoji;
  final List<CaseSearchHit> hits;

  const CaseSearchGroup({
    required this.id,
    required this.name,
    required this.emoji,
    required this.hits,
  });
}

/// Buscador de la selección de contexto del módulo de tarjetas LSB.
///
/// Filtra poco a poco, como el buscador del sistema: cada palabra escrita
/// debe aparecer (por su comienzo) en el nombre, la descripción o lo que se
/// pregunta y responde dentro del caso. Sin tildes ni mayúsculas, y con un
/// error de tipeo de margen en palabras largas («selular»).
class CaseSearch {
  final List<CaseSearchEntry> entries;
  late final List<_Indexed> _index = [for (final e in entries) _Indexed(e)];

  CaseSearch(this.entries);

  /// El índice de la app: familias, instituciones de Trámites y casos, con
  /// lo que pregunta y responde cada uno según [bank].
  factory CaseSearch.fromCatalog(QuestionBank bank) {
    final entries = <CaseSearchEntry>[];
    const secciones = ('secciones', 'Secciones', '🗂️');
    for (final f in contextFamilies) {
      entries.add(
        CaseSearchEntry(
          kind: CaseHitKind.family,
          id: f.id,
          title: f.name,
          subtitle: f.description,
          emoji: f.emoji,
          groupId: secciones.$1,
          groupName: secciones.$2,
          groupEmoji: secciones.$3,
          familyId: f.id,
          family: f,
        ),
      );
    }
    final tramites = contextFamilies.where((f) => f.id == 'tramites');
    final familiaTramites = tramites.isEmpty ? null : tramites.first;
    for (final s in RagTramites.sections) {
      entries.add(
        CaseSearchEntry(
          kind: CaseHitKind.section,
          id: s.id,
          title: s.name,
          subtitle: s.description,
          emoji: s.emoji,
          groupId: secciones.$1,
          groupName: secciones.$2,
          groupEmoji: secciones.$3,
          familyId: familiaTramites?.id,
          sectionId: s.id,
          family: s,
        ),
      );
    }

    final seccionDe = <String, ContextFamily>{
      for (final s in RagTramites.sections)
        for (final id in s.contextIds) id: s,
    };
    final vistos = <String>{};
    for (final f in contextFamilies) {
      for (final c in contextsOfFamily(f)) {
        if (!vistos.add(c.id)) continue;
        final s = seccionDe[c.id];
        entries.add(
          CaseSearchEntry(
            kind: CaseHitKind.context,
            id: c.id,
            title: c.name,
            subtitle: c.description,
            emoji: c.emoji,
            groupId: s?.id ?? f.id,
            groupName: s == null ? f.name : '${f.name} · ${s.name}',
            groupEmoji: s?.emoji ?? f.emoji,
            groupDescription: s?.description ?? '',
            familyId: f.id,
            sectionId: s?.id,
            content: _contentOf(bank, c.id),
            context: c,
          ),
        );
      }
    }
    return CaseSearch(entries);
  }

  /// Las preguntas del recorrido de [contextId] y sus respuestas.
  static List<String> _contentOf(QuestionBank bank, String contextId) {
    final journey = bank.journey(contextId);
    if (journey == null) return const [];
    final out = <String>{};
    for (final step in journey.steps) {
      final q = bank.question(step.questionId);
      if (q == null) continue;
      out.add(q.formulation);
      for (final o in q.options) {
        out
          ..add(o.label)
          ..add(o.phrase);
      }
    }
    out.removeWhere((t) => t.trim().isEmpty);
    return out.toList();
  }

  /// Máximo de resultados por grupo: más que eso ya no es «directo».
  static const maxPerGroup = 6;

  /// Los resultados de [query], agrupados. Vacío si no hay qué buscar.
  List<CaseSearchGroup> search(String query, {int perGroup = maxPerGroup}) {
    final tokens = queryTokens(query);
    if (tokens.isEmpty) return const [];
    var hits = _hits(tokens, tolerante: false);
    // Sin nada exacto, lo que se le parece: «selular» encuentra «celular».
    if (hits.isEmpty) hits = _hits(tokens, tolerante: true);
    hits.sort((a, b) => b.score.compareTo(a.score));

    final grupos = <String, List<CaseSearchHit>>{};
    for (final h in hits) {
      final lista = grupos.putIfAbsent(h.entry.groupId, () => []);
      if (lista.length < perGroup) lista.add(h);
    }
    // Primero las secciones (llevan a una lista), luego los casos por su
    // mejor resultado.
    final orden = grupos.keys.toList()
      ..sort((a, b) {
        if (a == 'secciones') return -1;
        if (b == 'secciones') return 1;
        return grupos[b]!.first.score.compareTo(grupos[a]!.first.score);
      });
    return [
      for (final id in orden)
        CaseSearchGroup(
          id: id,
          name: grupos[id]!.first.entry.groupName,
          emoji: grupos[id]!.first.entry.groupEmoji,
          hits: grupos[id]!,
        ),
    ];
  }

  List<CaseSearchHit> _hits(List<String> tokens, {required bool tolerante}) => [
    for (final item in _index) ?item.match(tokens, tolerante: tolerante),
  ];

  /// Las palabras de [query] que cuentan, normalizadas. Las muy comunes
  /// («de», «mi», «el») no filtran nada.
  static List<String> queryTokens(String query) => [
    for (final w in normalize(query).split(_noPalabra))
      if (w.isNotEmpty && !_vacias.contains(w)) w,
  ];

  static const _vacias = {
    'a', 'al', 'de', 'del', 'el', 'la', 'las', 'lo', 'los', 'un', 'una', //
    'unos', 'unas', 'y', 'o', 'e', 'en', 'mi', 'mis', 'me', 'por', 'para', //
    'con', 'que', 'se', 'su', 'sus', 'tu', 'yo', 'es', 'si', 'no',
  };

  static final _noPalabra = RegExp(r'[^a-z0-9ñ]+');

  /// Cómo se dice en la calle lo que los casos dicen de otra forma. Solo
  /// amplía la búsqueda: no cambia ningún dato del caso.
  static const _coloquiales = {
    'plata': ['dinero'],
    'platita': ['dinero'],
    'celu': ['celular'],
    'carnet': ['cedula'],
    'ci': ['cedula'],
    'pego': ['violencia', 'golpe'],
    'pegaron': ['violencia', 'golpe'],
    'pegan': ['violencia', 'golpe'],
    'pegar': ['violencia', 'golpe'],
    // «Acoso» también es el que va por internet («ciberacoso»).
    'acoso': ['ciberacoso'],
    'acosa': ['acoso', 'ciberacoso'],
    'acosan': ['acoso', 'ciberacoso'],
    'acosar': ['acoso', 'ciberacoso'],
    'bulling': ['bullying'],
    'buling': ['bullying'],
    'ciberbullying': ['ciberacoso'],
    'discriminacion': ['discriminatorio'],
    'discrimina': ['discriminatorio'],
  };

  /// Terminaciones de verbos y plurales, de la más larga a la más corta.
  static const _terminaciones = [
    'ieron', 'aron', 'eron', 'iendo', 'ando', 'aban', 'ados', 'adas', //
    'idos', 'idas', 'ado', 'ada', 'ido', 'ida', 'aba', 'ar', 'er', 'ir', //
    'an', 'en', 'as', 'es', 'os', 'o', 'a', 'e', 's',
  ];

  static final Map<String, List<(String, double)>> _formas = {};

  /// Las formas con las que se busca [token], con su peso: él mismo (1), su
  /// raíz en palabras conjugadas («robaron» → «rob», 0.9) y lo que dice
  /// [_coloquiales] (0.9).
  static List<(String, double)> formsOf(String token) =>
      _formas.putIfAbsent(token, () {
        final out = <(String, double)>[(token, 1)];
        if (token.length >= 6) {
          for (final t in _terminaciones) {
            if (!token.endsWith(t)) continue;
            final raiz = token.substring(0, token.length - t.length);
            if (raiz.length >= 4 || (raiz.length == 3 && token.length >= 7)) {
              out.add((raiz, 0.9));
            }
            break;
          }
        }
        for (final s in _coloquiales[token] ?? const <String>[]) {
          out.add((s, 0.9));
        }
        return out;
      });

  /// Minúsculas y sin tildes, letra por letra: el texto normalizado mide lo
  /// mismo que el original, así una coincidencia se puede resaltar.
  static String normalize(String text) {
    final b = StringBuffer();
    for (final ch in text.toLowerCase().split('')) {
      b.write(_sinTilde[ch] ?? ch);
    }
    return b.toString();
  }

  static const _sinTilde = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', //
    'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
  };

  /// Dónde aparece cada palabra de [query] en [text] (por su comienzo), para
  /// resaltarla. Rangos `[inicio, fin)` sobre [text], ordenados y sin
  /// solaparse.
  static List<(int, int)> highlights(String text, String query) {
    final tokens = queryTokens(query);
    if (tokens.isEmpty) return const [];
    final plano = normalize(text);
    final rangos = <(int, int)>[];
    for (final w in _wordsOf(plano)) {
      for (final t in tokens) {
        for (final (f, _) in formsOf(t)) {
          if (w.$2.startsWith(f)) rangos.add((w.$1, w.$1 + f.length));
        }
      }
    }
    rangos.sort((a, b) => a.$1.compareTo(b.$1));
    final unidos = <(int, int)>[];
    for (final r in rangos) {
      if (unidos.isNotEmpty && r.$1 <= unidos.last.$2) {
        unidos.last = (unidos.last.$1, math.max(unidos.last.$2, r.$2));
      } else {
        unidos.add(r);
      }
    }
    return unidos;
  }

  /// Las palabras de un texto normalizado, con su posición.
  static Iterable<(int, String)> _wordsOf(String plano) sync* {
    for (final m in RegExp(r'[a-z0-9ñ]+').allMatches(plano)) {
      yield (m.start, m.group(0)!);
    }
  }
}

/// Una entrada con sus textos ya normalizados.
class _Indexed {
  final CaseSearchEntry entry;
  late final List<String> _title = _words(entry.title);
  late final List<String> _subtitle = _words(entry.subtitle);
  late final List<String> _group = _words(
    '${entry.groupName} ${entry.groupDescription}',
  );
  late final List<List<String>> _content = [
    for (final c in entry.content) _words(c),
  ];

  _Indexed(this.entry);

  static List<String> _words(String text) => [
    for (final w in CaseSearch._wordsOf(CaseSearch.normalize(text))) w.$2,
  ];

  /// Cuánto se parece [token] a una de [words]: 1 si una empieza por él (o
  /// por una de sus [CaseSearch.formsOf]), 0 si nada. Con [tolerante], también por cómo suena (0.8) o con un error
  /// de tipeo en palabras de 5 letras o más (0.6).
  static double _fit(
    String token,
    List<String> words, {
    bool tolerante = false,
  }) {
    var best = 0.0;
    final formas = CaseSearch.formsOf(token);
    final fonToken = tolerante ? _fonetica(token) : '';
    for (final w in words) {
      var exacta = 0.0;
      for (final (f, peso) in formas) {
        if (w.startsWith(f)) {
          // La palabra entera vale un poco más que su comienzo.
          exacta = math.max(exacta, (w.length == f.length ? 1.15 : 1.0) * peso);
        }
      }
      if (exacta > 0) {
        best = math.max(best, exacta);
      } else if (tolerante && token.length >= 3) {
        final fonW = _fonetica(w);
        if (fonW.startsWith(fonToken)) {
          best = math.max(best, 0.8);
        } else if (token.length >= 5 && fonW.length >= fonToken.length - 1) {
          final prefijo = fonW.substring(
            0,
            math.min(fonW.length, fonToken.length),
          );
          if (_distancia(fonToken, prefijo) <= 1) best = math.max(best, 0.6);
        }
      }
    }
    return best;
  }

  /// Cómo suena una palabra, para los errores de ortografía más comunes:
  /// c/s/z, qu/k, v/b, ll/y y la h muda.
  static String _fonetica(String w) => w
      .replaceAll('ll', 'y')
      .replaceAll('qu', 'k')
      .replaceAllMapped(RegExp('c(?=[ei])'), (_) => 's')
      .replaceAll('c', 'k')
      .replaceAll('z', 's')
      .replaceAll('v', 'b')
      .replaceAll('h', '');

  CaseSearchHit? match(List<String> tokens, {bool tolerante = false}) {
    var total = 0.0;
    var porContenido = false;
    for (final t in tokens) {
      final enTitulo = _fit(t, _title, tolerante: tolerante) * 10;
      final enSubtitulo = _fit(t, _subtitle, tolerante: tolerante) * 6;
      final enGrupo = _fit(t, _group, tolerante: tolerante) * 3;
      var enContenido = 0.0;
      // Las respuestas genéricas («Sí», «No sé») están en todos los casos:
      // en el contenido solo cuenta una palabra de 3 letras o más.
      if (t.length >= 3) {
        for (final c in _content) {
          final v = _fit(t, c, tolerante: tolerante) * 2;
          if (v > enContenido) enContenido = v;
        }
      }
      final mejor = [
        enTitulo,
        enSubtitulo,
        enGrupo,
        enContenido,
      ].reduce(math.max);
      if (mejor == 0) return null;
      if (mejor == enContenido &&
          enContenido > 0 &&
          enTitulo == 0 &&
          enSubtitulo == 0) {
        porContenido = true;
      }
      total += mejor;
    }
    return CaseSearchHit(
      entry,
      total,
      snippet: porContenido ? _snippet(tokens, tolerante) : null,
    );
  }

  /// La frase del caso que más palabras de la búsqueda tiene (la más corta,
  /// si empatan).
  String? _snippet(List<String> tokens, bool tolerante) {
    String? mejor;
    var puntos = 0;
    for (var i = 0; i < _content.length; i++) {
      final p = tokens
          .where((t) => _fit(t, _content[i], tolerante: tolerante) > 0)
          .length;
      if (p > puntos ||
          (p == puntos &&
              p > 0 &&
              entry.content[i].length < (mejor?.length ?? 1 << 20))) {
        puntos = p;
        mejor = entry.content[i];
      }
    }
    return mejor;
  }

  /// Distancia de edición con trasposiciones (Damerau, versión simple).
  static int _distancia(String a, String b) {
    final d = List.generate(
      a.length + 1,
      (i) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final costo = a[i - 1] == b[j - 1] ? 0 : 1;
        var v = math.min(
          math.min(d[i - 1][j] + 1, d[i][j - 1] + 1),
          d[i - 1][j - 1] + costo,
        );
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          v = math.min(v, d[i - 2][j - 2] + 1);
        }
        d[i][j] = v;
      }
    }
    return d[a.length][b.length];
  }
}
