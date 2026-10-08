import 'package:flutter_test/flutter_test.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/conversation/semantic_turn.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';

/// Lo que viaja entre la app y las Lambdas, o se guarda en el teléfono: si
/// la ida y vuelta pierde un campo, se rompe el contrato o la restauración.
void main() {
  group('aclaraciones del backend', () {
    test('desambiguación y pregunta pendiente se leen completas', () {
      final d = SemanticDisambiguation.fromJson(const {
        'original': 'banco',
        'meaning': 'BANCO (entidad)',
        'reason': 'habla de dinero',
      });
      expect(
        [d.original, d.meaning, d.reason],
        ['banco', 'BANCO (entidad)', 'habla de dinero'],
      );

      final p = PendingClarification.fromJson(const {
        'term': 'banco',
        'question': '¿Qué banco?',
        'options': [
          {'id': 'entidad', 'label': 'Entidad'},
          {'id': 'asiento', 'label': 'Asiento'},
        ],
      });
      expect(p.term, 'banco');
      expect(p.question, '¿Qué banco?');
      expect(
        [for (final o in p.options) '${o.id}:${o.label}'],
        ['entidad:Entidad', 'asiento:Asiento'],
      );
    });

    test('sin campos no falla: queda vacío', () {
      expect(SemanticDisambiguation.fromJson(const {}).original, '');
      expect(PendingClarification.fromJson(const {}).options, isEmpty);
      expect(ClarificationOption.fromJson(const {}).label, '');
    });
  });

  group('ruta propuesta por el modelo', () {
    test('se lee la forma de ruta', () {
      final r = ConversationRoute.fromModelJson(const {
        'routeType': 'DIRECT_QUESTION',
        'targetFamilyId': 'denuncias',
        'targetContextId': 'denuncia_robo',
        'targetQuestionIds': [' Q.LUG.DONDE ', '', 3],
        'requestedSlots': ['place'],
        'confidence': 1.7,
        'routeSource': 'cache',
      })!;
      expect(r.type, ConversationRouteType.directQuestion);
      expect(r.targetQuestionIds, ['Q.LUG.DONDE']);
      expect(r.confidence, 1.0);
      expect(r.source, RouteSource.cache);
      expect(r.toString(), contains('DIRECT_QUESTION'));
    });

    test('una ruta que trae respuestas no es una ruta', () {
      for (final key in ConversationRoute.answerKeys) {
        expect(
          ConversationRoute.fromModelJson({
            'routeType': 'DIRECT_QUESTION',
            key: const ['si'],
          }),
          isNull,
          reason: key,
        );
      }
    });

    test('un tipo desconocido no es una ruta', () {
      expect(
        ConversationRoute.fromModelJson(const {'routeType': 'OTRA_COSA'}),
        isNull,
      );
      expect(
        ConversationRouteType.parse('directQuestion'),
        ConversationRouteType.directQuestion,
      );
      expect(ConversationRouteType.parse(null), isNull);
    });
  });

  group('lectura semántica del backend', () {
    test('ida y vuelta sin perder la familia ni las negaciones', () {
      const original = BackendSemanticTurn(
        version: 2,
        intent: SemanticIntent.mentionContext,
        requestedSlots: ['time'],
        mentionedContexts: [
          ContextMention(id: 'denuncias', isFamily: true, evidence: ['QUEJAR']),
          ContextMention(
            id: 'violencia',
            isFamily: false,
            evidence: ['violaci'],
          ),
        ],
        negations: ['NO'],
        confidence: 0.8,
      );
      final vuelta = BackendSemanticTurn.fromJson(original.toJson())!;
      expect(vuelta.toJson(), original.toJson());
      expect(vuelta.mentionedContexts.first.isFamily, isTrue);
    });

    test('sin intención no hay lectura; una desconocida es unknown', () {
      expect(BackendSemanticTurn.fromJson(const {'version': 1}), isNull);
      expect(BackendSemanticTurn.fromJson('texto'), isNull);
      expect(SemanticIntent.parse('inventada'), SemanticIntent.unknown);
    });
  });

  test('una tarjeta LSB vuelve igual de su JSON', () {
    final card = LsbCard(
      id: 'c1',
      gloss: 'CELULAR',
      displayText: 'Celular',
      iconUrl: 'celular.png',
      imageFrames: 2,
      categoryId: 'Objetos',
      subcategoryId: 'tecnologia',
      contexts: ['denuncia_robo'],
      priority: 3,
      suggestedNextCardIds: ['c2'],
      isFrequent: true,
      isEmergency: false,
      animationFile: 'celular.glb',
    );
    final vuelta = LsbCard.fromJson(card.toJson());
    expect(vuelta.toJson(), card.toJson());
  });
}
