enum SpeechAct {
  question,

  instruction,

  statement,
}

SpeechAct classifySpeechAct(String text) {
  final limpio = _normalizar(text);
  if (limpio.isEmpty) return SpeechAct.statement;

  if (text.trimRight().endsWith('?') || text.contains('¿')) {
    return SpeechAct.question;
  }

  for (final marca in _marcasDeInstruccion) {
    if (limpio.contains(marca)) return SpeechAct.instruction;
  }

  final primeras = limpio.split(' ').take(3).join(' ');
  for (final marca in _interrogativosIniciales) {
    if (primeras.startsWith(marca)) return SpeechAct.question;
  }

  return SpeechAct.statement;
}

const _interrogativosIniciales = {
  'que ', 'quien ', 'quienes ', 'donde ', 'cuando ', 'como ', 'cual ',
  'cuales ', 'cuanto ', 'cuantos ', 'cuanta ', 'cuantas ', 'por que ',
  'para que ', 'tiene ', 'tienes ', 'trae ', 'trajo ', 'sabe ', 'sabes ',
  'puede ', 'puedes ', 'necesita ', 'necesitas ', 'me da ', 'me puede ',
};

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
  return '${out.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim()} ';
}
