import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Invariantes del corpus RAG de Cochabamba (`assets/rag/escenarios_cbba.json`,
/// generado por `tool/build_rag_corpus.py`): lo que puede llegar a verse en la
/// app nunca contiene un dato sin verificar ni un dato personal de ejemplo.
void main() {
  final corpus =
      jsonDecode(File('assets/rag/escenarios_cbba.json').readAsStringSync())
          as Map<String, dynamic>;
  final hechos = (corpus['hechos'] as Map).cast<String, dynamic>();
  final fuentes = (corpus['fuentes'] as Map).cast<String, dynamic>();
  final escenarios = (corpus['escenarios'] as List)
      .cast<Map<String, dynamic>>();

  Iterable<Map<String, dynamic>> turnos() => [
    for (final e in escenarios)
      ...(e['turnos'] as List).cast<Map<String, dynamic>>(),
  ];

  Iterable<Map<String, dynamic>> respuestas() => [
    for (final e in escenarios)
      for (final p in (e['variantes'] as List).cast<Map<String, dynamic>>())
        ...(p['respuestas'] as List).cast<Map<String, dynamic>>(),
  ];

  test('cubre las instituciones pedidas con varios escenarios cada una', () {
    final porArea = <String, int>{};
    for (final e in escenarios) {
      final area = (e['id'] as String).split('-')[1];
      porArea[area] = (porArea[area] ?? 0) + 1;
    }
    expect(porArea.keys, hasLength(greaterThanOrEqualTo(15)));
    expect(porArea.values.every((n) => n >= 4), isTrue, reason: '$porArea');
  });

  test('todo hecho citado existe y toda fuente citada existe', () {
    for (final t in turnos()) {
      for (final h in (t['hechos'] as List).cast<String>()) {
        expect(hechos, contains(h));
      }
    }
    for (final h in hechos.values.cast<Map<String, dynamic>>()) {
      for (final f in (h['fuentes'] as List).cast<String>()) {
        expect(fuentes, contains(f));
      }
    }
  });

  test('nada mostrable depende de un dato sin verificar', () {
    for (final t in turnos().where((t) => t['mostrable'] == true)) {
      expect(t['texto'], isNot(contains('[VERIFICAR]')));
      for (final h in (t['hechos'] as List).cast<String>()) {
        expect(
          (hechos[h] as Map)['verificar'],
          isFalse,
          reason: '${t['texto']} cita $h',
        );
      }
    }
  });

  test(
    'ninguna tarjeta del usuario sordo lleva un dato personal de ejemplo',
    () {
      final ejemplo = [
        for (final t in turnos())
          if (t['rol'] == 'sordo') t,
        ...respuestas(),
      ];
      for (final t in ejemplo.where((t) => t['mostrable'] == true)) {
        final texto = t['texto'] as String;
        expect(
          RegExp(r'\d').hasMatch(texto),
          isFalse,
          reason: 'cifra en una tarjeta ofrecible: $texto',
        );
      }
      // Los casos que motivaron el filtro siguen fuera.
      final ocultos = {
        for (final t in ejemplo)
          if (t['mostrable'] != true) t['texto'] as String,
      };
      expect(
        ocultos,
        containsAll(['Sí. La placa es 4821ABC.', 'Sí. Tiene quince años.']),
      );
    },
  );

  test('toda tarjeta mostrable del usuario sordo trae sus glosas LSB', () {
    final tarjetas = [
      for (final t in turnos())
        if (t['rol'] == 'sordo' && t['mostrable'] == true) t,
      for (final r in respuestas())
        if (r['mostrable'] == true) r,
    ];
    expect(tarjetas, isNotEmpty);
    for (final t in tarjetas) {
      expect(
        (t['glosas'] as List?) ?? const [],
        isNotEmpty,
        reason: 'sin glosas: ${t['texto']}',
      );
    }
  });

  test('lo que habla de la fuente en vez de atender no se muestra', () {
    final texto = {
      for (final t in turnos())
        if (t['mostrable'] != true) t['texto'] as String,
    };
    expect(
      texto,
      contains('Sí. Para este corpus usaremos el criterio actual de 25%.'),
    );
  });
}
