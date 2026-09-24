import 'dart:convert';

import 'package:lsb_legal_app/core/domain/entities/dialogue_node.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';

/// El banco de nodos conversacionales, con su emparejamiento.
///
/// Los datos salen de `assets/dialogue/dialogue_graph.json`, generado por
/// `tool/build_dialogue_graph.py` desde el corpus maestro. Aquí no se inventa
/// vocabulario: cada nodo trae ya resueltas sus opciones contra el catálogo
/// que carga la app, y las que no resolvieron viajan aparte, en
/// [DialogueNode.pendingOptions], para poder decir qué falta en vez de
/// simularlo.
///
/// Varias frases distintas pueden abrir la misma intención, y una misma
/// intención tiene nodos en varios ámbitos. El emparejamiento es por
/// similitud léxica sobre el enunciado real, no por un índice de frases
/// exactas: el oyente escribe lo que quiere, no lo que está en la tabla.
class DialogueGraph {
  final int version;
  final String generatedFrom;
  final List<DialogueNode> nodes;

  late final Map<String, DialogueNode> _byId = {
    for (final n in nodes) n.id: n,
  };

  DialogueGraph({
    required this.version,
    required this.nodes,
    this.generatedFrom = '',
  });

  static final DialogueGraph empty =
      DialogueGraph(version: 0, nodes: const []);

  factory DialogueGraph.fromJsonString(String raw) =>
      DialogueGraph.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  factory DialogueGraph.fromJson(Map<String, dynamic> json) => DialogueGraph(
        version: (json['version'] as num?)?.toInt() ?? 0,
        generatedFrom: (json['generatedFrom'] ?? '').toString(),
        nodes: [
          for (final n in (json['nodes'] as List? ?? const []))
            DialogueNode.fromJson(Map<String, dynamic>.from(n as Map)),
        ],
      );

  bool get isEmpty => nodes.isEmpty;

  DialogueNode? byId(String id) => _byId[id];

  List<DialogueNode> get all => List.unmodifiable(nodes);

  List<DialogueNode> forIntent(String intent) =>
      [for (final n in nodes) if (n.intent == intent) n];

  /// El nodo que mejor corresponde a [text], o `null` si nada encaja con
  /// seguridad suficiente.
  ///
  /// Devolver `null` es una respuesta válida y frecuente: el español libre no
  /// tiene por qué caber en un banco finito, y forzarlo a un nodo cercano es
  /// justamente lo que hace que se ofrezcan opciones que no responden nada.
  DialogueMatch? match(
    String text, {
    required CardsFlowPurpose mode,
    String? scope,
    double threshold = 0.34,
  }) {
    final wanted = _tokens(text);
    if (wanted.isEmpty) return null;

    DialogueMatch? best;
    for (final node in nodes) {
      if (!node.modes.contains(mode)) continue;

      final nodeTokens = _tokens(node.phrase);
      if (nodeTokens.isEmpty) continue;

      final shared = wanted.intersection(nodeTokens).length;
      if (shared == 0) continue;

      // Dice-Sørensen: premia coincidir sin castigar que la frase real sea
      // más larga que la del corpus, que es lo normal al hablar.
      var score = 2 * shared / (wanted.length + nodeTokens.length);

      // Estar en el ámbito que el chat ya traía desempata, pero no manda:
      // cambiar de tema a mitad de conversación es legítimo.
      if (scope != null && node.scope == scope) score += 0.08;

      if (best == null || score > best.score) {
        best = DialogueMatch(node: node, score: score, sharedTokens: shared);
      }
    }

    if (best == null || best.score < threshold) return null;
    return best;
  }

  /// Las intenciones candidatas cuando nada encaja con seguridad, para poder
  /// preguntar en vez de adivinar.
  List<DialogueNode> candidates(
    String text, {
    required CardsFlowPurpose mode,
    int limit = 3,
  }) {
    final wanted = _tokens(text);
    if (wanted.isEmpty) return const [];

    final scored = <MapEntry<DialogueNode, double>>[];
    final seenIntents = <String>{};
    for (final node in nodes) {
      if (!node.modes.contains(mode)) continue;
      final nodeTokens = _tokens(node.phrase);
      final shared = wanted.intersection(nodeTokens).length;
      if (shared == 0) continue;
      scored.add(MapEntry(node, 2 * shared / (wanted.length + nodeTokens.length)));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));

    final out = <DialogueNode>[];
    for (final e in scored) {
      if (!seenIntents.add(e.key.intent)) continue;
      out.add(e.key);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Los nodos a los que se puede seguir desde [node], ya resueltos.
  List<DialogueNode> nextFrom(DialogueNode node, {Set<String> answered = const {}}) {
    final out = <DialogueNode>[];
    for (final t in node.transitions) {
      final target = _byId[t.to];
      if (target == null) continue;
      // Una ranura ya respondida no vuelve a proponerse como siguiente paso.
      if (target.slots.every(answered.contains)) continue;
      out.add(target);
    }
    return out;
  }

  static const _stopwords = {
    'de', 'la', 'el', 'los', 'las', 'un', 'una', 'unos', 'unas', 'y', 'o',
    'que', 'en', 'a', 'al', 'del', 'se', 'su', 'sus', 'le', 'lo', 'me', 'mi',
    'es', 'esta', 'con', 'por', 'para', 'usted', 'si', 'no', 'mas', 'este',
    'ese', 'esa', 'tu', 'te', 'ya', 'ha', 'he', 'fue',
  };

  static Set<String> _tokens(String text) {
    final clean = _unaccent(text.toLowerCase())
        .replaceAll(RegExp(r'[^a-z0-9ñ ]'), ' ');
    return {
      for (final w in clean.split(RegExp(r'\s+')))
        if (w.length > 3 && !_stopwords.contains(w)) _stem(w),
    };
  }

  /// Raíz pobre pero suficiente: recorta los finales que más ruido meten al
  /// comparar («robaron» / «robado» / «robar», «fotos» / «fotografías»).
  static String _stem(String w) {
    for (final suffix in const [
      'aciones', 'iciones', 'amiento', 'aron', 'aban', 'ando', 'iendo',
      'ados', 'idos', 'adas', 'idas', 'ado', 'ido', 'ada', 'ida', 'ar',
      'er', 'ir', 'es', 's',
    ]) {
      if (w.length > suffix.length + 3 && w.endsWith(suffix)) {
        return w.substring(0, w.length - suffix.length);
      }
    }
    return w;
  }

  static String _unaccent(String s) {
    const from = 'áàäâéèëêíìïîóòöôúùüû';
    const to = 'aaaaeeeeiiiioooouuuu';
    var out = s;
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }
}

class DialogueMatch {
  final DialogueNode node;
  final double score;
  final int sharedTokens;

  const DialogueMatch({
    required this.node,
    required this.score,
    required this.sharedTokens,
  });
}
