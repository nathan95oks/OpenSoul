import 'package:lsb_legal_app/core/domain/entities/session_snapshot.dart';

/// Persistencia de la sesión entre arranques de la aplicación.
///
/// La interfaz vive en el dominio y la implementación en datos: el dominio
/// dice *qué* hace falta guardar, no *dónde*. Cambiar el almacenamiento no
/// toca nada de esta capa.
abstract class SessionRepository {
  /// Última sesión guardada, o `null` si no hay ninguna utilizable.
  Future<SessionSnapshot?> load();

  Future<void> save(SessionSnapshot snapshot);

  Future<void> clear();
}
