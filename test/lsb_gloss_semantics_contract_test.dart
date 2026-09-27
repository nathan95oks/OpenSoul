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

  test('Dart y Python leen igual el interrogativo del texto', () {
    expect(
      LsbGlossSemantics.spokenInterrogativeSlots,
      (contract['spokenInterrogativeSlots'] as Map).cast<String, String>(),
    );
    expect(
      LsbGlossSemantics.spokenOpenInterrogatives,
      Set<String>.from(contract['spokenOpenInterrogatives'] as List),
    );
    expect(
      LsbGlossSemantics.spokenHeadSlots,
      (contract['spokenHeadSlots'] as Map).cast<String, String>(),
    );
    expect(
      LsbGlossSemantics.spokenWordSlots,
      (contract['spokenWordSlots'] as Map).cast<String, String>(),
    );
    expect(
      LsbGlossSemantics.questionPrepositions,
      Set<String>.from(contract['questionPrepositions'] as List),
    );
  });

  test('el respaldo del cliente pide lo mismo que la Lambda', () {
    // Mismos casos que captura `regenerar_casos_semantic_turn.py`: lo que el
    // cliente lee del texto y las glosas coincide con la lectura del backend.
    final casos =
        (jsonDecode(
                  File('aws/tests/casos_semantic_turn.json').readAsStringSync(),
                )['casos']
                as List)
            .cast<Map<String, dynamic>>();
    for (final c in casos) {
      final texto = c['texto'] as String;
      final glosas = LsbGlossSemantics.normalizeAll(
        List<String>.from(c['glosas'] as List),
      );
      final pregunta =
          texto.contains('?') || LsbGlossSemantics.hasInterrogative(glosas);
      final cliente = {
        if (pregunta) ...LsbGlossSemantics.slotsOf(glosas),
        ...LsbGlossSemantics.spokenSlotsOf(texto),
      };
      final backend = Set<String>.from(
        (c['semanticTurn'] as Map)['requestedSlots'] as List,
      );
      expect(cliente, backend, reason: c['id'] as String);
    }
  });
}
