import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/engines/context_engine/context_catalog.dart';
import 'package:lsb_legal_app/core/engines/semantic_engine/local_sentence_assembler.dart';

/// Casos derivados del CORPUS CONVERSACIONAL PRELIMINAR (Cochabamba 2026).
///
/// Leen el MISMO archivo que la suite de Python (`aws/tests/casos_corpus.json`).
/// Esa es la gracia: el esperado del backend se captura del motor real y aquí
/// se comprueba que el cliente no lo descarte. Si los dos motores dejan de
/// coincidir, esta prueba lo dice antes que un usuario en una ventanilla.
void main() {
  const asm = LocalSentenceAssembler();

  final datos = jsonDecode(
    File('aws/tests/casos_corpus.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final casos = (datos['casos'] as List).cast<Map<String, dynamic>>();

  // El enrutado depende de la categoría de cada glosa: pasarle `(_) => null`
  // lo desactivaba y la prueba no ejercitaba el reparto real de 'tramite'
  // entre pérdida, gestión y orientación.
  final catalogo = {
    for (final e in ((jsonDecode(
              File('assets/dictionary/official_dictionary.json').readAsStringSync(),
            ) as Map<String, dynamic>)['entries'] as List)
        .cast<Map<String, dynamic>>())
      e['gloss'] as String: e['categoryId'] as String,
  };

  String contextoDelMotor(Map<String, dynamic> caso) => resolveAssemblerContext(
        caso['contexto'] as String,
        (caso['glosas'] as List).cast<String>(),
        (g) => catalogo[g],
      );

  test('hay casos y todos declaran lo necesario', () {
    expect(casos.length >= 15, true, reason: 'se esperaban al menos 15 casos');
    for (final c in casos) {
      for (final campo in ['case_id', 'corpus', 'contexto', 'glosas',
                           'esperado_backend', 'lsb_icons']) {
        expect(c[campo], isNotNull, reason: '${c['case_id']} sin $campo');
      }
    }
  });

  group('el cliente redacta cada caso del corpus', () {
    for (final caso in casos) {
      test('${caso['case_id']} — ${caso['descripcion']}', () {
        final glosas = (caso['glosas'] as List).cast<String>();
        final frase = asm.assemble(
          contextId: contextoDelMotor(caso),
          glosses: glosas,
        );

        expect(frase.trim(), isNotEmpty);
        expect(frase.trim().endsWith('.') || frase.trim().endsWith('?'), true,
            reason: 'debe ser una oración cerrada: "$frase"');
        expect(frase.contains('_'), false,
            reason: 'no deben filtrarse glosas crudas: "$frase"');
      });
    }
  });

  group('el cliente acepta lo que produce el backend', () {
    for (final caso in casos) {
      test('${caso['case_id']} no se descarta', () {
        final glosas = (caso['glosas'] as List).cast<String>();
        expect(
          asm.isBackendDegenerate(
            backendText: caso['esperado_backend'] as String,
            glosses: glosas,
          ),
          false,
          reason: 'el motor local descartaría esta respuesta del servidor y '
              'el trabajo del backend se tiraría:\n'
              '  "${caso['esperado_backend']}"',
        );
      });
    }
  });

  group('reglas de oro del corpus', () {
    Map<String, dynamic> porId(String id) =>
        casos.firstWhere((c) => c['case_id'] == id);

    String frase(String id) {
      final c = porId(id);
      return asm.assemble(
        contextId: contextoDelMotor(c),
        glosses: (c['glosas'] as List).cast<String>(),
      );
    }

    test('CP-002 la huida cierra el relato, no es agresión sufrida', () {
      final f = frase('CP-002').toLowerCase();
      expect(f.contains('me salió corriendo'), false);
      expect(f.contains('en el mercado y salió corriendo'), true, reason: f);
    });

    test('CP-003 la evidencia se aporta, no se sustrae', () {
      final f = frase('CP-003').toLowerCase();
      expect(f.contains('billetera y una fotografía'), false);
      expect(f.contains('como prueba tengo una fotografía'), true, reason: f);
    });

    test('CP-004 SEGURO es estado del declarante, no rasgo del agresor', () {
      final f = frase('CP-004').toLowerCase();
      expect(f.contains('expareja seguro'), false);
      expect(f.contains('lugar seguro'), true, reason: f);
    });

    test('CP-005 AYER manda como fecha; la reincidencia va aparte', () {
      final f = frase('CP-005').toLowerCase();
      expect(f.contains('ayer,'), true, reason: f);
      expect(f.contains('es la primera vez'), true, reason: f);
    });

    test('CP-006 unidad + cantidad componen en pasado', () {
      expect(frase('CP-006').toLowerCase().contains('hace dos semanas'), true);
    });

    test('CP-007 un canal digital no es complemento directo', () {
      final f = frase('CP-007').toLowerCase();
      expect(f.contains('amenazó whatsapp'), false,
          reason: 'falta la preposición: "$f"');
      expect(f.contains('por whatsapp'), true, reason: f);
    });

    test('CP-008 dos urgencias no se excluyen', () {
      final f = frase('CP-008').toLowerCase();
      expect(f.contains('herida'), true, reason: f);
      expect(f.contains('auxilio'), true, reason: f);
    });

    test('CP-011 una racha de dígitos es un número, no ruido suelto', () {
      final f = frase('CP-011');
      expect(f.contains('1024'), true,
          reason: 'el NUREJ deletreado debe conservarse entero: "$f"');
    });

    test('CP-012 un dígito huérfano no llega a la declaración', () {
      final f = frase('CP-012');
      expect(RegExp(r'\b7\b').hasMatch(f), false,
          reason: 'sin unidad de tiempo, un dígito no significa nada: "$f"');
    });

    test('CP-013 dos instituciones se enlazan, ninguna se cae', () {
      final f = frase('CP-013').toLowerCase();
      expect(f.contains('fiscalía'), true, reason: f);
      expect(f.contains('despacho'), true, reason: f);
      expect(f.contains('hago constar'), false,
          reason: 'la segunda institución no debe caer a la red de seguridad: "$f"');
    });

    test('CP-014 el plazo de un trámite mira hacia adelante', () {
      expect(frase('CP-014').toLowerCase().contains('dentro de tres días'), true);
    });

    test('CP-015 un servicio no es el objeto del verbo', () {
      final f = frase('CP-015').toLowerCase();
      expect(f.contains('corregir un intérprete'), false, reason: f);
      expect(f.contains('formulario'), true, reason: f);
    });
  });

  test('los íconos declarados existen en el catálogo', () {
    final catalogo = jsonDecode(
      File('assets/dictionary/official_dictionary.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final reales = {
      for (final e in (catalogo['entries'] as List).cast<Map<String, dynamic>>())
        e['semanticIcon'] as String,
    };
    for (final caso in casos) {
      for (final icono in (caso['lsb_icons'] as List).cast<String>()) {
        expect(reales.contains(icono), true,
            reason: '${caso['case_id']} declara un ícono inexistente: $icono');
      }
    }
  });
}
