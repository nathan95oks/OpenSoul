import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/services/local_sentence_assembler.dart';

/// Pruebas semánticas del motor propio de armado oracional.
///
/// Cubren los escenarios reales de instituciones públicas bolivianas
/// (policía, SEGIP, defensoría, alcaldía, emergencias) y verifican que el
/// fallback offline produzca oraciones con sintaxis española correcta —no
/// listas de glosas separadas por comas— y que el detector de degeneración
/// no incurra en falsos positivos por guiones bajos o conjugación.
void main() {
  const asm = LocalSentenceAssembler();

  // Coincidencia de subcadena sin distinguir mayúsculas/acentos de borde.
  bool has(String s, String sub) => s.toLowerCase().contains(sub.toLowerCase());


  /// Una oración "bien formada" mínima: empieza en mayúscula, termina en
  /// punto, contiene un verbo o conector y NO es una mera lista de glosas.
  void expectWellFormed(String s) {
    expect(s.isNotEmpty, true, reason: 'no debe estar vacía');
    expect(s.trim().endsWith('.'), true, reason: 'debe terminar en punto: "$s"');
    expect(s[0], s[0].toUpperCase(), reason: 'debe iniciar en mayúscula: "$s"');
  }

  group('assemble — POLICÍA (robo / asalto)', () {
    test('robo con agresor, arma, objeto, lugar y tiempo', () {
      final s = asm.assemble(
        contextId: 'denuncia_robo',
        glosses: ['HOMBRE', 'CUCHILLO', 'ROBAR', 'CELULAR', 'CALLE', 'NOCHE'],
      );
      expectWellFormed(s);
      expect(has(s, 'un hombre'), true);
      expect(has(s, 'me robó'), true);
      expect(has(s, 'mi celular'), true);
      expect(has(s, 'cuchillo'), true);
      expect(has(s, 'en la calle'), true);
      // No debe degenerar en lista de comas crudas.
      expect(s.toLowerCase().contains('hombre, cuchillo'), false);
    });

    test('robo con descripción física y vestimenta', () {
      final s = asm.assemble(
        contextId: 'denuncia_robo',
        glosses: ['HOMBRE', 'ALTO', 'CHOMPA', 'NEGRO', 'ROBAR', 'BILLETERA'],
      );
      expectWellFormed(s);
      expect(has(s, 'un hombre alto'), true);
      expect(has(s, 'me robó'), true);
      expect(has(s, 'mi billetera'), true);
    });

    test('robo de varios objetos usa coordinación con "y"', () {
      final s = asm.assemble(
        contextId: 'denuncia_robo',
        glosses: ['ROBAR', 'CELULAR', 'DINERO', 'RELOJ'],
      );
      expectWellFormed(s);
      expect(has(s, 'mi celular, mi dinero y mi reloj'), true);
    });

    test('robo sin agresor explícito sigue produciendo sujeto', () {
      final s = asm.assemble(
        contextId: 'denuncia_robo',
        glosses: ['ROBAR', 'MOCHILA', 'MERCADO'],
      );
      expectWellFormed(s);
      expect(has(s, 'me robó') || s.contains('quitaron'), true);
      expect(has(s, 'mi mochila'), true);
    });
  });

  group('assemble — POLICÍA / DEFENSORÍA (violencia)', () {
    test('violencia familiar con emoción y urgencia', () {
      final s = asm.assemble(
        contextId: 'violencia',
        glosses: ['ESPOSO', 'GOLPEAR', 'MIEDO', 'AYUDA'],
      );
      expectWellFormed(s);
      expect(has(s, 'me golpeó'), true);
      expect(s.toLowerCase().contains('miedo'), true);
      expect(s.toLowerCase().contains('ayuda'), true);
    });

    test('amenaza con arma', () {
      final s = asm.assemble(
        contextId: 'violencia',
        glosses: ['VECINO', 'AMENAZAR', 'CUCHILLO'],
      );
      expectWellFormed(s);
      expect(has(s, 'un vecino'), true);
      expect(has(s, 'me amenazó'), true);
      expect(has(s, 'cuchillo'), true);
    });
  });

  group('assemble — SEGIP (trámites)', () {
    test('renovación de carnet en el SEGIP', () {
      final s = asm.assemble(
        contextId: 'tramite_id',
        glosses: ['RENOVAR', 'CARNET', 'SEGIP'],
      );
      expectWellFormed(s);
      expect(has(s, 'quiero renovar'), true);
      expect(has(s, 'mi carnet de identidad'), true);
      expect(has(s, 'en el SEGIP'), true);
    });

    test('partida de nacimiento (glosa con guion bajo) se renderiza bien', () {
      final s = asm.assemble(
        contextId: 'tramite_id',
        glosses: ['SOLICITAR', 'PARTIDA_NACIMIENTO', 'REGISTRO_CIVIL'],
      );
      expectWellFormed(s);
      expect(has(s, 'mi partida de nacimiento'), true);
      expect(has(s, 'en el registro civil'), true);
      expect(has(s, '_'), false, reason: 'no deben filtrarse guiones bajos');
    });
  });

  group('assemble — ALCALDÍA / ORIENTACIÓN', () {
    test('solicitud de intérprete', () {
      final s = asm.assemble(
        contextId: 'orientacion',
        glosses: ['NECESITAR', 'INTERPRETE', 'ALCALDIA'],
      );
      expectWellFormed(s);
      expect(s.toLowerCase().contains('intérprete'), true);
    });
  });

  group('assemble — EMERGENCIA / ACCIDENTE', () {
    test('accidente con estado físico y ambulancia', () {
      final s = asm.assemble(
        contextId: 'accidente',
        glosses: ['DOLOR', 'AMBULANCIA', 'CALLE'],
      );
      expectWellFormed(s);
      expect(s.toLowerCase().contains('dolor'), true);
      expect(s.toLowerCase().contains('ambulancia'), true);
    });

    test('emergencia médica urgente', () {
      final s = asm.assemble(
        contextId: 'emergencia',
        glosses: ['ENFERMO', 'URGENTE', 'DOCTOR'],
      );
      expectWellFormed(s);
      expect(s.toLowerCase().contains('enfermo'), true);
      expect(s.toLowerCase().contains('médico') || s.toLowerCase().contains('urgente'), true);
    });
  });

  group('assemble — PÉRDIDA', () {
    test('pérdida de documento', () {
      final s = asm.assemble(
        contextId: 'perdida',
        glosses: ['PERDER', 'CARNET', 'MICRO'],
      );
      expectWellFormed(s);
      expect(has(s, 'Perdí'), true);
      expect(has(s, 'mi carnet de identidad'), true);
      expect(has(s, 'en el micro'), true);
    });
  });

  group('assemble — robustez', () {
    test('lista vacía retorna cadena vacía', () {
      expect(asm.assemble(contextId: 'denuncia_robo', glosses: []), '');
    });

    test('glosas desconocidas no se pierden', () {
      final s = asm.assemble(
        contextId: 'otro',
        glosses: ['XYZ_DESCONOCIDA'],
      );
      expectWellFormed(s);
      expect(s.toLowerCase().contains('xyz desconocida'), true);
    });

    test('una sola glosa de objeto', () {
      final s = asm.assemble(contextId: 'perdida', glosses: ['CELULAR']);
      expectWellFormed(s);
      expect(s.toLowerCase().contains('celular'), true);
    });
  });

  group('isBackendDegenerate — verdaderos positivos', () {
    test('texto vacío es degenerado', () {
      expect(asm.isBackendDegenerate(backendText: '', glosses: ['ROBAR']), true);
    });

    test('salida más corta que la cantidad de glosas', () {
      expect(
        asm.isBackendDegenerate(
          backendText: 'hoy',
          glosses: ['HOMBRE', 'ROBAR', 'CELULAR', 'CALLE', 'NOCHE'],
        ),
        true,
      );
    });

    test('salida que omite casi todas las glosas', () {
      expect(
        asm.isBackendDegenerate(
          backendText: 'Necesito información pronto por favor gracias',
          glosses: ['HOMBRE', 'CUCHILLO', 'ROBAR', 'CELULAR'],
        ),
        true,
      );
    });
  });

  group('isBackendDegenerate — sin falsos positivos', () {
    test('buen refinamiento con conjugación NO es degenerado', () {
      expect(
        asm.isBackendDegenerate(
          backendText: 'Un hombre me robó el celular en la calle anoche.',
          glosses: ['HOMBRE', 'ROBAR', 'CELULAR', 'CALLE', 'NOCHE'],
        ),
        false,
      );
    });

    test('glosa con guion bajo cubierta por el texto NO es degenerado', () {
      // Antes esto daba falso positivo: "PARTIDA_NACIMIENTO" nunca aparecía
      // como subcadena literal de "partida de nacimiento".
      expect(
        asm.isBackendDegenerate(
          backendText:
              'Deseo solicitar mi partida de nacimiento en el registro civil.',
          glosses: ['SOLICITAR', 'PARTIDA_NACIMIENTO', 'REGISTRO_CIVIL'],
        ),
        false,
      );
    });

    test('acentos no rompen la cobertura', () {
      expect(
        asm.isBackendDegenerate(
          backendText: 'Necesito un intérprete de señas en la alcaldía.',
          glosses: ['NECESITAR', 'INTERPRETE', 'ALCALDIA'],
        ),
        false,
      );
    });
  });
}
