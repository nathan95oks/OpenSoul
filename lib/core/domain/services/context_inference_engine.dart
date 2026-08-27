import 'dart:math' as math;

import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/services/context_catalog.dart';

class ContextInferenceEngine {
  final Map<String, Set<String>> _glossContexts;
  final Map<String, Set<String>> _contextStems;
  final List<String> _contextIds;
  final double minConfidence;

  const ContextInferenceEngine._({
    required Map<String, Set<String>> glossContexts,
    required Map<String, Set<String>> contextStems,
    required List<String> contextIds,
    required this.minConfidence,
  })  : _glossContexts = glossContexts,
        _contextStems = contextStems,
        _contextIds = contextIds;

  factory ContextInferenceEngine.empty() => ContextInferenceEngine._(
        glossContexts: const {},
        contextStems: const {},
        contextIds: const [],
        minConfidence: 1.0,
      );

  factory ContextInferenceEngine.fromLexicon(
    List<LsbCard> entries, {
    double minConfidence = 0.45,
  }) {
    final contextIds = [
      for (final c in availableContexts) c.id,
      identificacionContext.id,
    ];

    final sourceToUi = <String, Set<String>>{};
    for (final ui in contextIds) {
      for (final source in cardSourceContexts(ui)) {
        sourceToUi.putIfAbsent(source, () => <String>{}).add(ui);
      }
    }

    final glossContexts = <String, Set<String>>{};
    for (final entry in entries) {
      final uiContexts = <String>{
        for (final source in entry.contexts) ...?sourceToUi[source],
      };
      if (uiContexts.isEmpty) continue;
      glossContexts
          .putIfAbsent(entry.gloss.toUpperCase(), () => <String>{})
          .addAll(uiContexts);
    }

    final contextStems = <String, Set<String>>{
      for (final c in [...availableContexts, identificacionContext])
        c.id: _stemAll('${c.name} ${c.description}'),
    };

    return ContextInferenceEngine._(
      glossContexts: glossContexts,
      contextStems: contextStems,
      contextIds: contextIds,
      minConfidence: minConfidence,
    );
  }

  double _weightOf(String gloss) {
    final contexts = _glossContexts[gloss];
    if (contexts == null || contexts.isEmpty) return 0;
    return math.log(_contextIds.length / contexts.length);
  }

  ContextSuggestion? infer({
    List<String> glosses = const [],
    String text = '',
  }) {
    if (_contextIds.isEmpty) return null;

    final plano = _normalizeText(text);
    if (plano.isNotEmpty) {
      for (final rule in _hardRules) {
        final marca = rule.matchIn(plano);
        if (marca == null) continue;
        if (rule.contextId == null) return null;
        return ContextSuggestion(
          contextId: rule.contextId!,
          confidence: 1.0,
          evidence: [marca.toUpperCase()],
        );
      }
    }

    final scores = <String, double>{};
    final evidence = <String, Map<String, double>>{};

    void award(String contextId, String token, double weight,
        {bool asEvidence = true}) {
      if (weight <= 0) return;
      scores[contextId] = (scores[contextId] ?? 0) + weight;
      if (!asEvidence) return;
      final perContext = evidence.putIfAbsent(contextId, () => {});
      final previous = perContext[token] ?? 0;
      if (weight > previous) perContext[token] = weight;
    }

    for (final raw in glosses) {
      final gloss = raw.toUpperCase().trim();
      final weight = _weightOf(gloss);
      for (final contextId in _glossContexts[gloss] ?? const <String>{}) {
        award(contextId, gloss, weight);
      }
    }

    final textStems = _stemAll(text);
    if (textStems.isNotEmpty) {
      final stemToGloss = <String, String>{
        for (final gloss in _glossContexts.keys) ..._stemIndex(gloss),
      };
      for (final stem in textStems) {
        final gloss = stemToGloss[stem];
        if (gloss == null) continue;
        final weight = _weightOf(gloss) * _textSignalFactor;
        for (final contextId in _glossContexts[gloss] ?? const <String>{}) {
          award(contextId, gloss, weight);
        }
      }
      for (final entry in _contextStems.entries) {
        for (final stem in textStems) {
          if (entry.value.contains(stem)) {
            award(entry.key, stem, _contextNameWeight, asEvidence: false);
          }
        }
      }
    }

    if (scores.isEmpty) return null;

    final total = scores.values.reduce((a, b) => a + b);
    if (total <= 0) return null;

    if (evidence.isEmpty) return null;

    final ranked = scores.entries
        .where((e) => evidence.containsKey(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty) return null;
    final best = ranked.first;
    final confidence = best.value / total;
    if (confidence < minConfidence) return null;

    final tokens = (evidence[best.key] ?? const <String, double>{}).entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ContextSuggestion(
      contextId: best.key,
      confidence: confidence,
      evidence: [
        for (final t in tokens.take(3)) t.key.toUpperCase(),
      ],
    );
  }

  static const double _textSignalFactor = 0.6;
  static const double _contextNameWeight = 0.8;
}

class _HardRule {
  final List<String> markers;
  final String? contextId;

  const _HardRule(this.markers, this.contextId);

  String? matchIn(String haystack) {
    for (final m in markers) {
      if (haystack.contains(m)) return m;
    }
    return null;
  }
}

const List<_HardRule> _hardRules = [
  _HardRule([
    'nombre completo', 'cual es su nombre', 'cual es tu nombre',
    'como se llama', 'como te llamas', 'como se llaman',
    'su nombre', 'tu nombre', 'digame su nombre', 'apellido',
    'que edad', 'cuantos anos tiene', 'cuantos anos tienes', 'su edad',
    'tu edad', 'edad tiene', 'edad tienes',
    'su carnet', 'tu carnet', 'carnet de identidad', 'su cedula',
    'documento de identidad', 'su documento', 'tu documento',
    'mostrar su documento', 'identificarse', 'su identidad', 'identificarte',
  ], 'identificacion'),

  _HardRule([
    'que ocurrio', 'que paso', 'que sucedio', 'que le paso', 'que te paso',
    'que ha ocurrido', 'que le ocurrio', 'que te ocurrio',
    'cuando ocurrio', 'cuando fue', 'cuando paso', 'en que momento',
    'donde ocurrio', 'donde fue', 'donde paso', 'en que lugar',
    'conoce a la persona', 'conoces a la persona', 'la conoce', 'lo conoce',
    'conoce al agresor', 'persona involucrada',
    'describir a la persona', 'puede describir', 'como era la persona',
    'como era el', 'que aspecto',
    'hay testigos', 'algun testigo', 'habia testigos', 'hubo testigos',
    'tiene fotografias', 'tienes fotografias', 'tiene pruebas',
    'tienes pruebas', 'alguna prueba', 'tiene evidencia',
    'esta herido', 'estas herido', 'esta herida', 'atencion medica',
    'necesita un medico', 'necesita atencion',
    'desea realizar una denuncia', 'desea denunciar', 'quiere denunciar',
    'presentar una denuncia', 'realizar la denuncia',
    'apoyo legal', 'asistencia legal', 'necesita abogado',
    'necesita un abogado', 'defensa publica',
  ], null),
];

const List<String> _suffixes = [
  'aciones', 'iciones', 'aron', 'eron', 'ando', 'iendo', 'aba', 'ado',
  'ido', 'ion', 'ar', 'er', 'ir', 'on', 'os', 'as', 'es', 'a', 'e', 'o', 'n',
];

const int _minStemLength = 3;

String _removeAccents(String value) {
  const map = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  };
  var result = value;
  map.forEach((from, to) => result = result.replaceAll(from, to));
  return result;
}

String _normalizeText(String input) {
  final sinTildes = _removeAccents(input.toLowerCase());
  return sinTildes
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _stem(String word) {
  final normalized = _removeAccents(word.toLowerCase());
  for (final suffix in _suffixes) {
    if (normalized.length - suffix.length >= _minStemLength &&
        normalized.endsWith(suffix)) {
      return normalized.substring(0, normalized.length - suffix.length);
    }
  }
  return normalized;
}

const Set<String> _stopwords = {
  'como', 'cual', 'cuales', 'quien', 'quienes', 'donde', 'cuando', 'cuanto',
  'cuanta', 'cuantos', 'cuantas', 'porque', 'para', 'pero', 'esta', 'este',
  'esto', 'esos', 'esas', 'ese', 'eso', 'aqui', 'alli', 'sobre', 'desde',
  'hasta', 'entre', 'ante', 'tras', 'segun', 'sino', 'cada', 'todo', 'toda',
  'todos', 'todas', 'algo', 'alguno', 'alguna', 'algun', 'nada', 'nadie',
  'otro', 'otra', 'otros', 'otras', 'mismo', 'misma', 'tanto', 'tanta',
  'usted', 'ustedes', 'nosotros', 'ellos', 'ellas', 'suyo', 'suya',
  'tiene', 'tienes', 'tengo', 'tenia', 'tener', 'hacer', 'hace', 'haces',
  'puede', 'puedes', 'pueden', 'podria', 'quiere', 'quieres', 'quiero',
  'debe', 'debes', 'debo', 'estan', 'estoy', 'estar', 'estas',
  'seria', 'fueron', 'siendo', 'haber', 'habia', 'hubo', 'sera',
  'favor', 'gracias', 'senor', 'senora', 'senorita', 'buenos', 'buenas',
  'dias', 'tardes', 'noches', 'ahora', 'luego', 'entonces', 'tambien',
  'solo', 'muy', 'mas', 'menos', 'bien', 'alla',
};

Set<String> _stemAll(String text) {
  final words = _removeAccents(text.toLowerCase()).split(RegExp(r'[^a-z0-9_]+'));
  return {
    for (final word in words)
      if (word.length >= 4 && !_stopwords.contains(word)) _stem(word),
  };
}

Map<String, String> _stemIndex(String gloss) {
  final parts = gloss.split('_');
  return {
    for (final part in parts)
      if (part.length >= 4) _stem(part): gloss,
  };
}
