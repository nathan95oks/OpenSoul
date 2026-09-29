import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_zone.dart';
import 'package:lsb_legal_app/core/domain/guided/question_bank.dart';

/// Contextos que el banco declara en sus propios recorridos (`contexto`).
///
/// Un escenario nuevo se añade con datos: preguntas, un recorrido con sus
/// condiciones y el bloque `contexto` (nombre, familia, descripción, emoji)
/// en `docs/negocio/config/banco_preguntas.json`. El generador lo valida y
/// aquí se convierte en un [SemanticContext] que la app lista dentro de su
/// familia y que el grafo de conversación puede abrir, con el mismo flujo
/// guiado que los contextos escritos a mano. No hay pantalla ni árbol propio.
abstract final class BankContexts {
  /// Zona única de un contexto declarado: las respuestas vienen del banco.
  static const zoneId = 'recorrido';

  static List<SemanticContext> fromBank(QuestionBank bank) => [
    for (final j in bank.journeysWithContext) _contextOf(j),
  ];

  /// Identificadores de los contextos declarados en [familyId].
  static List<String> idsOfFamily(QuestionBank bank, String familyId) => [
    for (final j in bank.journeysWithContext)
      if (j.context!.familyId == familyId) j.id,
  ];

  /// Los del banco empaquetado con la app.
  static final List<SemanticContext> contexts = fromBank(
    QuestionBank.generated(),
  );

  static List<SemanticContext> ofFamily(String familyId) {
    final ids = idsOfFamily(QuestionBank.generated(), familyId).toSet();
    return [
      for (final c in contexts)
        if (ids.contains(c.id)) c,
    ];
  }

  static SemanticContext _contextOf(BankJourney journey) {
    final c = journey.context!;
    return SemanticContext(
      id: journey.id,
      name: c.name,
      icon: c.icon,
      emoji: c.emoji,
      description: c.description,
      entryZoneId: zoneId,
      zones: [
        SemanticZone(
          id: zoneId,
          label: c.name,
          hint: c.description,
          emoji: c.emoji,
          glossAllowlist: const ['SÍ', 'NO', 'NO_SABER'],
        ),
      ],
    );
  }
}
