import 'package:lsb_legal_app/core/domain/entities/session_snapshot.dart';

/// Persistencia de la sesión entre arranques de la aplicación.
///
/// La interfaz vive en el dominio y la implementación en datos: el dominio
/// dice *qué* hace falta guardar, no *dónde*. Cambiar el almacenamiento no
/// toca nada de esta capa.
///
/// La configuración del dispositivo y el contenido de una atención se guardan
/// y se borran por separado. Finalizar una atención tiene que poder limpiar
/// lo que dijo una persona sin llevarse por delante el perfil de la
/// institución, y eso con un único almacén no se podía.
abstract class SessionRepository {
  Future<DeviceConfig> loadConfig();

  Future<void> saveConfig(DeviceConfig config);

  /// Contenido de la última sesión, o `null` si no hay ninguno utilizable.
  Future<SessionContent?> loadContent();

  Future<void> saveContent(SessionContent content);

  /// Borra lo dicho, conservando la configuración. Es lo que hace
  /// «Finalizar atención».
  Future<void> clearContent();

  /// Borra todo, incluida la configuración del dispositivo.
  Future<void> clearAll();
}
