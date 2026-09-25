import 'package:lsb_legal_app/core/domain/guided/guided_answer.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';

class GuidedComposer {
  final QuestionBank bank;

  const GuidedComposer(this.bank);

  String compose(GuidedIntervention intervention) {
    final answers = <String, Map<String, dynamic>>{
      for (final answer in intervention.answers)
        answer.questionId: answer.toJson(),
    };
    final consumed = <String>{};
    final sentences = <String>[];
    final reply = intervention.purpose == GuidedPurpose.reply;

    String? fragment(String id, List<String> extras) {
      final answer = answers[id];
      final question = bank.questions[id];
      if (answer == null || question == null || answer['estado'] == 'omitido') {
        return null;
      }
      consumed.add(id);
      final parts = _chosen(question, answer)
          .map((option) {
            final phrase = _fill(option, _phraseOf(option, answer), answer,
                answers, fragment, extras);
            final extra = option['fraseExtra'] as String?;
            if (extra != null) extras.add(extra);
            return phrase;
          })
          .where((text) => text.isNotEmpty)
          .toList();
      return parts.isEmpty ? null : _joinEs(parts);
    }

    for (final id in _order(intervention, answers)) {
      if (consumed.contains(id)) continue;
      final answer = answers[id];
      final question = bank.questions[id];
      if (answer == null || question == null || answer['estado'] == 'omitido') {
        continue;
      }
      final extras = <String>[];
      String text;
      if (question['modo'] == 'fragmento') {
        final value = fragment(id, extras);
        final loose = question['fraseSuelta'] as String?;
        text = value == null || loose == null ? '' : loose.replaceAll('{frag}', value);
      } else {
        consumed.add(id);
        final chosen = _chosen(question, answer);
        final parts = chosen.map((option) {
          final result = _fill(option, _phraseOf(option, answer), answer,
              answers, fragment, extras);
          final extra = option['fraseExtra'] as String?;
          if (extra != null) extras.add(extra);
          return result;
        }).where((value) => value.isNotEmpty).toList();
        final hasExit = chosen.any((option) => option['salida'] == true);
        if (parts.isEmpty) {
          text = '';
        } else if (question['plantilla'] != null && !hasExit) {
          final joined = _joinEs(parts, spaces: question['unir'] == 'espacio');
          text = (question['plantilla'] as String).replaceAll('{items}', joined);
        } else {
          text = parts.join(' ');
        }
      }
      final finalized = _finalize(text, reply: reply);
      if (finalized.isNotEmpty) sentences.add(finalized);
      sentences.addAll(extras.map((e) => _finalize(e, reply: reply)).where((e) => e.isNotEmpty));
    }
    return sentences.join(' ');
  }

  List<String> _order(GuidedIntervention intervention,
      Map<String, Map<String, dynamic>> answers) {
    final result = <String>[];
    final journeys = bank.data['recorridos'] as Map<String, dynamic>? ?? const {};
    final journey = journeys[intervention.journeyId] as Map<String, dynamic>?;
    final base = journey == null
        ? intervention.steps
        : ((journey['ordenRedaccion'] as List<dynamic>?) ??
                (journey['pasos'] as List<dynamic>).map(
                    (step) => (step as Map<String, dynamic>)['pregunta']))
            .cast<String>();
    for (final id in [...base, ...answers.keys]) {
      if (!result.contains(id)) result.add(id);
    }
    return result;
  }

  List<Map<String, dynamic>> _chosen(
      Map<String, dynamic> question, Map<String, dynamic> answer) {
    final ids = (answer['opciones'] as List<dynamic>? ?? const []).toSet();
    return (question['opciones'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((option) => ids.contains(option['id']))
        .toList();
  }

  Map<String, dynamic> _values(
      Map<String, dynamic> answer, Map<String, dynamic> option) {
    final all = answer['valores'] as Map<String, dynamic>? ?? const {};
    return all[option['id']] as Map<String, dynamic>? ?? const {};
  }

  String _phraseOf(Map<String, dynamic> option, Map<String, dynamic> answer) {
    final values = _values(answer, option);
    if (option['fraseSingular'] != null && '${values['n'] ?? ''}' == '1') {
      return option['fraseSingular'] as String;
    }
    final editor = option['editor'] as String?;
    final keys = _editorKeys[editor] ?? const <String>[];
    final complete = keys.isNotEmpty &&
        keys.every((key) => '${values[key] ?? ''}'.trim().isNotEmpty);
    if (editor != null && !complete && option.containsKey('fraseSinValor')) {
      return option['fraseSinValor'] as String? ?? '';
    }
    return option['frase'] as String? ?? '';
  }

  String _fill(
      Map<String, dynamic> option,
      String template,
      Map<String, dynamic> answer,
      Map<String, Map<String, dynamic>> answers,
      String? Function(String, List<String>) fragment,
      List<String> extras) {
    final values = _values(answer, option);
    final mention = answer['mencion'] as Map<String, dynamic>?;
    return template.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (match) {
      final token = match.group(1)!;
      if (token.startsWith('Q.') || token.startsWith('I.')) {
        final separator = token.indexOf('|');
        final reference = separator < 0 ? token : token.substring(0, separator);
        final fallback = separator < 0 ? '' : token.substring(separator + 1);
        final resolved = _resolveReference(reference);
        if (resolved == null) return fallback;
        final referenced = answers[resolved.$1];
        if (resolved.$2.isNotEmpty) {
          if (referenced == null || referenced['estado'] != 'afirmado') return fallback;
          for (final selected in _chosen(bank.questions[resolved.$1]!, referenced)) {
            final value = selected[resolved.$2];
            if (value != null) return '$value';
          }
          return fallback;
        }
        if (referenced == null || referenced['estado'] == 'omitido') return fallback;
        return fragment(resolved.$1, extras) ?? fallback;
      }
      if (token == 'aprox') return values['aprox'] == 'si' ? 'aproximadamente ' : '';
      if (token == 'mencionado') return '${mention?['frase'] ?? 'eso'}';
      if (token.startsWith('?')) {
        final value = '${values[token.substring(1)] ?? ''}'.trim();
        return value.isEmpty ? '' : ' $value';
      }
      return '${values[token] ?? ''}'.trim();
    });
  }

  (String, String)? _resolveReference(String reference) {
    final parts = reference.split('.');
    for (var length = parts.length; length > 1; length--) {
      final id = parts.take(length).join('.');
      if (bank.questions.containsKey(id)) {
        return (id, parts.skip(length).join('.'));
      }
    }
    return null;
  }

  String _finalize(String text, {required bool reply}) {
    var result = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+([.,;:?!»])'), r'$1')
        .replaceAll(RegExp(r'«\s+'), '«')
        .trim();
    if (result.isEmpty) return '';
    if (!reply) {
      for (final prefix in const ['Sí, ', 'No, ']) {
        if (result.startsWith(prefix)) result = result.substring(prefix.length);
      }
    }
    result = result[0].toUpperCase() + result.substring(1);
    if (!'.?!'.contains(result[result.length - 1])) result += '.';
    return result;
  }
}

const _editorKeys = <String, List<String>>{
  'texto_nombre': ['nombre'],
  'telefono': ['telefono'],
  'entero': ['n'],
  'edad': ['n'],
  'monto': ['monto', 'moneda'],
  'texto_detalle': ['texto'],
  'lugar_literal': ['nombre'],
  'referencia': ['referencia'],
  'documento_numero': ['numero'],
  'hora': ['hora'],
};

String _joinEs(List<String> items, {bool spaces = false}) {
  if (spaces) return items.join(' ');
  if (items.length < 2) return items.join();
  return '${items.take(items.length - 1).join(', ')} y ${items.last}';
}
