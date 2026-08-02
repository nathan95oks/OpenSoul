import 'dart:math' as math;

import '../../domain/entities/context_suggestion.dart';
import '../../domain/entities/lsb_card.dart';
import 'context_catalog.dart';

/// Infiere el contexto situacional de un enunciado de la persona oyente.
///
/// Es la pieza que cierra el ciclo conversacional: sin ella, el turno del
/// oyente muere en el avatar y la persona sorda debe volver a declarar desde
/// cero de qué se está hablando.
///
/// **No usa una lista de palabras clave escrita a mano.** El corpus es el
/// propio diccionario evolutivo, donde cada entrada ya declara los contextos
/// en los que aplica ([LsbCard.contexts]). Cada glosa se pondera por su poder
/// discriminativo (IDF): una que aparece en todos los contextos —HOMBRE,
/// MUJER— no aporta información y pesa cero; una exclusiva —ROBAR, PEGAR,
/// TRAMITAR— decide la inferencia. Así el diccionario sigue siendo la única
/// fuente de vocabulario, también para inferir.
///
/// Ante evidencia insuficiente o empate devuelve `null`: es preferible dejar
/// que la persona elija a encerrarla en un contexto equivocado.
class ContextInferenceEngine {
  /// Glosa (en mayúsculas) → contextos de UI en los que aparece.
  final Map<String, Set<String>> _glossContexts;

  /// Contexto de UI → raíces léxicas de su nombre y descripción.
  final Map<String, Set<String>> _contextStems;

  /// Contextos de UI considerados, en el orden del catálogo.
  final List<String> _contextIds;

  /// Confianza mínima para emitir una sugerencia. Por debajo de este valor
  /// la evidencia está demasiado repartida como para proponer nada.
  final double minConfidence;

  const ContextInferenceEngine._({
    required Map<String, Set<String>> glossContexts,
    required Map<String, Set<String>> contextStems,
    required List<String> contextIds,
    required this.minConfidence,
  })  : _glossContexts = glossContexts,
        _contextStems = contextStems,
        _contextIds = contextIds;

  /// Motor vacío: siempre devuelve `null`. Se usa mientras el diccionario
  /// todavía no ha cargado, para que la conversación nunca se bloquee.
  factory ContextInferenceEngine.empty() => ContextInferenceEngine._(
        glossContexts: const {},
        contextStems: const {},
        contextIds: const [],
        minConfidence: 1.0,
      );

  /// Construye el índice a partir de las entradas del diccionario.
  factory ContextInferenceEngine.fromLexicon(
    List<LsbCard> entries, {
    double minConfidence = 0.45,
  }) {
    final contextIds = [for (final c in availableContexts) c.id];

    // Los contextos con los que se etiquetan las tarjetas no siempre son
    // contextos de la UI: 'tramite_id' y 'perdida' son sub-dominios de
    // 'orientacion'. Reutilizamos [cardSourceContexts] para no duplicar ese
    // conocimiento. Los que no resuelven a un contexto de UI ('general',
    // 'emergencia') se descartan por no ser discriminativos.
    final sourceToUi = <String, String>{
      for (final ui in contextIds)
        for (final source in cardSourceContexts(ui)) source: ui,
    };

    final glossContexts = <String, Set<String>>{};
    for (final entry in entries) {
      final uiContexts = <String>{
        for (final source in entry.contexts)
          if (sourceToUi[source] != null) sourceToUi[source]!,
      };
      if (uiContexts.isEmpty) continue;
      glossContexts
          .putIfAbsent(entry.gloss.toUpperCase(), () => <String>{})
          .addAll(uiContexts);
    }

    final contextStems = <String, Set<String>>{
      for (final c in availableContexts)
        c.id: _stemAll('${c.name} ${c.description}'),
    };

    return ContextInferenceEngine._(
      glossContexts: glossContexts,
      contextStems: contextStems,
      contextIds: contextIds,
      minConfidence: minConfidence,
    );
  }

  /// Peso de una glosa: cuanto en menos contextos aparece, más informa.
  /// Una glosa presente en todos los contextos pesa exactamente 0.
  double _weightOf(String gloss) {
    final contexts = _glossContexts[gloss];
    if (contexts == null || contexts.isEmpty) return 0;
    return math.log(_contextIds.length / contexts.length);
  }

  /// Infiere el contexto de un enunciado.
  ///
  /// [glosses] es la señal principal: ya vienen normalizadas y desambiguadas
  /// por el motor de traducción. [text] actúa de respaldo para cuando el
  /// backend no responde y no hay glosas que analizar.
  ContextSuggestion? infer({
    List<String> glosses = const [],
    String text = '',
  }) {
    if (_contextIds.isEmpty) return null;

    final scores = <String, double>{};
    final evidence = <String, Map<String, double>>{};

    /// [asEvidence] distingue lo que se puede enseñar al usuario de lo que
    /// solo sirve para puntuar: una raíz léxica interna ('rob') no significa
    /// nada para quien lee la pantalla, una glosa ('ROBAR') sí.
    void award(String contextId, String token, double weight,
        {bool asEvidence = true}) {
      if (weight <= 0) return;
      scores[contextId] = (scores[contextId] ?? 0) + weight;
      if (!asEvidence) return;
      final perContext = evidence.putIfAbsent(contextId, () => {});
      // Un mismo token no debe contar dos veces (glosa + texto).
      final previous = perContext[token] ?? 0;
      if (weight > previous) perContext[token] = weight;
    }

    // ── Señal principal: las glosas del enunciado ───────────────────────
    for (final raw in glosses) {
      final gloss = raw.toUpperCase().trim();
      final weight = _weightOf(gloss);
      for (final contextId in _glossContexts[gloss] ?? const <String>{}) {
        award(contextId, gloss, weight);
      }
    }

    // ── Respaldo: el texto en español, por raíces léxicas ───────────────
    final textStems = _stemAll(text);
    if (textStems.isNotEmpty) {
      // Contra el vocabulario del diccionario.
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
      // Contra el nombre y la descripción de cada contexto.
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

    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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

  /// El texto crudo es una señal más débil que las glosas: no ha pasado por
  /// la desambiguación del motor y la coincidencia es por raíz, no exacta.
  static const double _textSignalFactor = 0.6;

  /// Peso de coincidir con el nombre o la descripción de un contexto. Son
  /// términos exclusivos de ese contexto, pero se trata de una coincidencia
  /// aproximada, así que no llega al peso de una glosa exclusiva (~1.6).
  static const double _contextNameWeight = 0.8;
}

// ── Normalización léxica ────────────────────────────────────────────────
//
// Un lematizador completo sería desproporcionado: basta con reducir las
// flexiones más comunes del español para que "robaron", "robar" y "robo"
// caigan en la misma raíz.

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

/// Raíces de todas las palabras de un texto, descartando las demasiado
/// cortas para ser informativas (artículos, preposiciones, pronombres).
Set<String> _stemAll(String text) {
  final words = _removeAccents(text.toLowerCase()).split(RegExp(r'[^a-z0-9_]+'));
  return {
    for (final word in words)
      if (word.length >= 4) _stem(word),
  };
}

/// Raíz → glosa original, para una glosa que puede ser compuesta
/// ('PARTIDA_NACIMIENTO' indexa por 'partid' y 'nacimient').
Map<String, String> _stemIndex(String gloss) {
  final parts = gloss.split('_');
  return {
    for (final part in parts)
      if (part.length >= 4) _stem(part): gloss,
  };
}
