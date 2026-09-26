import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';
import 'package:lsb_legal_app/core/domain/services/context_catalog.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart'
    show kEvidenceMarker, kVehicleMarker, kVictimMarker;

/// Toda glosa LSB del módulo LSB → texto/audio existe en el Corpus Maestro
/// Unificado LSB v4.
///
/// La fuente canónica en la app es `assets/dictionary/official_dictionary.json`:
/// las 303 glosas de la sección 12 del corpus más los mecanismos que el propio
/// corpus autoriza (alfabeto dactilológico, números y dactilología
/// institucional). Que ese archivo coincide con el corpus lo comprueba
/// `aws/tests/test_corpus_v4.py` leyendo el documento del corpus.
void main() {
  final corpus = {
    for (final e in (jsonDecode(File('assets/dictionary/official_dictionary.json')
            .readAsStringSync()) as Map<String, dynamic>)['entries'] as List)
      (e as Map<String, dynamic>)['gloss'] as String,
  };
  final bank = QuestionBank.generated();

  test('allLsbGlossesExistInCorpusV4: respuestas del banco', () {
    final fuera = <String>[];
    for (final q in bank.allQuestions) {
      for (final o in q.options) {
        for (final g in o.glosses) {
          if (!corpus.contains(g)) fuera.add('${q.id}/${o.id}: $g');
        }
      }
    }
    expect(fuera, isEmpty);
  });

  test('allLsbGlossesExistInCorpusV4: glosas que formulan preguntas', () {
    final fuera = [
      for (final q in bank.allQuestions)
        for (final g in q.formulationGlosses)
          if (!corpus.contains(g)) '${q.id}: $g',
    ];
    expect(fuera, isEmpty);
  });

  test('allLsbGlossesExistInCorpusV4: tarjetas de los recorridos visibles', () {
    // Lo que puede aparecer en pantalla: las opciones de cada paso de los
    // ocho recorridos del módulo.
    final fuera = <String>[];
    for (final journey in bank.journeys.values) {
      for (final step in journey.steps) {
        for (final o in bank.question(step.questionId)!.options) {
          if (!o.hasSign) continue;
          for (final g in o.glosses) {
            if (!corpus.contains(g)) fuera.add('${journey.id}/${o.id}: $g');
          }
        }
      }
    }
    expect(fuera, isEmpty);
  });

  test('allLsbGlossesExistInCorpusV4: catálogo de contextos', () {
    // Los marcadores internos no son glosas ni se muestran ni viajan en el
    // flujo guiado; todo lo demás tiene que estar en el corpus.
    const marcadores = {kEvidenceMarker, kVehicleMarker, kVictimMarker};
    final fuera = [
      for (final c in allSelectableContexts)
        for (final z in c.zones)
          for (final g in z.glossAllowlist)
            if (!corpus.contains(g) && !marcadores.contains(g)) '${c.id}.${z.id}: $g',
    ];
    expect(fuera, isEmpty);
  });

  test('los ocho contextos seleccionables tienen su recorrido en el banco', () {
    for (final c in allSelectableContexts) {
      expect(bank.journey(c.id), isNotNull, reason: c.id);
    }
  });
}
