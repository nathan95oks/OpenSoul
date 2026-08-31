/// Lo mínimo para devolver a alguien donde estaba tras cerrar la aplicación.
///
/// No guarda el flujo entero: las zonas semánticas y las tarjetas se derivan
/// del contexto y de la frase, así que con esos dos el resto se reconstruye
/// solo. Guardar estado derivado sería guardar dos veces lo mismo y arriesgar
/// que las copias dejen de coincidir.
class SessionSnapshot {
  /// Pestaña abierta en la barra inferior.
  final int tabIndex;

  /// Contexto semántico elegido, por id. `null` si aún no se eligió ninguno.
  final String? contextId;

  /// Glosas seleccionadas para la frase, en orden.
  final List<String> sentence;

  /// Si se estaba viendo la declaración terminada.
  final bool resultVisible;

  /// La conversación en curso, ya serializada.
  ///
  /// Se guarda opaca —tal cual la dejó la capa de datos— para que el dominio
  /// no tenga que conocer el formato de almacenamiento.
  final Map<String, dynamic>? conversation;

  const SessionSnapshot({
    this.tabIndex = 0,
    this.contextId,
    this.sentence = const [],
    this.resultVisible = false,
    this.conversation,
  });

  static const empty = SessionSnapshot();

  /// Una sesión sin contexto ni frase no merece restaurarse: devolver a la
  /// persona a una pantalla vacía no es continuidad, es ruido.
  bool get isWorthRestoring =>
      contextId != null || sentence.isNotEmpty || conversation != null;

  Map<String, dynamic> toJson() => {
        'tabIndex': tabIndex,
        'contextId': contextId,
        'sentence': sentence,
        'resultVisible': resultVisible,
        'conversation': conversation,
      };

  factory SessionSnapshot.fromJson(Map<String, dynamic> json) {
    return SessionSnapshot(
      tabIndex: (json['tabIndex'] as num?)?.toInt() ?? 0,
      contextId: json['contextId'] as String?,
      sentence: [
        for (final w in (json['sentence'] as List? ?? const [])) w.toString(),
      ],
      resultVisible: json['resultVisible'] == true,
      conversation: json['conversation'] is Map
          ? Map<String, dynamic>.from(json['conversation'] as Map)
          : null,
    );
  }
}
