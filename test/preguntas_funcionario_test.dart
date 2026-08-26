import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/engines/context_engine/context_catalog.dart';
import 'package:lsb_legal_app/core/engines/context_engine/context_inference_engine.dart';
import 'package:lsb_legal_app/core/engines/context_engine/zone_inference_engine.dart';
import 'package:lsb_legal_app/core/engines/semantic_engine/local_sentence_assembler.dart';

import 'helpers/official_dictionary.dart';

/// Corpus penal judicial §4 y §6: el guion de una recepción de denuncia.
///
/// El funcionario hace trece preguntas y el ciudadano cinco. Cada una tiene
/// que llevar a la persona sorda al sitio exacto donde contestarla, y cada
/// respuesta tiene que salir redactada como la entiende un acta.
///
/// Estas pruebas nacen de un fallo en producción: "¿cómo te llamas?" abría
/// "¿Qué hecho presenciaste?" —el flujo de testigo—, porque la única palabra
/// que puntuaba era «como» y coincidía con el nombre del contexto «Declarar
/// **como** testigo». Con la máxima confianza posible, además: era el único
/// contexto con puntos, así que se llevaba el 100%.
void main() {
  late ContextInferenceEngine motor;
  const zonas = ZoneInferenceEngine();
  const asm = LocalSentenceAssembler();

  setUp(() => motor = ContextInferenceEngine.fromLexicon(loadOfficialEntries()));

  group('§4 — a qué contexto lleva cada pregunta del funcionario', () {
    const identidad = [
      '¿Cuál es su nombre completo?',
      '¿Cómo te llamas?',
      '¿Cómo se llama?',
      '¿Qué edad tiene?',
      '¿Cuántos años tienes?',
      '¿Puede mostrar su documento?',
      '¿Me da su carnet de identidad?',
      '¿Cuál es su apellido?',
    ];

    for (final pregunta in identidad) {
      test('«$pregunta» es Fase 1, no una declaración', () {
        final s = motor.infer(text: pregunta);
        expect(s?.contextId, 'identificacion', reason: pregunta);
      });
    }

    // Estas se contestan DENTRO del flujo en curso. Proponer contexto las
    // desviaba: "¿hay testigos?" invitaba a la víctima a declarar como
    // testigo, y "¿está herido?" convertía una urgencia en una consulta.
    const dentroDelFlujo = [
      '¿Qué ocurrió?',
      '¿Qué pasó?',
      '¿Cuándo ocurrió el hecho?',
      '¿Dónde ocurrió?',
      '¿Conoce a la persona involucrada?',
      '¿Puede describir a la persona?',
      '¿Hay testigos?',
      '¿Tiene fotografías o documentos?',
      '¿Está herido?',
      '¿Necesita atención médica?',
      '¿Desea realizar una denuncia?',
      '¿Necesita apoyo legal?',
    ];

    for (final pregunta in dentroDelFlujo) {
      test('«$pregunta» no cambia de contexto', () {
        expect(motor.infer(text: pregunta), isNull, reason: pregunta);
      });
    }
  });

  group('§4 — a qué zona lleva cada pregunta', () {
    const esperado = {
      '¿Cuándo ocurrió el hecho?': 'tiempo',
      '¿Dónde ocurrió?': 'lugar',
      '¿Conoce a la persona involucrada?': 'conocimiento',
      '¿Puede describir a la persona?': 'apariencia',
      '¿Hay testigos?': 'testigos',
      '¿Tiene fotografías o documentos?': 'pruebas',
      '¿Está herido?': 'emergencia',
      '¿Necesita atención médica?': 'emergencia',
      '¿Desea realizar una denuncia?': 'denuncia',
      '¿Necesita apoyo legal?': 'apoyo_legal',
      '¿Qué se llevaron?': 'objetos',
    };
    final robo = contextById('denuncia_robo')!;

    esperado.forEach((pregunta, zona) {
      test('«$pregunta» abre $zona', () {
        expect(zonas.zonesFor(context: robo, text: pregunta).first, zona,
            reason: pregunta);
      });
    });

    test('las preguntas de Fase 1 abren su zona', () {
      final ident = contextById('identificacion')!;
      const casos = {
        '¿Cuál es su nombre completo?': 'identidad',
        '¿Puede mostrar su documento?': 'identidad',
        '¿Qué edad tiene?': 'edad',
      };
      casos.forEach((pregunta, zona) {
        expect(zonas.zonesFor(context: ident, text: pregunta).first, zona,
            reason: pregunta);
      });
    });
  });

  group('§4 — cómo se redacta la respuesta', () {
    String robo(List<String> g) =>
        asm.assemble(contextId: 'denuncia_robo', glosses: g);

    test('conocer a la persona dice a quién se conoce', () {
      expect(robo(['SI', 'CONOCER']), contains('Sí conozco a esa persona'));
      expect(robo(['NO', 'CONOCER']), contains('No conozco a esa persona'));
      expect(robo(['DESCONOCER']), contains('No conozco a esa persona'));
    });

    test('un testigo NUNCA ocupa el sitio del agresor', () {
      // Como `personaDesc` el compositor lo tomaba por el autor del delito:
      // "Un testigo me asaltó" acusa de un robo a quien solo lo presenció.
      final f = robo(['ROBAR', 'TELEFONO', 'SI', 'TESTIGO']);
      expect(f, contains('Sí, hay un testigo'));
      expect(f.contains('testigo me'), false, reason: f);
    });

    test('que no haya testigos también es un dato del acta', () {
      expect(robo(['NO', 'TESTIGO']), contains('No hay testigos'));
      // Y nunca la contradicción de hoistar el NO como cortesía suelta.
      expect(robo(['NO', 'TESTIGO']).contains('No. Hay'), false);
    });

    test('la denuncia se consiente o se rechaza', () {
      expect(robo(['SI', 'DENUNCIAR']), contains('Sí quiero presentar una denuncia'));
      expect(robo(['NO', 'DENUNCIAR']), contains('No quiero presentar una denuncia'));
    });

    test('el apoyo legal se pide por su nombre', () {
      expect(robo(['ABOGADO']), contains('Necesito un abogado'));
      expect(robo(['INTERPRETE']), contains('intérprete'));
    });

    test('el relato completo mantiene cada respuesta en su sitio', () {
      final f = robo(['HOMBRE', 'ROBAR', 'TELEFONO', 'NO', 'CONOCER',
                      'SI', 'TESTIGO']);
      expect(f, contains('Un hombre me robó mi teléfono'));
      expect(f, contains('No conozco a esa persona'));
      expect(f, contains('Sí, hay un testigo'));
    });
  });

  group('§6 — las preguntas del ciudadano', () {
    String p(List<String> g) =>
        asm.assemble(contextId: 'preguntas', glosses: g);

    test('¿Dónde puedo presentar la denuncia?', () {
      expect(p(['DONDE', 'DENUNCIAR']), '¿Dónde puedo presentar una denuncia?');
    });

    test('¿Qué documentos necesito?', () {
      expect(p(['QUE', 'FORMULARIO']), '¿Qué documentos necesito?');
    });

    test('¿Cuándo debo volver?', () {
      expect(p(['CUANDO', 'VOLVER']), '¿Cuándo debo volver?');
    });

    test('¿Cómo puedo saber el avance del caso?', () {
      expect(p(['COMO', 'AVANCE']),
          '¿Cómo puedo saber el avance de la investigación?');
      expect(p(['COMO', 'CASO']), '¿Cómo puedo saber el estado de mi caso?');
    });

    test('¿Dónde está la Fiscalía / FELCC / FELCV?', () {
      expect(p(['DONDE', 'FISCALIA']), '¿Dónde está la Fiscalía?');
      expect(p(['DONDE', 'FELCC']), '¿Dónde está la FELCC?');
      expect(p(['DONDE', 'FELCV']), '¿Dónde está la FELCV?');
    });

    test('la pregunta va en primera persona: la formula quien la hace', () {
      // En segunda —"¿Qué documento necesitas?"— la aplicación le preguntaba
      // al funcionario por las necesidades DEL FUNCIONARIO.
      expect(p(['QUE', 'REQUISITO']), '¿Qué trámite necesito?');
    });
  });

  group('las zonas nuevas existen y solo ofrecen glosas del diccionario', () {
    test('cada glosa de las cuatro zonas nuevas está en el catálogo', () {
      final catalogo = {for (final e in loadOfficialEntries()) e.gloss};
      const nuevas = ['conocimiento', 'testigos', 'denuncia', 'apoyo_legal'];
      for (final ctx in allSelectableContexts) {
        for (final zona in ctx.zones.where((z) => nuevas.contains(z.id))) {
          for (final g in zona.glossAllowlist) {
            expect(catalogo, contains(g),
                reason: '${ctx.id}/${zona.id} ofrece $g, que no existe');
          }
        }
      }
    });
  });
}
