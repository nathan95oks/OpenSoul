/// Las tres respuestas que admite una pregunta de sí o no cuando el grafo y
/// el RAG no tienen una pregunta propia con sus tarjetas: afirmar, negar o
/// decir que no se sabe.
///
/// Son las mismas tres opciones «polares» del banco (`Q.PER.CONOCE`: «Sí»,
/// «No», «No sé») con sus mismas glosas, pero sin frase propia de la
/// pregunta: aquí no se sabe de qué se preguntó, así que la respuesta no
/// repite ni inventa nada del contenido.
enum PolarAnswer {
  yes('Sí', 'Sí.', 'SÍ'),
  no('No', 'No.', 'NO'),
  unknown('No sé', 'No sé.', 'NO_SABER');

  /// Lo que dice la tarjeta.
  final String label;

  /// Lo que se lee y se escucha en el chat.
  final String text;

  /// La seña con la que responde la persona sorda.
  final String gloss;

  const PolarAnswer(this.label, this.text, this.gloss);
}

/// Si [text] es una pregunta que se contesta con sí o no: «¿Quieres agua?»,
/// «¿Tienes hijos?», «¿Puedes leer esto?».
///
/// Es una pregunta polar cuando **todas** sus preguntas empiezan por un verbo
/// o un sujeto y no por una palabra interrogativa (qué, quién, cuándo,
/// dónde, cómo, cuánto, cuál, «por qué»…), y no ofrecen alternativas
/// («¿Quiere agua o café?»), que un sí o no no contesta. Hace falta el signo
/// de pregunta: sin él, «Puede pasar» o «Tiene que firmar» son indicaciones,
/// no preguntas.
bool isPolarQuestion(String text) {
  final questions = _questionsOf(text);
  return questions.isNotEmpty && questions.every(_isPolar);
}

/// Cada pregunta del texto, sin los signos. «Entiendo. ¿Tiene hijos?» →
/// `[Tiene hijos]`. Un `?` sin `¿` toma la oración que lo cierra.
List<String> _questionsOf(String text) {
  final opened = [
    for (final m in RegExp(r'¿([^?¿]*)\??').allMatches(text)) m.group(1)!,
  ];
  if (opened.isNotEmpty) return opened;
  final close = text.lastIndexOf('?');
  if (close < 0) return const [];
  return [text.substring(0, close).split(RegExp(r'[.!]')).last];
}

bool _isPolar(String question) {
  final lower = question.toLowerCase();
  // La palabra interrogativa tildada delata una pregunta abierta en
  // cualquier lugar de la frase («Usted vino ayer, ¿a qué hora?»). Sin
  // tilde solo se mira al principio: «que» también es conjunción
  // («¿Quiere que le ayude?» sí es de sí o no).
  if (_accentedInterrogative.hasMatch(lower)) return false;

  final words = _normalize(
    lower,
  ).split(' ').where((w) => w.isNotEmpty).skipWhile(_fillers.contains).toList();
  if (words.isEmpty) return false;
  if (words.contains('o')) return false;

  var first = 0;
  if (_prepositions.contains(words[first]) && words.length > 1) first++;
  return !_interrogatives.contains(words[first]);
}

final _accentedInterrogative = RegExp(
  r'(?<![a-záéíóúñ])(qué|quién|quiénes|cuál|cuáles|cuándo|dónde|adónde|'
  r'cómo|cuánto|cuánta|cuántos|cuántas)(?![a-záéíóúñ])',
);

const _interrogatives = {
  'que',
  'quien',
  'quienes',
  'cual',
  'cuales',
  'cuando',
  'donde',
  'adonde',
  'como',
  'cuanto',
  'cuanta',
  'cuantos',
  'cuantas',
};

const _prepositions = {
  'a',
  'de',
  'con',
  'en',
  'desde',
  'hasta',
  'por',
  'para',
  'sobre',
  'hacia',
  'segun',
};

/// Palabras que preceden a la pregunta sin cambiarla: «Y ¿tiene hijos?».
const _fillers = {
  'y',
  'e',
  'entonces',
  'pero',
  'oiga',
  'disculpe',
  'perdon',
  'bueno',
  'ya',
};

String _normalize(String input) {
  const con = 'áàäâéèëêíìïîóòöôúùüûñ';
  const sin = 'aaaaeeeeiiiioooouuuun';
  var out = input;
  for (var i = 0; i < con.length; i++) {
    out = out.replaceAll(con[i], sin[i]);
  }
  return out
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
