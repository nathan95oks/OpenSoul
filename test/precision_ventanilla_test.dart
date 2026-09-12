import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/services/context_catalog.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';

/// Pruebas de precisión en ventanilla judicial penal.
void main() {
  const asm = LocalSentenceAssembler();

  group('el número de expediente y datos se deletrean', () {
    test('un número de carnet o celular se concatena adecuadamente', () {
      expect(
        asm.assemble(
          contextId: 'identificacion',
          glosses: ['CELULAR', '7', '0', '3', '9', '4'],
        ),
        contains('70394'),
      );
    });

    test('los identificadores declaran que piden dactilología', () {
      for (final g in ['IDENTIDAD', 'CELULAR', 'NOMBRE', 'APELLIDO', 'PAPEL']) {
        expect(LocalSentenceAssembler.etiquetaDeDetalle(g), isNotNull,
            reason: '$g debe abrir el teclado dactilológico');
      }
    });
  });

  group('la evidencia es concreta o no es evidencia', () {
    test('ninguna zona ofrece ya la glosa genérica inventada', () {
      for (final ctx in allSelectableContexts) {
        for (final zona in ctx.zones) {
          expect(zona.glossAllowlist.contains('PRUEBA'), false,
              reason: 'en ${ctx.id}/${zona.id}: en un juzgado nadie declara '
                  '"tengo una prueba" sin decir cuál');
        }
      }
    });

    test('las evidencias concretas del corpus están disponibles', () {
      final pruebas = contextById('denuncia_robo')!.zoneById('pruebas') ??
          contextById('denuncia_robo')!
              .zones
              .firstWhere((z) => z.glossAllowlist.contains('FOTOS'));
      expect(pruebas.glossAllowlist, containsAll(['FOTOS', 'VIDEO', 'FACTURA']));
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
      final tiempo = contextById('denuncia_robo')!.zoneById('tiempo')!;
      for (final u in ['MINUTO', 'HORA', 'DÍA', 'SEMANA', 'MES']) {
        expect(tiempo.chainTriggers.contains(u), true, reason: u);
        expect(tiempo.glossAllowlist.contains(u), true,
            reason: '$u debe poder elegirse para que la cadena arranque');
      }
    });
  });
}

