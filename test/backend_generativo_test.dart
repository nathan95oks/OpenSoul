import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';

/// Desde que el backend REDACTA en vez de pulir, su texto no coincide
/// literalmente con el lexicón local. Estas pruebas fijan la frontera de
/// confianza: qué comprueba cada lado y por qué.
void main() {
  const asm = LocalSentenceAssembler();
  const glosas = ['HOMBRE', 'ROBAR', 'MOCHILA', 'CALLE', 'HERIDA', 'AUXILIO'];

  test('una redacción natural NO pasa la comprobación literal del cliente', () {
    // Es el motivo de existir de `coverageValidated`: sin esa bandera, el
    // cliente descartaría un texto correcto solo por no ser el suyo.
    const natural = 'Quiero denunciar que un hombre me sustrajo mi mochila en '
        'la vía pública. Resulté con una herida y requiero auxilio.';
    expect(
      asm.isBackendDegenerate(backendText: natural, glosses: glosas),
      true,
      reason: 'si esto dejara de ser cierto, la bandera del servidor sobraría',
    );
  });

  test('el motor local sigue componiendo sin red', () {
    final local = asm.assemble(contextId: 'denuncia_robo', glosses: glosas);
    expect(local, contains('mi mochila'));
    expect(local, contains('en la calle'));
    expect(local, contains('auxilio'),
        reason: 'el respaldo offline no puede perder la urgencia');
  });

  test('la comprobación estricta sigue atrapando una omisión real', () {
    expect(
      asm.isBackendDegenerate(
        backendText: 'Un hombre me robó mi mochila en la calle.',
        glosses: glosas,
      ),
      true,
      reason: 'faltan HERIDA y AUXILIO',
    );
  });

  test('y sigue atrapando un volcado de glosas sin gramática', () {
    expect(
      asm.isBackendDegenerate(
        backendText: 'HOMBRE ROBAR MOCHILA CALLE HERIDA AUXILIO',
        glosses: glosas,
      ),
      true,
    );
  });
}
