import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';

/// Pruebas del generador estructurado de `denuncia_robo` (auditoría
/// 2026-09, sección 3 y 10 del prompt de auditoría). A diferencia de
/// `local_sentence_assembler_test.dart` (bolsa de palabras heredada), estas
/// pruebas alimentan directamente el [DeclarationDraft] con relaciones ya
/// explícitas, como llegaría desde los nuevos editores de entidades.
void main() {
  const assembler = LocalSentenceAssembler();

  test('PERDER nunca atribuye la pérdida a otra persona ni conjuga mal', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'PERDER')],
      objects: const [
        ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'lost'),
      ],
    );
    final texto = assembler.assembleStructured(draft);
    expect(texto.toLowerCase(), contains('perdí'));
    expect(texto.toLowerCase(), isNot(contains('me robó')));
    expect(texto.toLowerCase(), isNot(contains('una persona')));
  });

  test('CERCA + Mi casa produce la referencia esperada', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'ROBAR')],
      objects: const [
        ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
      ],
      location: const LocationInfo(relation: 'CERCA', referenceType: 'home'),
    );
    final texto = assembler.assembleStructured(draft);
    expect(texto.toLowerCase(), contains('cerca de mi casa'));
  });

  test('FUERA + Otro lugar conserva el texto literal con mayúsculas y espacios', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'ROBAR')],
      objects: const [
        ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
      ],
      location: const LocationInfo(
        relation: 'FUERA',
        referenceType: 'other',
        referenceLiteralText: 'Mercado Calatayud',
      ),
    );
    final texto = assembler.assembleStructured(draft);
    expect(texto, contains('fuera de Mercado Calatayud'));
  });

  test('CERCA sin referencia (pendiente) no inventa un lugar vago', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'ROBAR')],
      objects: const [
        ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
      ],
      location: const LocationInfo(relation: 'CERCA'),
    );
    final texto = assembler.assembleStructured(draft);
    expect(texto.toLowerCase(), isNot(contains('cerca')));
    expect(texto.toLowerCase(), isNot(contains('lugar')));
  });

  test('DENTRO + micro (tarjeta) no lo convierte en objeto robado', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'ROBAR')],
      objects: const [
        ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
      ],
      location: const LocationInfo(
        relation: 'DENTRO',
        referenceType: 'conceptCard',
        referenceConceptGloss: 'MICRO',
      ),
    );
    final texto = assembler.assembleStructured(draft);
    final lower = texto.toLowerCase();
    expect(lower, contains('dentro de un micro'));
    expect(lower, isNot(contains('me robó un micro')));
  });

  test('Un micro como vehículo robado sí es un objeto sustraído', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'ROBAR')],
      objects: const [
        ObjectInvolved(id: 'o1', concept: 'MICRO', role: 'stolen'),
      ],
    );
    final texto = assembler.assembleStructured(draft);
    expect(texto.toLowerCase(), contains('me robó un micro'));
  });

  test('Polera roja y pantalón negro: cada color pertenece a su prenda', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'ROBAR')],
      persons: [
        PersonEntity(
          id: 'p1',
          role: 'suspect',
          gender: 'HOMBRE',
          height: 'ALTO',
          clothing: const [
            ClothingItem(
                id: 'c1',
                personId: 'p1',
                concept: 'POLERA',
                color: 'ROJO',
                colorState: ConfirmationState.confirmed),
            ClothingItem(
                id: 'c2',
                personId: 'p1',
                concept: 'PANTALÓN',
                color: 'NEGRO',
                colorState: ConfirmationState.confirmed),
          ],
        ),
      ],
      objects: const [
        ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
      ],
    );
    final texto = assembler.assembleStructured(draft);
    final lower = texto.toLowerCase();
    expect(lower, contains('polera roja'));
    expect(lower, contains('pantalón negro'));
    // Ni la polera ni el pantalón del sospechoso deben figurar como botín.
    expect(lower, contains('me robó mi celular.'));
  });

  test('Segunda persona con polera azul mantiene los atributos separados', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'ROBAR')],
      persons: [
        PersonEntity(
          id: 'p1',
          role: 'suspect',
          gender: 'HOMBRE',
          clothing: const [
            ClothingItem(
                id: 'c1',
                personId: 'p1',
                concept: 'POLERA',
                color: 'ROJO',
                colorState: ConfirmationState.confirmed),
          ],
        ),
        PersonEntity(
          id: 'p2',
          role: 'suspect',
          gender: 'MUJER',
          clothing: const [
            ClothingItem(
                id: 'c2',
                personId: 'p2',
                concept: 'POLERA',
                color: 'AZUL',
                colorState: ConfirmationState.confirmed),
          ],
        ),
      ],
      objects: const [
        ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
      ],
    );
    final texto = assembler.assembleStructured(draft);
    final lower = texto.toLowerCase();
    expect(lower, contains('polera roja'));
    expect(lower, contains('polera azul'));
  });

  test('Mochila robada y mochila que llevaba otra persona son entidades distintas', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'ROBAR')],
      persons: const [
        PersonEntity(id: 'p1', role: 'suspect', gender: 'HOMBRE'),
      ],
      objects: const [
        ObjectInvolved(id: 'o1', concept: 'MOCHILA', role: 'stolen'),
        ObjectInvolved(
            id: 'o2',
            concept: 'MOCHILA',
            role: 'carriedByOtherPerson',
            carriedByPersonId: 'p1'),
      ],
    );
    final texto = assembler.assembleStructured(draft);
    final lower = texto.toLowerCase();
    expect(lower, contains('me robó'));
    expect(lower, contains('llevaba una mochila'));
  });

  test('No conoce a la persona y sí hay testigos: ambas polaridades sin mezclarse', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'ROBAR')],
      objects: const [
        ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
      ],
      witnesses: const WitnessInfo(existence: ConfirmationState.confirmed, count: '2'),
    );
    final texto = assembler.assembleStructured(draft);
    expect(texto.toLowerCase(), contains('hay 2 testigos'));
  });

  test('No sabe si hay testigos no redacta que no hay', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'ROBAR')],
      objects: const [
        ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
      ],
      witnesses: const WitnessInfo(existence: ConfirmationState.uncertain),
    );
    final texto = assembler.assembleStructured(draft);
    final lower = texto.toLowerCase();
    expect(lower, contains('no sé si hay testigos'));
    expect(lower, isNot(contains('no hay testigos')));
  });

  test('500 bolivianos en billetes conserva monto y unidad', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      facts: [Fact(id: 'f1', action: 'ROBAR')],
      objects: const [
        ObjectInvolved(
            id: 'o1', concept: 'BILLETES', role: 'stolen', quantity: '500', unit: 'bolivianos'),
      ],
    );
    final texto = assembler.assembleStructured(draft);
    expect(texto, contains('500 bolivianos en billetes'));
  });

  test('Sin hecho confirmado no afirma un robo solo por estar en este menú', () {
    final draft = DeclarationDraft(
      contextId: 'denuncia_robo',
      witnesses: const WitnessInfo(existence: ConfirmationState.negated),
    );
    final texto = assembler.assembleStructured(draft);
    expect(texto.toLowerCase(), isNot(contains('robó')));
    expect(texto.toLowerCase(), contains('no hay testigos'));
  });
}
