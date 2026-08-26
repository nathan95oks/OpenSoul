/// Qué hace el enunciado del oyente, no de qué habla.
///
/// El contexto ya se infiere aparte —de las glosas que devuelve la Lambda—,
/// pero saber el TEMA no basta para decidir qué ofrecerle a la persona sorda.
/// En una ventanilla, "¿tiene su carnet?" y "traiga su carnet" hablan de lo
/// mismo y piden cosas opuestas: la primera espera una respuesta, la segunda
/// espera que entiendas y te vayas.
///
/// Antes las dos abrían el mismo flujo inquisitivo, así que a una instrucción
/// la app respondía con un cuestionario.
enum SpeechAct {
  /// Espera una respuesta: se abre el panel guiado de la zona preguntada.
  question,

  /// Indica un paso a dar. No se pregunta nada: se ofrecen respuestas breves
  /// —entendido, dónde queda, puede repetir— y se deja seguir.
  instruction,

  /// Ni pregunta ni manda: informa. Se muestra y ya.
  statement,
}

/// Clasifica el enunciado del oyente por análisis sintáctico ligero.
///
/// Deliberadamente sin modelo: es una decisión de interfaz que ocurre en cada
/// turno, y una llamada de red por turno se nota en una conversación de
/// ventanilla. Las marcas del español bastan —el signo, el interrogativo
/// inicial, la perífrasis de obligación— y cuando no bastan cae en
/// [SpeechAct.statement], que no promete nada.
SpeechAct classifySpeechAct(String text) {
  final limpio = _normalizar(text);
  if (limpio.isEmpty) return SpeechAct.statement;

  // Una pregunta puede venir sin signo de apertura —el teclado del móvil se
  // lo come— pero casi nunca sin el de cierre.
  if (text.trimRight().endsWith('?') || text.contains('¿')) {
    return SpeechAct.question;
  }

  // La obligación va ANTES que el interrogativo inicial: "tiene que presentar
  // el memorial" empieza por "tiene", pero manda, no pregunta. El signo ya se
  // comprobó arriba, así que "¿debe traer algo más?" sigue siendo pregunta.
  // Se busca en toda la frase porque el funcionario antepone cortesía:
  // "por favor, diríjase a la ventanilla 3".
  for (final marca in _marcasDeInstruccion) {
    if (limpio.contains(marca)) return SpeechAct.instruction;
  }

  final primeras = limpio.split(' ').take(3).join(' ');
  for (final marca in _interrogativosIniciales) {
    if (primeras.startsWith(marca)) return SpeechAct.question;
  }

  return SpeechAct.statement;
}

/// Interrogativos que abren una pregunta sin signo.
///
/// Solo al principio: "no sé dónde queda" no es una pregunta, y "dónde" en
/// medio de la frase suele ser una subordinada.
const _interrogativosIniciales = {
  'que ', 'quien ', 'quienes ', 'donde ', 'cuando ', 'como ', 'cual ',
  'cuales ', 'cuanto ', 'cuantos ', 'cuanta ', 'cuantas ', 'por que ',
  'para que ', 'tiene ', 'tienes ', 'trae ', 'trajo ', 'sabe ', 'sabes ',
  'puede ', 'puedes ', 'necesita ', 'necesitas ', 'me da ', 'me puede ',
};

/// Perífrasis de obligación e imperativos de ventanilla.
///
/// Son los verbos con los que un funcionario dirige: los del corpus §3.6 y
/// §4.x, donde la ORIENTACIÓN es un tipo de turno propio.
const _marcasDeInstruccion = {
  'debe ', 'debera ', 'tiene que ', 'hay que ', 'le corresponde ',
  'vaya ', 'valla ', 'acuda ', 'dirijase ', 'pase ', 'presente ',
  'traiga ', 'lleve ', 'llene ', 'firme ', 'espere ', 'vuelva ',
  'recoja ', 'entregue ', 'saque ', 'suba ', 'baje ', 'diríjase ',
  'debes ', 'tienes que ',
};

String _normalizar(String input) {
  const con = 'áàäâéèëêíìïîóòöôúùüûñ';
  const sin = 'aaaaeeeeiiiioooouuuun';
  var out = input.toLowerCase();
  for (var i = 0; i < con.length; i++) {
    out = out.replaceAll(con[i], sin[i]);
  }
  // Se conserva un espacio final para que las marcas con espacio ("debe ")
  // casen también cuando la palabra cierra la frase.
  return '${out.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
}
