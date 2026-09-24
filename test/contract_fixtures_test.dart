import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lsb_legal_app/core/data/datasources/remote_translation_datasource.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';

/// Escribe el cuerpo **exacto** que el cliente enviaría, para que el backend
/// se pruebe contra él y no contra un JSON escrito a mano.
///
/// Los dos fallos más caros del contrato —`actorRole` frente a `actor_role`, y
/// la puerta que descartaba el `declaration` fuera de `denuncia_robo`—
/// sobrevivieron meses porque cada lado se probaba con su propio formato. Un
/// cambio de nombre en Dart rompía el backend sin que ninguna prueba se
/// enterara.
///
/// Estos ficheros los consume `aws/tests/test_contrato_cliente_real.py`. Si
/// el cliente cambia de forma, esta prueba los regenera y la de Python falla
/// donde corresponda, que es justo lo que se quiere.
const _dir = 'test/fixtures/contract';

void _write(String name, Map<String, dynamic> body) {
  final file = File('$_dir/$name.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert(body),
    flush: true,
  );
}

Map<String, dynamic> _body(DeclarationDraft draft, List<String> cards) =>
    RemoteTranslationDataSourceImpl.buildRequestBody(
      context: draft.contextId,
      cards: cards,
      declaration: draft.toJson(),
      speechAct: draft.speechAct,
    );

void main() {
  group('fixtures del contrato con el backend', () {
    test('robo y huida del sospechoso', () {
      final draft = DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: const [
          Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect),
          Fact(id: 'f2', action: 'ESCAPAR', actorRole: ActorRole.suspect),
        ],
        objects: const [
          ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
        ],
      );
      _write('robo_y_huida_sospechoso', _body(draft, ['ROBAR', 'ESCAPAR', 'CELULAR']));

      final json = draft.toJson();
      expect(json['facts'], hasLength(2),
          reason: 'Los dos hechos tienen que viajar, no solo el primero.');
      expect((json['facts'] as List)[1]['actorRole'], 'suspect');
    });

    test('robo y huida de la propia persona', () {
      final draft = DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: const [
          Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect),
          Fact(id: 'f2', action: 'ESCAPAR', actorRole: ActorRole.victim),
        ],
        objects: const [
          ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
        ],
      );
      _write('robo_y_huida_victima', _body(draft, ['ROBAR', 'ESCAPAR', 'CELULAR']));
    });

    test('solo huida: no es un robo', () {
      final draft = DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: const [
          Fact(id: 'f1', action: 'ESCAPAR', actorRole: ActorRole.victim),
        ],
      );
      _write('solo_escapar', _body(draft, ['ESCAPAR']));
    });

    test('pérdida sin acusación de robo', () {
      final draft = DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: const [
          Fact(id: 'f1', action: 'PERDER', lossType: 'loss'),
        ],
        objects: const [
          ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'lost'),
        ],
      );
      _write('solo_perder', _body(draft, ['PERDER', 'CELULAR']));
    });

    test('declaración estructurada fuera de denuncia_robo', () {
      final draft = DeclarationDraft(
        contextId: 'violencia',
        facts: const [
          Fact(id: 'f1', action: 'GOLPEAR', actorRole: ActorRole.suspect),
        ],
        violence: const ViolenceDetails(
          aggressionType: 'física',
          medicalCareRequested: true,
        ),
      );
      _write('violencia_estructurada', _body(draft, ['GOLPEAR']));
    });

    test('huida sin aclarar quién', () {
      final draft = DeclarationDraft(
        contextId: 'denuncia_robo',
        facts: const [
          Fact(id: 'f1', action: 'ROBAR', actorRole: ActorRole.suspect),
          Fact(id: 'f2', action: 'ESCAPAR'),
        ],
        objects: const [
          ObjectInvolved(id: 'o1', concept: 'CELULAR', role: 'stolen'),
        ],
      );
      _write('huida_sin_aclarar', _body(draft, ['ROBAR', 'ESCAPAR', 'CELULAR']));
    });

    test('borrador antiguo: un hecho con la huida dentro', () {
      // Lo que hay guardado en dispositivos con la versión anterior.
      final legacy = <String, dynamic>{
        'contextId': 'denuncia_robo',
        'speechAct': 'statement',
        'fact': {
          'action': 'ROBAR',
          'motiveConfirmed': true,
          'escapar_actor': 'sospechoso',
        },
        'objects': [
          {'id': 'o1', 'concept': 'CELULAR', 'role': 'stolen'},
        ],
      };
      final draft = DeclarationDraft.fromJson(legacy);

      expect(draft.facts, hasLength(2),
          reason: 'La huida era un hecho propio disfrazado de propiedad.');
      expect(draft.facts.first.action, 'ROBAR');
      expect(draft.facts.last.action, 'ESCAPAR');
      expect(draft.facts.last.actorRole, ActorRole.suspect);

      _write('borrador_antiguo_migrado', _body(draft, ['ROBAR', 'CELULAR']));
      _write('borrador_antiguo_tal_cual',
          RemoteTranslationDataSourceImpl.buildRequestBody(
            context: 'denuncia_robo',
            cards: ['ROBAR', 'CELULAR'],
            declaration: legacy,
            speechAct: 'statement',
          ));
    });
  });
}
