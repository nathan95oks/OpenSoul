import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/services/context_catalog.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';

/// Tres fallos vistos en ventanillas reales: la app admitía respuestas que en
/// el ámbito penal no sirven.
void main() {
  const asm = LocalSentenceAssembler();

  group('el número de expediente se deletrea', () {
    test('un caso sin número no identifica nada', () {
      expect(
        asm.assemble(
          contextId: 'orientacion',
          glosses: ['SEGUIMIENTO', 'CASO', '2', '0', '3', '9', '4'],
        ),
        contains('mi caso número 20394'),
      );
    });

    test('NUREJ y expediente también', () {
      expect(
        asm.assemble(
          contextId: 'orientacion',
          glosses: ['SEGUIMIENTO', 'NUREJ', '1', '0', '2', '4'],
        ),
        contains('número 1024'),
      );
      expect(
        asm.assemble(
          contextId: 'orientacion',
          glosses: ['PEDIR', 'EXPEDIENTE', '7', '7', '1'],
        ),
        contains('número 771'),
      );
    });

    test('sin número, la glosa sigue valiendo', () {
      final f = asm.assemble(
          contextId: 'orientacion', glosses: ['SEGUIMIENTO', 'CASO']);
      expect(f.toLowerCase(), contains('mi caso'));
      expect(f, isNot(contains('número')));
    });

    test('el identificador declara que pide dactilología alfanumérica', () {
      for (final g in ['CASO', 'CODIGO', 'NUREJ', 'WEBID', 'EXPEDIENTE']) {
        expect(LocalSentenceAssembler.etiquetaDeDetalle(g), 'numero',
            reason: '$g debe abrir el teclado');
      }
    });
  });

  group('la evidencia es concreta o no es evidencia', () {
    test('ninguna zona ofrece ya la glosa genérica', () {
      for (final ctx in allSelectableContexts) {
        for (final zona in ctx.zones) {
          expect(zona.glossAllowlist.contains('PRUEBA'), false,
              reason: 'en ${ctx.id}/${zona.id}: en un juzgado nadie declara '
                  '"tengo una prueba" sin decir cuál');
        }
      }
    });

    test('las concretas siguen ahí', () {
      final agravante = contextById('denuncia_robo')!.zoneById('evidencia') ??
          contextById('denuncia_robo')!
              .zones
              .firstWhere((z) => z.glossAllowlist.contains('FOTOGRAFIA'));
      expect(agravante.glossAllowlist, containsAll(['FOTOGRAFIA', 'MENSAJE']));
    });
  });

  group('la cadena de tiempo sigue intacta', () {
    test('unidad + cantidad compone en pasado', () {
      expect(
        asm.assemble(
          contextId: 'denuncia_robo',
          glosses: ['ROBAR', 'SEMANA', '3'],
        ).toLowerCase(),
        contains('hace tres semanas'),
      );
    });

    test('toda unidad combinable declara su cadena en la zona de tiempo', () {
      // Si una unidad no está en `chainTriggers`, la interfaz no abre el
      // selector y la cantidad se pierde: es el fallo que se vio en campo.
      final tiempo = contextById('denuncia_robo')!.zoneById('tiempo')!;
      for (final u in ['MINUTO', 'HORA', 'DIA', 'SEMANA', 'MES']) {
        expect(tiempo.chainTriggers.contains(u), true, reason: u);
        expect(tiempo.glossAllowlist.contains(u), true,
            reason: '$u debe poder elegirse para que la cadena arranque');
      }
    });
  });
}
