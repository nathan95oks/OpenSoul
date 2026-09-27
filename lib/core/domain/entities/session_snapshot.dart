/// Lo mínimo para devolver a alguien donde estaba tras cerrar la aplicación.
///
/// No guarda el flujo entero: las zonas semánticas y las tarjetas se derivan
/// del contexto y de la frase, así que con esos dos el resto se reconstruye
/// solo. Guardar estado derivado sería guardar dos veces lo mismo y arriesgar
/// que las copias dejen de coincidir.
///
/// Se divide en dos piezas que se almacenan por separado, porque tienen
/// dueños y tiempos de vida distintos:
///
///   [DeviceConfig]     cómo está configurado el dispositivo. Sobrevive a
///                      finalizar una atención.
///   [SessionContent]   lo que dijo una persona concreta. Se borra al
///                      finalizar la atención.
///
/// Antes vivían juntos en una sola clave, así que en una ventanilla
/// compartida no había forma de limpiar al ciudadano anterior sin perder
/// también el perfil de la institución.
library;

/// Modo de uso elegido al entrar.
enum UsageMode {
  /// El teléfono de la propia persona sorda.
  personal,

  /// Un dispositivo que se usa durante una atención y pasa de mano en mano.
  counter;

  static UsageMode? byName(String? raw) {
    for (final m in UsageMode.values) {
      if (m.name == raw) return m;
    }
    return null;
  }
}

/// Configuración del dispositivo. No contiene nada dicho por nadie.
class DeviceConfig {
  /// La animación de bienvenida ya se mostró al menos una vez en este
  /// dispositivo.
  final bool hasOpened;

  /// `null` cuando todavía no se ha elegido: entonces toca el selector.
  final UsageMode? mode;

  /// Perfil institucional activo en modo ventanilla, por id.
  final String? institutionProfileId;

  /// Pestaña abierta, por identificador estable y no por posición.
  final String? lastTabId;

  static const int schemaVersion = 1;

  const DeviceConfig({
    this.hasOpened = false,
    this.mode,
    this.institutionProfileId,
    this.lastTabId,
  });

  static const empty = DeviceConfig();

  bool get hasMode => mode != null;

  DeviceConfig copyWith({
    bool? hasOpened,
    UsageMode? mode,
    String? institutionProfileId,
    String? lastTabId,
    bool clearInstitution = false,
  }) => DeviceConfig(
    hasOpened: hasOpened ?? this.hasOpened,
    mode: mode ?? this.mode,
    institutionProfileId: clearInstitution
        ? null
        : (institutionProfileId ?? this.institutionProfileId),
    lastTabId: lastTabId ?? this.lastTabId,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'hasOpened': hasOpened,
    if (mode != null) 'mode': mode!.name,
    if (institutionProfileId != null)
      'institutionProfileId': institutionProfileId,
    if (lastTabId != null) 'lastTabId': lastTabId,
  };

  factory DeviceConfig.fromJson(Map<String, dynamic> json) => DeviceConfig(
    // Una configuración de versiones anteriores solo puede existir si la
    // app ya fue abierta; no se repite el splash tras actualizar.
    hasOpened: json.containsKey('hasOpened') ? json['hasOpened'] == true : true,
    mode: UsageMode.byName(json['mode'] as String?),
    institutionProfileId: json['institutionProfileId'] as String?,
    lastTabId: json['lastTabId'] as String?,
  );
}

/// Lo que se dijo en una sesión personal o en una atención.
class SessionContent {
  /// Contexto semántico elegido, por id. `null` si aún no se eligió ninguno.
  final String? contextId;

  /// Glosas seleccionadas para la frase, en orden.
  final List<String> sentence;

  /// Si se estaba viendo la declaración terminada.
  final bool resultVisible;

  static const int schemaVersion = 1;

  const SessionContent({
    this.contextId,
    this.sentence = const [],
    this.resultVisible = false,
  });

  static const empty = SessionContent();

  /// Una sesión sin contexto ni frase no merece restaurarse: devolver a la
  /// persona a una pantalla vacía no es continuidad, es ruido.
  bool get isWorthRestoring => contextId != null || sentence.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'contextId': contextId,
    'sentence': sentence,
    'resultVisible': resultVisible,
  };

  factory SessionContent.fromJson(Map<String, dynamic> json) => SessionContent(
    contextId: json['contextId'] as String?,
    sentence: [
      for (final w in (json['sentence'] as List? ?? const [])) w.toString(),
    ],
    resultVisible: json['resultVisible'] == true,
  );
}
