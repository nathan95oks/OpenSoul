import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/data/datasources/backend_capability.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_translation_datasource.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';

/// «No devolvió error» no es compatibilidad.
///
/// El contrato v3 manda una colección de hechos. Una Lambda anterior lee
/// `declaration.fact` —un objeto único— y no mira `declaration.facts`: acepta
/// la petición, responde 200 y redacta habiendo perdido el segundo hecho y el
/// protagonista de cada uno. Sin compuerta, el fallo es invisible: la persona
/// ve una frase plausible a la que le falta la mitad de lo que declaró.
const _dosHechos = DeclarationDraft(
  contextId: 'denuncia_robo',
  facts: [
    Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect),
    Fact(id: 'f2', action: 'ESCAPAR', actorRole: ActorRole.victim),
  ],
);

const _unHecho = DeclarationDraft(
  contextId: 'denuncia_robo',
  facts: [Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect)],
);

void main() {
  group('se lee la capacidad del servidor', () {
    test('un backend v3 anuncia que conserva la colección', () {
      expect(BackendCompatibility.fromResponse({'contractVersion': 3}),
          BackendCapability.factsCollection);
    });

    test('un backend anterior se reconoce por su versión', () {
      expect(BackendCompatibility.fromResponse({'contractVersion': 2}),
          BackendCapability.singleFact);
    });

    test('sin anuncio se asume el anterior, no el mejor caso', () {
      expect(BackendCompatibility.fromResponse({'baseSentence': 'x'}),
          BackendCapability.singleFact,
          reason: 'Suponer lo mejor es justo lo que hace perder datos.');
    });

    test('el cliente declara el contrato que habla', () {
      expect(BackendCompatibility.clientContractVersion, 4);
      expect(RemoteTranslationDataSourceImpl.contractVersion, 4);
    });
  });

  group('la compuerta impide perder un hecho en silencio', () {
    test('dos hechos no caben en un backend antiguo', () {
      expect(
        BackendCompatibility.canSendWithoutLoss(
            _dosHechos, BackendCapability.singleFact),
        isFalse,
      );
      expect(
        BackendCompatibility.wouldLose(
            _dosHechos, BackendCapability.singleFact),
        ['ESCAPAR'],
        reason: 'Hay que poder decir exactamente qué se perdería.',
      );
    });

    test('un hecho cabe en los dos contratos', () {
      for (final cap in BackendCapability.values) {
        expect(BackendCompatibility.canSendWithoutLoss(_unHecho, cap), isTrue,
            reason: cap.name);
        expect(BackendCompatibility.wouldLose(_unHecho, cap), isEmpty);
      }
    });

    test('con un backend v3 no se pierde nada', () {
      expect(
        BackendCompatibility.canSendWithoutLoss(
            _dosHechos, BackendCapability.factsCollection),
        isTrue,
      );
      expect(
        BackendCompatibility.wouldLose(
            _dosHechos, BackendCapability.factsCollection),
        isEmpty,
      );
    });

    test('no se reduce a un hecho por su cuenta', () {
      // La compuerta informa; no recorta el borrador.
      final antes = _dosHechos.facts.length;
      BackendCompatibility.wouldLose(_dosHechos, BackendCapability.singleFact);
      expect(_dosHechos.facts.length, antes);
    });

    test('un borrador sin hechos no dispara la compuerta', () {
      const vacio = DeclarationDraft(contextId: 'denuncia_robo');
      expect(
        BackendCompatibility.canSendWithoutLoss(
            vacio, BackendCapability.singleFact),
        isTrue,
      );
    });
  });
}
