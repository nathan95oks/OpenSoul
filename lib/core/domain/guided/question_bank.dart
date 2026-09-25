import 'dart:convert';

import 'package:lsb_legal_app/core/domain/guided/question_bank_data.g.dart';

class QuestionBank {
  final Map<String, dynamic> data;
  late final Map<String, Map<String, dynamic>> questions = {
    for (final raw in data['preguntas'] as List<dynamic>)
      (raw as Map<String, dynamic>)['id'] as String: raw,
  };

  QuestionBank(this.data);

  factory QuestionBank.generated() => QuestionBank(
        jsonDecode(kQuestionBankJson) as Map<String, dynamic>,
      );
}
