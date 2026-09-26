import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/lsb_gloss_semantics.dart';

void main() {
  final contract =
      jsonDecode(File('aws/tests/lsb_gloss_semantics.json').readAsStringSync())
          as Map<String, dynamic>;

  test('Dart y Python comparten las tablas semánticas cerradas', () {
    expect(
      LsbGlossSemantics.interrogativeSlots,
      (contract['interrogativeSlots'] as Map).cast<String, String>(),
    );
    expect(
      LsbGlossSemantics.headSlots,
      (contract['headSlots'] as Map).cast<String, String>(),
    );
    expect(
      LsbGlossSemantics.openInterrogatives,
      Set<String>.from(contract['openInterrogatives'] as List),
    );
    expect(
      LsbGlossSemantics.negators,
      Set<String>.from(contract['negators'] as List),
    );
  });
}
