import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';

/// Qué sabe conservar el backend que hay al otro lado.
///
/// El contrato v3 manda una **colección** de hechos. Una Lambda anterior lee
/// `declaration.fact` —un objeto único— y no mira `declaration.facts`: acepta
/// la petición, responde 200, y redacta habiendo perdido el segundo hecho y
/// el protagonista de cada uno. No devuelve error, así que sin una compuerta
/// el fallo es invisible: la persona ve una frase plausible a la que le falta
/// la mitad de lo que declaró.
///
/// Por eso «no devuelve error» no es compatibilidad.
enum BackendCapability {
  /// Conserva la colección de hechos. Contrato v3.
  factsCollection,

  /// Solo entiende `declaration.fact`. Contrato v2.
  singleFact,

  /// Todavía no se sabe: aún no ha respondido nadie.
  unknown,
}

/// Decide qué se puede enviar sin perder significado.
class BackendCompatibility {
  const BackendCompatibility._();

  /// Contrato que habla este cliente.
  static const int clientContractVersion = 3;

  /// Lee la capacidad de la respuesta del servidor.
  ///
  /// Un backend v3 devuelve `contractVersion` en su respuesta. Si no viene,
  /// se asume el anterior: suponer lo mejor es justo lo que hace perder datos.
  static BackendCapability fromResponse(Map<String, dynamic> body) {
    final version = body['contractVersion'];
    if (version is num && version >= 3) return BackendCapability.factsCollection;
    if (version is num) return BackendCapability.singleFact;
    return BackendCapability.singleFact;
  }

  /// Si se puede enviar [draft] sin que el backend pierda parte de lo dicho.
  ///
  /// Un solo hecho cabe en los dos contratos. Dos, no.
  static bool canSendWithoutLoss(
    DeclarationDraft draft,
    BackendCapability capability,
  ) {
    if (capability == BackendCapability.factsCollection) return true;
    return draft.facts.length <= 1;
  }

  /// Qué se perdería al enviar, para poder decirlo.
  ///
  /// **No se reduce en silencio a un hecho.** Perder «y escapó» sin avisar es
  /// cambiar la declaración de alguien.
  static List<String> wouldLose(
    DeclarationDraft draft,
    BackendCapability capability,
  ) {
    if (canSendWithoutLoss(draft, capability)) return const [];
    return [
      for (final f in draft.facts.skip(1)) f.action,
    ];
  }
}
