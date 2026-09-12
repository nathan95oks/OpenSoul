import 'dart:io';

void main() {
  final file = File('lib/core/domain/services/local_sentence_assembler.dart');
  var content = file.readAsStringSync();

  // Replace accented keys in _lexicon map: 'KEY': _Lex(
  final reg = RegExp(r"'([^']+)':\s*_Lex\(");
  content = content.replaceAllMapped(reg, (match) {
    final key = match.group(1)!;
    final normalizedKey = stripGlossAccents(key);
    return "'$normalizedKey': _Lex(";
  });

  file.writeAsStringSync(content);
  print('Updated _lexicon keys in local_sentence_assembler.dart');
}

String stripGlossAccents(String input) {
  const from = 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛ';
  const to = 'AAAAEEEEIIIIOOOOUUUU';
  var out = input.replaceAll('-', '_');
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}
