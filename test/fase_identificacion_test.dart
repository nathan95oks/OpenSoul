import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/engines/context_engine/context_catalog.dart';
import 'package:lsb_legal_app/core/engines/context_engine/zone_inference_engine.dart';
import 'package:lsb_legal_app/core/engines/semantic_engine/local_sentence_assembler.dart';

/// Fase 1. Toda atención en ventanilla empieza por "¿cómo se llama?" y "¿qué
/// edad tiene?", y hasta ahora la persona sorda no tenía con qué contestarlo:
/// se quedaba bloqueada antes de llegar a su relato.
void main() {
  const asm = LocalSentenceAssembler();
  String f1(List<String> g) =>
      asm.assemble(contextId: 'identificacion', glosses: g);

  group('redacción de los datos', () {
    test('la edad se teclea entera, no dígito a dígito', () {
      expect(f1(['EDAD', '2', '5']), 'Tengo 25 años.');
    });

    test('EDAD y ANOS_EDAD son la misma respuesta y no se repiten', () {
      expect(f1(['EDAD', '2', '5', 'ANOS_EDAD']), 'Tengo 25 años.');
    });

    test('el nombre se deletrea y sale con inicial mayúscula', () {
      expect(f1(['NOMBRE', 'J', 'U', 'A', 'N']), 'Mi nombre es Juan.');
    });

    test('nombre y apellido conviven', () {
      final f = f1(['NOMBRE', 'J', 'U', 'A', 'N', 'APELLIDO', 'P', 'E', 'R', 'E', 'Z']);
      expect(f, contains('Mi nombre es Juan.'));
      expect(f, contains('Mi apellido es Perez.'));
    });

    test('el carnet lleva su número', () {
      expect(f1(['CARNET', '1', '2', '3', '4', '5']),
          contains('carnet de identidad número 12345'));
    });

    test('los datos completos, en el orden en que se dicen', () {
      expect(
        f1(['NOMBRE', 'J', 'U', 'A', 'N', 'EDAD', '2', '5', 'CARNET', '7', '8', '9']),
        'Mi nombre es Juan. Tengo 25 años. Mi carnet de identidad número 789.',
      );
    });

    test('sin preámbulo: el funcionario espera un dato', () {
      final f = f1(['NOMBRE', 'A', 'N', 'A']);
      expect(f.contains('Quiero comunicar'), false, reason: f);
      expect(f.contains('Necesito asistencia'), false, reason: f);
    });
  });

  group('los datos encabezan cualquier declaración', () {
    test('la identidad va antes del relato', () {
      final f = asm.assemble(
        contextId: 'denuncia_robo',
        glosses: ['NOMBRE', 'M', 'A', 'R', 'I', 'A', 'EDAD', '3', '0',
                  'ROBAR', 'TELEFONO'],
      );
      expect(f.startsWith('Mi nombre es Maria. Tengo 30 años.'), true, reason: f);
      expect(f, contains('me robó mi teléfono'));
    });

    test('NOMBRE ya no se confunde con el agresor', () {
      // Como `personaDesc` producía "mi nombre me robó".
      final f = asm.assemble(
          contextId: 'denuncia_robo', glosses: ['NOMBRE', 'ROBAR']).toLowerCase();
      expect(f.contains('mi nombre me rob'), false, reason: f);
    });
  });

  group('la interfaz sabe qué teclado abrir', () {
    test('la edad y el carnet son numéricos; el nombre, alfabético', () {
      expect(LocalSentenceAssembler.etiquetaDeDetalle('EDAD'), 'edad');
      expect(LocalSentenceAssembler.etiquetaDeDetalle('ANOS_EDAD'), 'edad');
      expect(LocalSentenceAssembler.etiquetaDeDetalle('CARNET'), 'carnet');
      expect(LocalSentenceAssembler.etiquetaDeDetalle('NOMBRE'), 'nombre');
      expect(LocalSentenceAssembler.etiquetaDeDetalle('APELLIDO'), 'apellido');
    });
  });

  group('el contexto y su inferencia', () {
    test('existe la familia de Fase 1 con sus dos zonas', () {
      final ctx = contextById('identificacion');
      expect(ctx, isNotNull);
      expect(ctx!.zoneById('identidad')!.glossAllowlist,
          containsAll(['NOMBRE', 'APELLIDO', 'CARNET', 'IDENTIDAD']));
      expect(ctx.zoneById('edad')!.glossAllowlist,
          containsAll(['EDAD', 'ANOS_EDAD']));
    });

    test('la pregunta del funcionario abre la zona correcta', () {
      const motor = ZoneInferenceEngine();
      final ctx = contextById('identificacion')!;
      for (final caso in {
        '¿Cuál es su nombre?': 'identidad',
        '¿Cómo se llama?': 'identidad',
        '¿Tiene su carnet?': 'identidad',
        '¿Qué edad tiene?': 'edad',
        '¿Cuántos años tiene?': 'edad',
      }.entries) {
        expect(motor.zonesFor(context: ctx, text: caso.key),
            contains(caso.value),
            reason: caso.key);
      }
    });
  });
}
