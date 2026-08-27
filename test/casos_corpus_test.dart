import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/services/context_catalog.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';

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

  group('lagunas cerradas', () {
    String componer(String ctx, List<String> glosas) => asm.assemble(
          contextId: resolveAssemblerContext(ctx, glosas, (g) => catalogo[g]),
          glosses: glosas,
        );

    test('una estafa se relata sin nombrar el delito', () {
      final f = componer('denuncia_robo',
          ['PAGAR', 'WHATSAPP', 'NO', 'ENTREGAR', 'PRODUCTO']).toLowerCase();
      expect(f.contains('pagué por whatsapp'), true, reason: f);
      expect(f.contains('no me entregaron el producto'), true, reason: f);
      for (final juicio in ['robó', 'sustrajeron', 'agredió']) {
        expect(f.contains(juicio), false,
            reason: 'la declaración no puede calificar el hecho: "$f"');
      }
    });

    test('la negación es una glosa aparte, no un prefijo horneado', () {
      final conNo = componer('denuncia_robo',
          ['PAGAR', 'NO', 'ENTREGAR', 'PRODUCTO']).toLowerCase();
      final sinNo = componer('denuncia_robo',
          ['PAGAR', 'ENTREGAR', 'PRODUCTO']).toLowerCase();
      expect(conNo.contains('no me entregaron'), true, reason: conNo);
      expect(sinNo.contains('no me entregaron'), false, reason: sinNo);
    });

    test('el verbo manda sobre el contexto en la dirección temporal', () {
      final revisar =
          componer('consulta', ['SEGUIMIENTO', 'CASO', 'SEMANA', '2']).toLowerCase();
      final gestionar =
          componer('consulta', ['GESTIONAR', 'CASO', 'SEMANA', '2']).toLowerCase();
      expect(revisar.contains('hace dos semanas'), true, reason: revisar);
      expect(gestionar.contains('dentro de dos semanas'), true, reason: gestionar);
    });
  });

  group('precisión de datos', () {
    String componer(String ctx, List<String> glosas) => asm.assemble(
          contextId: resolveAssemblerContext(ctx, glosas, (g) => catalogo[g]),
          glosses: glosas,
        );

    test('el género concuerda en los oficios, en cualquier orden', () {
      for (final g in [
        ['VECINO', 'MUJER', 'ROBAR'],
        ['MUJER', 'VECINO', 'ROBAR'],
      ]) {
        expect(componer('denuncia_robo', g).toLowerCase().contains('una vecina'),
            true, reason: '$g');
      }
    });

    test('el masculino no se duplica', () {
      final f = componer('denuncia_robo', ['MILITAR', 'HOMBRE', 'ROBAR']).toLowerCase();
      expect(f.contains('un militar'), true, reason: f);
      expect(f.contains('militar hombre'), false, reason: f);
    });

    test('un lugar admite su nombre propio deletreado', () {
      expect(
        componer('denuncia_robo',
            ['ROBAR', 'PLAZA', 'M', 'U', 'R', 'I', 'L', 'L', 'O']),
        contains('en la plaza Murillo'),
      );
    });

    test('un vehículo admite su placa alfanumérica', () {
      expect(
        componer('denuncia_robo', ['DANAR', 'AUTO', '2', '3', '4', 'A', 'B', 'C']),
        contains('con placa 234ABC'),
      );
    });

    test('el detalle es opcional y su ausencia no ensucia la frase', () {
      final f = componer('denuncia_robo', ['ROBAR', 'PLAZA']).toLowerCase();
      expect(f.contains('en la plaza'), true, reason: f);
      expect(f.contains('hago constar'), false, reason: f);
    });

    test('LADRON ya no se ofrece como respuesta a quién', () {
      for (final ctx in ['denuncia_robo', 'violencia']) {
        final zona = contextById(ctx)!.zoneById('personas');
        if (zona == null) continue;
        expect(zona.glossAllowlist.contains('LADRON'), false,
            reason: 'en $ctx el verbo ya dice que fue un ladrón');
      }
    });

    test('la pregunta de Consultas dirige a la acción', () {
      final zona = contextById('consulta')!.zoneById('necesidad');
      expect(zona!.question, '¿Qué necesitas hacer?');
    });
  });

  group('dominio penal judicial', () {
    test('la zona institucional ofrece las dependencias penales', () {
      for (final ctx in ['tramite', 'consulta']) {
        final zona = contextById(ctx)!.zoneById(ctx == 'tramite' ? 'donde' : 'donde');
        expect(zona!.glossAllowlist, containsAll(['FISCALIA', 'FELCC', 'FELCV']),
            reason: 'en $ctx faltan las unidades del ámbito penal');
        expect(zona.glossAllowlist.contains('ALCALDIA'), false,
            reason: 'una alcaldía no recibe una denuncia penal');
      }
    });

    test('existe la rama de seguimiento de investigación', () {
      final consulta = contextById('consulta')!;
      final avance = consulta.zoneById('avance');
      expect(avance, isNotNull, reason: 'el corpus penal lo exige');
      expect(avance!.question, '¿Qué necesita saber?');
      expect(avance.glossAllowlist, containsAll(['AVANCE', 'CASO']));

      final defensa = consulta.zoneById('defensa');
      expect(defensa, isNotNull);
      expect(defensa!.question, '¿Tiene abogado?');
      expect(defensa.glossAllowlist, containsAll(['SI', 'NO', 'DEFENSA_PUBLICA']));
    });

    test('las dos respuestas frecuentes están a un toque', () {
      final necesidad = contextById('consulta')!.zoneById('necesidad')!;
      expect(necesidad.glossAllowlist, containsAll(['INTERPRETE', 'CASO']),
          reason: 'son las que el corpus penal ve una y otra vez');
    });

    test('el dominio penal no rompe la dactilología ni el tiempo', () {
      final ctx = resolveAssemblerContext(
          'consulta', ['AUDIENCIA', 'JUZGADO', 'CASO', '4', '0', '7'],
          (g) => catalogo[g]);
      final f = asm.assemble(
        contextId: ctx,
        glosses: ['AUDIENCIA', 'JUZGADO', 'CASO', '4', '0', '7'],
      );
      expect(f, contains('407'), reason: 'el número de caso sigue uniéndose');

      final t = asm.assemble(
        contextId: 'denuncia_robo',
        glosses: ['ROBAR', 'FISCALIA', 'SEMANA', '2'],
      );
      expect(t.toLowerCase(), contains('hace dos semanas'),
          reason: 'la composición temporal sigue intacta');
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
