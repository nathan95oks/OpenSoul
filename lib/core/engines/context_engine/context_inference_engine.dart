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
    // Fase 1 entra aquí aunque no esté en [availableContexts]: esa lista es
    // la de contextos que NARRAN un hecho, y la identificación no narra. Pero
    // sí se infiere —"¿cuál es su nombre?" es la primera pregunta de toda
    // atención— y al quedar fuera, el diccionario ya etiquetaba NOMBRE, EDAD
    // y CARNET con 'identificacion' y este motor tiraba la etiqueta: el dato
    // estaba bien y nadie lo miraba.
    final contextIds = [
      for (final c in availableContexts) c.id,
      identificacionContext.id,
    ];

    // Los contextos con los que se etiquetan las tarjetas no siempre son
    // contextos de la UI: 'tramite_id' y 'perdida' son sub-dominios de
    // 'orientacion'. Reutilizamos [cardSourceContexts] para no duplicar ese
    // conocimiento. Los que no resuelven a un contexto de UI ('general',
    // 'emergencia') se descartan por no ser discriminativos.
    // 1:N y no 1:1. Desde que 'orientacion' se escindió en 'tramite' y
    // 'consulta', una misma fuente alimenta dos contextos de UI: con un mapa
    // 1:1 el segundo sobrescribía al primero en silencio y toda glosa de
    // orientación acababa contando como evidencia de un solo lado.
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

    // ── Capa 1: reglas duras ────────────────────────────────────────────
    //
    // El modelo por frecuencia es bueno para lo que no se puede enumerar —el
    // relato de un hecho—, pero las preguntas del funcionario SÍ se enumeran:
    // el corpus §4 las lista, son trece y no cambian. Dejarlas a la
    // estadística fue el error: "¿cómo te llamas?" no contiene ninguna glosa,
    // así que el único punto que puntuaba era la palabra «como» contra el
    // nombre del contexto «Declarar **como** testigo», y con esa única señal
    // en el marcador la confianza salía 1.00. Una coincidencia de palabra
    // vacía, con la máxima confianza posible, enrutando una identificación a
    // una declaración de testigo.
    final plano = _normalizeText(text);
    if (plano.isNotEmpty) {
      for (final rule in _hardRules) {
        final marca = rule.matchIn(plano);
        if (marca == null) continue;
        // Regla de abstención: la pregunta se responde DENTRO del flujo en
        // curso, no cambiando de flujo. Devolver null conserva el contexto
        // activo (`ReplyPrompt.proposedContextId`) y deja que
        // [ZoneInferenceEngine] abra la zona exacta. Y cuando no hay contexto
        // activo —"¿qué ocurrió?" es la primera pregunta de la atención— lo
        // que aparece es el menú raíz, que es justo lo que debe aparecer.
        if (rule.contextId == null) return null;
        return ContextSuggestion(
          contextId: rule.contextId!,
          confidence: 1.0,
          evidence: [marca.toUpperCase()],
        );
      }
    }

    // ── Capa 2: modelo por frecuencia sobre el diccionario ──────────────
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

    // Una sugerencia debe apoyarse en al menos una glosa del diccionario.
    // Coincidir con el NOMBRE o la DESCRIPCIÓN de un contexto desempata, pero
    // no puede por sí solo proponer nada: son cuatro o cinco palabras sueltas
    // de prosa, y bastaba acertar una para llevarse el 100% de una puntuación
    // en la que no competía nadie más. Es el mismo defecto que la regla dura
    // ataja por delante, cerrado aquí también para que ninguna frase futura
    // vuelva a colarse por él.
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

  /// El texto crudo es una señal más débil que las glosas: no ha pasado por
  /// la desambiguación del motor y la coincidencia es por raíz, no exacta.
  static const double _textSignalFactor = 0.6;

  /// Peso de coincidir con el nombre o la descripción de un contexto. Son
  /// términos exclusivos de ese contexto, pero se trata de una coincidencia
  /// aproximada, así que no llega al peso de una glosa exclusiva (~1.6).
  static const double _contextNameWeight = 0.8;
}

// ── Reglas duras: las preguntas del funcionario (corpus §4) ─────────────
//
// Trece preguntas, enumerables y estables: son el guion de una recepción de
// denuncia. Se comprueban ANTES del modelo por frecuencia porque en ellas no
// hay nada que estimar —se sabe exactamente a dónde llevan— y porque son
// justo las frases donde el modelo falla: están hechas de palabras vacías
// («cómo», «cuál», «qué»), que es lo único que puede coincidir por azar.
//
// Una regla con [contextId] nulo **se abstiene**: la pregunta se responde
// dentro del flujo en curso y quien abre la zona es [ZoneInferenceEngine].

class _HardRule {
  /// Frases que disparan la regla, ya normalizadas (sin tildes ni signos).
  final List<String> markers;

  /// Contexto al que enrutar, o `null` para abstenerse (ver arriba).
  final String? contextId;

  const _HardRule(this.markers, this.contextId);

  /// Primera marca presente en [haystack], o `null`.
  String? matchIn(String haystack) {
    for (final m in markers) {
      if (haystack.contains(m)) return m;
    }
    return null;
  }
}

/// El orden importa: gana la primera que coincida, así que van de más
/// específica a más general.
const List<_HardRule> _hardRules = [
  // ── Fase 1: identidad ─────────────────────────────────────────────────
  // "¿Cuál es su nombre completo?" · "¿Cómo se llama?" · "¿Qué edad tiene?"
  // · "¿Puede mostrar su documento?"
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

  // ── Abstenciones: se contestan dentro del flujo en curso ──────────────
  //
  // Todas estaban desviando la conversación. "¿Hay testigos?" proponía
  // «Declarar como testigo» —invitando a la víctima a declarar como si fuera
  // ella quien lo presenció— y "¿está herido?" proponía «Consultas», que
  // convierte una urgencia médica en una consulta administrativa.
  _HardRule([
    // "¿Qué ocurrió?" — el menú raíz: es la persona quien dice de qué viene.
    'que ocurrio', 'que paso', 'que sucedio', 'que le paso', 'que te paso',
    'que ha ocurrido', 'que le ocurrio', 'que te ocurrio',
    // "¿Cuándo ocurrió el hecho?" · "¿Dónde ocurrió?"
    'cuando ocurrio', 'cuando fue', 'cuando paso', 'en que momento',
    'donde ocurrio', 'donde fue', 'donde paso', 'en que lugar',
    // "¿Conoce a la persona involucrada?"
    'conoce a la persona', 'conoces a la persona', 'la conoce', 'lo conoce',
    'conoce al agresor', 'persona involucrada',
    // "¿Puede describir a la persona?"
    'describir a la persona', 'puede describir', 'como era la persona',
    'como era el', 'que aspecto',
    // "¿Hay testigos?"
    'hay testigos', 'algun testigo', 'habia testigos', 'hubo testigos',
    // "¿Tiene fotografías o documentos?"
    'tiene fotografias', 'tienes fotografias', 'tiene pruebas',
    'tienes pruebas', 'alguna prueba', 'tiene evidencia',
    // "¿Está herido?" · "¿Necesita atención médica?"
    'esta herido', 'estas herido', 'esta herida', 'atencion medica',
    'necesita un medico', 'necesita atencion',
    // "¿Desea realizar una denuncia?"
    'desea realizar una denuncia', 'desea denunciar', 'quiere denunciar',
    'presentar una denuncia', 'realizar la denuncia',
    // "¿Necesita apoyo legal?"
    'apoyo legal', 'asistencia legal', 'necesita abogado',
    'necesita un abogado', 'defensa publica',
  ], null),
];

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

/// Texto listo para buscar frases: sin tildes, sin signos y con los espacios
/// colapsados, de modo que «¿Cómo te llamas?» contenga literalmente
/// 'como te llamas'.
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

/// Palabras de función: gramática, no contenido.
///
/// El filtro por longitud (>= 4) las dejaba pasar todas —«como», «cual»,
/// «esta», «tiene»— y son precisamente las que forman una PREGUNTA. Por eso
/// el motor fallaba justo con las preguntas del funcionario y acertaba con
/// los relatos: «¿cómo te llamas?» solo tenía «como» que ofrecer, y «como»
/// aparece en el nombre del contexto «Declarar como testigo».
///
/// Una palabra de esta lista no puede sumar por sí sola a ningún contexto.
/// Ninguna es vocabulario del dominio: no hay glosa que las tenga por lexema.
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

/// Raíces de todas las palabras de un texto, descartando las demasiado
/// cortas para ser informativas (artículos, preposiciones, pronombres) y las
/// que son gramática pura ([_stopwords]).
Set<String> _stemAll(String text) {
  final words = _removeAccents(text.toLowerCase()).split(RegExp(r'[^a-z0-9_]+'));
  return {
    for (final word in words)
      if (word.length >= 4 && !_stopwords.contains(word)) _stem(word),
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
